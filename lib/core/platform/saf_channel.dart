import 'package:flutter/services.dart';

/// SAF 目录浏览通道的 Dart 封装（Android）。
///
/// 素材根目录通过系统目录选择器（SAF）选定，App 持久化该目录的只读权限，
/// 之后用 content:// URI 浏览和播放音频，全程不需要存储权限。
class SafChannel {
  SafChannel._();

  static const MethodChannel _channel = MethodChannel('cuebox/saf');

  /// 弹出系统目录选择器，返回用户选中的树 URI；取消时返回 null。
  static Future<String?> pickDirectory() async {
    return _channel.invokeMethod<String>('pickDirectory');
  }

  /// 列出 [uri]（树 URI 或文档 URI）下的直接子项。
  static Future<List<SafEntry>> listChildren(String uri) async {
    final raw = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'listChildren',
      <String, Object?>{'uri': uri},
    );
    return (raw ?? const [])
        .map((e) => SafEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// 读取树根目录的显示名称，用于素材池标题展示。
  static Future<String?> getTreeName(String uri) async {
    return _channel.invokeMethod<String>('getTreeName', <String, Object?>{'uri': uri});
  }

  /// 解码音频并提取 [peakCount] 个峰值（0..1），失败时返回 null。
  static Future<List<double>?> extractWaveform(String uri, int peakCount) async {
    final raw = await _channel.invokeMethod<List<Object?>>(
      'extractWaveform',
      <String, Object?>{'uri': uri, 'peakCount': peakCount},
    );
    if (raw == null) return null;
    return raw.map((e) => (e as num).toDouble()).toList();
  }
}

/// SAF 里的一个目录/文件条目。
class SafEntry {
  const SafEntry({
    required this.uri,
    required this.name,
    required this.mime,
    required this.isDirectory,
    required this.size,
  });

  final String uri;
  final String name;
  final String mime;
  final bool isDirectory;
  final int size;

  factory SafEntry.fromMap(Map<String, dynamic> map) {
    return SafEntry(
      uri: map['uri'] as String? ?? '',
      name: map['name'] as String? ?? '',
      mime: map['mime'] as String? ?? '',
      isDirectory: map['isDirectory'] as bool? ?? false,
      size: (map['size'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isAudio => !isDirectory && mime.startsWith('audio/');
}
