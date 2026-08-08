import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'show_models.dart';
import 'show_providers.dart';

/// 复制内容的类型：Cue 或 Card。
enum ClipboardKind { cue, card }

/// 复制到应用内剪贴板的条目（内存中，重启后清空）。
class ClipboardItem {
  ClipboardItem({
    required this.kind,
    required this.name,
    required this.note,
    required this.uri,
    required this.volume,
    required this.fadeInMs,
    required this.fadeOutMs,
    required this.loop,
    required this.startMs,
    required this.endMs,
    required this.preWaitMs,
    required this.postWaitMs,
    required this.followGlobal,
    this.solo = true,
    this.shortcutKeyId,
    this.shortcutLabel,
  });

  final ClipboardKind kind;
  final String name;
  final String note;
  final String uri;
  final double volume;
  final int fadeInMs;
  final int fadeOutMs;
  final bool loop;
  final int startMs;
  final int endMs;
  final int preWaitMs;
  final int postWaitMs;
  final bool followGlobal;
  final bool solo;
  final int? shortcutKeyId;
  final String? shortcutLabel;

  factory ClipboardItem.fromCue(Cue cue) {
    return ClipboardItem(
      kind: ClipboardKind.cue,
      name: cue.name,
      note: cue.note,
      uri: cue.uri,
      volume: cue.volume,
      fadeInMs: cue.fadeInMs,
      fadeOutMs: cue.fadeOutMs,
      loop: cue.loop,
      startMs: cue.startMs,
      endMs: cue.endMs,
      preWaitMs: cue.preWaitMs,
      postWaitMs: cue.postWaitMs,
      followGlobal: cue.followGlobal,
    );
  }

  factory ClipboardItem.fromCard(CartSlot slot) {
    return ClipboardItem(
      kind: ClipboardKind.card,
      name: slot.name,
      note: slot.note,
      uri: slot.uri,
      volume: slot.volume,
      fadeInMs: slot.fadeInMs,
      fadeOutMs: slot.fadeOutMs,
      loop: slot.loop,
      startMs: slot.startMs,
      endMs: slot.endMs,
      preWaitMs: 0,
      postWaitMs: 0,
      followGlobal: slot.followGlobal,
      solo: slot.solo,
      shortcutKeyId: slot.shortcutKeyId,
      shortcutLabel: slot.shortcutLabel,
    );
  }
}

final clipboardProvider = StateProvider<ClipboardItem?>((ref) => null);

void copyCueToClipboard(WidgetRef ref, Cue cue) {
  ref.read(clipboardProvider.notifier).state = ClipboardItem.fromCue(cue);
}

void copyCardToClipboard(WidgetRef ref, CartSlot slot) {
  ref.read(clipboardProvider.notifier).state = ClipboardItem.fromCard(slot);
}

/// 把剪贴板内容粘贴到当前工程（仅限同类工程）。
Future<void> pasteClipboard(WidgetRef ref, BuildContext context) async {
  final item = ref.read(clipboardProvider);
  final messenger = ScaffoldMessenger.of(context);
  if (item == null) {
    messenger.showSnackBar(SnackBar(content: Text('剪贴板为空，先复制一个 Cue 或 Card')));
    return;
  }
  final lib = ref.read(showProvider).valueOrNull;
  final show = lib?.activeShow;
  if (show == null) return;

  if (show.kind == ShowKind.cue && item.kind == ClipboardKind.cue) {
    await ref
        .read(showProvider.notifier)
        .addCueWithParams(
          uri: item.uri,
          name: item.name,
          note: item.note,
          volume: item.volume,
          fadeInMs: item.fadeInMs,
          fadeOutMs: item.fadeOutMs,
          loop: item.loop,
          startMs: item.startMs,
          endMs: item.endMs,
          preWaitMs: item.preWaitMs,
          postWaitMs: item.postWaitMs,
          followGlobal: item.followGlobal,
        );
    messenger.showSnackBar(SnackBar(content: Text('已粘贴 Cue「${item.name}」')));
  } else if (show.kind == ShowKind.cart && item.kind == ClipboardKind.card) {
    await ref
        .read(showProvider.notifier)
        .addCartSlotWithParams(
          uri: item.uri,
          name: item.name,
          note: item.note,
          volume: item.volume,
          fadeInMs: item.fadeInMs,
          fadeOutMs: item.fadeOutMs,
          loop: item.loop,
          startMs: item.startMs,
          endMs: item.endMs,
          solo: item.solo,
          shortcutKeyId: item.shortcutKeyId,
          shortcutLabel: item.shortcutLabel,
          followGlobal: item.followGlobal,
        );
    messenger.showSnackBar(SnackBar(content: Text('已粘贴 Card「${item.name}」')));
  } else {
    messenger.showSnackBar(
      SnackBar(content: Text('只能粘贴到同类演出项目（Cue 对 Cue，Card 对 Card）')),
    );
  }
}
