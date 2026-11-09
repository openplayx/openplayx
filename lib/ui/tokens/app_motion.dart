import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const feedback = Duration(milliseconds: 150);
  static const panel = Duration(milliseconds: 200);
  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}
