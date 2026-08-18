import '../../core/platform/media_access.dart';

/// 素材根目录：用户通过 SAF 选择的设备本地目录。
class MediaRoot {
  MediaRoot({required this.uri, required this.name});

  final String uri;
  final String name;

  Map<String, dynamic> toJson() => {'uri': uri, 'name': name};

  factory MediaRoot.fromJson(Map<String, dynamic> json) => MediaRoot(
        uri: json['uri'] as String? ?? '',
        name: json['name'] as String? ?? '',
      );
}

/// 素材池中的一个条目（文件夹或音频文件）。
class MediaItem {
  MediaItem({
    required this.uri,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.mime,
  });

  final String uri;
  final String name;
  final bool isDirectory;
  final int size;
  final String mime;

  bool get isAudio => !isDirectory && mime.startsWith('audio/');

  factory MediaItem.fromEntry(MediaEntry entry) {
    return MediaItem(
      uri: entry.uri,
      name: entry.name,
      isDirectory: entry.isDirectory,
      size: entry.size,
      mime: entry.mime,
    );
  }

  factory MediaItem.root(MediaRoot root) {
    return MediaItem(
      uri: root.uri,
      name: root.name,
      isDirectory: true,
      size: 0,
      mime: '',
    );
  }

  /// 序列化浏览路径中的一截（用于记忆最后导入的目录）。
  Map<String, dynamic> toPathJson() => {'uri': uri, 'name': name};

  /// 从序列化恢复路径节点（一律按文件夹处理）。
  factory MediaItem.fromPathJson(Map<String, dynamic> json) => MediaItem(
        uri: json['uri'] as String? ?? '',
        name: json['name'] as String? ?? '',
        isDirectory: true,
        size: 0,
        mime: '',
      );
}

/// 素材浏览状态：当前路径（从根目录到当前文件夹）+ 当前文件夹的子项。
class MediaBrowseState {
  const MediaBrowseState({
    this.path = const [],
    this.children = const [],
    this.loading = false,
    this.error,
  });

  final List<MediaItem> path;
  final List<MediaItem> children;
  final bool loading;
  final String? error;

  MediaItem? get current => path.isEmpty ? null : path.last;

  bool get hasRoot => path.isNotEmpty;

  MediaBrowseState copyWith({
    List<MediaItem>? path,
    List<MediaItem>? children,
    bool? loading,
    String? error,
  }) {
    return MediaBrowseState(
      path: path ?? this.path,
      children: children ?? this.children,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}
