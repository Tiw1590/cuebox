import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

/// CueBox 设计令牌：统一的颜色、渐变与圆角，页面和组件都从这里取。
abstract final class CueBoxColors {
  static const Color background = Color(0xFF0A0E13);
  static const Color backgroundTop = Color(0xFF0E1520);
  static const Color surface = Color(0xFF121A24);
  static const Color surfaceHigh = Color(0xFF1A2531);
  static const Color surfacePressed = Color(0xFF22303F);

  static const Color primary = Color(0xFF38E1FF);
  static const Color primaryDeep = Color(0xFF0EA5D8);
  static const Color secondary = Color(0xFFA78BFA);
  static const Color amber = Color(0xFFFFC24B);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color success = Color(0xFF4ADE80);

  static const Color textPrimary = Color(0xFFE8EEF5);
  static const Color textSecondary = Color(0xFF93A6BB);
  static const Color textFaint = Color(0xFF5F7186);
  static const Color border = Color(0x1FFFFFFF);
  static const Color borderStrong = Color(0x2FFFFFFF);

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [primaryDeep, primary, secondary],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, background],
  );

  static const BoxShadow glow = BoxShadow(
    color: Color(0x5538E1FF),
    blurRadius: 28,
    spreadRadius: 0,
    offset: Offset(0, 8),
  );
}

/// CueBox 现代深色主题：舞台灯光风格，高对比、大圆角、柔和辉光。
ThemeData buildCueBoxTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: CueBoxColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: CueBoxColors.primary,
    onPrimary: const Color(0xFF002A36),
    secondary: CueBoxColors.secondary,
    surface: CueBoxColors.surface,
    surfaceContainerHighest: CueBoxColors.surfaceHigh,
    onSurface: CueBoxColors.textPrimary,
    onSurfaceVariant: CueBoxColors.textSecondary,
    outline: CueBoxColors.borderStrong,
    error: CueBoxColors.danger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: CueBoxColors.background,
    splashFactory: InkSparkle.splashFactory,
    fontFamilyFallback: const ['PingFang SC', 'Noto Sans CJK SC'],

    textTheme: const TextTheme(
      headlineMedium: TextStyle(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: TextStyle(fontSize: 15, height: 1.45),
      bodyMedium: TextStyle(fontSize: 13.5, height: 1.4),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: CueBoxColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: CueBoxColors.textPrimary),
      actionsIconTheme: IconThemeData(color: CueBoxColors.textPrimary),
    ),

    cardTheme: CardThemeData(
      color: CueBoxColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: CueBoxColors.border),
      ),
    ),

    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: const Color(0xFF0D131B),
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
              ? CueBoxColors.textPrimary
              : CueBoxColors.textFaint,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? CueBoxColors.primary
              : CueBoxColors.textFaint,
          size: 24,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CueBoxColors.primary,
        foregroundColor: const Color(0xFF002A36),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CueBoxColors.textPrimary,
        side: const BorderSide(color: CueBoxColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: CueBoxColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: CueBoxColors.textSecondary,
      textColor: CueBoxColors.textPrimary,
    ),

    dividerTheme: DividerThemeData(
      color: CueBoxColors.border,
      thickness: 1,
      space: 1,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: CueBoxColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: CueBoxColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      showDragHandle: true,
      dragHandleColor: Color(0x33FFFFFF),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: CueBoxColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: CueBoxColors.surfaceHigh,
      contentTextStyle: const TextStyle(
        color: CueBoxColors.textPrimary,
        fontSize: 13.5,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: CueBoxColors.borderStrong),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CueBoxColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CueBoxColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CueBoxColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: CueBoxColors.primary, width: 1.4),
      ),
      hintStyle: const TextStyle(color: CueBoxColors.textFaint),
    ),

    sliderTheme: SliderThemeData(
      activeTrackColor: CueBoxColors.primary,
      inactiveTrackColor: const Color(0x33FFFFFF),
      thumbColor: CueBoxColors.primary,
      overlayColor: const Color(0x2238E1FF),
      trackHeight: 4,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? const Color(0xFF002A36)
            : CueBoxColors.textFaint,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? CueBoxColors.primary
            : const Color(0x33FFFFFF),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: CueBoxColors.primary,
      linearTrackColor: Color(0x22FFFFFF),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: CueBoxColors.surfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: CueBoxColors.borderStrong),
      ),
      textStyle: const TextStyle(color: CueBoxColors.textPrimary, fontSize: 13.5),
    ),

    pageTransitionsTheme: const PageTransitionsTheme(
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
