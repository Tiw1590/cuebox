import 'dart:io';
import 'dart:math' as math;

import 'saf_channel.dart';

/// 素材池中的一个条目（文件夹或音频文件），与平台无关。
class MediaEntry {
  const MediaEntry({
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

  bool get isAudio => !isDirectory && mime.startsWith('audio/');
}

/// 素材目录访问抽象：
/// - Android：SAF（系统目录选择器 + content:// URI，无需存储权限）
/// - 桌面端（macOS 等）：本地目录（开发/测试用）
abstract class MediaAccess {
  Future<String?> pickDirectory();

  Future<List<MediaEntry>> listChildren(String uri);

  Future<String?> getTreeName(String uri);

  /// 解码音频并提取 [peakCount] 个峰值（0..1），失败返回 null。
  Future<List<double>?> extractWaveform(String uri, int peakCount);

  static MediaAccess get instance =>
      Platform.isAndroid ? SafMediaAccess() : LocalMediaAccess();
}

class SafMediaAccess implements MediaAccess {
  @override
  Future<String?> pickDirectory() => SafChannel.pickDirectory();

  @override
  Future<List<MediaEntry>> listChildren(String uri) async {
    final entries = await SafChannel.listChildren(uri);
    return entries
        .map(
          (e) => MediaEntry(
            uri: e.uri,
            name: e.name,
            mime: e.mime,
            isDirectory: e.isDirectory,
            size: e.size,
          ),
        )
        .toList();
  }

  @override
  Future<String?> getTreeName(String uri) => SafChannel.getTreeName(uri);

  @override
  Future<List<double>?> extractWaveform(String uri, int peakCount) =>
      SafChannel.extractWaveform(uri, peakCount);
}

class LocalMediaAccess implements MediaAccess {
  /// 桌面端默认素材目录：~/Music/CueBox。
  static String defaultRootPath() {
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        '';
    return '$home/Music/CueBox';
  }

  @override
  Future<String?> pickDirectory() async => null; // 桌面端无系统目录选择器，使用默认目录

  @override
  Future<String?> getTreeName(String uri) async => uri.split('/').last;

  @override
  Future<List<double>?> extractWaveform(String uri, int peakCount) async {
    // 桌面端兜底：仅支持未压缩 WAV（16-bit PCM）。
    final file = File(uri);
    if (!file.existsSync()) return null;
    try {
      final bytes = file.readAsBytesSync();
      if (bytes.length < 44) return null;
      if (bytes[0] != 0x52 || bytes[1] != 0x49 || bytes[2] != 0x46 || bytes[3] != 0x46) {
        return null;
      }
      if (bytes[8] != 0x57 || bytes[9] != 0x41 || bytes[10] != 0x56 || bytes[11] != 0x45) {
        return null;
      }

      var offset = 12;
      var bitsPerSample = 16;
      var channels = 1;
      var dataOffset = -1;
      var dataLength = 0;
      while (offset + 8 <= bytes.length) {
        final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
        final size = _le32(bytes, offset + 4);
        if (id == 'fmt ') {
          channels = _le16(bytes, offset + 10);
          bitsPerSample = _le16(bytes, offset + 14);
        } else if (id == 'data') {
          dataOffset = offset + 8;
          dataLength = size;
          break;
        }
        offset += 8 + size + (size.isOdd ? 1 : 0);
      }
      if (dataOffset < 0 || bitsPerSample != 16 || channels <= 0) return null;

      final sums = List<double>.filled(peakCount, 0);
      final counts = List<int>.filled(peakCount, 0);
      final bytesPerSample = channels * 2;
      final totalSamples = (dataLength / bytesPerSample).floor();
      if (totalSamples <= 0) return null;

      for (var i = 0; i < totalSamples; i++) {
        var amp = 0.0;
        for (var c = 0; c < channels; c++) {
          final p = dataOffset + i * bytesPerSample + c * 2;
          if (p + 1 >= bytes.length) break;
          final v = (bytes[p] | (bytes[p + 1] << 8)).toSigned(16);
          final norm = v / 32768.0;
          amp += norm * norm;
        }
        final bucket = ((i * peakCount) ~/ totalSamples).clamp(0, peakCount - 1);
        sums[bucket] += amp / channels;
        counts[bucket]++;
      }

      final rms = List<double>.filled(peakCount, 0);
      var last = 0.0;
      for (var i = 0; i < peakCount; i++) {
        if (counts[i] > 0) {
          rms[i] = math.sqrt(sums[i] / counts[i]);
          last = rms[i];
        } else {
          rms[i] = last;
        }
      }
      final smooth = List<double>.filled(peakCount, 0);
      for (var i = 0; i < peakCount; i++) {
        final a = i > 0 ? rms[i - 1] : rms[i];
        final b = rms[i];
        final c = i < peakCount - 1 ? rms[i + 1] : rms[i];
        smooth[i] = (a + 2 * b + c) / 4;
      }
      return smooth;
    } catch (_) {
      return null;
    }
  }

  static int _le16(List<int> b, int offset) =>
      (b[offset] | (b[offset + 1] << 8)) & 0xFFFF;

  static int _le32(List<int> b, int offset) =>
      (b[offset]) |
      (b[offset + 1] << 8) |
      (b[offset + 2] << 16) |
      (b[offset + 3] << 24);

  @override
  Future<List<MediaEntry>> listChildren(String uri) async {
    final dir = Directory(uri);
    final children = <MediaEntry>[];
    if (!dir.existsSync()) return children;
    await for (final entity in dir.list(followLinks: false)) {
      final name = entity.uri.pathSegments.last;
      if (entity is Directory) {
        children.add(
          MediaEntry(
            uri: entity.path,
            name: name,
            mime: '',
            isDirectory: true,
            size: 0,
          ),
        );
      } else if (entity is File) {
        final mime = _mimeFromExtension(name);
        if (mime.isEmpty) continue;
        var size = 0;
        try {
          size = entity.lengthSync();
        } catch (_) {}
        children.add(
          MediaEntry(
            uri: entity.path,
            name: name,
            mime: mime,
            isDirectory: false,
            size: size,
          ),
        );
      }
    }
    return children;
  }

  static const _audioExtensions = <String, String>{
    'mp3': 'audio/mpeg',
    'mp2': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'flac': 'audio/flac',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/opus',
    'aiff': 'audio/aiff',
    'aif': 'audio/aiff',
    'wma': 'audio/x-ms-wma',
    'amr': 'audio/amr',
    'caf': 'audio/x-caf',
  };

  static String _mimeFromExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '';
    final ext = name.substring(dot + 1).toLowerCase();
    return _audioExtensions[ext] ?? '';
  }
}
