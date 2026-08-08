import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/platform/audio_uri.dart';

/// 一次正在播放的触发。
class ActivePlay {
  ActivePlay({
    required this.id,
    required this.uri,
    required this.label,
    required this.loop,
    required this.baseVolume,
    required this.fadeOut,
    required this.player,
    this.sourceId,
  });

  final String id;
  final String uri;
  final String label;
  final bool loop;
  final double baseVolume;
  final Duration fadeOut;
  final AudioPlayer player;

  /// 逻辑条目标识（Cue id / Cart slot id / 试听标签），用于按条独立控制。
  final String? sourceId;

  /// 正在淡出停止中，忽略播放完成事件，避免重复清理。
  bool isStopping = false;

  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration?> get durationStream => player.durationStream;
  Stream<bool> get playingStream => player.playingStream;
}

/// 多轨播放引擎：每个触发独立一个 AudioPlayer 实例，
/// 支持叠放、单轨循环、自定义淡入淡出、solo（停掉其他）三种语义。
class PlaybackEngine extends Notifier<Map<String, ActivePlay>> {
  int _idCounter = 0;
  String? _focusedPlayId;
  final StreamController<String> _completedController =
      StreamController<String>.broadcast();

  @override
  Map<String, ActivePlay> build() => {};

  List<ActivePlay> get active => state.values.toList();

  bool get isAnyPlaying => state.isNotEmpty;

  /// 是否有声音正在淡出停止中（用于 ESC 两段式停止判断）。
  bool get isAnyStopping => state.values.any((p) => p.isStopping);

  /// 非循环的播放自然播完时，发出该播放的 id（供 Cue 列表循环推进等使用）。
  Stream<String> get onCompleted => _completedController.stream;

  bool isPlayingUri(String uri) =>
      state.values.any((p) => p.uri == uri && !p.isStopping);

  /// 是否有指定逻辑条目（Cue / Cart / 试听标签）正在播放。
  bool isPlayingSource(String sourceId) =>
      state.values.any((p) => p.sourceId == sourceId && !p.isStopping);

  /// 最近一次触发、仍在播放中的条目（Cart 顶部走带条用）。
  ActivePlay? get focusedPlay =>
      _focusedPlayId == null ? null : state[_focusedPlayId];

  /// 触发一个音效。
  ///
  /// [stopOthers] 为 true（solo）时，先按 [fadeOut] 淡出停掉其他所有声音，
  /// 再播放本条；否则与已响的声音叠放。
  Future<String?> trigger({
    required String uri,
    required String label,
    String? sourceId,
    int startMs = 0,
    int endMs = 0,
    bool loop = false,
    double volume = 1.0,
    Duration fadeIn = const Duration(milliseconds: 20),
    Duration fadeOut = const Duration(milliseconds: 150),
    bool stopOthers = false,
  }) async {
    if (stopOthers) {
      await stopAll(fadeOut: fadeOut);
    }

    final id = 'play_${_idCounter++}';
    final player = AudioPlayer();
    final play = ActivePlay(
      id: id,
      uri: uri,
      label: label,
      loop: loop,
      baseVolume: volume,
      fadeOut: fadeOut,
      player: player,
      sourceId: sourceId,
    );
    state = {...state, id: play};
    _focusedPlayId = id;

    // 自然播完（非循环）时自动清理。
    player.processingStateStream.listen((processing) {
      if (processing == ProcessingState.completed && !play.isStopping) {
        _completedController.add(play.id);
        unawaited(_disposePlay(play));
      }
    });

    try {
      await player.setVolume(0);
      await player.setLoopMode(loop ? LoopMode.one : LoopMode.off);
      final UriAudioSource baseSource = AudioSource.uri(resolveAudioUri(uri));
      AudioSource source = baseSource;
      if (startMs > 0 || endMs > 0) {
        source = ClippingAudioSource(
          child: baseSource,
          start: Duration(milliseconds: startMs),
          end: endMs > startMs ? Duration(milliseconds: endMs) : null,
        );
      }
      await player.setAudioSource(source);
      unawaited(player.play());
      await _fadeTo(player, volume, fadeIn);
    } catch (_) {
      await _disposePlay(play);
      return null;
    }
    return id;
  }

  /// 停止全部，按各自淡出时间（可覆盖）淡出。
  Future<void> stopAll({Duration? fadeOut}) async {
    final targets = active.toList();
    await Future.wait(targets.map((p) => stopPlay(p.id, fadeOut: fadeOut)));
  }

  Future<void> stopPlay(String id, {Duration? fadeOut}) async {
    final play = state[id];
    if (play == null) return;
    play.isStopping = true;
    final fade = fadeOut ?? play.fadeOut;
    if (fade > Duration.zero) {
      try {
        await _fadeTo(play.player, 0, fade);
      } catch (_) {
        // 播放器可能已释放，忽略。
      }
    }
    try {
      await play.player.stop();
    } catch (_) {}
    await _disposePlay(play);
  }

  /// 停止指定音频 URI 的所有播放（用于素材池试听开关等）。
  Future<void> stopUri(String uri, {Duration? fadeOut}) async {
    final targets = state.values
        .where((p) => p.uri == uri && !p.isStopping)
        .toList();
    await Future.wait(targets.map((p) => stopPlay(p.id, fadeOut: fadeOut)));
  }

  /// 停止指定逻辑条目的全部播放。
  Future<void> stopSource(String sourceId, {Duration? fadeOut}) async {
    final targets = state.values
        .where((p) => p.sourceId == sourceId && !p.isStopping)
        .toList();
    await Future.wait(targets.map((p) => stopPlay(p.id, fadeOut: fadeOut)));
  }

  Future<void> pausePlay(String id) async {
    final play = state[id];
    if (play == null || play.isStopping) return;
    try {
      await play.player.pause();
    } catch (_) {}
  }

  /// 暂停指定逻辑条目的全部播放（控制 Cue 用，可带淡出）。
  Future<void> pauseSource(
    String sourceId, {
    Duration fadeOut = Duration.zero,
  }) async {
    final targets = state.values
        .where((p) => p.sourceId == sourceId && !p.isStopping)
        .toList();
    for (final p in targets) {
      if (fadeOut > Duration.zero) {
        try {
          await _fadeTo(p.player, 0, fadeOut);
        } catch (_) {}
      }
      await pausePlay(p.id);
    }
  }

  /// 恢复指定逻辑条目的全部播放（控制 Cue 用，可带淡入）。
  Future<void> resumeSource(
    String sourceId, {
    Duration fadeIn = Duration.zero,
  }) async {
    final targets = state.values
        .where((p) => p.sourceId == sourceId && !p.isStopping)
        .toList();
    for (final p in targets) {
      if (fadeIn > Duration.zero) {
        try {
          await p.player.setVolume(0);
          unawaited(p.player.play());
          await _fadeTo(p.player, p.baseVolume, fadeIn);
        } catch (_) {}
      } else {
        await resumePlay(p.id);
      }
    }
  }

  Future<void> resumePlay(String id) async {
    final play = state[id];
    if (play == null || play.isStopping) return;
    try {
      await play.player.play();
    } catch (_) {}
  }

  /// 跳转到指定播放位置（走带条手动拖拽）。
  Future<void> seekPlay(String id, Duration position) async {
    final play = state[id];
    if (play == null || play.isStopping) return;
    try {
      await play.player.seek(position);
    } catch (_) {}
  }

  /// 把音量从当前值渐变到 [target]。
  Future<void> _fadeTo(
    AudioPlayer player,
    double target,
    Duration duration,
  ) async {
    if (duration <= Duration.zero) {
      await player.setVolume(target);
      return;
    }
    final current = player.volume;
    final steps = max(1, (duration.inMilliseconds / 20).round());
    for (var i = 1; i <= steps; i++) {
      await Future<void>.delayed(Duration(milliseconds: 20));
      final v = current + (target - current) * (i / steps);
      await player.setVolume(v.clamp(0.0, 1.0));
    }
  }

  Future<void> _disposePlay(ActivePlay play) async {
    if (state.containsKey(play.id)) {
      state = {...state}..remove(play.id);
      if (_focusedPlayId == play.id) {
        _focusedPlayId = state.isNotEmpty ? state.keys.last : null;
      }
    }
    await play.player.dispose();
  }
}

final playbackEngineProvider =
    NotifierProvider<PlaybackEngine, Map<String, ActivePlay>>(
      PlaybackEngine.new,
    );

/// 当前走带焦点（最近触发且仍在播放中的条目）。
final focusedPlayProvider = Provider<ActivePlay?>((ref) {
  ref.watch(playbackEngineProvider);
  return ref.read(playbackEngineProvider.notifier).focusedPlay;
});
