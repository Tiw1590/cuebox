import 'package:flutter/material.dart';

import '../theme.dart';

/// CueBox 统一页面背景：深色渐变 + 两团柔和的氛围光。
class CueBoxBackground extends StatelessWidget {
  const CueBoxBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: CueBoxColors.backgroundGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _Glow(
              size: 320,
              color: CueBoxColors.primary.withValues(alpha: 0.07),
            ),
          ),
          Positioned(
            bottom: -140,
            left: -100,
            child: _Glow(
              size: 360,
              color: CueBoxColors.secondary.withValues(alpha: 0.06),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

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
