import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 全局播放状态：
/// - [single]：单独播放，触发新声音时停掉其他所有声音。
/// - [multi]：多个播放，新声音与其他声音叠放（卡片自身标了 Solo 的仍独占）。
enum PlaybackMode { single, multi }

const _kPlaybackModeKey = 'playback.mode';

final playbackModeProvider =
    NotifierProvider<PlaybackModeNotifier, PlaybackMode>(
      PlaybackModeNotifier.new,
    );

class PlaybackModeNotifier extends Notifier<PlaybackMode> {
  @override
  PlaybackMode build() {
    _load();
    return PlaybackMode.single;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kPlaybackModeKey);
    if (name != null) {
      final mode = PlaybackMode.values.asNameMap()[name];
      if (mode != null && mode != state) {
        state = mode;
      }
    }
  }

  Future<void> setMode(PlaybackMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPlaybackModeKey, mode.name);
  }
}
