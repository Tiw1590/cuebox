import 'package:flutter/material.dart';

import '../theme.dart';

/// CueBox 统一页面背景：
/// - 深色：深色渐变 + 两团柔和的氛围光
/// - 浅色：蓝紫粉三色渐变 + 更多更亮的光斑，模拟玻璃折射光晕
class CueBoxBackground extends StatelessWidget {
  const CueBoxBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = currentThemeMode == CueBoxThemeMode.glass;
    return Container(
      decoration: BoxDecoration(
        gradient: glass ? _glassGradient : CueBoxColors.backgroundGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -140,
            right: -70,
            child: _Glow(
              size: glass ? 400 : 320,
              color: CueBoxColors.primary.withValues(alpha: glass ? 0.16 : 0.07),
            ),
          ),
          Positioned(
            bottom: -160,
            left: -100,
            child: _Glow(
              size: glass ? 440 : 360,
              color: CueBoxColors.secondary.withValues(
                alpha: glass ? 0.15 : 0.06,
              ),
            ),
          ),
          if (glass) ...[
            Positioned(
              top: 80,
              left: -120,
              child: _Glow(
                size: 360,
                color: CueBoxColors.amber.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: 40,
              right: -80,
              child: _Glow(
                size: 320,
                color: CueBoxColors.primaryDeep.withValues(alpha: 0.12),
              ),
            ),
          ],
          child,
        ],
      ),
    );
  }
}

/// 浅色主题背景：柔和的多段式蓝紫粉渐变。
final _glassGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    CueBoxColors.backgroundTop,
    Color(0xFFDCE7FF),
    Color(0xFFE8DCF6),
    CueBoxColors.background,
  ],
  stops: const [0.0, 0.4, 0.72, 1.0],
);

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
