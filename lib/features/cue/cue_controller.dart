import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../playback/playback_engine.dart';
import '../show/show_models.dart';
import '../show/show_providers.dart';

enum WaitPhase { pre, post }

class CueControlState {
  CueControlState({
    this.selectedCueId,
    this.lastTriggeredCueId,
    this.listLoop = false,
    this.ended = false,
    this.waitingCueId,
    this.waitingPhase,
  });

  final String? selectedCueId;
  final String? lastTriggeredCueId;
  final bool listLoop;

  /// 已播完列表最后一首：再按 GO 时停止而不是回到第一首。
  final bool ended;

  /// 正在等待中的 Cue（开始前 / 结束后），用于对应区域的进度显示。
  final String? waitingCueId;
  final WaitPhase? waitingPhase;

  CueControlState copyWith({
    Object? selectedCueId = _unset,
    String? lastTriggeredCueId,
    bool? listLoop,
    bool? ended,
    Object? waitingCueId = _unset,
    Object? waitingPhase = _unset,
  }) {
    return CueControlState(
      selectedCueId: identical(selectedCueId, _unset)
          ? this.selectedCueId
          : selectedCueId as String?,
      lastTriggeredCueId: lastTriggeredCueId ?? this.lastTriggeredCueId,
      listLoop: listLoop ?? this.listLoop,
      ended: ended ?? this.ended,
      waitingCueId: identical(waitingCueId, _unset)
          ? this.waitingCueId
          : waitingCueId as String?,
      waitingPhase: identical(waitingPhase, _unset)
          ? this.waitingPhase
          : waitingPhase as WaitPhase?,
    );
  }

  static const _unset = Object();
}

/// Cue 列表模式控制器：选中、GO 触发、列表循环推进。
class CueController extends Notifier<CueControlState> {
  final Map<String, String> _playToCue = {};
  int _waitToken = 0;
  bool _goBusy = false;

  @override
  CueControlState build() {
    final engine = ref.read(playbackEngineProvider.notifier);
    final sub = engine.onCompleted.listen((playId) async {
      final cueId = _playToCue.remove(playId);
      if (cueId == null) return;
      final cues =
          ref.read(showProvider).valueOrNull?.activeShow.cues ?? <Cue>[];
      if (cues.isEmpty) return;
      final idx = cues.indexWhere((c) => c.id == cueId);
      if (idx < 0) return;
      final cue = cues[idx];
      // 只有全局循环或该 Cue 开启“播完接下一个”才继续。
      if (!state.listLoop && !cue.autoNext) return;
      final nextIdx = (idx + 1) % cues.length;
      final next = cues[nextIdx];
      // 结束后等待，再触发下一条。
      if (cue.postWaitMs > 0) {
        state = state.copyWith(
          waitingCueId: cue.id,
          waitingPhase: WaitPhase.post,
        );
        if (!await _wait(cue.postWaitMs)) {
          state = state.copyWith(waitingCueId: null, waitingPhase: null);
          return;
        }
      }
      state = state.copyWith(waitingCueId: null, waitingPhase: null);
      final consumed = await _trigger(next);
      // 选中继续往后：下一条已被激活，GO 应指向再下一条。
      final afterIdx = nextIdx + consumed;
      state = state.copyWith(
        selectedCueId: afterIdx < cues.length ? cues[afterIdx].id : null,
        ended: afterIdx >= cues.length && !state.listLoop && !next.autoNext,
      );
    });
    ref.onDispose(sub.cancel);
    return CueControlState();
  }

  void select(String id) {
    state = state.copyWith(
      selectedCueId: id,
      ended: false,
      waitingCueId: null,
      waitingPhase: null,
    );
  }

  void clearSelection() {
    state = state.copyWith(
      selectedCueId: null,
      ended: false,
      waitingCueId: null,
      waitingPhase: null,
    );
  }

  Future<void> go() async {
    // 防抖：按钮焦点与空格快捷键可能同时触发，或按键连发。
    if (_goBusy) return;
    _goBusy = true;
    try {
      final cues =
          ref.read(showProvider).valueOrNull?.activeShow.cues ?? <Cue>[];
      if (cues.isEmpty) return;
      // 已到列表结尾：GO 变成停止，避免直接跳回第一首。
      if (state.ended) {
        await stopAll();
        state = state.copyWith(ended: false);
        return;
      }
      final selIdx = cues.indexWhere((c) => c.id == state.selectedCueId);
      final start = selIdx >= 0 ? selIdx : 0;
      final consumed = await _trigger(cues[start]);
      final nextIdx = start + consumed;
      state = state.copyWith(
        selectedCueId: nextIdx < cues.length ? cues[nextIdx].id : null,
        ended:
            nextIdx >= cues.length && !state.listLoop && !cues[start].autoNext,
      );
    } finally {
      _goBusy = false;
    }
  }

  Future<int> _trigger(Cue cue) async {
    final token = _waitToken;
    // 开始前等待。
    if (cue.preWaitMs > 0) {
      state = state.copyWith(waitingCueId: cue.id, waitingPhase: WaitPhase.pre);
      if (!await _wait(cue.preWaitMs)) {
        state = state.copyWith(waitingCueId: null, waitingPhase: null);
        return 1;
      }
    }
    // 等待刚结束时若已被 ESC 取消，不再触发播放。
    if (token != _waitToken) {
      state = state.copyWith(waitingCueId: null, waitingPhase: null);
      return 1;
    }
    state = state.copyWith(waitingCueId: null, waitingPhase: null);
    final engine = ref.read(playbackEngineProvider.notifier);
    final playId = await engine.trigger(
      uri: cue.uri,
      label: cue.name,
      sourceId: cue.id,
      startMs: cue.startMs,
      endMs: cue.endMs,
      loop: cue.loop,
      volume: cue.volume,
      fadeIn: cue.fadeIn,
      fadeOut: cue.fadeOut,
      stopOthers: true,
    );
    if (playId != null) {
      _playToCue[playId] = cue.id;
    }
    state = state.copyWith(lastTriggeredCueId: cue.id);

    // 同时播放下一个（叠放，不等待、不独占）。
    var consumed = 1;
    if (cue.playNextTogether) {
      final cues =
          ref.read(showProvider).valueOrNull?.activeShow.cues ?? <Cue>[];
      final idx = cues.indexWhere((c) => c.id == cue.id);
      if (idx >= 0 && idx + 1 < cues.length) {
        final next = cues[idx + 1];
        await engine.trigger(
          uri: next.uri,
          label: next.name,
          sourceId: next.id,
          startMs: next.startMs,
          endMs: next.endMs,
          loop: next.loop,
          volume: next.volume,
          fadeIn: next.fadeIn,
          fadeOut: next.fadeOut,
          stopOthers: false,
        );
        consumed = 2;
      }
    }
    return consumed;
  }

  void toggleListLoop() {
    state = state.copyWith(listLoop: !state.listLoop, ended: false);
  }

  Future<void> stopAll() async {
    _waitToken++;
    state = state.copyWith(waitingCueId: null, waitingPhase: null);
    await ref.read(playbackEngineProvider.notifier).stopAll();
  }

  /// 等待指定毫秒；期间被 stopAll 取消则返回 false。
  Future<bool> _wait(int ms) async {
    final token = _waitToken;
    await Future<void>.delayed(Duration(milliseconds: ms));
    return token == _waitToken;
  }
}

final cueControllerProvider = NotifierProvider<CueController, CueControlState>(
  CueController.new,
);
