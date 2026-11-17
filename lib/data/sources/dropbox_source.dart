import '../../core/capabilities/source_capability.dart';
import '../../l10n/l10n.dart';
import 'cloud_file_source.dart';

class DropboxSource extends CloudFileSource {
  DropboxSource(super.config, super.session, {super.client, super.ownsSession});
  @override
  String get apiHost => 'api.dropboxapi.com';
  Future<Map<String, dynamic>> rpc(String route, Map<String, dynamic> body) =>
      api(Uri.https(apiHost, '/2/$route'), body: body, post: true);
  @override
  Future<CloudFile> root() async => config.cloudRootId.isEmpty
      ? const CloudFile('', '/', folder: true)
      : metadata(config.cloudRootId);
  CloudFile _file(Map<String, dynamic> j) {
    final path = j['path_lower'] as String?;
    final slash = path?.lastIndexOf('/') ?? -1;
    return CloudFile(
      j['id'] as String,
      j['name'] as String,
      folder: j['.tag'] == 'folder',
      size: (j['size'] as num?)?.toInt(),
      parent: slash <= 0 ? '' : path!.substring(0, slash),
    );
  }

  @override
  Future<CloudFile> metadata(String id) async {
    if (id.isEmpty) return const CloudFile('', '/', folder: true);
    // Parent lookup uses a path only to discover its stable ID. References
    // accepted from callers must always use Dropbox's stable id: form.
    if (!id.startsWith('id:') && !id.startsWith('/')) {
      throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
    }
    final result = _file(await rpc('files/get_metadata', {'path': id}));
    final parentPath = result.parent;
    String? parent;
    if (parentPath != null && parentPath.isNotEmpty) {
      parent =
          (await rpc('files/get_metadata', {'path': parentPath}))['id']
              as String;
    } else {
      parent = '';
    }
    return CloudFile(
      result.id,
      result.name,
      folder: result.folder,
      size: result.size,
      parent: parent,
    );
  }

  @override
  Future<CloudFile> checked(String? id) {
    if (id != null && id.isNotEmpty && !id.startsWith('id:')) {
      throw PluginException('permissionDenied', appStrings.errPathOutsideRoot);
    }
    return super.checked(id);
  }

  @override
  Future<(List<CloudFile>, String?)> children(String id, String? cursor) async {
    final result = cursor == null
        ? await rpc('files/list_folder', {
            'path': id,
            'recursive': false,
            'include_deleted': false,
            'limit': 200,
          })
        : await rpc('files/list_folder/continue', {'cursor': cursor});
    return (
      (result['entries'] as List)
          .cast<Map<String, dynamic>>()
          .where((j) => j['.tag'] == 'folder' || j['.tag'] == 'file')
          .map(_file)
          .toList(),
      result['has_more'] == true ? result['cursor'] as String : null,
    );
  }

  @override
  Future<Uri> download(String id) async => Uri.parse(
    (await rpc('files/get_temporary_link', {'path': id}))['link'] as String,
  );
}
