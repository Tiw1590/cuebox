/// 毫秒 → mm:ss:cc（分:秒:厘秒）。
String fmtMmSsCc(int ms) {
  final totalCs = (ms < 0 ? 0 : ms) ~/ 10;
  final m = totalCs ~/ 6000;
  final s = (totalCs % 6000) ~/ 100;
  final cs = totalCs % 100;
  return '${m.toString().padLeft(2, '0')}:'
      '${s.toString().padLeft(2, '0')}:'
      '${cs.toString().padLeft(2, '0')}';
}
