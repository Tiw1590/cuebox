import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'audio_uri.dart';
import 'media_access.dart';

const kWaveformPeakCount = 160;

/// 波形与时长缓存：同一会话内重复打开编辑页直接命中，无需重新解码。
final Map<String, List<double>> _waveCache = {};
final Map<String, int> _durationCache = {};
final Map<String, Future<List<double>?>> _pending = {};
final Map<String, Future<int?>> _durationPending = {};

List<double>? cachedWaveform(String uri) => _waveCache[uri];

int? cachedDurationMs(String uri) => _durationCache[uri];

void rememberDuration(String uri, int ms) {
  if (ms > 0) _durationCache[uri] = ms;
}

/// 读取音频时长（毫秒）：缓存命中直接返回，否则临时加载元数据。
Future<int?> loadDurationMs(String uri) async {
  final hit = _durationCache[uri];
  if (hit != null) return hit;
  final existing = _durationPending[uri];
  if (existing != null) return existing;

  final future = () async {
    final player = AudioPlayer();
    try {
      final duration = await player.setAudioSource(
        AudioSource.uri(resolveAudioUri(uri)),
      );
      if (duration != null) rememberDuration(uri, duration.inMilliseconds);
      return duration?.inMilliseconds;
    } catch (_) {
      return null;
    } finally {
      await player.dispose();
    }
  }();
  _durationPending[uri] = future;
  try {
    return await future;
  } finally {
    _durationPending.remove(uri);
  }
}

/// 读取波形峰值；缓存命中直接返回，否则解码并缓存。
Future<List<double>?> loadWaveform(
  String uri, {
  int peakCount = kWaveformPeakCount,
}) async {
  final hit = _waveCache[uri];
  if (hit != null) return hit;
  final key = '$uri|$peakCount';
  final existing = _pending[key];
  if (existing != null) return existing;

  final future = MediaAccess.instance.extractWaveform(uri, peakCount).then((
    peaks,
  ) {
    if (peaks != null) _waveCache[uri] = peaks;
    return peaks;
  });
  _pending[key] = future;
  try {
    return await future;
  } finally {
    _pending.remove(key);
  }
}

/// 后台预提取波形（添加音频到 Cue 列表时调用，让首次打开编辑页也很快）。
void preloadWaveform(String uri) {
  if (_waveCache.containsKey(uri)) return;
  unawaited(loadWaveform(uri));
}
