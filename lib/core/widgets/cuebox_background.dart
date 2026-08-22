import 'package:flutter/material.dart';

import '../theme.dart';

/// CueBox 统一页面背景：
/// - 深色：深邃舞台蓝黑渐变 + 多组冷色氛围光 + 微弱暗角，突出舞台聚光感
/// - 浅色：Apple 风格蓝紫渐变 + 大面积柔光 + 玻璃折射高光带
class CueBoxBackground extends StatelessWidget {
  const CueBoxBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final glass = currentThemeMode == CueBoxThemeMode.glass;
    return Container(
      decoration: BoxDecoration(
        gradient: glass ? _glassGradient : _darkGradient,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (glass) ...[
            Positioned(
              top: -180,
              right: -100,
              child: _Glow(
                size: 520,
                color: CueBoxColors.primary.withValues(alpha: 0.18),
                bloom: 1.4,
              ),
            ),
            Positioned(
              top: 40,
              left: -160,
              child: _Glow(
                size: 480,
                color: CueBoxColors.secondary.withValues(alpha: 0.16),
                bloom: 1.3,
              ),
            ),
            Positioned(
              bottom: -140,
              left: -80,
              child: _Glow(
                size: 560,
                color: Color(0xFFFF9F0A).withValues(alpha: 0.10),
                bloom: 1.2,
              ),
            ),
            Positioned(
              bottom: -120,
              right: -90,
              child: _Glow(
                size: 480,
                color: CueBoxColors.primaryDeep.withValues(alpha: 0.14),
                bloom: 1.3,
              ),
            ),
            // 玻璃表面的大面积柔光，模拟 Apple 壁纸的层次感。
            Positioned(
              top: -80,
              left: 0,
              right: 0,
              child: _SoftLightPanel(),
            ),
            // 两道斜向折射光带。
            _GlassStreak(
              top: 110,
              left: -80,
              width: 560,
              height: 130,
              angle: -0.38,
            ),
            _GlassStreak(
              bottom: 40,
              right: -140,
              width: 640,
              height: 150,
              angle: 0.28,
            ),
          ] else ...[
            Positioned(
              top: -180,
              right: -120,
              child: _Glow(
                size: 460,
                color: CueBoxColors.primary.withValues(alpha: 0.10),
                bloom: 1.4,
              ),
            ),
            Positioned(
              bottom: -180,
              left: -120,
              child: _Glow(
                size: 520,
                color: CueBoxColors.secondary.withValues(alpha: 0.09),
                bloom: 1.4,
              ),
            ),
            Positioned(
              top: 180,
              left: -180,
              child: _Glow(
                size: 340,
                color: CueBoxColors.amber.withValues(alpha: 0.05),
                bloom: 1.2,
              ),
            ),
            Positioned(
              bottom: 60,
              right: -120,
              child: _Glow(
                size: 360,
                color: CueBoxColors.primaryDeep.withValues(alpha: 0.08),
                bloom: 1.3,
              ),
            ),
          ],
          _Vignette(glass: glass),
          child,
        ],
      ),
    );
  }
}

/// 深色主题背景：从舞台蓝黑到深邃近黑的渐变。
final _darkGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    CueBoxColors.backgroundTop,
    Color(0xFF0A1220),
    CueBoxColors.background,
  ],
  stops: const [0.0, 0.45, 1.0],
);

/// 浅色主题背景：柔和的多段式蓝紫粉渐变。
final _glassGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [
    CueBoxColors.backgroundTop,
    Color(0xFFDFEAFE),
    Color(0xFFEDE2FA),
    CueBoxColors.background,
  ],
  stops: const [0.0, 0.36, 0.68, 1.0],
);

/// 大面积的柔和白色高光面板，让浅色背景更“透气”。
class _SoftLightPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 420,
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.12, -0.35),
          radius: 1.4,
          colors: [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}

/// 斜向玻璃折射光带。
class _GlassStreak extends StatelessWidget {
  const _GlassStreak({
    this.top,
    this.left,
    this.bottom,
    this.right,
    required this.width,
    required this.height,
    required this.angle,
  });

  final double? top;
  final double? left;
  final double? bottom;
  final double? right;
  final double width;
  final double height;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.28),
                Colors.white.withValues(alpha: 0.06),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 极轻微暗角/顶光，保持背景不抢内容但更有厚度。
class _Vignette extends StatelessWidget {
  const _Vignette({required this.glass});

  final bool glass;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0.0, -0.15),
            radius: 1.6,
            colors: glass
                ? [
                    Colors.white.withValues(alpha: 0.06),
                    Colors.transparent,
                    Color(0x1F5B7FA6),
                  ]
                : [
                    Colors.white.withValues(alpha: 0.02),
                    Colors.transparent,
                    const Color(0x8C080B12),
                  ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.size,
    required this.color,
    this.bloom = 1,
  });

  final double size;
  final Color color;
  final double bloom;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          radius: bloom,
          colors: [
            color,
            color.withValues(alpha: color.a * 0.45),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}
