import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const feedback = Duration(milliseconds: 150);
  // Player controls fading in/out over video.
  static const controls = Duration(milliseconds: 300);
  static const panel = Duration(milliseconds: 200);
  static const page = Duration(milliseconds: 380);
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}
