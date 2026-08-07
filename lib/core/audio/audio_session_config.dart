import 'package:audio_session/audio_session.dart';

/// 配置全局音频会话，保证多轨叠放不被互相打断：
///
/// - `gainTransientMayDuck`：新触发只让其他播放器收到 CAN_DUCK（轻微降音量），
///   而非暂停；对 media 用途 just_audio 不会因此改变音量，叠放自然成立。
/// - `willPauseWhenDucked = false`：避免系统把 duck 当成暂停处理。
/// - 外部 App 抢占焦点（如来电）时，仍会收到 pause 事件并正常暂停。
Future<void> configureAudioSession() async {
  final session = await AudioSession.instance;
  await session.configure(
    AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ),
  );
}
