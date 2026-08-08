import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import 'show_providers.dart';

/// 弹出当前工程的全局参数面板（默认应用于新加入的音频）。
Future<void> showProjectSettingsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _ProjectSettingsSheet(),
  );
}

class _ProjectSettingsSheet extends ConsumerStatefulWidget {
  const _ProjectSettingsSheet();

  @override
  ConsumerState<_ProjectSettingsSheet> createState() =>
      _ProjectSettingsSheetState();
}

class _ProjectSettingsSheetState extends ConsumerState<_ProjectSettingsSheet> {
  late double _volume;
  late int _fadeInMs;
  late int _fadeOutMs;
  late bool _loop;

  @override
  void initState() {
    super.initState();
    final show = ref.read(activeShowProvider).valueOrNull;
    _volume = show?.defaultVolume ?? 1.0;
    _fadeInMs = show?.defaultFadeInMs ?? 20;
    _fadeOutMs = show?.defaultFadeOutMs ?? 150;
    _loop = show?.defaultLoop ?? false;
  }

  Future<void> _save() async {
    await ref
        .read(showProvider.notifier)
        .updateShowDefaults(
          volume: _volume,
          fadeInMs: _fadeInMs,
          fadeOutMs: _fadeOutMs,
          loop: _loop,
        );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('全局参数', style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: 4),
              Text(
                '仅对本演出项目生效；单独设置过的音频以它自己为准',
                style: TextStyle(fontSize: 12.5, color: CueBoxColors.textFaint),
              ),
              SizedBox(height: 12),
              _ParamSlider(
                label: '默认音量',
                valueLabel: '${(_volume * 100).round()}%',
                value: _volume,
                min: 0,
                max: 1,
                divisions: 20,
                onChanged: (v) => setState(() => _volume = v),
              ),
              _ParamSlider(
                label: '默认淡入',
                valueLabel: _fmtSec(_fadeInMs),
                value: _fadeInMs.toDouble(),
                min: 0,
                max: 3000,
                divisions: 60,
                onChanged: (v) => setState(() => _fadeInMs = v.round()),
              ),
              _ParamSlider(
                label: '默认淡出',
                valueLabel: _fmtSec(_fadeOutMs),
                value: _fadeOutMs.toDouble(),
                min: 0,
                max: 5000,
                divisions: 100,
                onChanged: (v) => setState(() => _fadeOutMs = v.round()),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('默认循环', style: TextStyle(fontSize: 14)),
                          SizedBox(height: 2),
                          Text(
                            '新加入的音频默认循环播放',
                            style: TextStyle(
                              color: CueBoxColors.textFaint,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _loop,
                      onChanged: (v) => setState(() => _loop = v),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _volume = 1.0;
                          _fadeInMs = 20;
                          _fadeOutMs = 150;
                          _loop = false;
                        });
                      },
                      icon: Icon(Icons.restart_alt, size: 18),
                      label: Text('恢复默认'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: Icon(Icons.check, size: 18),
                      label: Text('保存'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParamSlider extends StatelessWidget {
  const _ParamSlider({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: TextStyle(fontSize: 13.5)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: CueBoxColors.primary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

String _fmtSec(int ms) {
  if (ms <= 0) return '0s';
  return '${(ms / 1000).toStringAsFixed(1)}s';
}
