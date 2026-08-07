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

/// Cart 格块视图（主框架内嵌，无独立 AppBar）。
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  Future<void> _trigger(CartSlot slot) async {
    final engine = ref.read(playbackEngineProvider.notifier);
    if (engine.isPlayingSource(slot.id)) {
      await engine.stopSource(slot.id);
      return;
    }
    await engine.trigger(
      uri: slot.uri,
      label: slot.name,
      sourceId: slot.id,
      loop: slot.loop,
      volume: slot.volume,
      fadeIn: slot.fadeIn,
      fadeOut: slot.fadeOut,
      stopOthers: slot.solo,
    );
  }

  Future<void> _editSlot(CartSlot slot) async {
    final outcome = await showAudioSlotEditor(
      context: context,
      title: '编辑格块',
      initialName: slot.name,
      initialVolume: slot.volume,
      initialFadeInMs: slot.fadeInMs,
      initialFadeOutMs: slot.fadeOutMs,
      initialLoop: slot.loop,
      initialSolo: slot.solo,
      showSolo: true,
    );
    if (outcome is SlotEditSaved) {
      final r = outcome.result;
      await ref.read(showProvider.notifier).updateCartSlot(
            slot.copyWith(
              name: r.name,
              volume: r.volume,
              fadeInMs: r.fadeInMs,
              fadeOutMs: r.fadeOutMs,
              loop: r.loop,
              solo: r.solo,
            ),
          );
    }
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部格块？'),
        content: const Text('将删除本场演出全部 Cart 格块，此操作无法撤销。'),
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
    final playing = ref.watch(playbackEngineProvider);
    final show = showAsync.valueOrNull;
    final slots = show?.cartSlots ?? const <CartSlot>[];
    final locked = show?.locked ?? false;

    return Column(
      children: [
        if (!locked)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                const Spacer(),
                Text(
                  '共 ${slots.length} 个格块',
                  style: const TextStyle(
                    fontSize: 12,
                    color: CueBoxColors.textFaint,
                  ),
                ),
                IconButton(
                  tooltip: '清空全部格块',
                  visualDensity: VisualDensity.compact,
                  onPressed: slots.isNotEmpty ? _confirmClearAll : null,
                  color: slots.isNotEmpty
                      ? CueBoxColors.textSecondary
                      : CueBoxColors.textFaint.withValues(alpha: 0.4),
                  icon: const Icon(Icons.delete_sweep_outlined, size: 21),
                ),
              ],
            ),
          ),
        const _TransportBar(),
        Expanded(
          child: switch (showAsync) {
            AsyncLoading() => const Center(child: CircularProgressIndicator()),
            AsyncError(:final error) => EmptyState(
                icon: Icons.error_outline,
                title: '加载失败',
                subtitle: '$error',
              ),
            AsyncData() when slots.isEmpty => EmptyState(
                icon: Icons.grid_view_rounded,
                title: '格块还是空的',
                subtitle: '去素材库多选或长按音频，加入 Cart 格块；\n点按格块立即触发，Solo 会停掉其他声音。',
                action: locked
                    ? null
                    : FilledButton.icon(
                        onPressed: _openMediaLibrary,
                        icon: const Icon(Icons.library_music_outlined, size: 20),
                        label: const Text('去素材库添加'),
                      ),
              ),
            AsyncData(:final value) => _SlotGrid(
                slots: value.cartSlots,
                playing: playing,
                locked: locked,
                onTrigger: _trigger,
                onEdit: _editSlot,
                onDelete: (slot) =>
                    ref.read(showProvider.notifier).removeCartSlot(slot.id),
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.slots,
    required this.playing,
    required this.locked,
    required this.onTrigger,
    required this.onEdit,
    required this.onDelete,
  });

  final List<CartSlot> slots;
  final Map<String, ActivePlay> playing;
  final bool locked;
  final Future<void> Function(CartSlot) onTrigger;
  final Future<void> Function(CartSlot) onEdit;
  final Future<void> Function(CartSlot) onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isPlaying = playing.values
            .any((p) => p.sourceId == slot.id && !p.isStopping);
        return _SlotCard(
          slot: slot,
          isPlaying: isPlaying,
          locked: locked,
          onTrigger: () => onTrigger(slot),
          onEdit: () => onEdit(slot),
          onDelete: () => onDelete(slot),
        );
      },
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.isPlaying,
    required this.locked,
    required this.onTrigger,
    required this.onEdit,
    required this.onDelete,
  });

  final CartSlot slot;
  final bool isPlaying;
  final bool locked;
  final VoidCallback onTrigger;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: isPlaying
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0x2E38E1FF),
                  Color(0x1EA78BFA),
                ],
              )
            : null,
        color: isPlaying ? null : CueBoxColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPlaying ? CueBoxColors.primary : CueBoxColors.border,
          width: isPlaying ? 1.3 : 1,
        ),
        boxShadow: isPlaying ? [CueBoxColors.glow] : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTrigger,
          onLongPress: locked ? null : onEdit,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (slot.solo)
                          const _FlagChip(
                            icon: Icons.flash_on,
                            label: 'Solo',
                            color: CueBoxColors.amber,
                          )
                        else
                          const _FlagChip(
                            icon: Icons.layers,
                            label: '叠放',
                            color: CueBoxColors.textSecondary,
                          ),
                        if (slot.loop) ...[
                          const SizedBox(width: 6),
                          const _FlagChip(
                            icon: Icons.repeat,
                            label: '循环',
                            color: CueBoxColors.primary,
                          ),
                        ],
                      ],
                    ),
                    const Spacer(),
                    if (isPlaying)
                      const PlayingIndicator(size: 28)
                    else
                      Icon(
                        Icons.music_note_rounded,
                        size: 34,
                        color: isPlaying
                            ? CueBoxColors.primary
                            : CueBoxColors.textFaint,
                      ),
                    const SizedBox(height: 10),
                    Text(
                      slot.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '音量 ${(slot.volume * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: CueBoxColors.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
              if (!locked)
                Positioned(
                  top: 2,
                  right: 2,
                  child: PopupMenuButton<String>(
                    tooltip: '格块操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.tune, size: 19),
                            SizedBox(width: 10),
                            Text('编辑参数'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 19,
                              color: CueBoxColors.danger,
                            ),
                            SizedBox(width: 10),
                            Text(
                              '删除',
                              style: TextStyle(color: CueBoxColors.danger),
                            ),
                          ],
                        ),
                      ),
                    ],
                    icon: const Icon(
                      Icons.more_vert,
                      size: 18,
                      color: CueBoxColors.textFaint,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlagChip extends StatelessWidget {
  const _FlagChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: color),
          ),
        ],
      ),
    );
  }
}

/// Cart 顶部走带条：当前播放条目的暂停 / 播放 / 停止与计时信息。
class _TransportBar extends ConsumerWidget {
  const _TransportBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final focused = ref.watch(focusedPlayProvider);
    final engine = ref.read(playbackEngineProvider.notifier);
    final active = focused != null;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: CueBoxColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? CueBoxColors.primary.withValues(alpha: 0.5)
              : CueBoxColors.border,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: CueBoxColors.primary.withValues(alpha: 0.08),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (active)
                const PlayingIndicator(size: 18)
              else
                const Icon(
                  Icons.graphic_eq_rounded,
                  size: 18,
                  color: CueBoxColors.textFaint,
                ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  active ? focused.label : '未在播放',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (active)
                StreamBuilder<Duration>(
                  stream: focused.positionStream,
                  initialData: Duration.zero,
                  builder: (_, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    return StreamBuilder<Duration?>(
                      stream: focused.durationStream,
                      builder: (_, durSnap) {
                        final dur = durSnap.data;
                        final remaining = dur == null ? null : dur - pos;
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _fmtDur(pos),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: CueBoxColors.primary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const Text(
                              ' / ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: CueBoxColors.textFaint,
                              ),
                            ),
                            Text(
                              dur == null ? '--:--' : _fmtDur(dur),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: CueBoxColors.primary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            if (remaining != null) ...[
                              const SizedBox(width: 10),
                              Text(
                                _fmtDur(remaining),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: CueBoxColors.amber,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    );
                  },
                )
              else
                const Text(
                  '00:00 / --:--',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CueBoxColors.textFaint,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<bool>(
            stream: active ? focused.playingStream : null,
            initialData: true,
            builder: (_, playSnap) {
              final playing = active && (playSnap.data ?? true);
              return Row(
                children: [
                  Expanded(
                    child: _TransportButton(
                      icon: Icons.pause_rounded,
                      label: '暂停',
                      enabled: playing,
                      onTap: () {
                        if (focused != null) engine.pausePlay(focused.id);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TransportButton(
                      icon: Icons.play_arrow_rounded,
                      label: '播放',
                      enabled: active && !playing,
                      onTap: () {
                        if (focused != null) engine.resumePlay(focused.id);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _TransportButton(
                      icon: Icons.stop_rounded,
                      label: '停止',
                      danger: true,
                      enabled: active,
                      onTap: () {
                        if (focused != null) engine.stopPlay(focused.id);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? CueBoxColors.danger : CueBoxColors.primary;
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        side: BorderSide(
          color: enabled
              ? accent.withValues(alpha: 0.55)
              : CueBoxColors.border,
          width: enabled ? 1.3 : 1,
        ),
        foregroundColor: enabled
            ? (danger ? CueBoxColors.danger : CueBoxColors.textPrimary)
            : CueBoxColors.textFaint.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon, size: 22),
      label: Text(label),
    );
  }
}

String _fmtDur(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  final minutes = clamped.inMinutes;
  final seconds = clamped.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
