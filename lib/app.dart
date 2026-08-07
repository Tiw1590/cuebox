import 'package:flutter/material.dart';

import 'core/theme.dart';
import 'features/home/home_shell.dart';

class CueBoxApp extends StatelessWidget {
  const CueBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CueBox',
      debugShowCheckedModeBanner: false,
      theme: buildCueBoxTheme(),
      home: const HomeShell(),
    );
  }
}
