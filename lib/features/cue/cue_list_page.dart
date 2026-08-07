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
import 'cue_controller.dart';

/// Cue 列表视图（主框架内嵌，无独立 AppBar）。
class CueListPage extends ConsumerStatefulWidget {
  const CueListPage({super.key});

  @override
  ConsumerState<CueListPage> createState() => _CueListPageState();
}

class _CueListPageState extends ConsumerState<CueListPage> {
  Future<void> _editCue(Cue cue) async {
    final outcome = await showAudioSlotEditor(
      context: context,
      title: '编辑 Cue',
      initialName: cue.name,
      initialNote: cue.note,
      initialVolume: cue.volume,
      initialFadeInMs: cue.fadeInMs,
      initialFadeOutMs: cue.fadeOutMs,
      initialLoop: cue.loop,
      initialSolo: true,
      showNote: true,
      showTrim: true,
      waveformUri: cue.uri,
      initialStartMs: cue.startMs,
      initialEndMs: cue.endMs,
    );
    if (outcome is SlotEditSaved) {
      final r = outcome.result;
      await ref.read(showProvider.notifier).updateCue(
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
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空 Cue 列表？'),
        content: const Text('将删除本场演出全部 Cue，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CueBoxColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(showProvider.notifier).clearAll();
    }
  }

  void _openMediaLibrary() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MediaLibraryPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showAsync = ref.watch(activeShowProvider);
    final control = ref.watch(cueControllerProvider);
    final playing = ref.watch(playbackEngineProvider);
    final show = showAsync.valueOrNull;
    final cues = show?.cues ?? const <Cue>[];
    final locked = show?.locked ?? false;

    return Column(
      children: [
        _CueHeader(
          cues: cues,
          selectedCueId: control.selectedCueId,
          onGo: () => ref.read(cueControllerProvider.notifier).go(),
          onEditSelected: () {
            final selected = cues
                .where((c) => c.id == control.selectedCueId)
                .firstOrNull;
            if (selected != null) _editCue(selected);
          },
          locked: locked,
        ),
        if (!locked)
          _CueToolbar(
            cueCount: cues.length,
            listLoop: control.listLoop,
            playingCount: playing.length,
            onToggleLoop: () =>
                ref.read(cueControllerProvider.notifier).toggleListLoop(),
            onStopAll: () =>
                ref.read(playbackEngineProvider.notifier).stopAll(),
            onClearAll: _confirmClearAll,
            onProjectSettings: () =>
                showProjectSettingsSheet(context, ref),
          ),
        Expanded(
          child: switch (showAsync) {
            AsyncLoading() =>
              const Center(child: CircularProgressIndicator()),
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
                        icon: const Icon(Icons.library_music_outlined, size: 20),
                        label: const Text('去素材库添加'),
                      ),
              ),
            AsyncData(:final value) =>
              _buildList(value, control, playing, locked),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
        final isPlaying = playing.values
            .any((p) => p.sourceId == cue.id && !p.isStopping);
        final tile = Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _CueTile(
            cue: cue,
            index: index,
            selected: selected,
            isPlaying: isPlaying,
            locked: locked,
            onTap: () => ref
                .read(cueControllerProvider.notifier)
                .select(selected ? '' : cue.id),
            onEdit: () => _editCue(cue),
            onMoveUp: index > 0
                ? () => ref.read(showProvider.notifier).moveCue(cue.id, -1)
                : null,
            onMoveDown: index < cues.length - 1
                ? () => ref.read(showProvider.notifier).moveCue(cue.id, 1)
                : null,
            onDelete: () =>
                ref.read(showProvider.notifier).removeCue(cue.id),
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
    required this.playingCount,
    required this.onToggleLoop,
    required this.onStopAll,
    required this.onClearAll,
    required this.onProjectSettings,
  });

  final int cueCount;
  final bool listLoop;
  final int playingCount;
  final VoidCallback onToggleLoop;
  final VoidCallback onStopAll;
  final VoidCallback onClearAll;
  final VoidCallback onProjectSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Row(
        children: [
          _LoopChip(active: listLoop, onTap: onToggleLoop),
          const SizedBox(width: 6),
          IconButton(
            tooltip: '停止全部',
            visualDensity: VisualDensity.compact,
            onPressed: playingCount > 0 ? onStopAll : null,
            color: playingCount > 0
                ? CueBoxColors.danger
                : CueBoxColors.textFaint.withValues(alpha: 0.4),
            icon: const Icon(Icons.stop_circle_outlined, size: 22),
          ),
          const Spacer(),
          IconButton(
            tooltip: '工程参数',
            visualDensity: VisualDensity.compact,
            onPressed: onProjectSettings,
            color: CueBoxColors.textSecondary,
            icon: const Icon(Icons.tune, size: 21),
          ),
          Text(
            '共 $cueCount 条',
            style: const TextStyle(
              fontSize: 12,
              color: CueBoxColors.textFaint,
            ),
          ),
          IconButton(
            tooltip: '清空列表',
            visualDensity: VisualDensity.compact,
            onPressed: cueCount > 0 ? onClearAll : null,
            color: cueCount > 0
                ? CueBoxColors.textSecondary
                : CueBoxColors.textFaint.withValues(alpha: 0.4),
            icon: const Icon(Icons.delete_sweep_outlined, size: 21),
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                color: active
                    ? CueBoxColors.primary
                    : CueBoxColors.textFaint,
              ),
              const SizedBox(width: 5),
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

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
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
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            child: Row(
              children: [
                _IndexBadge(index: index + 1, selected: selected),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cue.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (cue.loop) ...[
                        const SizedBox(height: 5),
                        const Row(
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
                  const PlayingIndicator(),
                  const SizedBox(width: 8),
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
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: _MenuRow(
                          icon: Icons.tune,
                          label: '编辑参数',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'up',
                        enabled: onMoveUp != null,
                        child: const _MenuRow(
                          icon: Icons.arrow_upward,
                          label: '上移',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'down',
                        enabled: onMoveDown != null,
                        child: const _MenuRow(
                          icon: Icons.arrow_downward,
                          label: '下移',
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: _MenuRow(
                          icon: Icons.delete_outline,
                          label: '删除',
                          danger: true,
                        ),
                      ),
                    ],
                    icon: const Icon(
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
      duration: const Duration(milliseconds: 200),
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
              ? const Color(0xFF002A36)
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
        const SizedBox(width: 10),
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
    required this.onEditSelected,
    required this.locked,
  });

  final List<Cue> cues;
  final String? selectedCueId;
  final VoidCallback onGo;
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
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nameText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
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
          if (selected != null && !locked)
            IconButton(
              tooltip: '编辑名称与备注',
              visualDensity: VisualDensity.compact,
              onPressed: onEditSelected,
              icon: const Icon(
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
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      width: 128,
      height: 66,
      decoration: BoxDecoration(
        gradient: enabled ? CueBoxColors.accentGradient : null,
        color: enabled ? null : CueBoxColors.surfacePressed,
        borderRadius: BorderRadius.circular(20),
        boxShadow: enabled ? [CueBoxColors.glow] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: enabled ? onPressed : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.play_arrow_rounded,
                size: 34,
                color:
                    enabled ? const Color(0xFF002A36) : CueBoxColors.textFaint,
              ),
              const SizedBox(width: 6),
              Text(
                'GO',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color:
                      enabled ? const Color(0xFF002A36) : CueBoxColors.textFaint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
