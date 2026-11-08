import 'package:file_selector/file_selector.dart';

class LocalMedia {
  const LocalMedia(this.uri, this.name);
  final Uri uri;
  final String name;
}

Future<LocalMedia?> pickLocalMedia() async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(
        label: '视频和音频',
        extensions: [
          'mp4',
          'mkv',
          'mov',
          'avi',
          'webm',
          'm4v',
          'mp3',
          'flac',
          'wav',
          'm4a',
          'ts',
        ],
        mimeTypes: ['video/*', 'audio/*'],
        uniformTypeIdentifiers: ['public.movie', 'public.audio'],
      ),
      XTypeGroup(label: '所有文件'),
    ],
  );
  if (file == null) return null;
  final uri = file.path.startsWith('content://')
      ? Uri.parse(file.path)
      : Uri.file(file.path);
  return LocalMedia(uri, file.name);
}
