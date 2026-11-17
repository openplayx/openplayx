import 'package:openplayx/core/capabilities/source_capability.dart';
import 'package:openplayx/data/sources/source_config.dart';
import 'package:openplayx/capabilities/sources/source_manager.dart';

/// One SMB connection `s` ("NAS") whose every folder holds `Film.mp4`.
class Sources extends SourceManager {
  @override
  List<SourceConfig> get configs => [
    const SourceConfig(
      id: 's',
      kind: SourceKind.smb,
      name: 'NAS',
      address: 'smb://host/share',
    ),
  ];
  @override
  Future<void> load() async {}
  @override
  Future<void> reload() async {}
  @override
  Future<BrowseResult> browse(String id, BrowseRequest request) async =>
      const BrowseResult([
        SourceEntry(
          ResourceRef('s', '/share/film.mp4'),
          'Film.mp4',
          isFolder: false,
        ),
      ]);
}
