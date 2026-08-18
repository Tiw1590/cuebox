import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

const kThemeModePrefsKey = 'app.themeMode';

/// 启动时恢复上次选择的主题（在 runApp 之前调用）。
///
/// 兼容旧版本：早期保存的 "light"（明亮主题）已并入 "glass"。
Future<void> restoreThemeMode() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(kThemeModePrefsKey);
  if (saved == null) return;
  if (saved == 'light') {
    setCueBoxTheme(CueBoxThemeMode.glass);
    await prefs.setString(kThemeModePrefsKey, CueBoxThemeMode.glass.name);
    return;
  }
  final mode = CueBoxThemeMode.values.where((m) => m.name == saved).firstOrNull;
  if (mode != null) setCueBoxTheme(mode);
}

/// 主题模式控制器：切换并持久化主题选择。
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, CueBoxThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<CueBoxThemeMode> {
  @override
  CueBoxThemeMode build() => currentThemeMode;

  Future<void> setMode(CueBoxThemeMode mode) async {
    setCueBoxTheme(mode);
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kThemeModePrefsKey, mode.name);
  }
}
