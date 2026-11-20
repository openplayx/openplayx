import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../../core/capabilities/source_capability.dart';
import '../../l10n/l10n.dart';
import 'source_config.dart';

/// Public application IDs are supplied by the publisher, never by end users.
class CloudOAuthApp {
  CloudOAuthApp(this.kind, {String? clientId, Uri? redirect, Uri? broker})
    : broker =
          broker ??
          Uri.tryParse(const String.fromEnvironment('BAIDU_OAUTH_BROKER')),
      clientId =
          clientId ??
          (kind == SourceKind.baidu
              ? const String.fromEnvironment('BAIDU_CLIENT_ID')
              : kind == SourceKind.onedrive
              ? const String.fromEnvironment('ONEDRIVE_CLIENT_ID')
              : const String.fromEnvironment('DROPBOX_CLIENT_ID')),
      redirect =
          redirect ??
          Uri.parse(
            kind == SourceKind.baidu
                ? 'com.openplayx.app://oauth/baidu'
                : kind == SourceKind.onedrive
                ? const String.fromEnvironment(
                    'ONEDRIVE_REDIRECT_URI',
                    defaultValue: 'com.openplayx.app://oauth/onedrive',
                  )
                : const String.fromEnvironment(
                    'DROPBOX_REDIRECT_URI',
                    defaultValue: 'com.openplayx.app://oauth/dropbox',
                  ),
          );
  final Uri? broker;
  bool get configured =>
      clientId.isNotEmpty &&
      (kind != SourceKind.baidu ||
          (broker != null &&
              broker!.scheme == 'https' &&
              broker!.host.isNotEmpty &&
              broker!.userInfo.isEmpty &&
              !broker!.hasQuery &&
              !broker!.hasFragment));
  final SourceKind kind;
  final String clientId;
  final Uri redirect;
  Uri get authorize => kind == SourceKind.baidu
      ? broker!.resolve(
          '${broker!.path.replaceFirst(RegExp(r"/+$"), "")}/authorize',
        )
      : Uri.parse(
          kind == SourceKind.onedrive
              ? 'https://login.microsoftonline.com/consumers/oauth2/v2.0/authorize'
              : 'https://www.dropbox.com/oauth2/authorize',
        );
  Uri get token => kind == SourceKind.baidu
      ? broker!.resolve(
          '${broker!.path.replaceFirst(RegExp(r"/+$"), "")}/token',
        )
      : Uri.parse(
          kind == SourceKind.onedrive
              ? 'https://login.microsoftonline.com/consumers/oauth2/v2.0/token'
              : 'https://api.dropboxapi.com/oauth2/token',
        );
  String get scope => kind == SourceKind.baidu
      ? 'basic,netdisk'
      : kind == SourceKind.onedrive
      ? 'Files.Read offline_access'
      : 'files.metadata.read files.content.read';
}

class CloudTokens {
  const CloudTokens(this.accessToken, this.refreshToken, this.expiresAt);
  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;
  bool get needsRefresh =>
      expiresAt.isBefore(DateTime.now().add(const Duration(minutes: 2)));
  String encode() => jsonEncode({
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
  });
  factory CloudTokens.decode(String value) {
    try {
      final j = jsonDecode(value) as Map<String, dynamic>;
      return CloudTokens(
        j['accessToken'] as String,
        j['refreshToken'] as String,
        DateTime.parse(j['expiresAt'] as String),
      );
    } catch (_) {
      throw PluginException('authRequired', appStrings.cloudReauthorize);
    }
  }
}

/// One attempt owns its state and verifier. Never logs tokens or callback URLs.
class CloudOAuthAttempt {
  CloudOAuthAttempt(this.app) : state = _random(), verifier = _random();
  final CloudOAuthApp app;
  final String state;
  final String verifier;
  static String _random() =>
      base64UrlEncode(List.generate(32, (_) => Random.secure().nextInt(256)))
          .replaceAll('=', '');
  Uri get loginUri => app.authorize.replace(
    queryParameters: {
      'client_id': app.clientId,
      'response_type': 'code',
      'redirect_uri': app.redirect.toString(),
      'state': state,
      'scope': app.scope,
      'code_challenge_method': 'S256',
      'code_challenge': base64UrlEncode(
        sha256.convert(ascii.encode(verifier)).bytes,
      ).replaceAll('=', ''),
      if (app.kind == SourceKind.dropbox) 'token_access_type': 'offline',
      if (app.kind == SourceKind.onedrive) 'prompt': 'select_account',
    },
  );
  String? code(Uri callback) {
    if (callback.scheme != app.redirect.scheme ||
        callback.host != app.redirect.host ||
        callback.port != app.redirect.port ||
        callback.path != app.redirect.path ||
        callback.hasFragment ||
        callback.queryParametersAll.values.any((v) => v.length != 1) ||
        callback.queryParameters['state'] != state) {
      throw PluginException('authRequired', appStrings.cloudCallbackInvalid);
    }
    if (callback.queryParameters['error'] == 'access_denied') return null;
    final value = callback.queryParameters['code'];
    if (callback.queryParameters.containsKey('error') ||
        value == null ||
        value.isEmpty) {
      throw PluginException('authRequired', appStrings.cloudSignInFailed);
    }
    return value;
  }
}

class CloudOAuth {
  static Future<CloudTokens?> signIn(SourceKind kind) async {
    final app = CloudOAuthApp(kind);
    if (!Platform.isMacOS && !Platform.isIOS && !Platform.isAndroid) {
      throw PluginException('unsupported', appStrings.cloudNotConfigured);
    }
    if (!app.configured) {
      throw PluginException('unsupported', appStrings.cloudNotConfigured);
    }
    final attempt = CloudOAuthAttempt(app);
    try {
      final callback = await FlutterWebAuth2.authenticate(
        url: attempt.loginUri.toString(),
        callbackUrlScheme: app.redirect.scheme,
        options: const FlutterWebAuth2Options(
          preferEphemeral: true,
          useWebview: false,
        ),
      );
      final code = attempt.code(Uri.parse(callback));
      if (code == null) return null;
      return await exchange(app, {
        'grant_type': 'authorization_code',
        'code': code,
        'code_verifier': attempt.verifier,
        'redirect_uri': app.redirect.toString(),
      });
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED' || e.code == 'cancelled') return null;
      throw PluginException('authRequired', appStrings.cloudSignInFailed);
    }
  }

  static Future<CloudTokens> refresh(SourceKind kind, CloudTokens old) =>
      exchange(CloudOAuthApp(kind), {
        'grant_type': 'refresh_token',
        'refresh_token': old.refreshToken,
      }, previous: old);

  static Future<CloudTokens> exchange(
    CloudOAuthApp app,
    Map<String, String> fields, {
    CloudTokens? previous,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    try {
      if (!app.configured) {
        throw PluginException('unsupported', appStrings.cloudNotConfigured);
      }
      final request = await client
          .postUrl(app.token)
          .timeout(const Duration(seconds: 30));
      request.followRedirects = false;
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      request.write(
        Uri(
          queryParameters: {
            'client_id': app.clientId,
            ...fields,
            if (app.kind == SourceKind.onedrive) 'scope': app.scope,
          },
        ).query,
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        if (response.statusCode == 503 && app.kind == SourceKind.baidu) {
          throw PluginException('unsupported', appStrings.cloudNotConfigured);
        }
        if (response.statusCode == 429 || response.statusCode >= 500) {
          throw PluginException(
            'networkUnavailable',
            appStrings.errSourceUnreachable,
            retryable: true,
          );
        }
        throw PluginException('authRequired', appStrings.cloudReauthorize);
      }
      final body = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 30));
      final j = jsonDecode(body) as Map<String, dynamic>;
      final access = j['access_token'] as String? ?? '';
      final refresh =
          j['refresh_token'] as String? ?? previous?.refreshToken ?? '';
      if (access.isEmpty ||
          refresh.isEmpty ||
          j['expires_in'] is! num ||
          (j['expires_in'] as num) <= 0) {
        throw PluginException('authRequired', appStrings.cloudReauthorize);
      }
      return CloudTokens(
        access,
        refresh,
        DateTime.now().add(Duration(seconds: (j['expires_in'] as num).toInt())),
      );
    } on SocketException {
      throw PluginException(
        'networkUnavailable',
        appStrings.errSourceUnreachable,
        retryable: true,
      );
    } on TimeoutException {
      throw PluginException(
        'networkUnavailable',
        appStrings.errConnectTimeout,
        retryable: true,
      );
    } on FormatException {
      throw PluginException(
        'networkUnavailable',
        appStrings.errSourceUnreachable,
        retryable: true,
      );
    } finally {
      client.close(force: true);
    }
  }
}

/// Shared by the host for one account instance; merges concurrent refreshes.
class CloudTokenSession {
  CloudTokenSession(
    this.kind,
    this.tokens, {
    required this.persist,
    this.refresh,
  });
  final SourceKind kind;
  CloudTokens tokens;
  final Future<void> Function(CloudTokens) persist;
  final Future<CloudTokens> Function(CloudTokens)? refresh;
  Future<String>? _refreshing;
  bool _closed = false;
  bool get isClosed => _closed;
  final closeListeners = <void Function()>{};
  void close() {
    if (_closed) return;
    _closed = true;
    for (final listener in closeListeners.toList()) {
      listener();
    }
    closeListeners.clear();
  }

  Future<String> access({bool force = false, String? rejectedToken}) async {
    if (_closed) {
      throw PluginException('cancelled', appStrings.errInstanceChanged);
    }
    if (_refreshing != null) return _refreshing!;
    if (force && rejectedToken != null && tokens.accessToken != rejectedToken) {
      return tokens.accessToken;
    }
    if (!force && !tokens.needsRefresh) return tokens.accessToken;
    return _refreshing = (() async {
      try {
        final next =
            await (refresh?.call(tokens) ?? CloudOAuth.refresh(kind, tokens));
        if (_closed) {
          throw PluginException('cancelled', appStrings.errInstanceChanged);
        }
        await persist(next);
        tokens = next;
        return next.accessToken;
      } finally {
        _refreshing = null;
      }
    })();
  }
}
