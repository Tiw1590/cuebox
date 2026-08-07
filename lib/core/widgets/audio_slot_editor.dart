import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../platform/waveform_cache.dart';
import '../theme.dart';
import 'audio_trim_waveform.dart';
import 'waveform_fullscreen_page.dart';

/// 编辑面板的返回值：保存后的值、删除，或 null（取消）。
class SlotEditResult {
  const SlotEditResult({
    required this.name,
    required this.note,
    required this.volume,
    required this.fadeInMs,
    required this.fadeOutMs,
    required this.loop,
    required this.solo,
    this.startMs = 0,
    this.endMs = 0,
  });

  final String name;
  final String note;
  final double volume;
  final int fadeInMs;
  final int fadeOutMs;
  final bool loop;
  final bool solo;
  final int startMs;
  final int endMs;
}

/// 编辑面板结果：保存（带新值）或删除。
sealed class SlotEditOutcome {
  const SlotEditOutcome();
}

class SlotEditSaved extends SlotEditOutcome {
  const SlotEditSaved(this.result);

  final SlotEditResult result;
}

class SlotEditDeleted extends SlotEditOutcome {
  const SlotEditDeleted();
}

/// 弹出音频参数编辑面板，Cue 与 Cart 格块共用。
///
/// [showTrim] 为 true 时展示波形与播放区间裁剪（Cue 专用）。
Future<SlotEditOutcome?> showAudioSlotEditor({
  required BuildContext context,
  required String title,
  required String initialName,
  String initialNote = '',
  required double initialVolume,
  required int initialFadeInMs,
  required int initialFadeOutMs,
  required bool initialLoop,
  required bool initialSolo,
  bool showSolo = false,
  bool showNote = false,
  bool showTrim = false,
  String? waveformUri,
  int initialStartMs = 0,
  int initialEndMs = 0,
}) async {
  final outcome = await showModalBottomSheet<SlotEditOutcome>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CueBoxColors.surfaceHigh,
    builder: (context) => _AudioSlotEditorSheet(
      title: title,
      initialName: initialName,
      initialNote: initialNote,
      initialVolume: initialVolume,
      initialFadeInMs: initialFadeInMs,
      initialFadeOutMs: initialFadeOutMs,
      initialLoop: initialLoop,
      initialSolo: initialSolo,
      showSolo: showSolo,
      showNote: showNote,
      showTrim: showTrim,
      waveformUri: waveformUri,
      initialStartMs: initialStartMs,
      initialEndMs: initialEndMs,
    ),
  );
  return outcome;
}

class _AudioSlotEditorSheet extends StatefulWidget {
  const _AudioSlotEditorSheet({
    required this.title,
    required this.initialName,
    required this.initialNote,
    required this.initialVolume,
    required this.initialFadeInMs,
    required this.initialFadeOutMs,
    required this.initialLoop,
    required this.initialSolo,
    required this.showSolo,
    required this.showNote,
    required this.showTrim,
    required this.waveformUri,
    required this.initialStartMs,
    required this.initialEndMs,
  });

  final String title;
  final String initialName;
  final String initialNote;
  final double initialVolume;
  final int initialFadeInMs;
  final int initialFadeOutMs;
  final bool initialLoop;
  final bool initialSolo;
  final bool showSolo;
  final bool showNote;
  final bool showTrim;
  final String? waveformUri;
  final int initialStartMs;
  final int initialEndMs;

  @override
  State<_AudioSlotEditorSheet> createState() => _AudioSlotEditorSheetState();
}

class _AudioSlotEditorSheetState extends State<_AudioSlotEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late double _volume;
  late int _fadeInMs;
  late int _fadeOutMs;
  late bool _loop;
  late bool _solo;
  late int _startMs;
  late int _endMs;
  int? _previewStartMs;

  AudioPlayer? _previewPlayer;
  List<double>? _peaks;
  int _totalMs = 0;
  bool _previewing = false;
  bool _waveformLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _noteController = TextEditingController(text: widget.initialNote);
    _volume = widget.initialVolume;
    _fadeInMs = widget.initialFadeInMs;
    _fadeOutMs = widget.initialFadeOutMs;
    _loop = widget.initialLoop;
    _solo = widget.initialSolo;
    _startMs = widget.initialStartMs;
    _endMs = widget.initialEndMs;
    if (widget.waveformUri != null) {
      _totalMs = cachedDurationMs(widget.waveformUri!) ?? 0;
      _peaks = cachedWaveform(widget.waveformUri!);
    }

    if (widget.showTrim && widget.waveformUri != null) {
      _loadWaveform();
    }
  }

  Future<void> _loadWaveform() async {
    final uri = widget.waveformUri!;
    if (mounted) setState(() => _waveformLoading = true);
    final player = AudioPlayer();
    _previewPlayer = player;
    var fullDurationCaptured = false;
    player.durationStream.listen((d) {
      // 只接受完整文件时长；预览裁剪后回传的更短时长忽略，避免出点跳变。
      if (d != null && !fullDurationCaptured && mounted) {
        fullDurationCaptured = true;
        rememberDuration(uri, d.inMilliseconds);
        setState(() => _totalMs = d.inMilliseconds);
      }
    });
    player.processingStateStream.listen((s) {
      if (s == ProcessingState.completed && mounted) {
        setState(() => _previewing = false);
      }
    });
    // 初始加载不阻塞：立即并行提取波形，避免被试听打断后波形迟迟不显示。
    unawaited(
      player.setAudioSource(AudioSource.uri(Uri.parse(uri))).catchError((_) {
        // 加载失败不影响波形显示与裁剪设置。
        return null;
      }),
    );
    final peaks = await loadWaveform(uri);
    if (mounted) {
      setState(() {
        _peaks = peaks;
        _waveformLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    _previewPlayer?.dispose();
    super.dispose();
  }

  void _save() {
    final result = SlotEditResult(
      name: _nameController.text.trim().isEmpty
          ? widget.initialName
          : _nameController.text.trim(),
      note: _noteController.text.trim(),
      volume: _volume,
      fadeInMs: _fadeInMs,
      fadeOutMs: _fadeOutMs,
      loop: _loop,
      solo: _solo,
      startMs: _startMs,
      endMs: _endMs,
    );
    Navigator.of(context).pop(SlotEditSaved(result));
  }

  Future<void> _togglePreview() async {
    final player = _previewPlayer;
    if (player == null) return;
    if (_previewing) {
      await player.pause();
      if (mounted) setState(() => _previewing = false);
      return;
    }
    final playFrom = _previewStartMs ?? _startMs;
    final end = _endMs > 0 ? _endMs : _totalMs;
    final UriAudioSource baseSource =
        AudioSource.uri(Uri.parse(widget.waveformUri!));
    AudioSource source = baseSource;
    if (playFrom > 0 || (end > 0 && end > playFrom)) {
      source = ClippingAudioSource(
        child: baseSource,
        start: Duration(milliseconds: playFrom),
        end: end > playFrom ? Duration(milliseconds: end) : null,
      );
    }
    try {
      await player.setAudioSource(source);
      unawaited(player.play());
      if (mounted) setState(() => _previewing = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法试听该音频')),
        );
      }
    }
  }

  void _resetTrim() {
    setState(() {
      _startMs = 0;
      _endMs = 0;
      _previewStartMs = null;
    });
  }

  void _openFullscreen() {
    if (widget.waveformUri == null) return;
    WaveformFullscreenPage.open(
      context,
      uri: widget.waveformUri!,
      peaks: _peaks,
      totalMs: _totalMs,
      startMs: _startMs,
      endMs: _endMs,
      onStartChanged: (v) => setState(() => _startMs = v),
      onEndChanged: (v) => setState(() => _endMs = v),
      previewStartMs: _previewStartMs,
      onPreviewStartChanged: (v) =>
          setState(() => _previewStartMs = v > 0 ? v : null),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                prefixIcon: Icon(Icons.edit_outlined, size: 20),
              ),
            ),
            if (widget.showNote) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  prefixIcon: Icon(Icons.notes_outlined, size: 20),
                ),
                onSubmitted: (_) => _save(),
              ),
            ],
            if (widget.showTrim) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  const Text(
                    '播放区间',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: _openFullscreen,
                    icon: const Icon(Icons.open_in_full, size: 17),
                    label: const Text('全屏微调'),
                  ),
                  TextButton.icon(
                    onPressed: _resetTrim,
                    icon: const Icon(Icons.restart_alt, size: 17),
                    label: const Text('重置'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.touch_app_outlined,
                    size: 13,
                    color: CueBoxColors.textFaint,
                  ),
                  const SizedBox(width: 5),
                  const Expanded(
                    child: Text(
                      '点按设试听点 · 长按波形进入全屏微调',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: CueBoxColors.textFaint,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              StreamBuilder<Duration>(
                key: ValueKey('preview_$_previewing'),
                stream: _previewPlayer?.positionStream,
                builder: (_, posSnap) {
                  final playFrom = _previewStartMs ?? _startMs;
                  return Stack(
                    children: [
                      AudioTrimWaveform(
                        peaks: _peaks,
                        totalMs: _totalMs,
                        startMs: _startMs,
                        endMs: _endMs,
                        onStartChanged: (v) => setState(() => _startMs = v),
                        onEndChanged: (v) => setState(() => _endMs = v),
                        previewStartMs: _previewStartMs,
                        onTapSetPlayhead: (v) =>
                            setState(() => _previewStartMs = v),
                        onLongPress: _openFullscreen,
                        playPositionMs: _previewing
                            ? (playFrom + (posSnap.data?.inMilliseconds ?? 0))
                            : null,
                      ),
                      if (_waveformLoading)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: ColoredBox(
                              color: CueBoxColors.surfacePressed
                                  .withValues(alpha: 0.55),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    '波形加载中…',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: CueBoxColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '起点 ${_fmtSeconds(_startMs)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CueBoxColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_previewStartMs != null) ...[
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_arrow_rounded,
                          size: 12,
                          color: CueBoxColors.amber,
                        ),
                        Text(
                          '试听点 ${_fmtSeconds(_previewStartMs!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: CueBoxColors.amber,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              setState(() => _previewStartMs = null),
                          child: const Icon(
                            Icons.close,
                            size: 13,
                            color: CueBoxColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '总长 ${_fmtSeconds(_totalMs)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CueBoxColors.textFaint,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '终点 ${_fmtSeconds(_endMs > 0 ? _endMs : _totalMs)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CueBoxColors.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: _totalMs > 0 ? _togglePreview : null,
                icon: Icon(
                  _previewing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 19,
                ),
                label: Text(
                  _previewing
                      ? '停止试听'
                      : (_previewStartMs != null ? '从试听点播放' : '试听播放区间'),
                ),
              ),
            ],
            const SizedBox(height: 8),
            _SliderRow(
              label: '音量',
              valueLabel: '${(_volume * 100).round()}%',
              value: _volume,
              min: 0,
              max: 1,
              divisions: 20,
              onChanged: (v) => setState(() => _volume = v),
            ),
            _SliderRow(
              label: '淡入',
              valueLabel: _formatSeconds(_fadeInMs),
              value: _fadeInMs.toDouble(),
              min: 0,
              max: 3000,
              divisions: 60,
              onChanged: (v) => setState(() => _fadeInMs = v.round()),
            ),
            _SliderRow(
              label: '淡出',
              valueLabel: _formatSeconds(_fadeOutMs),
              value: _fadeOutMs.toDouble(),
              min: 0,
              max: 5000,
              divisions: 100,
              onChanged: (v) => setState(() => _fadeOutMs = v.round()),
            ),
            const SizedBox(height: 8),
            if (widget.showSolo)
              _SwitchRow(
                title: 'Solo 独占',
                subtitle: '触发时停掉其他所有声音',
                value: _solo,
                onChanged: (v) => setState(() => _solo = v),
              ),
            _SwitchRow(
              title: '循环播放',
              subtitle: '声音播完自动从头继续',
              value: _loop,
              onChanged: (v) => setState(() => _loop = v),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('保存'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 44,
          child: Text(label, style: const TextStyle(fontSize: 13.5)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 58,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: CueBoxColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: CueBoxColors.textFaint,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

String _formatSeconds(int ms) {
  if (ms <= 0) return '0s';
  return '${(ms / 1000).toStringAsFixed(1)}s';
}

String _fmtSeconds(int ms) {
  final minutes = ms ~/ 60000;
  final seconds = (ms % 60000) ~/ 1000;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
