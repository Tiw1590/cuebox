import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/platform/waveform_cache.dart';
import '../../core/theme.dart';
import '../../core/widgets/audio_slot_editor.dart';
import '../../core/widgets/empty_state.dart';
import '../media/media_library_page.dart';
import '../playback/playback_engine.dart';
import '../show/show_models.dart';
import '../show/show_providers.dart';
import '../show/project_settings_sheet.dart';
import '../show/clipboard.dart';
import 'cue_controller.dart';

/// Cue 列表视图（主框架内嵌，无独立 AppBar）。
class CueListPage extends ConsumerStatefulWidget {
  const CueListPage({super.key});

  @override
  ConsumerState<CueListPage> createState() => _CueListPageState();
}

class _CueListPageState extends ConsumerState<CueListPage> {
  bool _inspectorOpen = false;

  void _openInspectorFor(Cue cue) {
    ref.read(cueControllerProvider.notifier).select(cue.id);
    setState(() => _inspectorOpen = true);
  }

  void _savePanel(Cue cue, SlotEditResult r) {
    ref
        .read(showProvider.notifier)
        .updateCue(
          cue.copyWith(
            name: r.name,
            note: r.note,
            startMs: r.startMs,
            endMs: r.endMs,
            preWaitMs: r.preWaitMs,
            postWaitMs: r.postWaitMs,
            volume: r.volume,
            fadeInMs: r.fadeInMs,
            fadeOutMs: r.fadeOutMs,
            loop: r.loop,
          ),
        );
  }

  Future<void> _editWaitTime(Cue cue, bool isPre) async {
    final ms = await showDialog<int>(
      context: context,
      builder: (_) => _WaitTimeDialog(
        title: isPre ? '开始前等待' : '结束后等待',
        initialMs: isPre ? cue.preWaitMs : cue.postWaitMs,
      ),
    );
    if (ms == null) return;
    await ref
        .read(showProvider.notifier)
        .updateCue(
          cue.copyWith(
            preWaitMs: isPre ? ms : cue.preWaitMs,
            postWaitMs: isPre ? cue.postWaitMs : ms,
          ),
        );
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清空 Cue 列表？'),
        content: Text('将删除本场演出全部 Cue，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CueBoxColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(showProvider.notifier).clearAll();
    }
  }

  void _openMediaLibrary() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => MediaLibraryPage()));
  }

  @override
  Widget build(BuildContext context) {
    final showAsync = ref.watch(activeShowProvider);
    final control = ref.watch(cueControllerProvider);
    final playing = ref.watch(playbackEngineProvider);
    final show = showAsync.valueOrNull;
    final cues = show?.cues ?? <Cue>[];
    final locked = show?.locked ?? false;
    final clipboard = ref.watch(clipboardProvider);
    final canPaste = clipboard?.kind == ClipboardKind.cue;
    final selected = cues
        .where((c) => c.id == control.selectedCueId)
        .firstOrNull;

    final mainColumn = Column(
      children: [
        _CueHeader(
          cues: cues,
          selectedCueId: control.selectedCueId,
          onGo: () => ref.read(cueControllerProvider.notifier).go(),
          canStop: playing.isNotEmpty,
          onStopAll: () => ref.read(cueControllerProvider.notifier).stopAll(),
          onEditSelected: () {
            if (selected != null) _openInspectorFor(selected);
          },
          locked: locked,
        ),
        if (!locked)
          _CueToolbar(
            cueCount: cues.length,
            listLoop: control.listLoop,
            onToggleLoop: () =>
                ref.read(cueControllerProvider.notifier).toggleListLoop(),
            onClearAll: _confirmClearAll,
            onProjectSettings: () => showProjectSettingsSheet(context, ref),
            onPaste: canPaste ? () => pasteClipboard(ref, context) : null,
          ),
        Expanded(
          child: switch (showAsync) {
            AsyncLoading() => Center(child: CircularProgressIndicator()),
            AsyncError(:final error) => EmptyState(
              icon: Icons.error_outline,
              title: '加载失败',
              subtitle: '$error',
            ),
            AsyncData() when cues.isEmpty => EmptyState(
              icon: Icons.track_changes,
              title: '还没有 Cue',
              subtitle: '去素材库多选或长按音频，加入 Cue 列表；\nGO 会依次触发，开启列表循环可自动接龙。',
              action: locked
                  ? null
                  : FilledButton.icon(
                      onPressed: _openMediaLibrary,
                      icon: Icon(Icons.library_music_outlined, size: 20),
                      label: Text('去素材库添加'),
                    ),
            ),
            AsyncData(:final value) => _buildList(
              value,
              control,
              playing,
              locked,
              _inspectorOpen,
            ),
            _ => SizedBox.shrink(),
          },
        ),
      ],
    );

    final inspector = (!locked && _inspectorOpen && selected != null)
        ? AudioSlotEditorPanel(
            key: ValueKey(selected.id),
            title: '编辑参数',
            initialName: selected.name,
            initialNote: selected.note,
            initialVolume: selected.volume,
            initialFadeInMs: selected.fadeInMs,
            initialFadeOutMs: selected.fadeOutMs,
            initialLoop: selected.loop,
            initialSolo: true,
            showNote: true,
            showTrim: true,
            waveformUri: selected.uri,
            initialStartMs: selected.startMs,
            initialEndMs: selected.endMs,
            showWait: true,
            initialPreWaitMs: selected.preWaitMs,
            initialPostWaitMs: selected.postWaitMs,
            onCancel: () => setState(() => _inspectorOpen = false),
            onSave: (r) => _savePanel(selected, r),
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 720;
        if (wide) {
          if (inspector == null) return mainColumn;
          return Row(
            children: [
              Expanded(child: mainColumn),
              Container(
                width: 330,
                decoration: BoxDecoration(
                  color: CueBoxColors.surface.withValues(alpha: 0.45),
                  border: Border(left: BorderSide(color: CueBoxColors.border)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: inspector,
                ),
              ),
            ],
          );
        }
        return Column(
          children: [
            Expanded(child: mainColumn),
            if (inspector != null)
              Container(
                height: 360,
                decoration: BoxDecoration(
                  color: Color(0xF20D131B),
                  border: Border(top: BorderSide(color: CueBoxColors.border)),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 16),
                  child: inspector,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildList(
    Show show,
    CueControlState control,
    Map<String, ActivePlay> playing,
    bool locked,
    bool hideTimes,
  ) {
    final cues = show.cues;
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 16),
      buildDefaultDragHandles: false,
      itemCount: cues.length,
      onReorderItem: locked
          ? (_, _) {}
          : (oldIndex, newIndex) {
              final cue = cues[oldIndex];
              final delta = newIndex - oldIndex;
              if (delta != 0) {
                ref.read(showProvider.notifier).moveCue(cue.id, delta);
              }
            },
      itemBuilder: (context, index) {
        final cue = cues[index];
        final selected = control.selectedCueId == cue.id;
        final activePlay = playing.values
            .where((p) => p.sourceId == cue.id && !p.isStopping)
            .firstOrNull;
        final tile = Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _CueTile(
            cue: cue,
            index: index,
            selected: selected,
            activePlay: activePlay,
            waitingForThis: control.waitingCueId == cue.id,
            waitingPhase: control.waitingPhase,
            hideTimes: hideTimes,
            locked: locked,
            onTap: () => ref
                .read(cueControllerProvider.notifier)
                .select(selected ? '' : cue.id),
            onEdit: () => _openInspectorFor(cue),
            onToggleAutoNext: () => ref
                .read(showProvider.notifier)
                .updateCue(cue.copyWith(autoNext: !cue.autoNext)),
            onToggleTogether: () => ref
                .read(showProvider.notifier)
                .updateCue(
                  cue.copyWith(playNextTogether: !cue.playNextTogether),
                ),
            onDelete: () => ref.read(showProvider.notifier).removeCue(cue.id),
            onCopy: () {
              copyCueToClipboard(ref, cue);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已复制 Cue「${cue.name}」')));
            },
            onEditWait: (c, isPre) => _editWaitTime(c, isPre),
          ),
        );
        if (locked) {
          return KeyedSubtree(key: ValueKey(cue.id), child: tile);
        }
        return ReorderableDelayedDragStartListener(
          key: ValueKey(cue.id),
          index: index,
          child: tile,
        );
      },
    );
  }
}

class _CueToolbar extends StatelessWidget {
  const _CueToolbar({
    required this.cueCount,
    required this.listLoop,
    required this.onToggleLoop,
    required this.onClearAll,
    required this.onProjectSettings,
    required this.onPaste,
  });

  final int cueCount;
  final bool listLoop;
  final VoidCallback onToggleLoop;
  final VoidCallback onClearAll;
  final VoidCallback onProjectSettings;
  final VoidCallback? onPaste;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          _LoopChip(active: listLoop, onTap: onToggleLoop),
          SizedBox(width: 6),
          Spacer(),
          IconButton(
            tooltip: '工程参数',
            visualDensity: VisualDensity.compact,
            onPressed: onProjectSettings,
            color: CueBoxColors.textSecondary,
            icon: Icon(Icons.tune, size: 21),
          ),
          if (onPaste != null)
            IconButton(
              tooltip: '粘贴 Cue',
              visualDensity: VisualDensity.compact,
              onPressed: onPaste,
              color: CueBoxColors.secondary,
              icon: Icon(Icons.content_paste_go, size: 21),
            ),
          Text(
            '共 $cueCount 条',
            style: TextStyle(fontSize: 12, color: CueBoxColors.textFaint),
          ),
          IconButton(
            tooltip: '清空列表',
            visualDensity: VisualDensity.compact,
            onPressed: cueCount > 0 ? onClearAll : null,
            color: cueCount > 0
                ? CueBoxColors.textSecondary
                : CueBoxColors.textFaint.withValues(alpha: 0.4),
            icon: Icon(Icons.delete_sweep_outlined, size: 21),
          ),
        ],
      ),
    );
  }
}

class _LoopChip extends StatelessWidget {
  const _LoopChip({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? CueBoxColors.primary.withValues(alpha: 0.12)
          : CueBoxColors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? CueBoxColors.primary.withValues(alpha: 0.5)
                  : CueBoxColors.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.repeat,
                size: 16,
                color: active ? CueBoxColors.primary : CueBoxColors.textFaint,
              ),
              SizedBox(width: 5),
              Text(
                '列表循环',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active
                      ? CueBoxColors.primary
                      : CueBoxColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Cue 行右侧的时间信息列：前等待 / 时长 / 后等待。
/// Cue 行右侧的横向时间信息：前等待 / 时长 / 后等待。
/// 等待时间槽：数字 + 等待阶段专属进度条。
class _WaitSlot extends StatelessWidget {
  const _WaitSlot({
    required this.label,
    required this.text,
    required this.color,
    required this.active,
    required this.durationMs,
    required this.onDoubleTap,
  });

  final String label;
  final String text;
  final Color color;
  final bool active;
  final int durationMs;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _TimeText(label: label, text: text, onDoubleTap: onDoubleTap),
        const SizedBox(height: 4),
        if (active && durationMs > 0)
          TweenAnimationBuilder<double>(
            key: ValueKey('$label$active'),
            tween: Tween(begin: 0, end: 1),
            duration: Duration(milliseconds: durationMs),
            builder: (_, value, _) => _MiniBar(value: value, color: color),
          )
        else
          const SizedBox(height: 7),
      ],
    );
  }
}

/// 列表行上的小状态徽标（循环 / 接 / 同）。
class _FlagBadge extends StatelessWidget {
  const _FlagBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.tooltip,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 时长槽：空闲显示总时长，播放中显示实时已播 + 进度条。
class _DurationSlot extends StatelessWidget {
  const _DurationSlot({
    required this.activePlay,
    required this.durationFuture,
    required this.startMs,
    required this.endMs,
  });

  final ActivePlay? activePlay;
  final Future<int?> durationFuture;
  final int startMs;
  final int endMs;

  @override
  Widget build(BuildContext context) {
    if (activePlay != null) {
      return StreamBuilder<Duration>(
        stream: activePlay!.positionStream,
        initialData: Duration.zero,
        builder: (_, posSnap) {
          final pos = posSnap.data ?? Duration.zero;
          return StreamBuilder<Duration?>(
            stream: activePlay!.durationStream,
            builder: (_, durSnap) {
              final dur = durSnap.data;
              final progress = (dur != null && dur.inMilliseconds > 0)
                  ? (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TimeText(
                    label: '时长',
                    text: fmtMmSsCc(pos.inMilliseconds),
                    color: CueBoxColors.primary,
                  ),
                  const SizedBox(height: 4),
                  _MiniBar(value: progress, color: CueBoxColors.primary),
                ],
              );
            },
          );
        },
      );
    }
    return FutureBuilder<int?>(
      future: durationFuture,
      builder: (_, snap) {
        final total = snap.data ?? 0;
        final trimmed = _trimmedMs(total);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _TimeText(label: '时长', text: fmtMmSsCc(trimmed)),
            const SizedBox(height: 4),
            const SizedBox(height: 3),
          ],
        );
      },
    );
  }

  int _trimmedMs(int totalMs) {
    if (totalMs <= 0) return 0;
    if (endMs > 0 && endMs > startMs) return endMs - startMs;
    if (startMs > 0) return totalMs - startMs;
    return totalMs;
  }
}

class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 3,
          backgroundColor: CueBoxColors.surfacePressed,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

class _TimeText extends StatelessWidget {
  const _TimeText({
    required this.label,
    required this.text,
    this.onDoubleTap,
    this.color,
  });

  final String label;
  final String text;
  final VoidCallback? onDoubleTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: CueBoxColors.textFaint),
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color ?? CueBoxColors.textPrimary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
    if (onDoubleTap == null) return row;
    return Tooltip(
      message: '双击修改',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: onDoubleTap,
        child: row,
      ),
    );
  }
}

class _CueTile extends StatefulWidget {
  const _CueTile({
    required this.cue,
    required this.index,
    required this.selected,
    required this.activePlay,
    required this.waitingForThis,
    required this.waitingPhase,
    required this.hideTimes,
    required this.locked,
    required this.onTap,
    required this.onEdit,
    required this.onToggleAutoNext,
    required this.onToggleTogether,
    required this.onDelete,
    required this.onCopy,
    required this.onEditWait,
  });

  final Cue cue;
  final int index;
  final bool selected;
  final ActivePlay? activePlay;
  final bool waitingForThis;
  final WaitPhase? waitingPhase;
  final bool hideTimes;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onToggleAutoNext;
  final VoidCallback onToggleTogether;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final void Function(Cue cue, bool isPre) onEditWait;

  @override
  State<_CueTile> createState() => _CueTileState();
}

class _CueTileState extends State<_CueTile> {
  late final Future<int?> _durationFuture = loadDurationMs(widget.cue.uri);

  @override
  Widget build(BuildContext context) {
    final cue = widget.cue;
    final index = widget.index;
    final selected = widget.selected;
    final activePlay = widget.activePlay;
    final waitingForThis = widget.waitingForThis;
    final waitingPhase = widget.waitingPhase;
    final hideTimes = widget.hideTimes;
    final locked = widget.locked;
    final onTap = widget.onTap;
    final onEdit = widget.onEdit;
    final onToggleAutoNext = widget.onToggleAutoNext;
    final onToggleTogether = widget.onToggleTogether;
    final onDelete = widget.onDelete;
    final onCopy = widget.onCopy;
    final onEditWait = widget.onEditWait;
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected
            ? CueBoxColors.primary.withValues(alpha: 0.08)
            : CueBoxColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? CueBoxColors.primary : CueBoxColors.border,
          width: selected ? 1.2 : 1,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: CueBoxColors.primary.withValues(alpha: 0.10),
                  blurRadius: 24,
                  spreadRadius: -2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              children: [
                _IndexBadge(index: index + 1, selected: selected),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (cue.loop || cue.autoNext || cue.playNextTogether) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            if (cue.loop)
                              _FlagBadge(
                                icon: Icons.repeat_rounded,
                                label: '循环',
                                color: CueBoxColors.primary,
                                tooltip: '循环播放',
                              ),
                            if (cue.autoNext)
                              _FlagBadge(
                                icon: Icons.skip_next_rounded,
                                label: '接',
                                color: CueBoxColors.primary,
                                tooltip: '播完接下一个',
                              ),
                            if (cue.playNextTogether)
                              _FlagBadge(
                                icon: Icons.layers_rounded,
                                label: '同',
                                color: CueBoxColors.secondary,
                                tooltip: '同时播下一个',
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!hideTimes)
                  Flexible(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _WaitSlot(
                              label: '前',
                              text: fmtMmSsCc(cue.preWaitMs),
                              color: CueBoxColors.amber,
                              active:
                                  waitingForThis &&
                                  waitingPhase == WaitPhase.pre,
                              durationMs: cue.preWaitMs,
                              onDoubleTap: () => onEditWait(cue, true),
                            ),
                            const SizedBox(width: 14),
                            _DurationSlot(
                              activePlay: activePlay,
                              durationFuture: _durationFuture,
                              startMs: cue.startMs,
                              endMs: cue.endMs,
                            ),
                            const SizedBox(width: 14),
                            _WaitSlot(
                              label: '后',
                              text: fmtMmSsCc(cue.postWaitMs),
                              color: CueBoxColors.secondary,
                              active:
                                  waitingForThis &&
                                  waitingPhase == WaitPhase.post,
                              durationMs: cue.postWaitMs,
                              onDoubleTap: () => onEditWait(cue, false),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 6),
                if (!locked)
                  PopupMenuButton<String>(
                    tooltip: 'Cue 操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                        case 'auto_next':
                          onToggleAutoNext();
                        case 'together':
                          onToggleTogether();
                        case 'copy':
                          onCopy();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: _MenuRow(icon: Icons.tune, label: '编辑参数'),
                      ),
                      CheckedPopupMenuItem(
                        value: 'auto_next',
                        checked: cue.autoNext,
                        child: const Row(
                          children: [
                            Icon(Icons.skip_next_outlined, size: 19),
                            SizedBox(width: 10),
                            Text('播完接下一个'),
                          ],
                        ),
                      ),
                      CheckedPopupMenuItem(
                        value: 'together',
                        checked: cue.playNextTogether,
                        child: const Row(
                          children: [
                            Icon(Icons.layers_outlined, size: 19),
                            SizedBox(width: 10),
                            Text('同时播下一个'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: _MenuRow(icon: Icons.copy_outlined, label: '复制'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: _MenuRow(
                          icon: Icons.delete_outline,
                          label: '删除',
                          danger: true,
                        ),
                      ),
                    ],
                    icon: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: CueBoxColors.textFaint,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.index, required this.selected});

  final int index;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: selected ? CueBoxColors.accentGradient : null,
        color: selected ? null : CueBoxColors.surfacePressed,
      ),
      child: Text(
        index.toString().padLeft(2, '0'),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: selected ? Color(0xFF002A36) : CueBoxColors.textSecondary,
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? CueBoxColors.danger : CueBoxColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class _CueHeader extends StatelessWidget {
  const _CueHeader({
    required this.cues,
    required this.selectedCueId,
    required this.onGo,
    required this.canStop,
    required this.onStopAll,
    required this.onEditSelected,
    required this.locked,
  });

  final List<Cue> cues;
  final String? selectedCueId;
  final VoidCallback onGo;
  final bool canStop;
  final VoidCallback onStopAll;
  final VoidCallback onEditSelected;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final selected = cues.where((c) => c.id == selectedCueId).firstOrNull;
    final enabled = cues.isNotEmpty;

    final String nameText;
    final String noteText;
    if (selected != null) {
      nameText = selected.name;
      noteText = selected.note.isNotEmpty ? selected.note : '暂无备注，点右侧编辑添加';
    } else if (cues.isEmpty) {
      nameText = '列表为空';
      noteText = '去素材库把音频加进来';
    } else {
      nameText = '未选择 Cue';
      noteText = '点列表选中，GO 从当前选中开始触发';
    }

    return Container(
      margin: EdgeInsets.fromLTRB(16, 8, 16, 2),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CueBoxColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected != null
              ? CueBoxColors.primary.withValues(alpha: 0.55)
              : CueBoxColors.border,
        ),
        boxShadow: selected != null
            ? [
                BoxShadow(
                  color: CueBoxColors.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          _GoButton(enabled: enabled, onPressed: onGo),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  noteText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected != null
                        ? CueBoxColors.textSecondary
                        : CueBoxColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '停止全部',
            visualDensity: VisualDensity.compact,
            onPressed: canStop ? onStopAll : null,
            color: canStop
                ? CueBoxColors.danger
                : CueBoxColors.textFaint.withValues(alpha: 0.4),
            icon: Icon(Icons.stop_circle_outlined, size: 28),
          ),
          if (selected != null && !locked)
            IconButton(
              tooltip: '编辑名称与备注',
              visualDensity: VisualDensity.compact,
              onPressed: onEditSelected,
              icon: Icon(
                Icons.edit_outlined,
                size: 20,
                color: CueBoxColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _GoButton extends StatelessWidget {
  const _GoButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 196,
      height: 100,
      decoration: BoxDecoration(
        gradient: enabled ? CueBoxColors.accentGradient : null,
        color: enabled ? null : CueBoxColors.surfacePressed,
        borderRadius: BorderRadius.circular(24),
        boxShadow: enabled
            ? [
                CueBoxColors.glow,
                BoxShadow(
                  color: CueBoxColors.primary.withValues(alpha: 0.18),
                  blurRadius: 42,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: enabled ? onPressed : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 40,
                color: enabled ? Color(0xFF002A36) : CueBoxColors.textFaint,
              ),
              SizedBox(width: 6),
              Text(
                'GO',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: enabled ? Color(0xFF002A36) : CueBoxColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 双击等待时间后弹出的快速修改框（以秒输入，支持小数）。
class _WaitTimeDialog extends StatefulWidget {
  const _WaitTimeDialog({required this.title, required this.initialMs});

  final String title;
  final int initialMs;

  @override
  State<_WaitTimeDialog> createState() => _WaitTimeDialogState();
}

class _WaitTimeDialogState extends State<_WaitTimeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: (widget.initialMs / 1000).toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _parse() {
    final v = double.tryParse(_controller.text.trim());
    if (v == null || v < 0) return null;
    return (v * 1000).round().clamp(0, 60000);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              hintText: '秒，如 1.5',
              suffixText: 's',
            ),
            onSubmitted: (_) {
              final ms = _parse();
              if (ms != null) Navigator.of(context).pop(ms);
            },
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in [0.0, 0.5, 1, 2, 3, 5, 10])
                ActionChip(
                  label: Text(v == 0 ? '0' : '${v}s'),
                  onPressed: () {
                    setState(
                      () => _controller.text = v == 0 ? '0' : v.toString(),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final ms = _parse();
            if (ms != null) Navigator.of(context).pop(ms);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}
