import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:desktop_drop/desktop_drop.dart';

import '../../core/theme.dart';
import '../../core/widgets/cuebox_background.dart';
import '../../core/platform/media_access.dart';
import '../cart/cart_page.dart';
import '../cue/cue_controller.dart';
import '../cue/cue_list_page.dart';
import '../media/media_library_page.dart';
import '../media/media_providers.dart';
import '../playback/playback_engine.dart';
import '../settings/settings_page.dart';
import '../show/clipboard.dart';
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
  bool _dragging = false;

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
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
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
                SizedBox(width: 7),
                Flexible(
                  child: Text(
                    showName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (locked) ...[
                  SizedBox(width: 6),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: CueBoxColors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 14,
                      color: CueBoxColors.amber,
                    ),
                  ),
                ],
                SizedBox(width: 2),
                Icon(
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
              PopupMenuItem(
                value: 'media',
                child: _MenuRow(
                  icon: Icons.library_music_outlined,
                  label: '素材库',
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: _MenuRow(icon: Icons.settings_outlined, label: '设置'),
              ),
              PopupMenuItem(
                value: 'project_settings',
                child: _MenuRow(icon: Icons.tune, label: '工程参数'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'new_cue_show',
                child: _MenuRow(
                  icon: Icons.view_list_outlined,
                  label: '新建 Cue List',
                  color: CueBoxColors.primary,
                ),
              ),
              PopupMenuItem(
                value: 'new_cart_show',
                child: _MenuRow(
                  icon: Icons.grid_view_outlined,
                  label: '新建 Pad Set',
                  color: CueBoxColors.secondary,
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'toggle_lock',
                child: _MenuRow(
                  icon: locked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  label: locked ? '解锁演出项目' : '锁定演出项目',
                  color: locked ? CueBoxColors.textPrimary : CueBoxColors.amber,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _wrapShortcuts(
        kind: kind,
        lib: lib,
        child: CueBoxBackground(
          child: IndexedStack(
            index: kind == ShowKind.cart ? 1 : 0,
            children: [CueListPage(), CartPage()],
          ),
        ),
      ),
    );
  }

  Widget _wrapShortcuts({
    required ShowKind kind,
    required ShowLibrary? lib,
    required Widget child,
  }) {
    final slots = lib?.activeShow.cartSlots ?? <CartSlot>[];
    final shortcuts = <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.space): GoIntent(),
      SingleActivator(LogicalKeyboardKey.escape): StopIntent(),
      SingleActivator(LogicalKeyboardKey.keyC, control: true): CopyIntent(),
      SingleActivator(LogicalKeyboardKey.keyV, control: true): PasteIntent(),
      SingleActivator(LogicalKeyboardKey.keyC, meta: true): CopyIntent(),
      SingleActivator(LogicalKeyboardKey.keyV, meta: true): PasteIntent(),
      for (final slot in slots)
        if (slot.shortcutKeyId case final keyId?)
          if (LogicalKeyboardKey.findKeyByKeyId(keyId) case final key?)
            SingleActivator(key): CardIntent(slot.id),
    };

    final body = Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          GoIntent: CallbackAction<GoIntent>(
            onInvoke: (_) {
              if (kind == ShowKind.cue && !_isTyping) {
                ref.read(cueControllerProvider.notifier).go();
              }
              return null;
            },
          ),
          StopIntent: CallbackAction<StopIntent>(
            onInvoke: (_) {
              if (!_isTyping) {
                ref.read(playbackEngineProvider.notifier).stopAll();
              }
              return null;
            },
          ),
          CopyIntent: CallbackAction<CopyIntent>(
            onInvoke: (_) {
              _copyActive();
              return null;
            },
          ),
          PasteIntent: CallbackAction<PasteIntent>(
            onInvoke: (_) {
              if (!_isTyping) pasteClipboard(ref, context);
              return null;
            },
          ),
          CardIntent: CallbackAction<CardIntent>(
            onInvoke: (intent) {
              if (kind == ShowKind.cart && !_isTyping) {
                _triggerCard(intent.slotId);
              }
              return null;
            },
          ),
        },
        child: Focus(autofocus: true, child: child),
      ),
    );

    if (!_isDesktop) return body;
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) async {
        setState(() => _dragging = false);
        await _handleDrop(details.files);
      },
      child: Stack(
        children: [
          body,
          if (_dragging) Positioned.fill(child: _DropOverlay()),
        ],
      ),
    );
  }

  bool get _isDesktop => Platform.isWindows || Platform.isMacOS;

  bool get _isTyping {
    final focus = FocusManager.instance.primaryFocus;
    return focus?.context?.widget is EditableText;
  }

  void _copyActive() {
    final show = ref.read(showProvider).valueOrNull?.activeShow;
    if (show == null) return;
    if (show.kind == ShowKind.cue) {
      final selectedId = ref.read(cueControllerProvider).selectedCueId;
      final cue = show.cues.where((c) => c.id == selectedId).firstOrNull;
      if (cue != null) copyCueToClipboard(ref, cue);
    }
  }

  void _triggerCard(String slotId) {
    final show = ref.read(showProvider).valueOrNull?.activeShow;
    final slot = show?.cartSlots.where((s) => s.id == slotId).firstOrNull;
    if (slot != null) {
      triggerCartSlot(ref, slot);
    }
  }

  Future<void> _handleDrop(List<DropItem> files) async {
    final audioFiles = files
        .where((f) => f.path.isNotEmpty && isAudioPath(f.path))
        .toList();
    final log = StringBuffer('=== drop ${DateTime.now()} ===\n');
    log.writeln('received ${files.length} items, audio ${audioFiles.length}');
    if (audioFiles.isEmpty) {
      _showSnack('未发现音频文件');
      return;
    }

    // 确保素材根目录存在（桌面端默认 ~/Music/CueBox）。
    var rootPath = ref.read(mediaRootProvider).valueOrNull?.uri;
    if (rootPath == null) {
      await ref.read(mediaRootProvider.notifier).pick();
      rootPath = ref.read(mediaRootProvider).valueOrNull?.uri;
    }
    rootPath ??= LocalMediaAccess.defaultRootPath();
    log.writeln('rootPath: $rootPath');
    try {
      Directory(rootPath).createSync(recursive: true);
    } catch (e) {
      log.writeln('createRoot FAIL: $e');
    }

    final imported = <({String uri, String name})>[];
    for (final f in audioFiles) {
      log.writeln(
        'file: name="${f.name}" path="${f.path}" exists=${File(f.path).existsSync()}',
      );
      // 同名且大小一致 → 复用已有文件，避免重复复制。
      final existing = File('$rootPath${Platform.pathSeparator}${f.name}');
      if (existing.existsSync()) {
        try {
          if (existing.lengthSync() == File(f.path).lengthSync()) {
            imported.add((uri: existing.path, name: f.name));
            log.writeln('  -> reused ${existing.path}');
            continue;
          }
        } catch (_) {}
      }
      final dest = _uniquePath(rootPath, f.name);
      try {
        await File(f.path).copy(dest);
        imported.add((uri: dest, name: f.name));
        log.writeln('  -> copied $dest');
      } catch (e) {
        log.writeln('  -> COPY FAIL: $e');
      }
    }
    if (imported.isEmpty) {
      _showSnack('导入失败');
      _writeDropLog(log.toString());
      return;
    }

    final show = ref.read(showProvider).valueOrNull?.activeShow;
    if (show != null) {
      if (show.kind == ShowKind.cue) {
        await ref.read(showProvider.notifier).addCues(imported);
      } else {
        await ref.read(showProvider.notifier).addCartSlots(imported);
      }
    }
    _showSnack(
      '已导入 ${imported.length} 个音频到 ${show?.kind == ShowKind.cue ? 'Cue 列表' : 'Pad'}',
    );
    try {
      await ref.read(mediaBrowseProvider.notifier).refresh();
    } catch (_) {}
    _writeDropLog(log.toString());
  }

  void _writeDropLog(String content) {
    try {
      final home = Platform.environment['HOME'] ?? '';
      final logFile = File('$home/Library/Logs/CueBox/drop.log');
      logFile.parent.createSync(recursive: true);
      logFile.writeAsStringSync(content, mode: FileMode.append);
    } catch (_) {}
  }

  String _uniquePath(String dir, String name) {
    var candidate = '$dir${Platform.pathSeparator}$name';
    if (!File(candidate).existsSync()) return candidate;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot) : '';
    var i = 1;
    do {
      candidate = '$dir${Platform.pathSeparator}$base ($i)$ext';
      i++;
    } while (File(candidate).existsSync());
    return candidate;
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _onMenuSelected(String value) async {
    switch (value) {
      case 'media':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => MediaLibraryPage()));
      case 'settings':
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => SettingsPage()));
      case 'project_settings':
        showProjectSettingsSheet(context, ref);
      case 'new_cue_show':
        final name = await _promptShowName(context, title: '新建 Cue List');
        if (name != null && mounted) {
          await ref
              .read(showProvider.notifier)
              .createShow(name: name, kind: ShowKind.cue);
        }
      case 'new_cart_show':
        final name = await _promptShowName(context, title: '新建 Pad Set');
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
      builder: (_) => _ShowSwitcherSheet(),
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
    final shows = lib?.shows ?? <Show>[];
    final activeId = lib?.activeShowId;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('演出项目', style: Theme.of(context).textTheme.titleLarge),
                Spacer(),
                Text(
                  '${shows.length} 个演出项目',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CueBoxColors.textFaint,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: shows.length,
                separatorBuilder: (_, _) => SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final show = shows[index];
                  final isActive = show.id == activeId;
                  return AnimatedContainer(
                    duration: Duration(milliseconds: 180),
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
                          padding: EdgeInsets.fromLTRB(14, 10, 4, 10),
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
                              SizedBox(width: 12),
                              Icon(
                                show.kind == ShowKind.cue
                                    ? Icons.view_list_rounded
                                    : Icons.grid_view_rounded,
                                size: 19,
                                color: show.kind == ShowKind.cue
                                    ? CueBoxColors.primary
                                    : CueBoxColors.secondary,
                              ),
                              SizedBox(width: 8),
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
                                      SizedBox(width: 6),
                                      Icon(
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
                                    : '${show.cartSlots.length} 个 Pad',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: CueBoxColors.textFaint,
                                ),
                              ),
                              PopupMenuButton<String>(
                                tooltip: '演出项目操作',
                                onSelected: (value) async {
                                  if (value == 'rename') {
                                    final name = await _promptShowName(
                                      context,
                                      title: '重命名演出项目',
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
                                        title: Text('删除演出项目？'),
                                        content: Text(
                                          '将删除「${show.name}」及其全部内容，无法撤销。',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(false),
                                            child: Text('取消'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  CueBoxColors.danger,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () => Navigator.of(
                                              dialogContext,
                                            ).pop(true),
                                            child: Text('删除'),
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
                                  PopupMenuItem(
                                    value: 'rename',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.drive_file_rename_outline,
                                          size: 19,
                                        ),
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
                                        SizedBox(width: 10),
                                        Text(
                                          show.locked ? '解锁演出项目' : '锁定演出项目',
                                          style: TextStyle(
                                            color: CueBoxColors.amber,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
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
                                icon: Icon(
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
            SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final name = await _promptShowName(
                        context,
                        title: '新建 Cue List',
                      );
                      if (name != null) {
                        await ref
                            .read(showProvider.notifier)
                            .createShow(name: name, kind: ShowKind.cue);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(Icons.view_list_rounded, size: 19),
                    label: Text('新建 Cue List'),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final name = await _promptShowName(
                        context,
                        title: '新建 Pad Set',
                      );
                      if (name != null) {
                        await ref
                            .read(showProvider.notifier)
                            .createShow(name: name, kind: ShowKind.cart);
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    },
                    icon: Icon(Icons.grid_view_rounded, size: 19),
                    label: Text('新建 Pad Set'),
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
    // 全部内容放进可滚动区域：键盘弹出空间不足时保持居中并滚动，不会溢出。
    return AlertDialog(
      contentPadding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLength: 24,
              decoration: InputDecoration(hintText: '演出项目名称', counterText: ''),
              onSubmitted: (_) => _submit(),
            ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('取消'),
                ),
                SizedBox(width: 8),
                FilledButton(onPressed: _submit, child: Text('确定')),
              ],
            ),
          ],
        ),
      ),
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
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? CueBoxColors.textPrimary;
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        SizedBox(width: 10),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}

class GoIntent extends Intent {
  const GoIntent();
}

class StopIntent extends Intent {
  const StopIntent();
}

class CopyIntent extends Intent {
  const CopyIntent();
}

class PasteIntent extends Intent {
  const PasteIntent();
}

class CardIntent extends Intent {
  const CardIntent(this.slotId);

  final String slotId;
}

class _DropOverlay extends StatelessWidget {
  const _DropOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Color(0x990A0E13),
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: CueBoxColors.surfaceHigh,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: CueBoxColors.primary.withValues(alpha: 0.7),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.audio_file_outlined,
                size: 44,
                color: CueBoxColors.primary,
              ),
              SizedBox(height: 12),
              Text(
                '松开添加音频到当前演出项目',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 4),
              Text(
                '支持 mp3 / wav / m4a / flac / ogg 等',
                style: TextStyle(fontSize: 12, color: CueBoxColors.textFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
