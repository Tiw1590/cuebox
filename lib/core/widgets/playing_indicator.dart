import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 正在播放的跳动均衡器小图标。
class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({
    super.key,
    this.size = 18,
    this.color,
    this.calm = false,
  });

  final double size;
  final Color? color;

  /// 温和模式：跳动幅度更小、更安静（用于试听等需要弱化动画的场景）。
  final bool calm;

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? CueBoxColors.primary;
    final calm = widget.calm;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (i) {
              final phase = math.sin((t * 2 * math.pi) - (i * 0.9));
              final height = 0.35 + 0.65 * ((phase + 1) / 2).clamp(0.0, 1.0);
              // 温和模式下柱高收窄，动画更安静。
              final factor = calm ? (0.45 + 0.55 * height) : height;
              return Container(
                width: widget.size / 4,
                height: widget.size * (0.30 + 0.70 * factor),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
