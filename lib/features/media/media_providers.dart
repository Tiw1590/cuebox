import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/platform/media_access.dart';
import 'media_models.dart';

const _kMediaRootKey = 'media.rootUri';

/// 素材根目录（持久化）。null 表示尚未选择。
final mediaRootProvider =
    AsyncNotifierProvider<MediaRootNotifier, MediaRoot?>(MediaRootNotifier.new);

class MediaRootNotifier extends AsyncNotifier<MediaRoot?> {
  @override
  Future<MediaRoot?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_kMediaRootKey);
    if (uri == null) return null;
    return MediaRoot(uri: uri, name: await _resolveName(uri) ?? '素材目录');
  }

  /// 弹出系统目录选择器并持久化所选根目录。
  Future<void> pick() async {
    try {
      var uri = await MediaAccess.instance.pickDirectory();
      if (uri == null && !Platform.isAndroid) {
        // 桌面端：使用默认目录 ~/Music/CueBox。
        uri = LocalMediaAccess.defaultRootPath();
        final dir = Directory(uri);
        if (!dir.existsSync()) dir.createSync(recursive: true);
      }
      if (uri == null) return; // 用户取消
      final name = await _resolveName(uri) ?? '素材目录';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kMediaRootKey, uri);
      state = AsyncData(MediaRoot(uri: uri, name: name));
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMediaRootKey);
    state = const AsyncData(null);
  }

  Future<String?> _resolveName(String uri) async {
    try {
      return await MediaAccess.instance.getTreeName(uri);
    } catch (_) {
      return null;
    }
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

  /// 直接跳转到指定路径（用于面包屑点击）。
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
      final items = entries.map(MediaItem.fromEntry).toList()
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
