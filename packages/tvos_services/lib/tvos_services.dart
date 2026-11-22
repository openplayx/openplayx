import 'package:flutter/services.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';

/// tvOS has no system document picker. Browse the app's real writable storage
/// with a remote-compatible native file/folder picker instead.
class TVOSFileSelector extends FileSelectorPlatform {
  static const _channel = MethodChannel('openplayx/tvos');
  static void registerWith() =>
      FileSelectorPlatform.instance = TVOSFileSelector();
  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final path = await _channel.invokeMethod<String>('pickFile', {
      'extensions': [
        for (final group in acceptedTypeGroups ?? <XTypeGroup>[])
          ...?group.extensions,
      ],
    });
    return path == null ? null : XFile(path);
  }

  @override
  Future<List<XFile>> openFiles({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final file = await openFile(
      acceptedTypeGroups: acceptedTypeGroups,
      initialDirectory: initialDirectory,
      confirmButtonText: confirmButtonText,
    );
    return file == null ? [] : [file];
  }

  @override
  Future<String?> getDirectoryPath({
    String? initialDirectory,
    String? confirmButtonText,
  }) => _channel.invokeMethod<String>('pickDirectory');
  @override
  Future<List<String>> getDirectoryPaths({
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final path = await getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: confirmButtonText,
    );
    return path == null ? [] : [path];
  }

  @override
  Future<String?> getSavePath({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? suggestedName,
    String? confirmButtonText,
  }) async {
    final folder = await getDirectoryPath(
      initialDirectory: initialDirectory,
      confirmButtonText: confirmButtonText,
    );
    if (folder == null) return null;
    final name = suggestedName ?? 'export';
    if (name.contains('/') || name.contains('\\') || name == '..')
      throw ArgumentError('Invalid filename');
    return '$folder/$name';
  }
}
