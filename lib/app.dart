import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'core/theme_controller.dart';
import 'features/home/home_shell.dart';

class CueBoxApp extends ConsumerWidget {
  const CueBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听主题模式：MaterialApp 的 theme 跟随变化。
    // 注意：不使用 key 强制整树重建（那会重置导航栈、切主题弹回主页），
    // 改为由各常驻页面 watch 主题来刷新静态取色。
    final mode = ref.watch(themeModeProvider);

    // 状态栏/导航栏图标颜色跟随主题：
    // 深色主题用浅色图标（白），浅色主题用深色图标（黑）。
    // MaterialApp 会从 appBarTheme.systemOverlayStyle 读取并应用，
    // AnnotatedRegion 作为兜底保证所有页面（含 push 出的路由）一致。
    final dark = mode == CueBoxThemeMode.dark;
    final overlayStyle = (dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MaterialApp(
        title: 'CueBox',
        debugShowCheckedModeBanner: false,
        theme: buildCueBoxTheme(mode),
        home: const HomeShell(),
      ),
    );
  }
}
