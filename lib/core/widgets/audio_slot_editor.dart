import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

import '../platform/audio_uri.dart';
import '../platform/waveform_cache.dart';
import '../theme.dart';
import 'audio_trim_waveform.dart';
import 'waveform_fullscreen_page.dart';

/// 编辑面板的返回值：保存后的值、删除，或 null（取消）。
class SlotEditResult {
  SlotEditResult({
    required this.name,
    required this.note,
    required this.volume,
    required this.fadeInMs,
    required this.fadeOutMs,
    required this.loop,
    required this.solo,
    this.startMs = 0,
    this.endMs = 0,
    this.shortcutKeyId,
    this.shortcutLabel,
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
  final int? shortcutKeyId;
  final String? shortcutLabel;
}

/// 编辑面板结果：保存（带新值）或删除。
sealed class SlotEditOutcome {
  SlotEditOutcome();
}

class SlotEditSaved extends SlotEditOutcome {
  SlotEditSaved(this.result);

  final SlotEditResult result;
}

/// 以底部弹窗方式编辑（Pad 模式使用）。
///
/// [onApply] 在每次点“保存”时立即写入；关闭弹窗不做任何额外保存。
Future<void> showAudioSlotEditor({
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
  bool showShortcut = false,
  int? initialShortcutKeyId,
  String? initialShortcutLabel,
  Set<int> takenShortcutKeyIds = const {},
  VoidCallback? onCopy,
  required ValueChanged<SlotEditResult> onApply,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: CueBoxColors.surfaceHigh,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 4,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: AudioSlotEditorPanel(
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
        showShortcut: showShortcut,
        initialShortcutKeyId: initialShortcutKeyId,
        initialShortcutLabel: initialShortcutLabel,
        takenShortcutKeyIds: takenShortcutKeyIds,
        onCopy: onCopy,
        onCancel: () => Navigator.of(context).pop(),
        onSave: onApply,
      ),
    ),
  );
}

/// 音频参数编辑面板：底部弹窗与 Cue 列表右侧常驻面板共用。
class AudioSlotEditorPanel extends StatefulWidget {
  const AudioSlotEditorPanel({
    super.key,
    required this.title,
    required this.initialName,
    required this.initialNote,
    required this.initialVolume,
    required this.initialFadeInMs,
    required this.initialFadeOutMs,
    required this.initialLoop,
    required this.initialSolo,
    required this.onSave,
    required this.onCancel,
    this.showSolo = false,
    this.showNote = false,
    this.showTrim = false,
    this.waveformUri,
    this.initialStartMs = 0,
    this.initialEndMs = 0,
    this.showShortcut = false,
    this.initialShortcutKeyId,
    this.initialShortcutLabel,
    this.takenShortcutKeyIds = const {},
    this.onCopy,
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
  final bool showShortcut;
  final int? initialShortcutKeyId;
  final String? initialShortcutLabel;
  final Set<int> takenShortcutKeyIds;
  final VoidCallback? onCopy;
  final ValueChanged<SlotEditResult> onSave;
  final VoidCallback onCancel;

  @override
  State<AudioSlotEditorPanel> createState() => _AudioSlotEditorPanelState();
}

class _AudioSlotEditorPanelState extends State<AudioSlotEditorPanel> {
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
  int? _shortcutKeyId;
  String? _shortcutLabel;
  bool _shortcutConflict = false;

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
    _shortcutKeyId = widget.initialShortcutKeyId;
    _shortcutLabel = widget.initialShortcutLabel;
    if (widget.waveformUri != null) {
      _totalMs = cachedDurationMs(widget.waveformUri!) ?? 0;
      _peaks = cachedWaveform(widget.waveformUri!);
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
      player.setAudioSource(AudioSource.uri(resolveAudioUri(uri))).catchError((
        _,
      ) {
        // 加载失败不影响波形显示与裁剪设置。
        return null;
      }),
    );
    List<double>? peaks;
    try {
      peaks = await loadWaveform(uri);
    } catch (_) {
      peaks = null;
    }
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
    if (_shortcutConflict) return;
    widget.onSave(
      SlotEditResult(
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
        shortcutKeyId: _shortcutKeyId,
        shortcutLabel: _shortcutLabel,
      ),
    );
  }

  void _onShortcutCaptured(int keyId, String label) {
    setState(() {
      _shortcutKeyId = keyId;
      _shortcutLabel = label;
      _shortcutConflict = widget.takenShortcutKeyIds.contains(keyId);
    });
  }

  void _clearShortcut() {
    setState(() {
      _shortcutKeyId = null;
      _shortcutLabel = null;
      _shortcutConflict = false;
    });
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
    final UriAudioSource baseSource = AudioSource.uri(
      resolveAudioUri(widget.waveformUri!),
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('无法试听该音频')));
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
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                  foregroundColor: CueBoxColors.textSecondary,
                ),
                child: Text('关闭'),
              ),
              SizedBox(width: 4),
              FilledButton.tonal(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size(0, 36),
                  textStyle: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text('保存'),
              ),
            ],
          ),
          SizedBox(height: 18),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '名称',
              prefixIcon: Icon(Icons.edit_outlined, size: 20),
            ),
          ),
          if (widget.showNote) ...[
            SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: '备注（可选）',
                prefixIcon: Icon(Icons.notes_outlined, size: 20),
              ),
              onSubmitted: (_) => _save(),
            ),
          ],
          if (widget.showTrim) ...[
            SizedBox(height: 18),
            Row(
              children: [
                Text(
                  '播放区间',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
                Spacer(),
                TextButton.icon(
                  onPressed: _openFullscreen,
                  icon: Icon(Icons.open_in_full, size: 17),
                  label: Text('全屏微调'),
                ),
                TextButton.icon(
                  onPressed: _resetTrim,
                  icon: Icon(Icons.restart_alt, size: 17),
                  label: Text('重置'),
                ),
              ],
            ),
            SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 13,
                  color: CueBoxColors.textFaint,
                ),
                SizedBox(width: 5),
                Expanded(
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
            SizedBox(height: 6),
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
                            color: CueBoxColors.surfacePressed.withValues(
                              alpha: 0.55,
                            ),
                            child: Column(
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
            SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '起点 ${_fmtSeconds(_startMs)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CueBoxColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_previewStartMs != null) ...[
                  SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        size: 12,
                        color: CueBoxColors.amber,
                      ),
                      Text(
                        '试听点 ${_fmtSeconds(_previewStartMs!)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: CueBoxColors.amber,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _previewStartMs = null),
                        child: Icon(
                          Icons.close,
                          size: 13,
                          color: CueBoxColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ],
                Spacer(),
                Text(
                  '总长 ${_fmtSeconds(_totalMs)}',
                  style: TextStyle(fontSize: 12, color: CueBoxColors.textFaint),
                ),
                Spacer(),
                Text(
                  '终点 ${_fmtSeconds(_endMs > 0 ? _endMs : _totalMs)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: CueBoxColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            SizedBox(height: 6),
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
          SizedBox(height: 8),
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
          SizedBox(height: 8),
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
          if (widget.showShortcut) ...[
            SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '快捷键',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _ShortcutCaptureField(
                    label: _shortcutLabel,
                    capturingHint: '请按一个键…',
                    conflict: _shortcutConflict,
                    onCapture: _onShortcutCaptured,
                    onClear: _clearShortcut,
                  ),
                ),
              ],
            ),
            if (_shortcutConflict)
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '该快捷键已被其他 Card 使用，请换一个或清除',
                  style: TextStyle(fontSize: 12, color: CueBoxColors.danger),
                ),
              )
            else
              Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '在 Pad Set 中按此键触发该 Card（不同演出项目互不影响）',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: CueBoxColors.textFaint,
                  ),
                ),
              ),
          ],
          SizedBox(height: 20),
          if (widget.onCopy != null) ...[
            OutlinedButton.icon(
              onPressed: widget.onCopy,
              icon: Icon(Icons.copy_outlined, size: 18),
              label: Text('复制到剪贴板'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutCaptureField extends StatefulWidget {
  const _ShortcutCaptureField({
    required this.label,
    required this.capturingHint,
    required this.conflict,
    required this.onCapture,
    required this.onClear,
  });

  final String? label;
  final String capturingHint;
  final bool conflict;
  final void Function(int keyId, String label) onCapture;
  final VoidCallback onClear;

  @override
  State<_ShortcutCaptureField> createState() => _ShortcutCaptureFieldState();
}

class _ShortcutCaptureFieldState extends State<_ShortcutCaptureField> {
  final FocusNode _focusNode = FocusNode();
  bool _capturing = false;

  static final _modifierKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.shiftLeft,
    LogicalKeyboardKey.shiftRight,
    LogicalKeyboardKey.altLeft,
    LogicalKeyboardKey.altRight,
    LogicalKeyboardKey.metaLeft,
    LogicalKeyboardKey.metaRight,
  };

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startCapture() {
    setState(() => _capturing = true);
    _focusNode.requestFocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (!_capturing) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (_modifierKeys.contains(key)) return KeyEventResult.handled;
    final label = key.keyLabel.isNotEmpty
        ? key.keyLabel.toUpperCase()
        : (key.debugName ?? '?');
    widget.onCapture(key.keyId, label);
    setState(() => _capturing = false);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: widget.conflict
                    ? CueBoxColors.danger.withValues(alpha: 0.12)
                    : CueBoxColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: widget.conflict
                      ? CueBoxColors.danger
                      : CueBoxColors.borderStrong,
                ),
              ),
              child: Text(
                _capturing ? widget.capturingHint : (widget.label ?? '未设置'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _capturing
                      ? CueBoxColors.primary
                      : (widget.label == null
                            ? CueBoxColors.textFaint
                            : CueBoxColors.textPrimary),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(width: 8),
          if (_capturing)
            TextButton(
              onPressed: () {
                setState(() => _capturing = false);
                _focusNode.unfocus();
              },
              child: Text('取消'),
            )
          else ...[
            if (widget.label != null)
              IconButton(
                tooltip: '清除快捷键',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _focusNode.unfocus();
                  widget.onClear();
                },
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: CueBoxColors.textFaint,
                ),
              ),
            FilledButton.tonal(
              onPressed: _startCapture,
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                minimumSize: Size(0, 36),
                textStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              child: Text('录制'),
            ),
          ],
        ],
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
          child: Text(label, style: TextStyle(fontSize: 13.5)),
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
            style: TextStyle(
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
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14)),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: CueBoxColors.textFaint, fontSize: 12),
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
