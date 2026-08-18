import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../core/platform/media_access.dart';
import '../../core/platform/waveform_cache.dart';
import '../../core/widgets/cuebox_background.dart';
import '../../core/widgets/empty_state.dart';
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
  /// 默认开启复选框（多选）模式；点按音频只勾选，试听需点专门的试听按钮。
  bool _selecting = true;
  final Set<String> _selectedUris = <String>{};

  // ---------- 左侧文件夹树状态 ----------
  /// 已加载过子目录的文件夹：uri → 直接子目录列表（懒加载缓存）。
  final Map<String, List<MediaItem>> _treeDirCache = {};
  /// 已展开的文件夹 uri。
  final Set<String> _treeExpanded = {};
  /// 加载子目录中的文件夹 uri。
  final Set<String> _treeLoading = {};

  /// 加载文件夹的直接子目录（只取文件夹），失败返回空。
  Future<List<MediaItem>> _loadTreeChildren(String uri) async {
    try {
      final entries = await MediaAccess.instance.listChildren(uri);
      return entries
          .where((e) => e.isDirectory)
          .map(MediaItem.fromEntry)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (_) {
      return [];
    }
  }

  /// 展开/折叠左侧树节点；展开时懒加载子目录并让右侧进入该文件夹。
  Future<void> _toggleTreeFolder(
    MediaItem folder,
    List<MediaItem> path,
  ) async {
    // 右侧先进入该文件夹。
    await ref.read(mediaBrowseProvider.notifier).jumpTo([...path, folder]);

    if (_treeExpanded.contains(folder.uri)) {
      setState(() => _treeExpanded.remove(folder.uri));
      return;
    }
    setState(() {
      _treeExpanded.add(folder.uri);
      _treeLoading.add(folder.uri);
    });
    final children = await _loadTreeChildren(folder.uri);
    if (!mounted) return;
    setState(() {
      _treeDirCache[folder.uri] = children;
      _treeLoading.remove(folder.uri);
    });
  }

  /// 根据当前浏览路径自动展开左侧树（打开素材库定位时调用）。
  void _syncTreeToPath(List<MediaItem> path) {
    for (final item in path.skip(1)) {
      if (!_treeDirCache.containsKey(item.uri) &&
          !_treeLoading.contains(item.uri)) {
        _treeLoading.add(item.uri);
        _loadTreeChildren(item.uri).then((children) {
          if (!mounted) return;
          setState(() {
            _treeDirCache[item.uri] = children;
            _treeLoading.remove(item.uri);
          });
        });
      }
      _treeExpanded.add(item.uri);
    }
  }

  /// 左侧树面板（宽屏双栏布局用）。
  Widget _buildTreePanel(
    BuildContext context,
    List<MediaRoot> roots,
    List<MediaItem> currentPath,
  ) {
    final currentUri = currentPath.isEmpty ? null : currentPath.last.uri;
    final countsByFolder = _selectedCountByFolder;
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: CueBoxColors.surface.withValues(alpha: 0.55),
        border: Border(right: BorderSide(color: CueBoxColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(
                  Icons.folder_copy_outlined,
                  size: 17,
                  color: CueBoxColors.amber,
                ),
                SizedBox(width: 7),
                Text(
                  '文件夹',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: CueBoxColors.textFaint,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(8, 0, 8, 24),
              children: [
                for (final root in roots)
                  _buildTreeNode(
                    context,
                    item: MediaItem.root(root),
                    path: const [],
                    depth: 0,
                    currentUri: currentUri,
                    selectedCount: countsByFolder[root.uri] ?? 0,
                  ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: OutlinedButton.icon(
              onPressed: () => _addFolder(context),
              icon: Icon(Icons.create_new_folder_outlined, size: 17),
              label: Text('添加文件夹'),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeNode(
    BuildContext context, {
    required MediaItem item,
    required List<MediaItem> path,
    required int depth,
    required String? currentUri,
    required int selectedCount,
  }) {
    final expanded = _treeExpanded.contains(item.uri);
    final loading = _treeLoading.contains(item.uri);
    final children = _treeDirCache[item.uri];
    final selected = item.uri == currentUri;
    final hasChildren = children == null || children.isNotEmpty;
    final countsByFolder = _selectedCountByFolder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _toggleTreeFolder(item, path),
          child: Container(
            padding: EdgeInsets.only(
              left: 10.0 + depth * 18,
              right: 8,
              top: 9,
              bottom: 9,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? CueBoxColors.primary.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  child: loading
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.8),
                        )
                      : hasChildren
                          ? Icon(
                              expanded
                                  ? Icons.keyboard_arrow_down_rounded
                                  : Icons.keyboard_arrow_right_rounded,
                              size: 20,
                              color: CueBoxColors.textFaint,
                            )
                          : null,
                ),
                Icon(
                  item.isDirectory
                      ? (expanded
                            ? Icons.folder_open_rounded
                            : Icons.folder_rounded)
                      : Icons.audio_file_outlined,
                  size: 24,
                  color: selected
                      ? CueBoxColors.primary
                      : CueBoxColors.amber,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? CueBoxColors.primary
                          : CueBoxColors.textPrimary,
                    ),
                  ),
                ),
                // 该文件夹下选中的音频数量角标。
                if (_selecting && selectedCount > 0) ...[
                  SizedBox(width: 6),
                  _SelectedCountBadge(count: selectedCount),
                ],
              ],
            ),
          ),
        ),
        if (expanded && children != null)
          for (final child in children)
            _buildTreeNode(
              context,
              item: child,
              path: [...path, item],
              depth: depth + 1,
              currentUri: currentUri,
              selectedCount: countsByFolder[child.uri] ?? 0,
            ),
      ],
    );
  }

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
        fadeIn: Duration(milliseconds: 80),
        fadeOut: Duration(milliseconds: 120),
        stopOthers: true,
      );
    }
  }

  // ---------- 多选状态 ----------

  /// 选中音频 uri → 所属文件夹 uri。
  /// 用于在文件夹列表/树中显示"该文件夹下选中了几个音频"。
  final Map<String, String> _audioToFolder = {};

  /// 当前浏览路径的最后一个文件夹 uri（选中音频时记录归属用）。
  String? get _currentFolderUri {
    final path = ref.read(mediaBrowseProvider).path;
    return path.isEmpty ? null : path.last.uri;
  }

  /// 统计每个文件夹下选中的音频数量。
  Map<String, int> get _selectedCountByFolder {
    final counts = <String, int>{};
    for (final folder in _audioToFolder.values) {
      counts[folder] = (counts[folder] ?? 0) + 1;
    }
    return counts;
  }

  void _enterSelection([MediaItem? item]) {
    setState(() {
      _selecting = true;
      if (item != null) {
        _selectedUris.add(item.uri);
        final folder = _currentFolderUri;
        if (folder != null) _audioToFolder[item.uri] = folder;
      }
    });
  }

  void _toggleSelect(MediaItem item) {
    setState(() {
      if (!_selectedUris.add(item.uri)) {
        _selectedUris.remove(item.uri);
        _audioToFolder.remove(item.uri);
      } else {
        final folder = _currentFolderUri;
        if (folder != null) _audioToFolder[item.uri] = folder;
      }
    });
  }

  void _toggleSelectAll(List<MediaItem> audioItems) {
    setState(() {
      final all = audioItems.map((i) => i.uri).toSet();
      final allSelected = all.isNotEmpty && all.every(_selectedUris.contains);
      final folder = _currentFolderUri;
      if (allSelected) {
        _selectedUris.removeAll(all);
        for (final uri in all) {
          _audioToFolder.remove(uri);
        }
      } else {
        _selectedUris.addAll(all);
        if (folder != null) {
          for (final uri in all) {
            _audioToFolder[uri] = folder;
          }
        }
      }
    });
  }

  /// 清空多选（添加成功后保持多选模式，但已选列表清空）。
  void _clearSelection() {
    setState(() {
      _selectedUris.clear();
      _audioToFolder.clear();
    });
  }

  List<MediaItem> _currentAudioItems(List<MediaItem> children) =>
      children.where((i) => i.isAudio).toList();

  // ---------- 添加 ----------

  /// 记录本次导入所在的目录，供下次打开素材库时直接定位。
  void _rememberImportPath() {
    final path = ref.read(mediaBrowseProvider).path;
    if (path.isNotEmpty) {
      ref.read(lastImportPathProvider.notifier).remember(path);
    }
  }

  Future<void> _addToCue(MediaItem item) async {
    await ref
        .read(showProvider.notifier)
        .addCue(uri: item.uri, name: item.name);
    preloadWaveform(item.uri);
    _rememberImportPath();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${item.name}」已加入 Cue 列表'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _addToCart(MediaItem item) async {
    await ref
        .read(showProvider.notifier)
        .addCartSlot(uri: item.uri, name: item.name);
    _rememberImportPath();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('「${item.name}」已加入 Card'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _addSelectedToCue(List<MediaItem> selected) async {
    await ref
        .read(showProvider.notifier)
        .addCues(selected.map((i) => (uri: i.uri, name: i.name)).toList());
    for (final item in selected) {
      preloadWaveform(item.uri);
    }
    _rememberImportPath();
    if (!mounted) return;
    final n = selected.length;
    _clearSelection(); // 保持多选模式，可继续选
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已加入 Cue 列表 · $n 项，可继续选择添加'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  Future<void> _addSelectedToCart(List<MediaItem> selected) async {
    await ref
        .read(showProvider.notifier)
        .addCartSlots(selected.map((i) => (uri: i.uri, name: i.name)).toList());
    _rememberImportPath();
    if (!mounted) return;
    final n = selected.length;
    _clearSelection();
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('已加入 Card · $n 项，可继续选择添加'),
        duration: Duration(milliseconds: 1500),
      ),
    );
  }

  // ---------- 构建 ----------

  @override
  Widget build(BuildContext context) {
    // 监听主题：切主题时重建本页刷新静态取色。
    ref.watch(themeModeProvider);
    final rootsAsync = ref.watch(mediaRootProvider);
    final roots = rootsAsync.valueOrNull ?? const <MediaRoot>[];
    final browse = ref.watch(mediaBrowseProvider);
    final playing = ref.watch(playbackEngineProvider);
    final activeShow = ref.watch(activeShowProvider).valueOrNull;
    final targetKind = activeShow?.kind ?? ShowKind.cue;

    ref.listen(mediaRootProvider, (prev, next) {
      final prevUris = (prev?.valueOrNull ?? const <MediaRoot>[])
          .map((r) => r.uri)
          .toSet();
      final nextUris = (next.valueOrNull ?? const <MediaRoot>[])
          .map((r) => r.uri)
          .toSet();
      if (prevUris.length != nextUris.length ||
          !prevUris.containsAll(nextUris)) {
        ref.read(mediaBrowseProvider.notifier).reset();
      }
    });

    // 打开素材库时：
    // 1. 若记录了最后导入目录且其根仍在列表中 → 直接进入该目录；
    // 2. 否则进入第一个素材根目录。
    if (roots.isNotEmpty && browse.path.isEmpty && !browse.loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final notifier = ref.read(mediaBrowseProvider.notifier);
        final lastPath = ref.read(lastImportPathProvider).valueOrNull ?? [];
        if (lastPath.isNotEmpty &&
            roots.any((r) => r.uri == lastPath.first.uri)) {
          notifier.jumpTo(lastPath);
          _syncTreeToPath(lastPath);
        } else {
          notifier.openRoot(roots.first);
          _syncTreeToPath([MediaItem.root(roots.first)]);
        }
      });
    }

    final currentRootUri = browse.path.isEmpty ? null : browse.path.first.uri;
    final currentRoot = roots
        .where((r) => r.uri == currentRootUri)
        .firstOrNull;
    final audioItems = _currentAudioItems(browse.children);
    final allSelected =
        audioItems.isNotEmpty &&
        audioItems.every((i) => _selectedUris.contains(i.uri));

    return CueBoxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Row(
            children: [
              Flexible(
                child: Text(
                  currentRoot?.name ?? '素材池',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_selectedUris.isNotEmpty) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: CueBoxColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已选 ${_selectedUris.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: CueBoxColors.secondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: audioItems.isEmpty
                  ? null
                  : () => _toggleSelectAll(audioItems),
              child: Text(
                allSelected ? '取消全选' : '全选',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (roots.isNotEmpty)
              IconButton(
                tooltip: '管理素材文件夹',
                icon: Icon(Icons.create_new_folder_outlined),
                onPressed: () => _showFolderManager(context),
              ),
            if (browse.hasRoot)
              IconButton(
                tooltip: '刷新',
                icon: Icon(Icons.refresh),
                onPressed: () =>
                    ref.read(mediaBrowseProvider.notifier).refresh(),
              ),
          ],
        ),
        body: switch (rootsAsync) {
          AsyncLoading() => Center(child: CircularProgressIndicator()),
          AsyncError(:final error) => _ErrorView(
            message: '$error',
            onRetry: () => ref.invalidate(mediaRootProvider),
          ),
          _ when roots.isEmpty => EmptyState(
            icon: Icons.folder_open_rounded,
            iconColor: CueBoxColors.amber,
            title: '添加素材文件夹',
            subtitle: '可添加多个文件夹；\n点按勾选，点右侧按钮试听，可一次加入 Cue 或 Card。',
            action: FilledButton.icon(
              onPressed: () => _addFolder(context),
              icon: Icon(Icons.create_new_folder_outlined, size: 20),
              label: Text('添加素材文件夹'),
            ),
          ),
          _ => LayoutBuilder(
            builder: (context, constraints) {
              final right = _FolderBrowser(
                browse: browse,
                playing: playing,
                selectedUris: _selectedUris,
                selectedCountByFolder: _selectedCountByFolder,
                onPreview: _togglePreview,
                onSelect: _toggleSelect,
                onShowActions: _showAudioActions,
              );
              // 宽屏（平板/横屏）：左侧文件夹树 + 右侧详情，快速定位。
              if (constraints.maxWidth >= 760) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTreePanel(context, roots, browse.path),
                    Expanded(child: right),
                  ],
                );
              }
              // 窄屏（手机竖屏）：保持单栏浏览。
              return right;
            },
          ),
        },
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
      ),
    );
  }

  /// 弹出系统目录选择器并添加素材文件夹。
  Future<void> _addFolder(BuildContext context) async {
    final root = await ref.read(mediaRootProvider.notifier).addRoot();
    if (root != null) {
      ref.read(mediaBrowseProvider.notifier).openRoot(root);
      _syncTreeToPath([MediaItem.root(root)]);
    }
  }

  /// 素材文件夹管理弹窗：切换、添加、移除。
  void _showFolderManager(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _FolderManagerSheet(
        currentUri: ref.read(mediaBrowseProvider).path.isEmpty
            ? null
            : ref.read(mediaBrowseProvider).path.first.uri,
        onOpen: (root) {
          Navigator.of(sheetContext).pop();
          ref.read(mediaBrowseProvider.notifier).openRoot(root);
        },
        onAdd: () {
          Navigator.of(sheetContext).pop();
          _addFolder(context);
        },
        onRemove: (root) async {
          await ref.read(mediaRootProvider.notifier).removeRoot(root.uri);
          // 若当前浏览的根被移除，重置浏览状态。
          final browse = ref.read(mediaBrowseProvider);
          if (browse.path.isNotEmpty && browse.path.first.uri == root.uri) {
            ref.read(mediaBrowseProvider.notifier).reset();
          }
        },
      ),
    );
  }

  void _showAudioActions(MediaItem item) {
    final activeShow = ref.read(activeShowProvider).valueOrNull;
    final targetKind = activeShow?.kind ?? ShowKind.cue;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 10, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '音频文件 · ${_formatBytes(item.size)}',
                      style: TextStyle(
                        color: CueBoxColors.textFaint,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(),
              ListTile(
                leading: Icon(
                  Icons.play_circle_outline,
                  color: CueBoxColors.primary,
                ),
                title: Text('试听'),
                subtitle: Text('点按再次试听可停止'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _togglePreview(item);
                },
              ),
              if (targetKind == ShowKind.cue)
                ListTile(
                  leading: Icon(
                    Icons.playlist_add,
                    color: CueBoxColors.secondary,
                  ),
                  title: Text('加入 Cue 列表'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _addToCue(item);
                  },
                ),
              if (targetKind == ShowKind.cart)
                ListTile(
                  leading: Icon(
                    Icons.grid_view_rounded,
                    color: CueBoxColors.amber,
                  ),
                  title: Text('加入 Card'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _addToCart(item);
                  },
                ),
              ListTile(
                leading: Icon(
                  Icons.library_add_check_outlined,
                  color: CueBoxColors.textSecondary,
                ),
                title: Text('多选添加'),
                subtitle: Text('可一次选择多个文件批量加入'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _enterSelection(item);
                },
              ),
              SizedBox(height: 8),
            ],
          ),
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
        color: CueBoxColors.surfaceHigh.withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: CueBoxColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(16, 10, 16, 12),
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
            Spacer(),
            if (kind == ShowKind.cue) ...[
              OutlinedButton.icon(
                onPressed: onAddCue,
                icon: Icon(Icons.playlist_add, size: 18),
                label: Text(
                  '加入 Cue${selectedCount > 0 ? ' ($selectedCount)' : ''}',
                ),
              ),
            ] else ...[
              OutlinedButton.icon(
                onPressed: onAddCart,
                icon: Icon(Icons.grid_view_rounded, size: 18),
                label: Text(
                  '加入 Card${selectedCount > 0 ? ' ($selectedCount)' : ''}',
                ),
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
    required this.selectedUris,
    required this.selectedCountByFolder,
    required this.onPreview,
    required this.onSelect,
    required this.onShowActions,
  });

  final MediaBrowseState browse;
  final Map<String, ActivePlay> playing;
  final Set<String> selectedUris;
  final Map<String, int> selectedCountByFolder;
  final Future<void> Function(MediaItem) onPreview;
  final ValueChanged<MediaItem> onSelect;
  final ValueChanged<MediaItem> onShowActions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (browse.loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (browse.error != null) {
      return _ErrorView(message: browse.error!);
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (browse.path.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < browse.path.length; i++) ...[
                  if (i > 0)
                    Padding(
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
          SizedBox(height: 10),
        ],
        Row(
          children: [
            Icon(
              Icons.audio_file_outlined,
              size: 13,
              color: CueBoxColors.textFaint,
            ),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                '仅显示音频：mp3 / wav / m4a / flac / ogg / aac / opus / aiff 等',
                style: TextStyle(
                  fontSize: 12,
                  color: CueBoxColors.textFaint,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.checklist_rtl,
              size: 13,
              color: CueBoxColors.textFaint,
            ),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                '点按勾选 · 点右侧播放按钮试听，可拖动进度条',
                style: TextStyle(
                  fontSize: 12,
                  color: CueBoxColors.textFaint,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        if (browse.children.isEmpty)
          Padding(
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
              padding: EdgeInsets.only(bottom: 10),
              child: item.isDirectory
                  ? _FolderTile(
                      item: item,
                      selectedCount: selectedCountByFolder[item.uri] ?? 0,
                      onTap: () => ref
                          .read(mediaBrowseProvider.notifier)
                          .openFolder(item),
                    )
                  : _AudioTile(
                      item: item,
                      selected: selectedUris.contains(item.uri),
                      isPlaying: playing.values.any(
                        (p) =>
                            p.sourceId == 'preview_${item.uri}' &&
                            !p.isStopping,
                      ),
                      previewPlay: playing.values
                          .where(
                            (p) =>
                                p.sourceId == 'preview_${item.uri}' &&
                                !p.isStopping,
                          )
                          .firstOrNull,
                      onTap: () => onSelect(item),
                      onPreview: () => onPreview(item),
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
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
  const _FolderTile({
    required this.item,
    required this.onTap,
    this.selectedCount = 0,
  });

  final MediaItem item;
  final VoidCallback onTap;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CueBoxColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                child: Icon(
                  Icons.folder_rounded,
                  color: CueBoxColors.amber,
                  size: 22,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // 该文件夹下选中的音频数量角标。
              if (selectedCount > 0) ...[
                SizedBox(width: 6),
                _SelectedCountBadge(count: selectedCount),
                SizedBox(width: 4),
              ],
              Icon(Icons.chevron_right, color: CueBoxColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// 文件夹旁的选中数量角标。
class _SelectedCountBadge extends StatelessWidget {
  const _SelectedCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: CueBoxColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CueBoxColors.primary.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: CueBoxColors.primary,
        ),
      ),
    );
  }
}

class _AudioTile extends ConsumerWidget {
  const _AudioTile({
    required this.item,
    required this.selected,
    required this.isPlaying,
    required this.previewPlay,
    required this.onTap,
    required this.onPreview,
    required this.onMenu,
  });

  final MediaItem item;
  final bool selected;
  final bool isPlaying;

  /// 当前正在试听本条目的播放（用于显示进度条），null 表示未在试听。
  final ActivePlay? previewPlay;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final highlight = selected;
    final previewing = isPlaying;
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight
              ? CueBoxColors.secondary
              : (previewing
                    ? CueBoxColors.primary
                    : CueBoxColors.border),
          width: highlight || previewing ? 1.3 : 1,
        ),
        boxShadow: highlight || previewing
            ? [
                BoxShadow(
                  color: (highlight
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
            ? CueBoxColors.secondary.withValues(alpha: 0.08)
            : (previewing
                  ? CueBoxColors.primary.withValues(alpha: 0.06)
                  : CueBoxColors.surface),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    AnimatedContainer(
                      duration: Duration(milliseconds: 150),
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
                          ? Icon(
                              Icons.check,
                              size: 15,
                              color: CueBoxColors.onAccent,
                            )
                          : null,
                    ),
                    SizedBox(width: 12),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: previewing
                            ? CueBoxColors.primary.withValues(alpha: 0.12)
                            : CueBoxColors.surfacePressed,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      // 试听动画：用静态均衡器图标（之前版本同款），
                      // 不占满框，比动态线条更协调。
                      child: previewing
                          ? Icon(
                              Icons.graphic_eq_rounded,
                              color: CueBoxColors.primary,
                              size: 20,
                            )
                          : Icon(
                              Icons.music_note_rounded,
                              color: CueBoxColors.textSecondary,
                              size: 20,
                            ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            _formatBytes(item.size),
                            style: TextStyle(
                              fontSize: 11.5,
                              color: CueBoxColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                    // 专用试听按钮：只有点它才会播放/停止。
                    IconButton(
                      tooltip: previewing ? '停止试听' : '试听',
                      visualDensity: VisualDensity.compact,
                      onPressed: onPreview,
                      icon: Icon(
                        previewing
                            ? Icons.stop_circle_outlined
                            : Icons.play_circle_fill_rounded,
                        size: 30,
                        color: previewing
                            ? CueBoxColors.primary
                            : CueBoxColors.textSecondary,
                      ),
                    ),
                    IconButton(
                      tooltip: '操作',
                      visualDensity: VisualDensity.compact,
                      onPressed: onMenu,
                      icon: Icon(
                        Icons.more_vert,
                        size: 19,
                        color: CueBoxColors.textFaint,
                      ),
                    ),
                  ],
                ),
                // 试听中：显示可拖动进度条。
                if (previewing && previewPlay != null) ...[
                  SizedBox(height: 4),
                  _PreviewSeekBar(play: previewPlay!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 试听进度条：随播放推进，可拖动跳转。
class _PreviewSeekBar extends ConsumerStatefulWidget {
  const _PreviewSeekBar({required this.play});

  final ActivePlay play;

  @override
  ConsumerState<_PreviewSeekBar> createState() => _PreviewSeekBarState();
}

class _PreviewSeekBarState extends ConsumerState<_PreviewSeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final play = widget.play;
    return StreamBuilder<Duration?>(
      stream: play.durationStream,
      builder: (context, durSnap) {
        final totalMs = (durSnap.data ?? Duration.zero).inMilliseconds;
        return StreamBuilder<Duration>(
          stream: play.positionStream,
          builder: (context, posSnap) {
            final posMs = (posSnap.data ?? Duration.zero).inMilliseconds;
            final maxMs = totalMs > 0 ? totalMs.toDouble() : 1.0;
            final value = (_dragValue ?? posMs.toDouble()).clamp(0.0, maxMs);
            return Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: CueBoxColors.primary,
                      inactiveTrackColor: CueBoxColors.borderStrong,
                      thumbColor: CueBoxColors.primary,
                    ),
                    child: Slider(
                      value: value,
                      max: maxMs,
                      onChanged: (v) =>
                          setState(() => _dragValue = v),
                      onChangeEnd: (v) {
                        setState(() => _dragValue = null);
                        ref
                            .read(playbackEngineProvider.notifier)
                            .seekPlay(
                              play.id,
                              Duration(milliseconds: v.round()),
                            );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    '${_fmtTime(_dragValue ?? posMs.toDouble())} / ${_fmtTime(totalMs.toDouble())}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: CueBoxColors.textFaint,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static String _fmtTime(double ms) {
    final d = Duration(milliseconds: ms.round());
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _FolderManagerSheet extends ConsumerWidget {
  const _FolderManagerSheet({
    required this.currentUri,
    required this.onOpen,
    required this.onAdd,
    required this.onRemove,
  });

  final String? currentUri;
  final void Function(MediaRoot root) onOpen;
  final VoidCallback onAdd;
  final Future<void> Function(MediaRoot root) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roots = ref.watch(mediaRootProvider).valueOrNull ?? const <MediaRoot>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('素材文件夹', style: Theme.of(context).textTheme.titleLarge),
                Spacer(),
                Text(
                  '${roots.length} 个文件夹',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CueBoxColors.textFaint,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (roots.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '还没有素材文件夹',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CueBoxColors.textFaint),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: roots.length,
                  separatorBuilder: (_, _) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final root = roots[index];
                    final active = root.uri == currentUri;
                    return Container(
                      decoration: BoxDecoration(
                        color: active
                            ? CueBoxColors.primary.withValues(alpha: 0.08)
                            : CueBoxColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: active
                              ? CueBoxColors.primary
                              : CueBoxColors.border,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => onOpen(root),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(14, 6, 4, 6),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.folder_rounded,
                                  size: 22,
                                  color: active
                                      ? CueBoxColors.primary
                                      : CueBoxColors.amber,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    root.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (active)
                                  Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 6),
                                    child: Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: CueBoxColors.primary,
                                    ),
                                  ),
                                IconButton(
                                  tooltip: '移除文件夹',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => onRemove(root),
                                  icon: Icon(
                                    Icons.close,
                                    size: 19,
                                    color: CueBoxColors.textFaint,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.create_new_folder_outlined, size: 19),
              label: Text('添加素材文件夹'),
            ),
          ],
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
              icon: Icon(Icons.refresh, size: 18),
              label: Text('重试'),
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
