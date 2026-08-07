import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../theme.dart';
import 'audio_trim_waveform.dart';

/// 全屏波形微调页：长按小波形后进入，支持拖动手柄、点按设置试听起点、
/// 从任意位置试听、一键把试听点设为起点。
class WaveformFullscreenPage extends StatefulWidget {
  const WaveformFullscreenPage({
    super.key,
    required this.uri,
    required this.peaks,
    required this.totalMs,
    required this.startMs,
    required this.endMs,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.previewStartMs,
    required this.onPreviewStartChanged,
  });

  final String uri;
  final List<double>? peaks;
  final int totalMs;
  final int startMs;
  final int endMs;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;
  final int? previewStartMs;
  final ValueChanged<int> onPreviewStartChanged;

  /// 以全屏对话框方式打开。
  static Future<void> open(
    BuildContext context, {
    required String uri,
    required List<double>? peaks,
    required int totalMs,
    required int startMs,
    required int endMs,
    required ValueChanged<int> onStartChanged,
    required ValueChanged<int> onEndChanged,
    required int? previewStartMs,
    required ValueChanged<int> onPreviewStartChanged,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => WaveformFullscreenPage(
          uri: uri,
          peaks: peaks,
          totalMs: totalMs,
          startMs: startMs,
          endMs: endMs,
          onStartChanged: onStartChanged,
          onEndChanged: onEndChanged,
          previewStartMs: previewStartMs,
          onPreviewStartChanged: onPreviewStartChanged,
        ),
      ),
    );
  }

  @override
  State<WaveformFullscreenPage> createState() =>
      _WaveformFullscreenPageState();
}

class _WaveformFullscreenPageState extends State<WaveformFullscreenPage> {
  late int _startMs;
  late int _endMs;
  int? _previewStartMs;
  int _loadedTotalMs = 0;
  AudioPlayer? _player;
  bool _previewing = false;
  double _amplitudeScale = 2.0;

  int get _totalMs => _loadedTotalMs > 0 ? _loadedTotalMs : widget.totalMs;

  @override
  void initState() {
    super.initState();
    _startMs = widget.startMs;
    _endMs = widget.endMs;
    _previewStartMs = widget.previewStartMs;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final player = AudioPlayer();
    _player = player;
    var fullDurationCaptured = false;
    player.durationStream.listen((d) {
      if (d != null && !fullDurationCaptured && mounted) {
        fullDurationCaptured = true;
        setState(() => _loadedTotalMs = d.inMilliseconds);
      }
    });
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && mounted) {
        setState(() => _previewing = false);
      }
    });
    unawaited(
      player.setAudioSource(AudioSource.uri(Uri.parse(widget.uri))).catchError((_) {
        // 仅用于获取时长，失败不影响微调。
        return null;
      }),
    );
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePreview() async {
    final player = _player;
    if (player == null || _totalMs <= 0) return;
    if (_previewing) {
      await player.pause();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    final playFrom = _previewStartMs ?? _startMs;
    final end = _endMs > 0 ? _endMs : _totalMs;
    final base = AudioSource.uri(Uri.parse(widget.uri));
    AudioSource source;
    if (playFrom > 0 || (end > 0 && end > playFrom)) {
      source = ClippingAudioSource(
        child: base,
        start: Duration(milliseconds: playFrom),
        end: end > playFrom ? Duration(milliseconds: end) : null,
      );
    } else {
      source = base;
    }
    try {
      await player.setAudioSource(source);
      unawaited(player.play());
      if (mounted) setState(() => _previewing = true);
    } catch (_) {}
  }

  void _setStartFromPlayhead() {
    final p = _previewStartMs;
    if (p == null) return;
    setState(() => _startMs = p);
    widget.onStartChanged(p);
  }

  void _resetAll() {
    setState(() {
      _startMs = 0;
      _endMs = 0;
      _previewStartMs = null;
    });
    widget.onStartChanged(0);
    widget.onEndChanged(0);
    widget.onPreviewStartChanged(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CueBoxColors.background,
      appBar: AppBar(
        title: const Text('微调播放区间'),
        leading: IconButton(
          tooltip: '返回',
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 14,
                    color: CueBoxColors.textFaint,
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '点按波形设置试听起点，拖动左右手柄微调播放区间',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: CueBoxColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<Duration>(
                key: ValueKey('fs_preview_$_previewing'),
                stream: _player?.positionStream,
                builder: (_, posSnap) {
                  final playFrom = _previewStartMs ?? _startMs;
                  return AudioTrimWaveform(
                    peaks: widget.peaks,
                    totalMs: _totalMs,
                    startMs: _startMs,
                    endMs: _endMs,
                    onStartChanged: (v) {
                      setState(() => _startMs = v);
                      widget.onStartChanged(v);
                    },
                    onEndChanged: (v) {
                      setState(() => _endMs = v);
                      widget.onEndChanged(v);
                    },
                    previewStartMs: _previewStartMs,
                    onTapSetPlayhead: (v) {
                      setState(() => _previewStartMs = v);
                      widget.onPreviewStartChanged(v);
                    },
                    playPositionMs: _previewing
                        ? (playFrom + (posSnap.data?.inMilliseconds ?? 0))
                        : null,
                    height: 280,
                    handleWidth: 28,
                    amplitudeScale: _amplitudeScale,
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.swap_vert_rounded,
                    size: 17,
                    color: CueBoxColors.textFaint,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '振幅',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: CueBoxColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _amplitudeScale,
                      min: 0.5,
                      max: 3.5,
                      divisions: 30,
                      onChanged: (v) => setState(() => _amplitudeScale = v),
                    ),
                  ),
                  SizedBox(
                    width: 46,
                    child: Text(
                      '×${_amplitudeScale.toStringAsFixed(1)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: CueBoxColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _TimeLabel(
                    label: '起点',
                    text: _fmt(_startMs),
                    color: CueBoxColors.primary,
                  ),
                  const Spacer(),
                  _TimeLabel(
                    label: '总长',
                    text: _fmt(_totalMs),
                    color: CueBoxColors.textFaint,
                  ),
                  const Spacer(),
                  _TimeLabel(
                    label: '终点',
                    text: _fmt(_endMs > 0 ? _endMs : _totalMs),
                    color: CueBoxColors.secondary,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text(
                    '试听起点',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: CueBoxColors.textFaint,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _fmt(_previewStartMs ?? _startMs),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: CueBoxColors.amber,
                    ),
                  ),
                  if (_previewStartMs != null) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() => _previewStartMs = null);
                        widget.onPreviewStartChanged(0);
                      },
                      child: const Icon(
                        Icons.close,
                        size: 15,
                        color: CueBoxColors.textFaint,
                      ),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _previewStartMs != null ? _setStartFromPlayhead : null,
                    icon: const Icon(Icons.flag_outlined, size: 17),
                    label: const Text('设为起点'),
                  ),
                ],
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _resetAll,
                      icon: const Icon(Icons.restart_alt, size: 18),
                      label: const Text('重置'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _totalMs > 0 ? _togglePreview : null,
                      icon: Icon(
                        _previewing
                            ? Icons.stop_rounded
                            : Icons.play_arrow_rounded,
                        size: 20,
                      ),
                      label: Text(
                        _previewing
                            ? '停止试听'
                            : (_previewStartMs != null
                                ? '从试听点播放'
                                : '从起点播放'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  const _TimeLabel({
    required this.label,
    required this.text,
    required this.color,
  });

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: CueBoxColors.textFaint),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

String _fmt(int ms) {
  final minutes = ms ~/ 60000;
  final seconds = (ms % 60000) ~/ 1000;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
