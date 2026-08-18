import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 波形 + 裁剪起止节点控件。
///
/// 区间外波形保留显示（略微变淡）；点按可设置试听起点，长按可进入全屏微调。
class AudioTrimWaveform extends StatelessWidget {
  const AudioTrimWaveform({
    super.key,
    required this.peaks,
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.onStartChanged,
    required this.onEndChanged,
    this.previewStartMs,
    this.onTapSetPlayhead,
    this.onLongPress,
    this.playPositionMs,
    this.height = 120,
    this.handleWidth = 20,
    this.amplitudeScale = 1.6,
  });

  final List<double>? peaks;
  final int totalMs;
  final int startMs;
  final int endMs;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  final int? previewStartMs;
  final ValueChanged<int>? onTapSetPlayhead;
  final VoidCallback? onLongPress;
  final int? playPositionMs;
  final double height;
  final double handleWidth;
  final double amplitudeScale;

  @override
  Widget build(BuildContext context) {
    final effectiveEnd = endMs > 0 ? endMs : totalMs;
    final startFrac =
        totalMs <= 0 ? 0.0 : (startMs / totalMs).clamp(0.0, 1.0).toDouble();
    final endFrac =
        totalMs <= 0 ? 1.0 : (effectiveEnd / totalMs).clamp(0.0, 1.0).toDouble();
    final minGap = totalMs <= 0 ? 100 : math.max(100, totalMs ~/ 200);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPress,
            onTapUp: (d) {
              final playhead = onTapSetPlayhead;
              if (playhead == null || totalMs <= 0) return;
              final ms = ((d.localPosition.dx / width) * totalMs)
                  .round()
                  .clamp(0, totalMs)
                  .toInt();
              playhead(ms);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _WaveformPainter(
                        peaks: peaks,
                        startFrac: startFrac,
                        endFrac: endFrac,
                        previewStartFrac:
                            previewStartMs != null && totalMs > 0
                                ? (previewStartMs! / totalMs).clamp(0.0, 1.0)
                                : null,
                        playPositionFrac: playPositionMs != null && totalMs > 0
                            ? (playPositionMs! / totalMs).clamp(0.0, 1.0)
                            : null,
                        amplitudeScale: amplitudeScale,
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * startFrac - handleWidth / 2)
                        .clamp(0.0, width - handleWidth),
                    top: 0,
                    bottom: 0,
                    width: handleWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (d) {
                        if (totalMs <= 0) return;
                        final deltaMs =
                            ((d.delta.dx / width) * totalMs).round();
                        final newMs = (startMs + deltaMs)
                            .clamp(0, math.max(0, effectiveEnd - minGap))
                            .toInt();
                        onStartChanged(newMs);
                      },
                      child: _Handle(
                        color: CueBoxColors.primary,
                        icon: Icons.chevron_left,
                      ),
                    ),
                  ),
                  Positioned(
                    left: (width * endFrac - handleWidth / 2)
                        .clamp(0.0, width - handleWidth),
                    top: 0,
                    bottom: 0,
                    width: handleWidth,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragUpdate: (d) {
                        if (totalMs <= 0) return;
                        final deltaMs =
                            ((d.delta.dx / width) * totalMs).round();
                        final newEnd = (effectiveEnd + deltaMs)
                            .clamp(startMs + minGap, totalMs)
                            .toInt();
                        onEndChanged(newEnd >= totalMs ? 0 : newEnd);
                      },
                      child: _Handle(
                        color: CueBoxColors.secondary,
                        icon: Icons.chevron_right,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color, color.withValues(alpha: 0.55)],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 15, color: CueBoxColors.onAccent),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.startFrac,
    required this.endFrac,
    required this.previewStartFrac,
    required this.playPositionFrac,
    required this.amplitudeScale,
  });

  final List<double>? peaks;
  final double startFrac;
  final double endFrac;
  final double? previewStartFrac;
  final double? playPositionFrac;
  final double amplitudeScale;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = CueBoxColors.surfacePressed;
    canvas.drawRect(Offset.zero & size, background);

    final list = peaks ??
        List<double>.generate(
          96,
          (i) => 0.28 +
              0.62 *
                  ((math.sin(i * 0.65) * 0.5 +
                          math.sin(i * 0.21 + 1.3) * 0.5 +
                          2) /
                      2),
        );
    final barWidth = size.width / list.length;
    final barThickness = (barWidth * 0.7).clamp(2.0, 10.0);

    for (var i = 0; i < list.length; i++) {
      final centerX = (i + 0.5) * barWidth;
      final frac = i / list.length;
      final inside = frac >= startFrac && frac <= endFrac;
      final h = (list[i].clamp(0.02, 1.0) *
              size.height *
              0.86 *
              amplitudeScale)
          .clamp(2.0, size.height * 0.92);
      final paint = Paint()
        ..color = inside
            ? CueBoxColors.primary.withValues(alpha: 0.78)
            : CueBoxColors.textFaint.withValues(alpha: 0.45);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          centerX - barThickness / 2,
          (size.height - h) / 2,
          barThickness,
          h,
        ),
        Radius.circular(2),
      );
      canvas.drawRRect(rect, paint);
    }

    // 区间边界线
    final startX = startFrac * size.width;
    final endX = endFrac * size.width;
    canvas.drawLine(
      Offset(startX, 3),
      Offset(startX, size.height - 3),
      Paint()
        ..color = CueBoxColors.primary.withValues(alpha: 0.9)
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(endX, 3),
      Offset(endX, size.height - 3),
      Paint()
        ..color = CueBoxColors.secondary.withValues(alpha: 0.9)
        ..strokeWidth = 1.5,
    );

    // 试听起点标记
    final marker = previewStartFrac;
    if (marker != null) {
      final x = marker * size.width;
      canvas.drawLine(
        Offset(x, 3),
        Offset(x, size.height - 3),
        Paint()
          ..color = CueBoxColors.amber
          ..strokeWidth = 1.8,
      );
      final triangle = Path()
        ..moveTo(x - 5, 0)
        ..lineTo(x + 5, 0)
        ..lineTo(x, 8)
        ..close();
      canvas.drawPath(triangle, Paint()..color = CueBoxColors.amber);
    }

    // 播放进度线
    final pos = playPositionFrac;
    if (pos != null) {
      final x = pos * size.width;
      canvas.drawLine(
        Offset(x, 4),
        Offset(x, size.height - 4),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.85)
          ..strokeWidth = 1.2,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.peaks != peaks ||
        oldDelegate.startFrac != startFrac ||
        oldDelegate.endFrac != endFrac ||
        oldDelegate.previewStartFrac != previewStartFrac ||
        oldDelegate.playPositionFrac != playPositionFrac ||
        oldDelegate.amplitudeScale != amplitudeScale;
  }
}
