import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

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
  background: Color(0xFF0A0E13),
  backgroundTop: Color(0xFF0E1520),
  surface: Color(0xFF121A24),
  surfaceHigh: Color(0xFF1A2531),
  surfacePressed: Color(0xFF22303F),
  primary: Color(0xFF38E1FF),
  primaryDeep: Color(0xFF0EA5D8),
  secondary: Color(0xFFA78BFA),
  amber: Color(0xFFFFC24B),
  danger: Color(0xFFFF6B6B),
  success: Color(0xFF4ADE80),
  textPrimary: Color(0xFFE8EEF5),
  textSecondary: Color(0xFF93A6BB),
  textFaint: Color(0xFF5F7186),
  border: Color(0x1FFFFFFF),
  borderStrong: Color(0x2FFFFFFF),
  navBar: Color(0xFF0D131B),
);

const _lightPalette = CueBoxPalette(
  background: Color(0xFFF4F6FA),
  backgroundTop: Color(0xFFE9EEF6),
  surface: Color(0xFFFFFFFF),
  surfaceHigh: Color(0xFFF0F3F8),
  surfacePressed: Color(0xFFE2E8F0),
  primary: Color(0xFF0E9FD8),
  primaryDeep: Color(0xFF0B7FB0),
  secondary: Color(0xFF7C5CFF),
  amber: Color(0xFFE8A020),
  danger: Color(0xFFE5484D),
  success: Color(0xFF2FA84F),
  textPrimary: Color(0xFF121826),
  textSecondary: Color(0xFF55657A),
  textFaint: Color(0xFF8A99AC),
  border: Color(0x14000000),
  borderStrong: Color(0x26000000),
  navBar: Color(0xFFFFFFFF),
);

bool _dark = true;

/// 设置当前明暗（由主题控制器调用，页面取色用）。
void setCueBoxBrightness({required bool dark}) {
  _dark = dark;
}

CueBoxPalette get _palette => _dark ? _darkPalette : _lightPalette;

/// CueBox 设计令牌：深/浅两套调色板，随主题切换动态取色。
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

ThemeData _buildTheme(CueBoxPalette palette) {
  final dark = palette == _darkPalette;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: palette.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
  ).copyWith(
    primary: palette.primary,
    onPrimary: Color(0xFF002A36),
    secondary: palette.secondary,
    surface: palette.surface,
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
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
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
        foregroundColor: Color(0xFF002A36),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: Color(0x33000000),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: palette.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
            ? Color(0xFF002A36)
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

/// 深色主题（默认）。
ThemeData buildCueBoxTheme() => _buildTheme(_darkPalette);

/// 浅色（白色）主题。
ThemeData buildLightCueBoxTheme() => _buildTheme(_lightPalette);
