import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../playback/playback_engine.dart';
import '../show/show_models.dart';
import '../show/show_providers.dart';

class CueControlState {
  const CueControlState({
    this.selectedCueId,
    this.lastTriggeredCueId,
    this.listLoop = false,
  });

  final String? selectedCueId;
  final String? lastTriggeredCueId;
  final bool listLoop;

  CueControlState copyWith({
    Object? selectedCueId = _unset,
    String? lastTriggeredCueId,
    bool? listLoop,
  }) {
    return CueControlState(
      selectedCueId: identical(selectedCueId, _unset)
          ? this.selectedCueId
          : selectedCueId as String?,
      lastTriggeredCueId: lastTriggeredCueId ?? this.lastTriggeredCueId,
      listLoop: listLoop ?? this.listLoop,
    );
  }

  static const _unset = Object();
}

/// Cue 列表模式控制器：选中、GO 触发、列表循环推进。
class CueController extends Notifier<CueControlState> {
  final Map<String, String> _playToCue = {};

  @override
  CueControlState build() {
    final engine = ref.read(playbackEngineProvider.notifier);
    final sub = engine.onCompleted.listen((playId) {
      final cueId = _playToCue.remove(playId);
      if (cueId == null) return;
      if (!state.listLoop) return;
      final cues = ref
          .read(showProvider)
          .valueOrNull
          ?.activeShow
          .cues ?? const <Cue>[];
      if (cues.isEmpty) return;
      final idx = cues.indexWhere((c) => c.id == cueId);
      if (idx < 0) return;
      final next = cues[(idx + 1) % cues.length];
      _trigger(next);
    });
    ref.onDispose(sub.cancel);
    return const CueControlState();
  }

  void select(String id) {
    state = state.copyWith(selectedCueId: id);
  }

  void clearSelection() {
    state = state.copyWith(selectedCueId: null);
  }

  Future<void> go() async {
    final cues = ref
        .read(showProvider)
        .valueOrNull
        ?.activeShow
        .cues ?? const <Cue>[];
    if (cues.isEmpty) return;
    final selIdx = cues.indexWhere((c) => c.id == state.selectedCueId);
    final start = selIdx >= 0 ? selIdx : 0;
    await _trigger(cues[start]);
    final nextIdx = start + 1;
    state = state.copyWith(
      selectedCueId: nextIdx < cues.length ? cues[nextIdx].id : null,
    );
  }

  Future<void> _trigger(Cue cue) async {
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
  }

  void toggleListLoop() {
    state = state.copyWith(listLoop: !state.listLoop);
  }

  Future<void> stopAll() async {
    await ref.read(playbackEngineProvider.notifier).stopAll();
  }
}

final cueControllerProvider =
    NotifierProvider<CueController, CueControlState>(CueController.new);
