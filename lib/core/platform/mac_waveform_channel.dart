import 'package:flutter/services.dart';

/// macOS 波形提取通道：用 AVFoundation 解码音频（flac/mp3/m4a/wav 等）。
class MacWaveformChannel {
  MacWaveformChannel._();

  static const MethodChannel _channel = MethodChannel('cuebox/waveform');

  static Future<List<double>?> extractWaveform(
    String path,
    int peakCount,
  ) async {
    try {
      final raw = await _channel.invokeMethod<List<Object?>>(
        'extractWaveform',
        <String, Object?>{'path': path, 'peakCount': peakCount},
      );
      if (raw == null) return null;
      return raw.map((e) => (e as num).toDouble()).toList();
    } catch (_) {
      return null;
    }
  }
}
