import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/platform/waveform_cache.dart';
import '../../core/widgets/cuebox_background.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/playing_indicator.dart';
import '../playback/playback_engine.dart';
import '../show/show_models.dart';
import '../show/show_providers.dart';
import 'media_models.dart';
import 'media_providers.dart';

/// 素材池：浏览目录、试听、多选加入 Cue / Cart。
class MediaLibraryPage extends ConsumerStatefulWidget {
  const MediaLibraryPage({super.key});

  @override
  ConsumerState<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends ConsumerState<MediaLibraryPage> {
  bool _selecting = false;
  final Set<String> _selectedUris = <String>{};

  // ---------- 试听 ----------

  Future<void> _togglePreview(MediaItem item) async {
    final engine = ref.read(playbackEngineProvider.notifier);
    final tag = 'preview_${item.uri}';
    if (engine.isPlayingSource(tag)) {
      await engine.stopSource(tag);
    } else {
      await engine.trigger(
        uri: item.uri,
        label: item.name,
        sourceId: tag,
        fadeIn: const Duration(milliseconds: 80),
        fadeOut: const Duration(milliseconds: 120),
        stopOthers: true,
      );
    }
  }

  // ---------- 多选状态 ----------

  void _enterSelection([MediaItem? item]) {
    setState(() {
      _selecting = true;
      if (item != null) _selectedUris.add(item.uri);
    });
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedUris.clear();
    });
  }

  void _toggleSelect(MediaItem item) {
    setState(() {
      if (!_selectedUris.add(item.uri)) _selectedUris.remove(item.uri);
    });
  }

  void _toggleSelectAll(List<MediaItem> audioItems) {
    setState(() {
      final all = audioItems.map((i) => i.uri).toSet();
      final allSelected =
          all.isNotEmpty && all.every(_selectedUris.contains);
      if (allSelected) {
        _selectedUris.removeAll(all);
      } else {
        _selectedUris.addAll(all);
      }
    });
  }

  List<MediaItem> _currentAudioItems(List<MediaItem> children) =>
      children.where((i) => i.isAudio).toList();

  // ---------- 添加 ----------

  Future<void> _addToCue(MediaItem item) async {
    await ref.read(showProvider.notifier).addCue(
          uri: item.uri,
          name: item.name,
        );
    preloadWaveform(item.uri);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${item.name}」已加入 Cue 列表'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _addToCart(MediaItem item) async {
    await ref.read(showProvider.notifier).addCartSlot(
          uri: item.uri,
          name: item.name,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${item.name}」已加入 Cart 格块'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _addSelectedToCue(List<MediaItem> selected) async {
    await ref.read(showProvider.notifier).addCues(
          selected.map((i) => (uri: i.uri, name: i.name)).toList(),
        );
    for (final item in selected) {
      preloadWaveform(item.uri);
    }
    if (!mounted) return;
    final n = selected.length;
    setState(() => _selectedUris.clear()); // 保持多选模式，可继续选
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已加入 Cue 列表 · $n 项，可继续选择添加'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _addSelectedToCart(List<MediaItem> selected) async {
    await ref.read(showProvider.notifier).addCartSlots(
          selected.map((i) => (uri: i.uri, name: i.name)).toList(),
        );
    if (!mounted) return;
    final n = selected.length;
    setState(() => _selectedUris.clear());
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已加入 Cart 格块 · $n 项，可继续选择添加'),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  // ---------- 构建 ----------

  @override
  Widget build(BuildContext context) {
    final rootAsync = ref.watch(mediaRootProvider);
    final browse = ref.watch(mediaBrowseProvider);
    final playing = ref.watch(playbackEngineProvider);
    final activeShow = ref.watch(activeShowProvider).valueOrNull;
    final targetKind = activeShow?.kind ?? ShowKind.cue;

    ref.listen(mediaRootProvider, (prev, next) {
      final prevUri = prev?.valueOrNull?.uri;
      final nextUri = next.valueOrNull?.uri;
      if (prevUri != nextUri) {
        ref.read(mediaBrowseProvider.notifier).reset();
      }
    });

    final root = rootAsync.valueOrNull;
    if (root != null && browse.path.isEmpty && !browse.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(mediaBrowseProvider.notifier).openRoot(root);
      });
    }

    final audioItems = _currentAudioItems(browse.children);
    final allSelected = audioItems.isNotEmpty &&
        audioItems.every((i) => _selectedUris.contains(i.uri));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                tooltip: '退出多选',
                icon: const Icon(Icons.close),
                onPressed: _exitSelection,
              ),
              title: Text('已选 ${_selectedUris.length} 项'),
              actions: [
                TextButton(
                  onPressed: () => _toggleSelectAll(audioItems),
                  child: Text(
                    allSelected ? '取消全选' : '全选',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            )
          : AppBar(
              title: Text(root?.name ?? '素材池'),
              actions: [
                if (root != null)
                  IconButton(
                    tooltip: '更换素材目录',
                    icon: const Icon(Icons.folder_open_outlined),
                    onPressed: () =>
                        ref.read(mediaRootProvider.notifier).pick(),
                  ),
                if (browse.hasRoot)
                  IconButton(
                    tooltip: '刷新',
                    icon: const Icon(Icons.refresh),
                    onPressed: () =>
                        ref.read(mediaBrowseProvider.notifier).refresh(),
                  ),
                if (root != null)
                  IconButton(
                    tooltip: '多选添加',
                    icon: const Icon(Icons.library_add_check_outlined),
                    onPressed: () => _enterSelection(),
                  ),
              ],
            ),
      body: CueBoxBackground(
        child: switch (rootAsync) {
          AsyncLoading() => const Center(child: CircularProgressIndicator()),
          AsyncError(:final error) => _ErrorView(
              message: '$error',
              onRetry: () => ref.invalidate(mediaRootProvider),
            ),
          _ when root == null => EmptyState(
              icon: Icons.folder_open_rounded,
              iconColor: CueBoxColors.amber,
              title: '选择素材目录',
              subtitle: '音频文件按子文件夹分组展示；\n点按试听，长按进入多选，可一次加入 Cue 或 Cart。',
              action: FilledButton.icon(
                onPressed: () => ref.read(mediaRootProvider.notifier).pick(),
                icon: const Icon(Icons.folder_open, size: 20),
                label: const Text('选择素材目录'),
              ),
            ),
          _ => _FolderBrowser(
              browse: browse,
              playing: playing,
              selecting: _selecting,
              selectedUris: _selectedUris,
              onPreview: _togglePreview,
              onLongPress: _toggleSelect,
              onTapItem: _selecting ? _toggleSelect : _togglePreview,
              onEnterSelection: _enterSelection,
              onShowActions: _showAudioActions,
            ),
        },
      ),
      bottomNavigationBar: _selecting
          ? _SelectionBar(
              kind: targetKind,
              selectedCount: _selectedUris.length,
              onAddCue: _selectedUris.isEmpty || targetKind != ShowKind.cue
                  ? null
                  : () => _addSelectedToCue(
                        audioItems
                            .where((i) => _selectedUris.contains(i.uri))
                            .toList(),
                      ),
              onAddCart: _selectedUris.isEmpty || targetKind != ShowKind.cart
                  ? null
                  : () => _addSelectedToCart(
                        audioItems
                            .where((i) => _selectedUris.contains(i.uri))
                            .toList(),
                      ),
            )
          : null,
    );
  }

  void _showAudioActions(MediaItem item) {
    final activeShow = ref.read(activeShowProvider).valueOrNull;
    final targetKind = activeShow?.kind ?? ShowKind.cue;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '音频文件 · ${_formatBytes(item.size)}',
                    style: const TextStyle(
                      color: CueBoxColors.textFaint,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.play_circle_outline,
                color: CueBoxColors.primary,
              ),
              title: const Text('试听'),
              subtitle: const Text('点按再次试听可停止'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _togglePreview(item);
              },
            ),
            if (targetKind == ShowKind.cue)
              ListTile(
                leading: const Icon(
                  Icons.playlist_add,
                  color: CueBoxColors.secondary,
                ),
                title: const Text('加入 Cue 列表'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _addToCue(item);
                },
              ),
            if (targetKind == ShowKind.cart)
              ListTile(
                leading: const Icon(
                  Icons.grid_view_rounded,
                  color: CueBoxColors.amber,
                ),
                title: const Text('加入 Cart 格块'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _addToCart(item);
                },
              ),
            ListTile(
              leading: const Icon(
                Icons.library_add_check_outlined,
                color: CueBoxColors.textSecondary,
              ),
              title: const Text('多选添加'),
              subtitle: const Text('可一次选择多个文件批量加入'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _enterSelection(item);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.kind,
    required this.selectedCount,
    required this.onAddCue,
    required this.onAddCart,
  });

  final ShowKind kind;
  final int selectedCount;
  final VoidCallback? onAddCue;
  final VoidCallback? onAddCart;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF20D131B),
        border: const Border(top: BorderSide(color: CueBoxColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Text(
              selectedCount == 0 ? '选择音频文件' : '已选 $selectedCount 项',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selectedCount == 0
                    ? CueBoxColors.textFaint
                    : CueBoxColors.primary,
              ),
            ),
            const Spacer(),
            if (kind == ShowKind.cue) ...[
              OutlinedButton.icon(
                onPressed: onAddCue,
                icon: const Icon(Icons.playlist_add, size: 18),
                label:
                    Text('加入 Cue${selectedCount > 0 ? ' ($selectedCount)' : ''}'),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: onAddCart,
                icon: const Icon(Icons.grid_view_rounded, size: 18),
                label:
                    Text('加入 Cart${selectedCount > 0 ? ' ($selectedCount)' : ''}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FolderBrowser extends ConsumerWidget {
  const _FolderBrowser({
    required this.browse,
    required this.playing,
    required this.selecting,
    required this.selectedUris,
    required this.onPreview,
    required this.onLongPress,
    required this.onTapItem,
    required this.onEnterSelection,
    required this.onShowActions,
  });

  final MediaBrowseState browse;
  final Map<String, ActivePlay> playing;
  final bool selecting;
  final Set<String> selectedUris;
  final Future<void> Function(MediaItem) onPreview;
  final ValueChanged<MediaItem> onLongPress;
  final ValueChanged<MediaItem> onTapItem;
  final ValueChanged<MediaItem> onEnterSelection;
  final ValueChanged<MediaItem> onShowActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (browse.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (browse.error != null) {
      return _ErrorView(message: browse.error!);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (browse.path.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < browse.path.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.chevron_right,
                        size: 15,
                        color: CueBoxColors.textFaint,
                      ),
                    ),
                  _BreadcrumbChip(
                    label: browse.path[i].name,
                    isCurrent: i == browse.path.length - 1,
                    onTap: i < browse.path.length - 1
                        ? () => ref
                            .read(mediaBrowseProvider.notifier)
                            .jumpTo(browse.path.sublist(0, i + 1))
                        : null,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            Icon(
              selecting
                  ? Icons.checklist_rtl
                  : Icons.touch_app_outlined,
              size: 13,
              color: CueBoxColors.textFaint,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                selecting
                    ? '多选模式：点按勾选，可跨文件夹继续选择'
                    : '点按试听 · 长按进入多选',
                style: const TextStyle(
                  fontSize: 12,
                  color: CueBoxColors.textFaint,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (browse.children.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: EmptyState(
              icon: Icons.folder_off_outlined,
              title: '此文件夹为空',
              subtitle: '把音频文件放到这个目录下，\n然后点右上角刷新。',
            ),
          )
        else
          for (final item in browse.children)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: item.isDirectory
                  ? _FolderTile(
                      item: item,
                      onTap: () => ref
                          .read(mediaBrowseProvider.notifier)
                          .openFolder(item),
                    )
                  : _AudioTile(
                      item: item,
                      selecting: selecting,
                      selected: selectedUris.contains(item.uri),
                      isPlaying: playing.values
                          .any((p) =>
                              p.sourceId == 'preview_${item.uri}' &&
                              !p.isStopping),
                      onTap: () => onTapItem(item),
                      onLongPress: () => onLongPress(item),
                      onMenu: () => onShowActions(item),
                    ),
            ),
      ],
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
    required this.label,
    required this.isCurrent,
    this.onTap,
  });

  final String label;
  final bool isCurrent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isCurrent
              ? CueBoxColors.primary.withValues(alpha: 0.10)
              : CueBoxColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: isCurrent
                ? CueBoxColors.primary.withValues(alpha: 0.45)
                : CueBoxColors.border,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
            color: isCurrent
                ? CueBoxColors.primary
                : CueBoxColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.item, required this.onTap});

  final MediaItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CueBoxColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CueBoxColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CueBoxColors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.folder_rounded,
                  color: CueBoxColors.amber,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: CueBoxColors.textFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.isPlaying,
    required this.onTap,
    required this.onLongPress,
    required this.onMenu,
  });

  final MediaItem item;
  final bool selecting;
  final bool selected;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final highlight = selecting ? selected : isPlaying;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? (selecting ? CueBoxColors.secondary : CueBoxColors.primary)
              : CueBoxColors.border,
          width: highlight ? 1.3 : 1,
        ),
        boxShadow: highlight
            ? [
                BoxShadow(
                  color: (selecting
                          ? CueBoxColors.secondary
                          : CueBoxColors.primary)
                      .withValues(alpha: 0.10),
                  blurRadius: 20,
                ),
              ]
            : null,
      ),
      child: Material(
        color: highlight
            ? (selecting
                ? CueBoxColors.secondary.withValues(alpha: 0.08)
                : CueBoxColors.primary.withValues(alpha: 0.06))
            : CueBoxColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (selecting) ...[
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected
                          ? CueBoxColors.secondary
                          : Colors.transparent,
                      border: Border.all(
                        color: selected
                            ? CueBoxColors.secondary
                            : CueBoxColors.borderStrong,
                        width: 1.6,
                      ),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            size: 15,
                            color: Color(0xFF17101F),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                ],
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: highlight
                        ? (selecting
                            ? CueBoxColors.secondary.withValues(alpha: 0.15)
                            : CueBoxColors.primary.withValues(alpha: 0.15))
                        : CueBoxColors.surfacePressed,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    selecting
                        ? Icons.music_note_rounded
                        : (isPlaying
                            ? Icons.graphic_eq_rounded
                            : Icons.music_note_rounded),
                    color: highlight
                        ? (selecting
                            ? CueBoxColors.secondary
                            : CueBoxColors.primary)
                        : CueBoxColors.textSecondary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _formatBytes(item.size),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: CueBoxColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (selecting)
                  const SizedBox(width: 26)
                else if (isPlaying)
                  const PlayingIndicator(size: 16)
                else
                  const Icon(
                    Icons.play_circle_outline,
                    size: 24,
                    color: CueBoxColors.textFaint,
                  ),
                if (!selecting) ...[
                  const SizedBox(width: 2),
                  IconButton(
                    tooltip: '操作',
                    visualDensity: VisualDensity.compact,
                    onPressed: onMenu,
                    icon: const Icon(
                      Icons.more_vert,
                      size: 19,
                      color: CueBoxColors.textFaint,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.error_outline,
      title: '加载失败',
      subtitle: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('重试'),
            ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
