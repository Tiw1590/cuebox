import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets/audio_slot_editor.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/playing_indicator.dart';
import '../media/media_library_page.dart';
import '../playback/playback_engine.dart';
import '../playback/playback_mode.dart';
import '../show/show_models.dart';
import '../show/show_providers.dart';
import '../show/clipboard.dart';

/// 触发一个 Card（已在播放则停止），供点按与快捷键共用。
Future<void> triggerCartSlot(WidgetRef ref, CartSlot slot) async {
  final engine = ref.read(playbackEngineProvider.notifier);
  if (engine.isPlayingSource(slot.id)) {
    await engine.stopSource(slot.id);
    return;
  }
  final show = ref.read(showProvider).valueOrNull?.activeShow;
  final volume = slot.followGlobal ? (show?.defaultVolume ?? 1.0) : slot.volume;
  final loop = slot.followGlobal ? (show?.defaultLoop ?? false) : slot.loop;
  final fadeInMs = slot.followGlobal
      ? (show?.defaultFadeInMs ?? 20)
      : slot.fadeInMs;
  final fadeOutMs = slot.followGlobal
      ? (show?.defaultFadeOutMs ?? 150)
      : slot.fadeOutMs;
  await engine.trigger(
    uri: slot.uri,
    label: slot.name,
    sourceId: slot.id,
    startMs: slot.startMs,
    endMs: slot.endMs,
    loop: loop,
    volume: volume,
    fadeIn: Duration(milliseconds: fadeInMs),
    fadeOut: Duration(milliseconds: fadeOutMs),
    // 全局“多个播放”优先于卡片自身的 Solo：多播模式下一律叠放。
    stopOthers: ref.read(playbackModeProvider) == PlaybackMode.single,
  );
}

/// Pad 视图（主框架内嵌，无独立 AppBar）。
class CartPage extends ConsumerStatefulWidget {
  const CartPage({super.key});

  @override
  ConsumerState<CartPage> createState() => _CartPageState();
}

class _CartPageState extends ConsumerState<CartPage> {
  Future<void> _trigger(CartSlot slot) async {
    await triggerCartSlot(ref, slot);
  }

  Future<void> _editSlot(CartSlot slot) async {
    final show = ref.read(activeShowProvider).valueOrNull;
    final takenKeys = show == null
        ? <int>{}
        : show.cartSlots
              .where((s) => s.id != slot.id)
              .map((s) => s.shortcutKeyId)
              .whereType<int>()
              .toSet();
    await showAudioSlotEditor(
      context: context,
      title: '编辑 Card',
      initialName: slot.name,
      initialNote: slot.note,
      initialVolume: slot.volume,
      initialFadeInMs: slot.fadeInMs,
      initialFadeOutMs: slot.fadeOutMs,
      initialLoop: slot.loop,
      initialSolo: slot.solo,
      showSolo: true,
      showNote: true,
      showTrim: true,
      waveformUri: slot.uri,
      initialStartMs: slot.startMs,
      initialEndMs: slot.endMs,
      showShortcut: true,
      initialShortcutKeyId: slot.shortcutKeyId,
      initialShortcutLabel: slot.shortcutLabel,
      takenShortcutKeyIds: takenKeys,
      showFollowGlobal: true,
      initialFollowGlobal: slot.followGlobal,
      globalVolume: show?.defaultVolume ?? 1.0,
      globalFadeInMs: show?.defaultFadeInMs ?? 20,
      globalFadeOutMs: show?.defaultFadeOutMs ?? 150,
      globalLoop: show?.defaultLoop ?? false,
      onCopy: () {
        copyCardToClipboard(ref, slot);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('已复制 Card「${slot.name}」')));
        }
      },
      onApply: (r) {
        ref
            .read(showProvider.notifier)
            .updateCartSlot(
              slot.copyWith(
                name: r.name,
                note: r.note,
                startMs: r.startMs,
                endMs: r.endMs,
                shortcutKeyId: r.shortcutKeyId,
                shortcutLabel: r.shortcutLabel,
                followGlobal: r.followGlobal,
                volume: r.volume,
                fadeInMs: r.fadeInMs,
                fadeOutMs: r.fadeOutMs,
                loop: r.loop,
                solo: r.solo,
              ),
            );
      },
    );
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清空全部 Card？'),
        content: Text('将删除本场演出全部 Card，此操作无法撤销。'),
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
    final playing = ref.watch(playbackEngineProvider);
    final show = showAsync.valueOrNull;
    final slots = show?.cartSlots ?? <CartSlot>[];
    final locked = show?.locked ?? false;
    final clipboard = ref.watch(clipboardProvider);
    final canPaste = clipboard?.kind == ClipboardKind.card;

    return Column(
      children: [
        _TransportBar(),
        if (!locked)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                Spacer(),
                Text(
                  '共 ${slots.length} 个 Pad',
                  style: TextStyle(fontSize: 12, color: CueBoxColors.textFaint),
                ),
                if (canPaste)
                  IconButton(
                    tooltip: '粘贴 Card',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => pasteClipboard(ref, context),
                    color: CueBoxColors.secondary,
                    icon: Icon(Icons.content_paste_go, size: 21),
                  ),
                IconButton(
                  tooltip: '清空全部 Card',
                  visualDensity: VisualDensity.compact,
                  onPressed: slots.isNotEmpty ? _confirmClearAll : null,
                  color: slots.isNotEmpty
                      ? CueBoxColors.textSecondary
                      : CueBoxColors.textFaint.withValues(alpha: 0.4),
                  icon: Icon(Icons.delete_sweep_outlined, size: 21),
                ),
              ],
            ),
          ),
        Expanded(
          child: switch (showAsync) {
            AsyncLoading() => Center(child: CircularProgressIndicator()),
            AsyncError(:final error) => EmptyState(
              icon: Icons.error_outline,
              title: '加载失败',
              subtitle: '$error',
            ),
            AsyncData() when slots.isEmpty => EmptyState(
              icon: Icons.grid_view_rounded,
              title: '还没有 Card',
              subtitle: '去素材库多选或长按音频，加入 Card；\n点按 Card 立即触发，Solo 会停掉其他声音。',
              action: locked
                  ? null
                  : FilledButton.icon(
                      onPressed: _openMediaLibrary,
                      icon: Icon(Icons.library_music_outlined, size: 20),
                      label: Text('去素材库添加'),
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
              onCopy: (slot) {
                copyCardToClipboard(ref, slot);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('已复制 Card「${slot.name}」')),
                );
              },
              onPaste: () => pasteClipboard(ref, context),
            ),
            _ => SizedBox.shrink(),
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
    required this.onCopy,
    required this.onPaste,
  });

  final List<CartSlot> slots;
  final Map<String, ActivePlay> playing;
  final bool locked;
  final Future<void> Function(CartSlot) onTrigger;
  final Future<void> Function(CartSlot) onEdit;
  final Future<void> Function(CartSlot) onDelete;
  final void Function(CartSlot) onCopy;
  final Future<void> Function() onPaste;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 190,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.05,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isPlaying = playing.values.any(
          (p) => p.sourceId == slot.id && !p.isStopping,
        );
        return _SlotCard(
          slot: slot,
          isPlaying: isPlaying,
          locked: locked,
          onTrigger: () => onTrigger(slot),
          onEdit: () => onEdit(slot),
          onDelete: () => onDelete(slot),
          onCopy: () => onCopy(slot),
          onPaste: onPaste,
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
    required this.onCopy,
    required this.onPaste,
  });

  final CartSlot slot;
  final bool isPlaying;
  final bool locked;
  final VoidCallback onTrigger;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopy;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: isPlaying
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x2E38E1FF), Color(0x1EA78BFA)],
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
                padding: EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (slot.solo)
                          _FlagChip(
                            icon: Icons.flash_on,
                            label: 'Solo',
                            color: CueBoxColors.amber,
                          )
                        else
                          _FlagChip(
                            icon: Icons.layers,
                            label: '叠放',
                            color: CueBoxColors.textSecondary,
                          ),
                        if (slot.loop) ...[
                          SizedBox(width: 6),
                          _FlagChip(
                            icon: Icons.repeat,
                            label: '循环',
                            color: CueBoxColors.primary,
                          ),
                        ],
                        if (slot.shortcutLabel != null) ...[
                          SizedBox(width: 6),
                          _KeyChip(label: slot.shortcutLabel!),
                        ],
                      ],
                    ),
                    Spacer(),
                    if (isPlaying)
                      PlayingIndicator(size: 28)
                    else
                      Icon(
                        Icons.music_note_rounded,
                        size: 34,
                        color: isPlaying
                            ? CueBoxColors.primary
                            : CueBoxColors.textFaint,
                      ),
                    SizedBox(height: 10),
                    Text(
                      slot.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '音量 ${(slot.volume * 100).round()}%',
                      style: TextStyle(
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
                    tooltip: 'Card 操作',
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit();
                        case 'copy':
                          onCopy();
                        case 'paste':
                          onPaste();
                        case 'delete':
                          onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.tune, size: 19),
                            SizedBox(width: 10),
                            Text('编辑参数'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy_outlined, size: 19),
                            SizedBox(width: 10),
                            Text('复制'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'paste',
                        child: Row(
                          children: [
                            Icon(Icons.content_paste_go_outlined, size: 19),
                            SizedBox(width: 10),
                            Text('粘贴'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
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
                    icon: Icon(
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

class _KeyChip extends StatelessWidget {
  const _KeyChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: CueBoxColors.secondary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: CueBoxColors.secondary.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: CueBoxColors.secondary,
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
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 9.5, color: color)),
        ],
      ),
    );
  }
}

/// Pad 顶部走带条：左上名称、右上三时间、左下播放按钮、右下可拖进度条。
class _TransportBar extends ConsumerStatefulWidget {
  const _TransportBar();

  @override
  ConsumerState<_TransportBar> createState() => _TransportBarState();
}

class _TransportBarState extends ConsumerState<_TransportBar> {
  double? _dragMs;

  @override
  Widget build(BuildContext context) {
    final focused = ref.watch(focusedPlayProvider);
    final engine = ref.read(playbackEngineProvider.notifier);
    final active = focused != null;
    final mode = ref.watch(playbackModeProvider);

    return Container(
      margin: EdgeInsets.fromLTRB(16, 4, 16, 6),
      padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
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
              // 左上：名称 + 全局播放模式
              Expanded(
                child: Row(
                  children: [
                    if (active)
                      PlayingIndicator(size: 16)
                    else
                      Icon(
                        Icons.graphic_eq_rounded,
                        size: 16,
                        color: CueBoxColors.textFaint,
                      ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        active ? focused.label : '未在播放',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: mode == PlaybackMode.single
                          ? '全局：单独播放（触发时停掉其他）'
                          : '全局：多个播放（叠放，优先于卡片 Solo）',
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        ref
                            .read(playbackModeProvider.notifier)
                            .setMode(
                              mode == PlaybackMode.single
                                  ? PlaybackMode.multi
                                  : PlaybackMode.single,
                            );
                      },
                      icon: Icon(
                        mode == PlaybackMode.single
                            ? Icons.flash_on_rounded
                            : Icons.layers_rounded,
                        size: 21,
                        color: mode == PlaybackMode.single
                            ? CueBoxColors.amber
                            : CueBoxColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 6),
              // 右上：三个等宽时间
              Expanded(
                child: StreamBuilder<Duration>(
                  stream: active ? focused.positionStream : null,
                  initialData: Duration.zero,
                  builder: (_, posSnap) {
                    final pos = posSnap.data ?? Duration.zero;
                    return StreamBuilder<Duration?>(
                      stream: active ? focused.durationStream : null,
                      builder: (_, durSnap) {
                        final dur = durSnap.data;
                        final rawRemaining = dur == null ? null : dur - pos;
                        final remaining =
                            (rawRemaining == null || rawRemaining.isNegative)
                            ? null
                            : rawRemaining;
                        // 三个时间共用同一帧快照，严格同步。
                        return Row(
                          children: [
                            _TimeCell(
                              label: '已播',
                              text: _fmtDur(pos),
                              color: CueBoxColors.primary,
                            ),
                            _TimeCell(
                              label: '总长',
                              text: dur == null ? '--:--' : _fmtDur(dur),
                              color: CueBoxColors.textPrimary,
                            ),
                            _TimeCell(
                              label: '倒计时',
                              text: remaining == null
                                  ? '--:--'
                                  : _fmtDur(remaining),
                              color: CueBoxColors.amber,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              // 左下：播放 / 暂停 / 停止
              Expanded(
                flex: 5,
                child: StreamBuilder<bool>(
                  stream: active ? focused.playingStream : null,
                  initialData: true,
                  builder: (_, playSnap) {
                    final playing = active && (playSnap.data ?? true);
                    return Row(
                      children: [
                        Expanded(
                          child: _TransportButton(
                            tooltip: '暂停',
                            icon: Icons.pause_rounded,
                            enabled: playing,
                            onTap: () {
                              if (focused != null) {
                                engine.pausePlay(focused.id);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: _TransportButton(
                            tooltip: '播放',
                            icon: Icons.play_arrow_rounded,
                            enabled: active && !playing,
                            onTap: () {
                              if (focused != null) {
                                engine.resumePlay(focused.id);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: _TransportButton(
                            tooltip: '停止',
                            icon: Icons.stop_rounded,
                            danger: true,
                            enabled: active,
                            onTap: () {
                              if (focused != null) {
                                engine.stopPlay(focused.id);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              SizedBox(width: 10),
              // 右下：可拖拽进度条
              Expanded(
                flex: 4,
                child: StreamBuilder<Duration>(
                  stream: active ? focused.positionStream : null,
                  initialData: Duration.zero,
                  builder: (_, posSnap) {
                    return StreamBuilder<Duration?>(
                      stream: active ? focused.durationStream : null,
                      builder: (_, durSnap) {
                        final durMs = (durSnap.data?.inMilliseconds ?? 0)
                            .toDouble();
                        final posMs = (posSnap.data?.inMilliseconds ?? 0)
                            .toDouble();
                        final value = (_dragMs ?? posMs).clamp(
                          0.0,
                          durMs > 0 ? durMs : 0.0,
                        );
                        return SizedBox(
                          height: 64,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 6,
                              thumbShape: RoundSliderThumbShape(
                                enabledThumbRadius: 9,
                              ),
                              overlayShape: RoundSliderOverlayShape(
                                overlayRadius: 16,
                              ),
                            ),
                            child: Slider(
                              value: value,
                              max: durMs > 0 ? durMs : 1,
                              onChanged: active && durMs > 0
                                  ? (v) => setState(() => _dragMs = v)
                                  : null,
                              onChangeEnd: (v) {
                                if (focused != null) {
                                  engine.seekPlay(
                                    focused.id,
                                    Duration(milliseconds: v.round()),
                                  );
                                }
                                setState(() => _dragMs = null);
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.label,
    required this.text,
    required this.color,
  });

  final String label;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: CueBoxColors.textFaint),
          ),
          SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              text,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransportButton extends StatelessWidget {
  const _TransportButton({
    required this.tooltip,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? CueBoxColors.danger : CueBoxColors.primary;
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: enabled ? onTap : null,
        style: OutlinedButton.styleFrom(
          minimumSize: Size(0, 64),
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: enabled
                ? accent.withValues(alpha: 0.55)
                : CueBoxColors.border,
            width: enabled ? 1.3 : 1,
          ),
          foregroundColor: enabled
              ? (danger ? CueBoxColors.danger : CueBoxColors.textPrimary)
              : CueBoxColors.textFaint.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Icon(icon, size: 26),
      ),
    );
  }
}

String _fmtDur(Duration d) {
  final clamped = d.isNegative ? Duration.zero : d;
  return fmtMmSsCc(clamped.inMilliseconds);
}
