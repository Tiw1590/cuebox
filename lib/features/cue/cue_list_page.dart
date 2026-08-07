import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/audio_slot_editor.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/playing_indicator.dart';
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
            volume: r.volume,
            fadeInMs: r.fadeInMs,
            fadeOutMs: r.fadeOutMs,
            loop: r.loop,
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
          onStopAll: () => ref.read(playbackEngineProvider.notifier).stopAll(),
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
                  border: Border(
                    left: BorderSide(color: CueBoxColors.border),
                  ),
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
                  border: Border(
                    top: BorderSide(color: CueBoxColors.border),
                  ),
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
        final isPlaying = playing.values.any(
          (p) => p.sourceId == cue.id && !p.isStopping,
        );
        final tile = Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: _CueTile(
            cue: cue,
            index: index,
            selected: selected,
            isPlaying: isPlaying,
            locked: locked,
            onTap: () => ref
                .read(cueControllerProvider.notifier)
                .select(selected ? '' : cue.id),
            onEdit: () => _openInspectorFor(cue),
            onMoveUp: index > 0
                ? () => ref.read(showProvider.notifier).moveCue(cue.id, -1)
                : null,
            onMoveDown: index < cues.length - 1
                ? () => ref.read(showProvider.notifier).moveCue(cue.id, 1)
                : null,
            onDelete: () => ref.read(showProvider.notifier).removeCue(cue.id),
            onCopy: () {
              copyCueToClipboard(ref, cue);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已复制 Cue「${cue.name}」')));
            },
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

class _CueTile extends StatelessWidget {
  const _CueTile({
    required this.cue,
    required this.index,
    required this.selected,
    required this.isPlaying,
    required this.locked,
    required this.onTap,
    required this.onEdit,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onCopy,
  });

  final Cue cue;
  final int index;
  final bool selected;
  final bool isPlaying;
  final bool locked;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
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
                      if (cue.loop) ...[
                        SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.repeat,
                              size: 12,
                              color: CueBoxColors.primary,
                            ),
                            SizedBox(width: 3),
                            Text(
                              '循环',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: CueBoxColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (isPlaying) ...[
                  PlayingIndicator(),
                  SizedBox(width: 8),
                ],
                if (!locked)
                  PopupMenuButton<String>(
                    tooltip: 'Cue 操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                        case 'up':
                          onMoveUp?.call();
                        case 'down':
                          onMoveDown?.call();
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
                      PopupMenuItem(
                        value: 'up',
                        enabled: onMoveUp != null,
                        child: _MenuRow(
                          icon: Icons.arrow_upward,
                          label: '上移',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: onMoveDown != null,
                        child: _MenuRow(
                          icon: Icons.arrow_downward,
                          label: '下移',
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
          color: selected
              ? Color(0xFF002A36)
              : CueBoxColors.textSecondary,
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
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
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
                color: enabled
                    ? Color(0xFF002A36)
                    : CueBoxColors.textFaint,
              ),
              SizedBox(width: 6),
              Text(
                'GO',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: enabled
                      ? Color(0xFF002A36)
                      : CueBoxColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
