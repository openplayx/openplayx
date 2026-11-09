import 'package:flutter/material.dart';

import 'app/app_shell.dart';

void main() => runApp(const OpenPlayXApp());

class OpenPlayXApp extends StatelessWidget {
  const OpenPlayXApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'OpenPlayX',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF67D9BD),
    ),
    home: const AppShell(),
  );
}
