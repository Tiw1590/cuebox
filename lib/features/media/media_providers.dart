import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform/media_access.dart';
import 'media_models.dart';

const _kMediaRootsKey = 'media.rootUris'; // 多根目录 JSON 数组
const _kMediaRootLegacyKey = 'media.rootUri'; // 旧版单根目录
const _kLastImportPathKey = 'media.lastImportPath'; // 最后导入音频的目录路径

/// 素材根目录集合（支持多个文件夹）。
final mediaRootProvider =
    AsyncNotifierProvider<MediaRootNotifier, List<MediaRoot>>(
      MediaRootNotifier.new,
    );

class MediaRootNotifier extends AsyncNotifier<List<MediaRoot>> {
  @override
  Future<List<MediaRoot>> build() async {
    final prefs = await SharedPreferences.getInstance();
    // 读取新版多根目录。
    final raw = prefs.getString(_kMediaRootsKey);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        final roots = <MediaRoot>[];
        for (final e in list) {
          final root = MediaRoot.fromJson((e as Map).cast<String, dynamic>());
          if (root.uri.isEmpty) continue;
          // 名称缺失时补全。
          if (root.name.isEmpty) {
            final name = await _resolveName(root.uri);
            roots.add(MediaRoot(uri: root.uri, name: name ?? '素材目录'));
          } else {
            roots.add(root);
          }
        }
        return roots;
      } catch (_) {
        // 数据损坏时回退到空列表。
      }
    }
    // 兼容旧版单根目录：迁移到新格式。
    final legacy = prefs.getString(_kMediaRootLegacyKey);
    if (legacy != null && legacy.isNotEmpty) {
      final name = await _resolveName(legacy) ?? '素材目录';
      final root = MediaRoot(uri: legacy, name: name);
      await prefs.setString(
        _kMediaRootsKey,
        jsonEncode([root.toJson()]),
      );
      await prefs.remove(_kMediaRootLegacyKey);
      return [root];
    }
    return [];
  }

  /// 弹出系统目录选择器，把选中的文件夹追加到素材根目录列表。
  ///
  /// 返回新增（或已存在）的根目录；用户取消时返回 null。
  Future<MediaRoot?> addRoot() async {
    try {
      var uri = await MediaAccess.instance.pickDirectory();
      if (uri == null && !Platform.isAndroid) {
        // 桌面端：使用默认目录 ~/Music/CueBox。
        uri = LocalMediaAccess.defaultRootPath();
        final dir = Directory(uri);
        if (!dir.existsSync()) dir.createSync(recursive: true);
      }
      if (uri == null) return null; // 用户取消
      return await _addByUri(uri);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return null;
    }
  }

  /// 直接把本地路径添加为素材根目录（桌面端拖放导入用，不弹选择器）。
  ///
  /// 返回新增（或已存在）的根目录；路径无效时返回 null。
  Future<MediaRoot?> addLocalRoot(String path) async {
    if (path.isEmpty) return null;
    try {
      return await _addByUri(path);
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return null;
    }
  }

  Future<MediaRoot?> _addByUri(String uri) async {
    final roots = [...(state.valueOrNull ?? <MediaRoot>[])];
    final existing = roots.where((r) => r.uri == uri).firstOrNull;
    if (existing != null) return existing; // 去重
    final name = await _resolveName(uri) ?? '素材目录';
    final root = MediaRoot(uri: uri, name: name);
    await _save([...roots, root]);
    return root;
  }

  /// 移除指定素材根目录（仅解除引用，不删除文件）。
  Future<void> removeRoot(String uri) async {
    final roots = [...(state.valueOrNull ?? <MediaRoot>[])];
    roots.removeWhere((r) => r.uri == uri);
    await _save(roots);
  }

  /// 清空全部素材根目录。
  Future<void> clear() async {
    await _save([]);
  }

  Future<void> _save(List<MediaRoot> roots) async {
    state = AsyncData(roots);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMediaRootsKey, jsonEncode(roots.map((r) => r.toJson()).toList()));
  }

  Future<String?> _resolveName(String uri) async {
    try {
      return await MediaAccess.instance.getTreeName(uri);
    } catch (_) {
      return null;
    }
  }
}

/// 最近一次导入音频时所在的目录路径（从根目录到当前文件夹）。
///
/// 打开素材库时若该路径仍有效，则直接进入，方便继续从上次位置导入。
final lastImportPathProvider =
    AsyncNotifierProvider<LastImportPathNotifier, List<MediaItem>>(
      LastImportPathNotifier.new,
    );

class LastImportPathNotifier extends AsyncNotifier<List<MediaItem>> {
  @override
  Future<List<MediaItem>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastImportPathKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => MediaItem.fromPathJson((e as Map).cast<String, dynamic>()))
          .where((i) => i.uri.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// 记录导入发生时的目录路径。
  Future<void> remember(List<MediaItem> path) async {
    if (path.isEmpty) return;
    state = AsyncData(List.of(path));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kLastImportPathKey,
      jsonEncode(path.map((i) => i.toPathJson()).toList()),
    );
  }

  Future<void> clear() async {
    state = const AsyncData([]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastImportPathKey);
  }
}

/// 素材池浏览状态。
final mediaBrowseProvider =
    NotifierProvider<MediaBrowseNotifier, MediaBrowseState>(MediaBrowseNotifier.new);

class MediaBrowseNotifier extends Notifier<MediaBrowseState> {
  @override
  MediaBrowseState build() => MediaBrowseState();

  void reset() => state = const MediaBrowseState();

  Future<void> openRoot(MediaRoot root) async {
    if (state.loading) return;
    _beginLoad(path: [MediaItem.root(root)]);
    await _loadCurrent();
  }

  Future<void> openFolder(MediaItem folder) async {
    if (state.loading || !folder.isDirectory) return;
    _beginLoad(path: [...state.path, folder]);
    await _loadCurrent();
  }

  Future<void> goBack() async {
    if (state.loading || state.path.length <= 1) return;
    _beginLoad(path: state.path.sublist(0, state.path.length - 1));
    await _loadCurrent();
  }

  Future<void> refresh() async {
    if (state.loading || state.path.isEmpty) return;
    _beginLoad(path: state.path);
    await _loadCurrent();
  }

  /// 直接跳转到指定路径（用于面包屑点击、恢复最后导入目录）。
  Future<void> jumpTo(List<MediaItem> path) async {
    if (state.loading || path.isEmpty) return;
    _beginLoad(path: path);
    await _loadCurrent();
  }

  void _beginLoad({required List<MediaItem> path}) {
    state = MediaBrowseState(path: path, loading: true);
  }

  Future<void> _loadCurrent() async {
    final current = state.current;
    if (current == null) {
      state = state.copyWith(loading: false);
      return;
    }
    try {
      final entries = await MediaAccess.instance.listChildren(current.uri);
      // 只保留文件夹与支持的音频文件，过滤掉其他无关文件。
      final items = entries
          .where((e) => e.isDirectory || e.isAudio)
          .map(MediaItem.fromEntry)
          .toList()
        ..sort((a, b) {
          if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      state = state.copyWith(loading: false, children: items, error: null);
    } catch (e) {
      state = state.copyWith(loading: false, error: '$e');
    }
  }
}
