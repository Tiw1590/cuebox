import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/cuebox_background.dart';
import '../media/media_providers.dart';
import '../show/show_providers.dart';

/// 设置页：素材库、数据管理与关于。
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _confirmClearData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('清空演出数据？'),
        content: Text('将删除全部 Cue 列表与 Card，此操作无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: CueBoxColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(showProvider.notifier).clearAll();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('演出数据已清空')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rootAsync = ref.watch(mediaRootProvider);
    final root = rootAsync.valueOrNull;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text('设置')),
      body: CueBoxBackground(
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _SectionHeader('素材库'),
            SizedBox(height: 10),
            _SettingsCard(
              children: [
                ListTile(
                  leading: _TileIcon(
                    icon: Icons.folder_rounded,
                    color: CueBoxColors.amber,
                  ),
                  title: Text('当前素材目录'),
                  subtitle: Text(
                    root?.name ?? '未选择',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: root == null
                          ? CueBoxColors.textFaint
                          : CueBoxColors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: CueBoxColors.textFaint,
                  ),
                  onTap: () async {
                    try {
                      await ref.read(mediaRootProvider.notifier).pick();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('选择目录失败')),
                        );
                      }
                    }
                  },
                ),
                Divider(indent: 56),
                ListTile(
                  leading: _TileIcon(
                    icon: Icons.folder_open_rounded,
                    color: CueBoxColors.primary,
                  ),
                  title: Text('更换目录'),
                  subtitle: Text('重新选择素材所在文件夹'),
                  onTap: () async {
                    try {
                      await ref.read(mediaRootProvider.notifier).pick();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('选择目录失败')),
                        );
                      }
                    }
                  },
                ),
                if (root != null) ...[
                  Divider(indent: 56),
                  ListTile(
                    leading: _TileIcon(
                      icon: Icons.link_off_rounded,
                      color: CueBoxColors.danger,
                    ),
                    title: Text(
                      '解除素材目录',
                      style: TextStyle(color: CueBoxColors.danger),
                    ),
                    subtitle: Text('仅解除引用，不会删除文件'),
                    onTap: () =>
                        ref.read(mediaRootProvider.notifier).clear(),
                  ),
                ],
              ],
            ),
            SizedBox(height: 28),
            _SectionHeader('数据'),
            SizedBox(height: 10),
            _SettingsCard(
              children: [
                ListTile(
                  leading: _TileIcon(
                    icon: Icons.delete_sweep_outlined,
                    color: CueBoxColors.danger,
                  ),
                  title: Text(
                    '清空演出数据',
                    style: TextStyle(color: CueBoxColors.danger),
                  ),
                  subtitle: Text('删除当前演出的全部 Cue 与 Card'),
                  onTap: () => _confirmClearData(context, ref),
                ),
              ],
            ),
            SizedBox(height: 28),
            _SectionHeader('关于'),
            SizedBox(height: 10),
            _SettingsCard(
              children: [
                ListTile(
                  leading: _TileIcon(
                    icon: Icons.auto_awesome,
                    color: CueBoxColors.secondary,
                  ),
                  title: Text('CueBox'),
                  subtitle: Text('现场表演音效 Cue 播放器'),
                ),
                Divider(indent: 56),
                ListTile(
                  leading: _TileIcon(
                    icon: Icons.info_outline,
                    color: CueBoxColors.textSecondary,
                  ),
                  title: Text('版本'),
                  trailing: Text(
                    '1.0.0',
                    style: TextStyle(
                      color: CueBoxColors.textFaint,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: CueBoxColors.textFaint,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CueBoxColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: CueBoxColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}
