import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/audio/audio_session_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // audio_session 仅在 Android / iOS / macOS 有实现，桌面端跳过会话配置。
  if (!Platform.isWindows && !Platform.isLinux) {
    await configureAudioSession();
  }
  runApp(const ProviderScope(child: CueBoxApp()));
}
