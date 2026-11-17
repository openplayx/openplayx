import 'package:flutter/services.dart';

enum PlayerScreenOrientation {
  system([]),
  portrait([DeviceOrientation.portraitUp]),
  landscape([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  const PlayerScreenOrientation(this.orientations);
  final List<DeviceOrientation> orientations;
}
