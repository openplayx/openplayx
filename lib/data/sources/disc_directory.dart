import 'dart:io';

/// Native main-title playback for complete, unencrypted local disc trees.
/// Menus/BD-J and encrypted commercial discs are outside this entry point.
Future<Uri?> discDirectoryUri(String path) async {
  Future<bool> file(String p) async =>
      await FileSystemEntity.type(p, followLinks: false) ==
      FileSystemEntityType.file;
  Future<bool> directory(String p) async =>
      await FileSystemEntity.type(p, followLinks: false) ==
      FileSystemEntityType.directory;
  if (!await directory(path)) return null;
  final name =
      Directory(path).uri.pathSegments.where((s) => s.isNotEmpty).lastOrNull ??
      '';
  final bd = name == 'BDMV' ? path : '$path/BDMV';
  final dvd = name == 'VIDEO_TS' ? path : '$path/VIDEO_TS';
  if (await file('$bd/index.bdmv') &&
      await file('$bd/MovieObject.bdmv') &&
      await directory('$bd/PLAYLIST') &&
      await directory('$bd/CLIPINF') &&
      await directory('$bd/STREAM')) {
    return Uri.file(Directory(bd).parent.path).replace(scheme: 'bluray');
  }
  if (await file('$dvd/VIDEO_TS.IFO') &&
      await file('$dvd/VIDEO_TS.BUP') &&
      await file('$dvd/VTS_01_0.IFO') &&
      await file('$dvd/VTS_01_1.VOB')) {
    return Uri.file(Directory(dvd).parent.path).replace(scheme: 'dvd');
  }
  return null;
}
