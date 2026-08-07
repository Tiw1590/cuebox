/// 把存储的 URI/路径转成可播放的 Uri。
///
/// Android 素材是 content://（自带 scheme）；桌面端存的是纯文件路径，
/// 直接交给 AVPlayer/ExoPlayer 会失败，需要补上 file:// 前缀。
Uri resolveAudioUri(String uri) {
  final parsed = Uri.tryParse(uri);
  if (parsed != null && parsed.scheme.isNotEmpty) return parsed;
  return Uri.file(uri);
}
