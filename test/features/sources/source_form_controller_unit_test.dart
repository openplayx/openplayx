import 'package:flutter_test/flutter_test.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';
import 'package:openplayx/data/remote_access/remote_config.dart';
import 'package:openplayx/data/sources/dlna_source.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/data/sources/source_sign_in.dart';
import 'package:openplayx/features/sources/controller/source_form_controller.dart';

class _TestManager extends SourceManager {
  @override
  Future<void> load() async {}
  @override
  Future<String?> storedSecret(String id) async => 'stored-secret';
}

void main() {
  test('SourceFormController handles kinds, normalization, presets, DLNA and edit init', () {
    final failures = <String>[];
    final manager = _TestManager();

    final initial = SourceConfig(
      id: 'smb-1',
      name: 'NAS',
      kind: SourceKind.smb,
      address: 'smb://192.168.1.5/movies',
      username: 'alice',
      domain: 'WORKGROUP',
      remote: const SourceRemote(
        proxy: 'nas-smb',
        mode: RemoteConnectionMode.automatic,
        localAddress: 'https://192.168.1.5:445',
      ),
    );
    final edit = SourceFormController(
      manager: manager,
      initial: initial,
      onFailure: failures.add,
    );
    addTearDown(edit.dispose);

    expect(edit.kind, SourceKind.smb);
    expect(edit.address.text, '192.168.1.5');
    expect(edit.path.text, 'movies');
    expect(edit.username.text, 'alice');
    expect(edit.domain.text, 'WORKGROUP');
    expect(edit.remoteEnabled, isTrue);
    expect(edit.remoteProxy, 'nas-smb');
    expect(edit.connectionMode, RemoteConnectionMode.automatic);

    edit.changeKind(SourceKind.webdav);
    edit.address.text = 'https://dav.example.com:8443/media/videos';
    edit.normalizeAddress();
    expect(edit.https, isTrue);
    expect(edit.address.text, 'dav.example.com');
    expect(edit.port.text, '8443');
    expect(edit.path.text, 'media/videos');

    edit.setHttps(false);
    expect(edit.https, isFalse);
    expect(edit.port.text, isEmpty);

    edit.toggleAdvanced();
    expect(edit.advanced, isTrue);

    final preset = SourcePreset.byId('jianguoyun');
    if (preset != null) {
      edit.changePreset(preset);
      expect(edit.preset, preset);
    }

    edit.changeKind(SourceKind.plex);
    edit.setManualPlex(true);
    expect(edit.manualPlex, isTrue);
    final server = PlexServer(
      id: 'p1',
      name: 'Home Plex',
      token: 'tok',
      connections: [Uri.parse('http://192.168.1.10:32400')],
    );
    edit.selectServer(server);
    expect(edit.server, server);

    edit.changeKind(SourceKind.dlna);
    final dev = DlnaDevice(
      'Living Room',
      Uri.parse('http://192.168.1.20:8200/rootDesc.xml'),
    );
    edit.selectDevice(dev);
    expect(edit.device, dev);
    expect(edit.address.text, dev.location.toString());

    for (final k in [
      SourceKind.ftp,
      SourceKind.sftp,
      SourceKind.s3,
      SourceKind.jellyfin,
      SourceKind.emby,
      SourceKind.local,
    ]) {
      edit.changeKind(k);
      expect(edit.kind, k);
    }
  });
}
