import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// 主题风格。
enum CueBoxThemeMode {
  /// 深色（默认）：舞台暗光、高对比。
  dark('深色', '舞台暗光 · 高对比', Icons.dark_mode_rounded),

  /// 浅色：清爽通透的浅色玻璃质感（Liquid Glass 风格）。
  glass('浅色', '柔和通透 · 玻璃质感', Icons.light_mode_rounded);

  const CueBoxThemeMode(this.label, this.subtitle, this.icon);

  final String label;
  final String subtitle;
  final IconData icon;
}

/// 一套完整的配色。
class CueBoxPalette {
  const CueBoxPalette({
    required this.background,
    required this.backgroundTop,
    required this.surface,
    required this.surfaceHigh,
    required this.surfacePressed,
    required this.primary,
    required this.primaryDeep,
    required this.secondary,
    required this.amber,
    required this.danger,
    required this.success,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.border,
    required this.borderStrong,
    required this.navBar,
  });

  final Color background;
  final Color backgroundTop;
  final Color surface;
  final Color surfaceHigh;
  final Color surfacePressed;
  final Color primary;
  final Color primaryDeep;
  final Color secondary;
  final Color amber;
  final Color danger;
  final Color success;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color border;
  final Color borderStrong;
  final Color navBar;
}

const _darkPalette = CueBoxPalette(
  background: Color(0xFF080B12),
  backgroundTop: Color(0xFF121D31),
  surface: Color(0xFF121926),
  surfaceHigh: Color(0xFF1C2634),
  surfacePressed: Color(0xFF263342),
  primary: Color(0xFF38E1FF),
  primaryDeep: Color(0xFF0EA5D8),
  secondary: Color(0xFFA78BFA),
  amber: Color(0xFFFFC24B),
  danger: Color(0xFFFF6B6B),
  success: Color(0xFF4ADE80),
  textPrimary: Color(0xFFE8EEF5),
  textSecondary: Color(0xFF93A6BB),
  textFaint: Color(0xFF5F7186),
  border: Color(0x26FFFFFF),
  borderStrong: Color(0x38FFFFFF),
  navBar: Color(0xE60C111B),
);

/// 浅色主题（Liquid Glass 风格）：半透明玻璃表面、柔和蓝紫渐变、
/// 白色高光描边，主色采用 Apple 系统蓝 / 紫 / 橙。
const _glassPalette = CueBoxPalette(
  background: Color(0xFFF2EEFF), // 底部：淡紫白
  backgroundTop: Color(0xFFD9E9FF), // 顶部：天蓝
  surface: Color(0xBCFFFFFF), // 74% 白玻璃，透出下层渐变
  surfaceHigh: Color(0xD9FFFFFF), // 85% 白，更实
  surfacePressed: Color(0x99FFFFFF),
  primary: Color(0xFF0A84FF), // Apple 蓝
  primaryDeep: Color(0xFF0059D6),
  secondary: Color(0xFFAF52DE), // Apple 紫
  amber: Color(0xFFFF9F0A), // Apple 橙
  danger: Color(0xFFFF3B30), // Apple 红
  success: Color(0xFF34C759), // Apple 绿
  textPrimary: Color(0xFF1D1D1F), // Apple 墨色
  textSecondary: Color(0xFF5F6672),
  textFaint: Color(0xFF9AA3AF),
  border: Color(0x73FFFFFF), // 白色高光描边
  borderStrong: Color(0xA6FFFFFF),
  navBar: Color(0xE6EDF4FF), // 半透明玻璃导航
);

CueBoxThemeMode _mode = CueBoxThemeMode.dark;

/// 当前主题模式（由主题控制器切换，页面取色用）。
CueBoxThemeMode get currentThemeMode => _mode;

/// 设置当前主题风格。
void setCueBoxTheme(CueBoxThemeMode mode) {
  _mode = mode;
}

/// 各风格对应的调色板（设置页预览也用）。
CueBoxPalette paletteForMode(CueBoxThemeMode mode) => switch (mode) {
  CueBoxThemeMode.dark => _darkPalette,
  CueBoxThemeMode.glass => _glassPalette,
};

CueBoxPalette get _palette => paletteForMode(_mode);

/// CueBox 设计令牌：随主题动态取色。
abstract final class CueBoxColors {
  static Color get background => _palette.background;
  static Color get backgroundTop => _palette.backgroundTop;
  static Color get surface => _palette.surface;
  static Color get surfaceHigh => _palette.surfaceHigh;
  static Color get surfacePressed => _palette.surfacePressed;

  static Color get primary => _palette.primary;
  static Color get primaryDeep => _palette.primaryDeep;
  static Color get secondary => _palette.secondary;
  static Color get amber => _palette.amber;
  static Color get danger => _palette.danger;
  static Color get success => _palette.success;

  static Color get textPrimary => _palette.textPrimary;
  static Color get textSecondary => _palette.textSecondary;
  static Color get textFaint => _palette.textFaint;
  static Color get border => _palette.border;
  static Color get borderStrong => _palette.borderStrong;

  /// 主色 / 强调渐变之上的前景文字色（按钮、图标等）。
  static Color get onAccent => _mode == CueBoxThemeMode.dark
      ? const Color(0xFF002A36)
      : Colors.white;

  /// 播放中高亮色：柔和的淡蓝色，比主色更安静、不刺眼。
  static Color get playHighlight => switch (_mode) {
    CueBoxThemeMode.dark => const Color(0xFF7CC5F0),
    CueBoxThemeMode.glass => const Color(0xFF6FB6E8),
  };

    /// 当前是否为浅色玻璃主题。
    static bool get isGlass => _mode == CueBoxThemeMode.glass;

    /// 玻璃表面顶部高光（浅色更亮，深色保留极微弱的冷光）。
    static Color get glassSheen => isGlass
        ? Colors.white.withValues(alpha: 0.65)
        : Colors.white.withValues(alpha: 0.03);

    /// 卡片阴影颜色：玻璃主题用 Apple 蓝的柔光，深色用黑色氛围。
    static Color get cardShadowColor => isGlass
        ? const Color(0x2E0A84FF)
        : const Color(0x73000000);

    /// 柔和环境阴影。
    static BoxShadow get ambientShadow => BoxShadow(
          color: cardShadowColor,
          blurRadius: isGlass ? 32 : 16,
          spreadRadius: isGlass ? -4 : -2,
          offset: Offset(0, isGlass ? 10 : 6),
        );

    /// 选中态 / 播放态辉光，用于列表项、卡片等。
    static BoxShadow get selectionGlow => BoxShadow(
          color: primary.withValues(alpha: isGlass ? 0.24 : 0.20),
          blurRadius: 28,
          spreadRadius: -4,
          offset: Offset(0, 8),
        );

    /// 卡片表面渐变：浅色为白色玻璃从高到低的透明度，深色为细微的冷色浮层。
    static LinearGradient get surfaceGradient => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isGlass
              ? [surfaceHigh, surface]
              : [surfaceHigh, surface],
        );

    /// 玻璃卡片顶部光带（模拟 Apple Liquid Glass 的折射高光）。
    static LinearGradient get glassHighlightGradient => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isGlass
              ? [
                  Colors.white.withValues(alpha: 0.45),
                  Colors.white.withValues(alpha: 0.02),
                ]
              : [
                  Colors.white.withValues(alpha: 0.06),
                  Colors.white.withValues(alpha: 0.0),
                ],
        );

  static LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [primaryDeep, primary, secondary],
      );

  static LinearGradient get backgroundGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [backgroundTop, background],
      );

  static BoxShadow get glow => BoxShadow(
        color: primary.withValues(alpha: 0.33),
        blurRadius: 28,
        spreadRadius: 0,
        offset: Offset(0, 8),
      );
}

ThemeData _buildTheme(CueBoxThemeMode mode) {
  final palette = paletteForMode(mode);
  final dark = mode == CueBoxThemeMode.dark;
  final glass = mode == CueBoxThemeMode.glass;
  // 玻璃/明亮主题下，主色上的前景文字用白色更贴近 Apple 观感。
  final onAccent = dark ? const Color(0xFF002A36) : Colors.white;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: palette.primary,
    onPrimary: onAccent,
    secondary: palette.secondary,
    surface: palette.surface,
    surfaceContainerLowest: glass
        ? const Color(0xDDFFFFFF)
        : const Color(0xFF0B1017),
    surfaceContainerLow: palette.surface,
    surfaceContainer: palette.surfaceHigh,
    surfaceContainerHigh: palette.surfacePressed,
    surfaceContainerHighest: palette.surfaceHigh,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    outline: palette.borderStrong,
    error: palette.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: palette.background,
    splashFactory: InkSparkle.splashFactory,
    fontFamilyFallback: ['PingFang SC', 'Noto Sans CJK SC'],

    textTheme: TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: palette.textPrimary,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: palette.textPrimary,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45, color: palette.textPrimary),
      bodyMedium:
          TextStyle(fontSize: 13.5, height: 1.4, color: palette.textPrimary),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: palette.textPrimary,
      ),
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      // 状态栏图标亮度跟随主题：深色用浅色图标（白），亮色用深色图标（黑）。
      // MaterialApp 会读取此值并应用到系统状态栏。
      systemOverlayStyle: dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
      actionsIconTheme: IconThemeData(color: palette.textPrimary),
    ),

    cardTheme: CardThemeData(
      color: palette.surface,
      surfaceTintColor: Colors.transparent,
      // 玻璃主题：微浮起 + 柔和阴影，更像真实的玻璃层。
      elevation: glass ? 2 : 1,
      shadowColor: glass ? const Color(0x3D0A84FF) : const Color(0x59000000),
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(glass ? 24 : 18),
        side: BorderSide(color: palette.border),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: palette.navBar,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11.5,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? palette.textPrimary
              : palette.textFaint,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? palette.primary
              : palette.textFaint,
          size: 24,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: palette.primary,
        foregroundColor: onAccent,
        elevation: 0,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: palette.textPrimary,
        side: BorderSide(color: palette.borderStrong),
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: palette.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: palette.textSecondary,
      textColor: palette.textPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    dividerTheme: DividerThemeData(
      color: palette.border,
      thickness: 1,
      space: 1,
    ),

    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: palette.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: palette.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(glass ? 32 : 28)),
        side: BorderSide(color: glass ? const Color(0x99FFFFFF) : palette.border),
      ),
      showDragHandle: true,
      dragHandleColor: glass
          ? const Color(0x330A84FF)
          : const Color(0x33000000),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      elevation: glass ? 8 : 4,
      shadowColor: glass ? const Color(0x330A84FF) : const Color(0x66000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(glass ? 28 : 24),
        side: BorderSide(color: glass ? const Color(0x99FFFFFF) : palette.border),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.surfaceHigh,
      contentTextStyle: TextStyle(color: palette.textPrimary, fontSize: 13.5),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: palette.borderStrong),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: palette.primary, width: 1.4),
      ),
      hintStyle: TextStyle(color: palette.textFaint),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: palette.primary,
      inactiveTrackColor: Color(0x22000000),
      thumbColor: palette.primary,
      overlayColor: palette.primary.withValues(alpha: 0.13),
      trackHeight: 4,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? onAccent
            : palette.textFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? palette.primary
            : Color(0x22000000),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: palette.primary,
      linearTrackColor: Color(0x22000000),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: palette.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: palette.borderStrong),
      ),
      textStyle: TextStyle(color: palette.textPrimary, fontSize: 13.5),
    ),

    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

/// 按主题风格构建 ThemeData。
ThemeData buildCueBoxTheme([CueBoxThemeMode mode = CueBoxThemeMode.dark]) =>
    _buildTheme(mode);
