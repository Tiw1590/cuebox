import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets/cuebox_background.dart';
import '../cart/cart_page.dart';
import '../cue/cue_controller.dart';
import '../cue/cue_list_page.dart';
import '../media/media_library_page.dart';
import '../settings/settings_page.dart';
import '../show/show_models.dart';
import '../show/show_providers.dart';
import '../show/project_settings_sheet.dart';

/// 应用主框架：
/// - 标题为当前工程名，点按弹出工程切换器；
/// - 右上角菜单：素材库、设置、新建 Cue / Cart 工程、锁定。
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final libAsync = ref.watch(showProvider);
    final lib = libAsync.valueOrNull;
    final show = lib?.activeShow;
    final showName = show?.name ?? 'CueBox';
    final kind = show?.kind ?? ShowKind.cue;
    final locked = show?.locked ?? false;

    // 切换工程时清掉 Cue 选中态，避免残留。
    ref.listen(showProvider, (prev, next) {
      final a = prev?.valueOrNull?.activeShowId;
      final b = next.valueOrNull?.activeShowId;
      if (a != b) {
        ref.read(cueControllerProvider.notifier).clearSelection();
      }
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: InkWell(
          onTap: _openShowSwitcher,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  kind == ShowKind.cue
                      ? Icons.view_list_rounded
                      : Icons.grid_view_rounded,
                  size: 18,
                  color: kind == ShowKind.cue
                      ? CueBoxColors.primary
                      : CueBoxColors.secondary,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    showName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (locked) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: CueBoxColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: CueBoxColors.amber,
                    ),
                  ),
                ],
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: CueBoxColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: '主菜单',
            onSelected: _onMenuSelected,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'media',
                child: _MenuRow(
                  icon: Icons.library_music_outlined,
                  label: '素材库',
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: _MenuRow(
                  icon: Icons.settings_outlined,
                  label: '设置',
                ),
              ),
              const PopupMenuItem(
                value: 'project_settings',
                child: _MenuRow(
                  icon: Icons.tune,
                  label: '工程参数',
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'new_cue_show',
                child: _MenuRow(
                  icon: Icons.view_list_outlined,
                  label: '新建 Cue 工程',
                  color: CueBoxColors.primary,
                ),
              ),
              const PopupMenuItem(
                value: 'new_cart_show',
                child: _MenuRow(
                  icon: Icons.grid_view_outlined,
                  label: '新建 Cart 工程',
                  color: CueBoxColors.secondary,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_lock',
                child: _MenuRow(
                  icon: locked
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  label: locked ? '解锁工程' : '锁定工程',
                  color: locked
                      ? CueBoxColors.textPrimary
                      : CueBoxColors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
      body: CueBoxBackground(
        child: IndexedStack(
          index: kind == ShowKind.cart ? 1 : 0,
          children: const [CueListPage(), CartPage()],
        ),
      ),
    );
  }

  Future<void> _onMenuSelected(String value) async {
    switch (value) {
      case 'media':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MediaLibraryPage()),
        );
      case 'settings':
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
      case 'project_settings':
        showProjectSettingsSheet(context, ref);
      case 'new_cue_show':
        final name = await _promptShowName(context, title: '新建 Cue 工程');
        if (name != null && mounted) {
          await ref
              .read(showProvider.notifier)
              .createShow(name: name, kind: ShowKind.cue);
        }
      case 'new_cart_show':
        final name = await _promptShowName(context, title: '新建 Cart 工程');
        if (name != null && mounted) {
          await ref
              .read(showProvider.notifier)
              .createShow(name: name, kind: ShowKind.cart);
        }
      case 'toggle_lock':
        final activeId = ref.read(showProvider).valueOrNull?.activeShowId;
        final active = ref.read(showProvider).valueOrNull?.activeShow;
        if (activeId != null && active != null) {
          await ref
              .read(showProvider.notifier)
              .setLocked(activeId, !active.locked);
        }
    }
  }

  void _openShowSwitcher() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ShowSwitcherSheet(),
    );
  }
}

/// 工程切换器：列出全部 Cue / Cart 工程，支持新建、重命名、锁定、删除。
class _ShowSwitcherSheet extends ConsumerWidget {
  const _ShowSwitcherSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final libAsync = ref.watch(showProvider);
    final lib = libAsync.valueOrNull;
    final shows = lib?.shows ?? const <Show>[];
    final activeId = lib?.activeShowId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '工程列表',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                Text(
                  '${shows.length} 个工程',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: CueBoxColors.textFaint,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: shows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final show = shows[index];
                  final isActive = show.id == activeId;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isActive
                          ? CueBoxColors.primary.withValues(alpha: 0.08)
                          : CueBoxColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isActive
                            ? CueBoxColors.primary
                            : CueBoxColors.border,
                        width: isActive ? 1.2 : 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (!isActive) {
                            ref
                                .read(showProvider.notifier)
                                .setActiveShow(show.id);
                          }
                          Navigator.of(context).pop();
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                          child: Row(
                            children: [
                              Icon(
                                isActive
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                size: 20,
                                color: isActive
                                    ? CueBoxColors.primary
                                    : CueBoxColors.textFaint,
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                show.kind == ShowKind.cue
                                    ? Icons.view_list_rounded
                                    : Icons.grid_view_rounded,
                                size: 19,
                                color: show.kind == ShowKind.cue
                                    ? CueBoxColors.primary
                                    : CueBoxColors.secondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        show.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isActive
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (show.locked) ...[
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.lock_rounded,
                                        size: 13,
                                        color: CueBoxColors.amber,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                show.kind == ShowKind.cue
                                    ? '${show.cues.length} 条 Cue'
                                    : '${show.cartSlots.length} 个格块',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: CueBoxColors.textFaint,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: '工程操作',
                                onSelected: (value) async {
                                  if (value == 'rename') {
                                    final name = await _promptShowName(
                                      context,
                                      title: '重命名工程',
                                      initial: show.name,
                                    );
                                    if (name != null) {
                                      await ref
                                          .read(showProvider.notifier)
                                          .renameShow(show.id, name);
                                    }
                                  } else if (value == 'lock') {
                                    await ref
                                        .read(showProvider.notifier)
                                        .setLocked(show.id, !show.locked);
                                  } else if (value == 'delete') {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text('删除工程？'),
                                        content: Text(
                                          '将删除「${show.name}」及其全部内容，无法撤销。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  CueBoxColors.danger,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(dialogContext)
                                                    .pop(true),
                                            child: const Text('删除'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await ref
                                          .read(showProvider.notifier)
                                          .deleteShow(show.id);
                                    }
                                  }
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(Icons.drive_file_rename_outline,
                                            size: 19),
                                        SizedBox(width: 10),
                                        Text('重命名'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'lock',
                                    child: Row(
                                      children: [
                                        Icon(
                                          show.locked
                                              ? Icons.lock_open_rounded
                                              : Icons.lock_rounded,
                                          size: 19,
                                          color: CueBoxColors.amber,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          show.locked ? '解锁工程' : '锁定工程',
                                          style: const TextStyle(
                                            color: CueBoxColors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 19,
                                          color: CueBoxColors.danger,
                                        ),
                                        SizedBox(width: 10),
                                        Text(
                                          '删除',
                                          style: TextStyle(
                                            color: CueBoxColors.danger,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                icon: const Icon(
                                  Icons.more_vert,
                                  size: 20,
                                  color: CueBoxColors.textFaint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final name =
                          await _promptShowName(context, title: '新建 Cue 工程');
                      if (name != null) {
                        await ref
                            .read(showProvider.notifier)
                            .createShow(name: name, kind: ShowKind.cue);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.view_list_rounded, size: 19),
                    label: const Text('新建 Cue 工程'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final name =
                          await _promptShowName(context, title: '新建 Cart 工程');
                      if (name != null) {
                        await ref
                            .read(showProvider.notifier)
                            .createShow(name: name, kind: ShowKind.cart);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.grid_view_rounded, size: 19),
                    label: const Text('新建 Cart 工程'),
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

/// 名称输入弹窗：控制器随弹窗生命周期创建/销毁，避免关闭动画中访问已释放控制器。
class _ShowNameDialog extends StatefulWidget {
  const _ShowNameDialog({required this.title, this.initial = ''});

  final String title;
  final String initial;

  @override
  State<_ShowNameDialog> createState() => _ShowNameDialogState();
}

class _ShowNameDialogState extends State<_ShowNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 24,
        decoration: const InputDecoration(
          hintText: '工程名称',
          counterText: '',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('确定'),
        ),
      ],
    );
  }
}

Future<String?> _promptShowName(
  BuildContext context, {
  required String title,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ShowNameDialog(title: title, initial: initial),
  );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.color = CueBoxColors.textPrimary,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
