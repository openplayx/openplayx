import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Apple TV only permits writes in Caches and tmp. tvOS may purge this data;
/// source configuration and library indexes must be recoverable from a server.
Future<Directory> appSupportDirectory() async {
  if (Platform.operatingSystem == 'tvos') {
    return Directory(
      '${(await getApplicationCacheDirectory()).path}/OpenPlayX',
    );
  }
  return getApplicationSupportDirectory();
}
