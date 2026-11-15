import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A failed web request. [code] is short and safe to show to the model.
class WebException implements Exception {
  const WebException(this.code);
  final String code;
  @override
  String toString() => 'WebException($code)';
}

/// A bounded HTTP response body.
class WebResponse {
  const WebResponse({
    required this.url,
    required this.status,
    required this.contentType,
    required this.body,
  });

  /// Final URL after redirects.
  final Uri url;
  final int status;
  final ContentType? contentType;
  final String body;
}

/// Public-internet-only HTTP for the assistant's web tools.
///
/// Every connection — including each redirect hop — resolves the host
/// itself, rejects loopback, private, link-local, CGNAT, multicast and other
/// non-public addresses, and then connects to the checked address, so a DNS
/// answer cannot change between the check and the connect. For HTTPS the TLS
/// handshake still verifies the certificate against the original host name.
///
/// Web pages and search results can carry prompt injections; without this a
/// model could be steered into reading the user's router, NAS or LAN
/// services and leaking them through a later search query.
class SafeHttp {
  SafeHttp({
    this.allowPrivate = false,
    this.timeout = const Duration(seconds: 15),
    this.maxBytes = 3 << 20,
    this.maxRedirects = 5,
  });

  /// Tests only: lets requests reach a loopback server.
  final bool allowPrivate;
  final Duration timeout;
  final int maxBytes;
  final int maxRedirects;

  static const userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/130.0 Safari/537.36';

  /// Whether [address] is a public unicast internet address.
  static bool isPublic(InternetAddress address) {
    if (address.type == InternetAddressType.unix) return false;
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return false;
    }
    var b = address.rawAddress;
    if (b.length == 16) {
      // IPv4-mapped (::ffff:a.b.c.d) and IPv4-compatible (::a.b.c.d).
      final prefixZero = b.sublist(0, 10).every((x) => x == 0);
      if (prefixZero &&
          ((b[10] == 0xff && b[11] == 0xff) || (b[10] == 0 && b[11] == 0))) {
        if (b.sublist(10).every((x) => x == 0)) return false; // :: / ::1
        b = b.sublist(12);
      } else {
        if (b.every((x) => x == 0)) return false; // ::
        if ((b[0] & 0xfe) == 0xfc) return false; // fc00::/7 unique local
        if (b[0] == 0xfe && (b[1] & 0xc0) == 0xc0) return false; // fec0::/10
        if (b[0] == 0x20 && b[1] == 0x01 && b[2] == 0x0d && b[3] == 0xb8) {
          return false; // 2001:db8::/32 documentation
        }
        if (b[0] == 0x00 && b[1] == 0x64 && b[2] == 0xff && b[3] == 0x9b) {
          // 64:ff9b::/96 NAT64: judge the embedded IPv4 address.
          b = b.sublist(12);
        } else {
          return true;
        }
      }
    }
    if (b.length != 4) return false;
    final (a0, a1) = (b[0], b[1]);
    return !(a0 == 0 || // 0.0.0.0/8
        a0 == 10 ||
        a0 == 127 ||
        (a0 == 100 && a1 >= 64 && a1 < 128) || // CGNAT
        (a0 == 169 && a1 == 254) ||
        (a0 == 172 && a1 >= 16 && a1 < 32) ||
        (a0 == 192 && a1 == 168) ||
        (a0 == 192 && a1 == 0 && b[2] == 0) || // 192.0.0.0/24
        (a0 == 198 && (a1 == 18 || a1 == 19)) || // benchmarking
        a0 >= 224); // multicast, reserved, broadcast
  }

  Future<InternetAddress> _resolve(String host) async {
    final literal = InternetAddress.tryParse(host);
    final List<InternetAddress> addresses;
    try {
      addresses = literal != null
          ? [literal]
          : await InternetAddress.lookup(host).timeout(timeout);
    } on SocketException {
      throw const WebException('dnsFailed');
    } on TimeoutException {
      throw const WebException('timeout');
    }
    if (addresses.isEmpty) throw const WebException('dnsFailed');
    if (allowPrivate) return addresses.first;
    // Any non-public answer rejects the host: no "first public" picking.
    if (!addresses.every(isPublic)) throw const WebException('blockedAddress');
    return addresses.first;
  }

  Future<ConnectionTask<Socket>> _connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    final address = await _resolve(uri.host);
    final secure = uri.scheme == 'https';
    final port = uri.hasPort ? uri.port : (secure ? 443 : 80);
    final socket = Socket.connect(address, port, timeout: timeout).then<Socket>(
      (s) async => secure ? await SecureSocket.secure(s, host: uri.host) : s,
    );
    return ConnectionTask.fromSocket(socket, () {});
  }

  /// GETs (or POSTs a form to) [uri] and returns at most [maxBytes] of the
  /// body decoded as text. Only http(s) on default or explicit ports.
  Future<WebResponse> request(
    Uri uri, {
    Map<String, String> headers = const {},
    Map<String, String>? form,
    Object? json,
    bool Function()? active,
  }) async {
    if (!(uri.isScheme('http') || uri.isScheme('https')) || uri.host.isEmpty) {
      throw const WebException('unsupportedUrl');
    }
    if (uri.userInfo.isNotEmpty) throw const WebException('unsupportedUrl');
    final client = HttpClient()
      ..connectionTimeout = timeout
      ..idleTimeout = const Duration(seconds: 5)
      ..userAgent = userAgent
      ..findProxy = ((_) => 'DIRECT')
      ..connectionFactory = _connect;
    try {
      final post = form != null || json != null;
      final req = await (post ? client.postUrl(uri) : client.getUrl(uri))
          .timeout(timeout);
      req.followRedirects = true;
      req.maxRedirects = maxRedirects;
      req.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,text/plain;q=0.9,*/*;q=0.5',
      );
      headers.forEach(req.headers.set);
      if (form != null) {
        req.headers.contentType = ContentType(
          'application',
          'x-www-form-urlencoded',
          charset: 'utf-8',
        );
        req.write(Uri(queryParameters: form).query);
      } else if (json != null) {
        req.headers.contentType = ContentType.json;
        req.add(utf8.encode(jsonEncode(json)));
      }
      final res = await req.close().timeout(timeout);
      final bytes = <int>[];
      await for (final chunk in res.timeout(timeout)) {
        if (active != null && !active()) throw const WebException('cancelled');
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          bytes.length = maxBytes;
          break;
        }
      }
      final finalUrl = res.redirects.isEmpty
          ? uri
          : uri.resolveUri(res.redirects.last.location);
      return WebResponse(
        url: finalUrl,
        status: res.statusCode,
        contentType: res.headers.contentType,
        body: _decode(bytes, res.headers.contentType?.charset),
      );
    } on WebException {
      rethrow;
    } on RedirectException {
      throw const WebException('tooManyRedirects');
    } on TimeoutException {
      throw const WebException('timeout');
    } on HandshakeException {
      throw const WebException('tlsFailed');
    } on SocketException {
      throw const WebException('connectionFailed');
    } on HttpException {
      throw const WebException('connectionFailed');
    } finally {
      client.close(force: true);
    }
  }

  static String _decode(List<int> bytes, String? charset) {
    final cs = charset?.toLowerCase().trim();
    if (cs == 'iso-8859-1' || cs == 'latin1' || cs == 'us-ascii') {
      return latin1.decode(bytes, allowInvalid: true);
    }
    // UTF-8 for everything else; other legacy encodings (GBK, Shift_JIS)
    // degrade to replacement characters rather than failing.
    return utf8.decode(bytes, allowMalformed: true);
  }
}
