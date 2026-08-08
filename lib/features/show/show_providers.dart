import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'show_models.dart';

const _kShowKey = 'show.data';

/// 工程库（多个 Cue / Cart 工程 + 当前激活项），自动持久化到本机。
final showProvider = AsyncNotifierProvider<ShowNotifier, ShowLibrary>(
  ShowNotifier.new,
);

/// 当前激活的工程，页面直接 watch 它。
final activeShowProvider = Provider<AsyncValue<Show>>((ref) {
  return ref.watch(showProvider).whenData((lib) => lib.activeShow);
});

class ShowNotifier extends AsyncNotifier<ShowLibrary> {
  @override
  Future<ShowLibrary> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kShowKey);
    if (raw != null) {
      try {
        final lib = _ensureUniqueIds(
          ShowLibrary.fromJson(jsonDecode(raw) as Map<String, dynamic>),
        );
        if (lib.shows.isNotEmpty) return lib;
      } catch (_) {
        // 数据损坏时回退到默认工程。
      }
    }
    final show = Show();
    return ShowLibrary(shows: [show], activeShowId: show.id);
  }

  ShowLibrary? get _current => state.valueOrNull;

  Future<void> _set(ShowLibrary lib) async {
    final normalized = _ensureUniqueIds(lib);
    state = AsyncData(normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kShowKey, jsonEncode(normalized.toJson()));
  }

  /// 修复历史数据里可能重复的 id（批量导入曾因微秒时间戳相同而撞 id），
  /// 并保证每次写入前 id 全局唯一。
  ShowLibrary _ensureUniqueIds(ShowLibrary lib) {
    final used = <String>{};
    var seq = 0;
    String fresh(String prefix) {
      String id;
      do {
        id = '$prefix${DateTime.now().microsecondsSinceEpoch}_${seq++}';
      } while (used.contains(id));
      used.add(id);
      return id;
    }

    String fix(String prefix, String id) {
      if (id.isNotEmpty && !used.contains(id)) {
        used.add(id);
        return id;
      }
      return fresh(prefix);
    }

    return ShowLibrary(
      shows: lib.shows.map((s) {
        return Show(
          id: fix('show', s.id),
          name: s.name,
          kind: s.kind,
          locked: s.locked,
          defaultVolume: s.defaultVolume,
          defaultFadeInMs: s.defaultFadeInMs,
          defaultFadeOutMs: s.defaultFadeOutMs,
          defaultLoop: s.defaultLoop,
          cues: s.cues
              .map(
                (c) => Cue(
                  id: fix('cue', c.id),
                  name: c.name,
                  uri: c.uri,
                  note: c.note,
                  startMs: c.startMs,
                  endMs: c.endMs,
                  preWaitMs: c.preWaitMs,
                  postWaitMs: c.postWaitMs,
                  autoNext: c.autoNext,
                  playNextTogether: c.playNextTogether,
                  followGlobal: c.followGlobal,
                  loop: c.loop,
                  volume: c.volume,
                  fadeInMs: c.fadeInMs,
                  fadeOutMs: c.fadeOutMs,
                ),
              )
              .toList(),
          cartSlots: s.cartSlots
              .map(
                (c) => CartSlot(
                  id: fix('cart', c.id),
                  name: c.name,
                  uri: c.uri,
                  note: c.note,
                  startMs: c.startMs,
                  endMs: c.endMs,
                  solo: c.solo,
                  loop: c.loop,
                  volume: c.volume,
                  fadeInMs: c.fadeInMs,
                  fadeOutMs: c.fadeOutMs,
                  shortcutKeyId: c.shortcutKeyId,
                  shortcutLabel: c.shortcutLabel,
                ),
              )
              .toList(),
        );
      }).toList(),
      activeShowId: lib.activeShowId,
    );
  }

  /// 对指定工程做一次修改；缺省用当前激活工程。
  Future<void> _mutateShow(
    Show Function(Show show) change, {
    String? showId,
  }) async {
    final lib = _current;
    if (lib == null || lib.shows.isEmpty) return;
    final target = showId == null
        ? lib.activeShow
        : lib.shows.firstWhere(
            (s) => s.id == showId,
            orElse: () => lib.activeShow,
          );
    final next = change(target);
    await _set(
      ShowLibrary(
        shows: lib.shows.map((s) => s.id == target.id ? next : s).toList(),
        activeShowId: lib.activeShowId,
      ),
    );
  }

  // ---------- 工程管理 ----------

  Future<void> createShow({
    String name = '新演出',
    ShowKind kind = ShowKind.cue,
  }) async {
    final lib = _current;
    final show = Show(name: name, kind: kind);
    await _set(
      ShowLibrary(
        shows: [...(lib?.shows ?? <Show>[]), show],
        activeShowId: show.id,
      ),
    );
  }

  Future<void> renameShow(String id, String name) {
    return _mutateShow((s) => s.copyWith(name: name), showId: id);
  }

  Future<void> setLocked(String id, bool locked) {
    return _mutateShow((s) => s.copyWith(locked: locked), showId: id);
  }

  Future<void> updateShowDefaults({
    required double volume,
    required int fadeInMs,
    required int fadeOutMs,
    required bool loop,
  }) {
    return _mutateShow(
      (s) => s.copyWith(
        defaultVolume: volume,
        defaultFadeInMs: fadeInMs,
        defaultFadeOutMs: fadeOutMs,
        defaultLoop: loop,
      ),
    );
  }

  Future<void> deleteShow(String id) async {
    final lib = _current;
    if (lib == null) return;
    var shows = lib.shows.where((s) => s.id != id).toList();
    if (shows.isEmpty) {
      final fallback = Show();
      shows = [fallback];
      await _set(ShowLibrary(shows: shows, activeShowId: fallback.id));
      return;
    }
    var activeId = lib.activeShowId;
    if (!shows.any((s) => s.id == activeId)) activeId = shows.first.id;
    await _set(ShowLibrary(shows: shows, activeShowId: activeId));
  }

  Future<void> setActiveShow(String id) async {
    final lib = _current;
    if (lib == null || !lib.shows.any((s) => s.id == id)) return;
    if (lib.activeShowId == id) return;
    await _set(ShowLibrary(shows: lib.shows, activeShowId: id));
  }

  // ---------- 当前工程的 Cue / Cart 操作 ----------

  Future<void> addCue({required String uri, required String name}) {
    return _mutateShow(
      (show) => show.copyWith(
        cues: [
          ...show.cues,
          Cue(
            id: _genId('cue'),
            name: name,
            uri: uri,
            volume: show.defaultVolume,
            fadeInMs: show.defaultFadeInMs,
            fadeOutMs: show.defaultFadeOutMs,
            loop: show.defaultLoop,
            followGlobal: true,
          ),
        ],
      ),
    );
  }

  Future<void> addCues(List<({String uri, String name})> items) {
    return _mutateShow(
      (show) => show.copyWith(
        cues: [
          ...show.cues,
          for (final item in items)
            Cue(
              id: _genId('cue'),
              name: item.name,
              uri: item.uri,
              volume: show.defaultVolume,
              fadeInMs: show.defaultFadeInMs,
              fadeOutMs: show.defaultFadeOutMs,
              loop: show.defaultLoop,
              followGlobal: true,
            ),
        ],
      ),
    );
  }

  Future<void> addCueWithParams({
    required String uri,
    required String name,
    String note = '',
    double volume = 1.0,
    int fadeInMs = 20,
    int fadeOutMs = 150,
    bool loop = false,
    int startMs = 0,
    int endMs = 0,
    int preWaitMs = 0,
    int postWaitMs = 0,
    bool followGlobal = true,
  }) {
    return _mutateShow(
      (show) => show.copyWith(
        cues: [
          ...show.cues,
          Cue(
            id: _genId('cue'),
            name: name,
            uri: uri,
            note: note,
            volume: volume,
            fadeInMs: fadeInMs,
            fadeOutMs: fadeOutMs,
            loop: loop,
            startMs: startMs,
            endMs: endMs,
            preWaitMs: preWaitMs,
            postWaitMs: postWaitMs,
            followGlobal: followGlobal,
          ),
        ],
      ),
    );
  }

  Future<void> addCartSlot({required String uri, required String name}) {
    return _mutateShow(
      (show) => show.copyWith(
        cartSlots: [
          ...show.cartSlots,
          CartSlot(id: _genId('cart'), name: name, uri: uri),
        ],
      ),
    );
  }

  Future<void> addCartSlots(List<({String uri, String name})> items) {
    return _mutateShow(
      (show) => show.copyWith(
        cartSlots: [
          ...show.cartSlots,
          for (final item in items)
            CartSlot(id: _genId('cart'), name: item.name, uri: item.uri),
        ],
      ),
    );
  }

  Future<void> addCartSlotWithParams({
    required String uri,
    required String name,
    String note = '',
    double volume = 1.0,
    int fadeInMs = 20,
    int fadeOutMs = 150,
    bool loop = false,
    int startMs = 0,
    int endMs = 0,
    bool solo = true,
    int? shortcutKeyId,
    String? shortcutLabel,
  }) {
    return _mutateShow(
      (show) => show.copyWith(
        cartSlots: [
          ...show.cartSlots,
          CartSlot(
            id: _genId('cart'),
            name: name,
            uri: uri,
            note: note,
            volume: volume,
            fadeInMs: fadeInMs,
            fadeOutMs: fadeOutMs,
            loop: loop,
            startMs: startMs,
            endMs: endMs,
            solo: solo,
            shortcutKeyId: shortcutKeyId,
            shortcutLabel: shortcutLabel,
          ),
        ],
      ),
    );
  }

  Future<void> updateCue(Cue cue) {
    return _mutateShow(
      (show) => show.copyWith(
        cues: show.cues.map((c) => c.id == cue.id ? cue : c).toList(),
      ),
    );
  }

  Future<void> updateCartSlot(CartSlot slot) {
    return _mutateShow(
      (show) => show.copyWith(
        cartSlots: show.cartSlots
            .map((c) => c.id == slot.id ? slot : c)
            .toList(),
      ),
    );
  }

  Future<void> removeCue(String id) {
    return _mutateShow(
      (show) =>
          show.copyWith(cues: show.cues.where((c) => c.id != id).toList()),
    );
  }

  Future<void> removeCartSlot(String id) {
    return _mutateShow(
      (show) => show.copyWith(
        cartSlots: show.cartSlots.where((c) => c.id != id).toList(),
      ),
    );
  }

  Future<void> moveCue(String id, int delta) {
    return _mutateShow((show) {
      final cues = [...show.cues];
      final idx = cues.indexWhere((c) => c.id == id);
      final target = idx + delta;
      if (idx < 0 || target < 0 || target >= cues.length) return show;
      final tmp = cues[idx];
      cues[idx] = cues[target];
      cues[target] = tmp;
      return show.copyWith(cues: cues);
    });
  }

  /// 清空当前工程的 Cue 与 Pad。
  Future<void> clearAll() {
    return _mutateShow((show) => show.copyWith(cues: [], cartSlots: []));
  }

  static int _idSeq = 0;

  static String _genId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}_${_idSeq++}';
}
