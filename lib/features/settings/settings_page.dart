import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/theme_controller.dart';
import '../../core/widgets/cuebox_background.dart';
import '../media/media_models.dart';
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

  /// 素材文件夹管理弹窗：列出全部文件夹，支持切换/添加/移除。
  void _showRootsManager(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _RootsManagerSheet(
        onAdd: () async {
          Navigator.of(sheetContext).pop();
          await ref.read(mediaRootProvider.notifier).addRoot();
        },
        onRemove: (root) async {
          await ref.read(mediaRootProvider.notifier).removeRoot(root.uri);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听主题：切主题时停留在本页并立即刷新。
    ref.watch(themeModeProvider);
    final rootsAsync = ref.watch(mediaRootProvider);
    final roots = rootsAsync.valueOrNull ?? const <MediaRoot>[];

    return CueBoxBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: Text('设置')),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _SectionHeader('外观'),
            SizedBox(height: 10),
            const _ThemeSection(),
            SizedBox(height: 28),
            _SectionHeader('素材库'),
            SizedBox(height: 10),
            _SettingsCard(
              children: [
                ListTile(
                  leading: _TileIcon(
                    icon: Icons.folder_rounded,
                    color: CueBoxColors.amber,
                  ),
                  title: Text('素材文件夹'),
                  subtitle: Text(
                    roots.isEmpty
                        ? '未添加，点击添加文件夹'
                        : roots.length == 1
                            ? roots.first.name
                            : '${roots.length} 个文件夹',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: roots.isEmpty
                          ? CueBoxColors.textFaint
                          : CueBoxColors.textSecondary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: CueBoxColors.textFaint,
                  ),
                  onTap: () => _showRootsManager(context, ref),
                ),
                Divider(indent: 56),
                ListTile(
                  leading: _TileIcon(
                    icon: Icons.create_new_folder_outlined,
                    color: CueBoxColors.primary,
                  ),
                  title: Text('添加文件夹'),
                  subtitle: Text('选择设备上的素材文件夹，可添加多个'),
                  onTap: () async {
                    try {
                      await ref.read(mediaRootProvider.notifier).addRoot();
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('选择目录失败')),
                        );
                      }
                    }
                  },
                ),
                if (roots.isNotEmpty) ...[
                  Divider(indent: 56),
                  ListTile(
                    leading: _TileIcon(
                      icon: Icons.link_off_rounded,
                      color: CueBoxColors.danger,
                    ),
                    title: Text(
                      '移除全部文件夹',
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
                    '2.0.1',
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

/// 主题选择：深色 / 浅色。
class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    return _SettingsCard(
      children: [
        for (final mode in CueBoxThemeMode.values) ...[
          if (mode != CueBoxThemeMode.values.first) Divider(indent: 56),
          _ThemeTile(
            mode: mode,
            selected: current == mode,
            onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
          ),
        ],
      ],
    );
  }
}

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final CueBoxThemeMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = paletteForMode(mode);
    return ListTile(
      leading: _ThemePreview(palette: palette),
      title: Text(
        mode.label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? CueBoxColors.primary : CueBoxColors.textPrimary,
        ),
      ),
      subtitle: Text(
        mode.subtitle,
        style: TextStyle(color: CueBoxColors.textFaint, fontSize: 12),
      ),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        size: 22,
        color: selected ? CueBoxColors.primary : CueBoxColors.textFaint,
      ),
      onTap: onTap,
    );
  }
}

/// 主题预览：三色圆点（背景 / 主色 / 强调色）。
class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.palette});

  final CueBoxPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      padding: EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette.backgroundTop, palette.background],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderStrong, width: 1),
        boxShadow: [
          BoxShadow(
            color: palette.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            spreadRadius: -4,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: _Dot(color: palette.primary, size: 9),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: _Dot(color: palette.secondary, size: 9),
          ),
          Align(
            alignment: Alignment.center,
            child: _Dot(color: palette.amber, size: 9),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
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
      elevation: CueBoxColors.isGlass ? 2 : 1,
      shadowColor: CueBoxColors.cardShadowColor,
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

/// 素材文件夹管理弹窗：列出全部文件夹，可添加、移除。
class _RootsManagerSheet extends ConsumerWidget {
  const _RootsManagerSheet({required this.onAdd, required this.onRemove});

  final Future<void> Function() onAdd;
  final Future<void> Function(MediaRoot root) onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roots = ref.watch(mediaRootProvider).valueOrNull ?? const <MediaRoot>[];

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('素材文件夹', style: Theme.of(context).textTheme.titleLarge),
                Spacer(),
                Text(
                  '${roots.length} 个文件夹',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CueBoxColors.textFaint,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            if (roots.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '还没有素材文件夹',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CueBoxColors.textFaint),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: roots.length,
                  separatorBuilder: (_, _) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final root = roots[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: CueBoxColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: CueBoxColors.border),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(14, 8, 4, 8),
                          child: Row(
                            children: [
                              Icon(
                                Icons.folder_rounded,
                                size: 22,
                                color: CueBoxColors.amber,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  root.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '移除文件夹',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => onRemove(root),
                                icon: Icon(
                                  Icons.close,
                                  size: 19,
                                  color: CueBoxColors.textFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: Icon(Icons.create_new_folder_outlined, size: 19),
              label: Text('添加素材文件夹'),
            ),
          ],
        ),
      ),
    );
  }
}
