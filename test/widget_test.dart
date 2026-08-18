import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:cuebox/app.dart';
import 'package:cuebox/core/theme.dart';
import 'package:cuebox/core/theme_controller.dart';
import 'package:cuebox/features/media/media_models.dart';
import 'package:cuebox/features/media/media_providers.dart';
import 'package:cuebox/features/show/show_models.dart';
import 'package:cuebox/features/show/show_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setCueBoxTheme(CueBoxThemeMode.dark);
  });

  testWidgets('CueBox 骨架可以构建并显示主框架', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();
    expect(find.text('我的演出'), findsOneWidget);
    expect(find.text('还没有 Cue'), findsOneWidget);
    expect(find.text('GO'), findsOneWidget);
  });

  testWidgets('右上角菜单包含新建 Cue List/Pad Set、素材库与设置', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    expect(find.text('新建 Cue List'), findsOneWidget);
    expect(find.text('新建 Pad Set'), findsOneWidget);
    expect(find.text('素材库'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('新建 Pad Set'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Pad Set');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('还没有 Card'), findsOneWidget);
  });

  testWidgets('从菜单进入设置页', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('清空演出数据'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('关于'), 200);
    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('添加 Cue 后列表与 GO 按钮渲染', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    await container
        .read(showProvider.notifier)
        .addCue(uri: 'file:///tmp/test.mp3', name: '测试音效');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CueBoxApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试音效'), findsWidgets);
    expect(find.text('GO'), findsOneWidget);
    // 默认不展开编辑面板，点击后才显示。
    expect(find.text('编辑参数'), findsNothing);
  });

  testWidgets('点击 Cue 只选中，编辑参数菜单才打开面板', (tester) async {
    // 测试环境没有 macOS 波形通道，mock 成无波形。
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('cuebox/waveform'),
      (call) async => null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('cuebox/waveform'),
        null,
      );
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    await container
        .read(showProvider.notifier)
        .addCue(uri: 'file:///tmp/test1.mp3', name: '点击测试');
    await container
        .read(showProvider.notifier)
        .addCue(uri: 'file:///tmp/test2.mp3', name: '第二条');

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CueBoxApp()),
    );
    await tester.pumpAndSettle();

    // 默认不展开编辑面板。
    expect(find.text('编辑参数'), findsNothing);

    // 点击 Cue 只选中，不打开面板。
    await tester.tap(find.text('第二条').first);
    await tester.pumpAndSettle();
    expect(find.text('编辑参数'), findsNothing);

    // 通过 ⋮ 菜单“编辑参数”打开面板，内容为对应 Cue。
    await tester.tap(find.byTooltip('Cue 操作').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑参数'));
    await tester.pumpAndSettle();
    expect(find.text('编辑参数'), findsOneWidget);
    expect(find.widgetWithText(TextField, '第二条'), findsOneWidget);
  });

  test('可以创建、切换并删除多个演出', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);

    await notifier.createShow(name: '第二场');
    var lib = container.read(showProvider).value!;
    expect(lib.shows.length, 2);
    expect(lib.activeShow.name, '第二场');

    await notifier.addCue(uri: 'a.mp3', name: 'Cue A');
    lib = container.read(showProvider).value!;
    expect(lib.activeShow.cues.length, 1);

    await notifier.setActiveShow(lib.shows.first.id);
    lib = container.read(showProvider).value!;
    expect(lib.activeShow.name, '我的演出');
    expect(lib.activeShow.cues, isEmpty);
    expect(lib.shows[1].cues.length, 1);

    await notifier.deleteShow(lib.shows[1].id);
    lib = container.read(showProvider).value!;
    expect(lib.shows.length, 1);
    expect(lib.activeShow.name, '我的演出');
  });

  test('演出项目最多创建 3 个', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);
    await notifier.createShow(name: '第二场');
    await notifier.createShow(name: '第三场');
    expect(container.read(showProvider).value!.shows.length, 3);

    final ok = await notifier.createShow(name: '第四场');
    expect(ok, isFalse);
    expect(container.read(showProvider).value!.shows.length, 3);
  });

  test('锁定只对当前演出生效且可持久化', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);
    await notifier.createShow(name: '第二场');

    final firstId = container.read(showProvider).value!.shows.first.id;
    await notifier.setActiveShow(firstId);
    await notifier.setLocked(firstId, true);

    var lib = container.read(showProvider).value!;
    expect(lib.activeShow.locked, isTrue);

    // 切换到其他演出，不受锁定影响。
    await notifier.setActiveShow(lib.shows[1].id);
    lib = container.read(showProvider).value!;
    expect(lib.activeShow.locked, isFalse);

    // 切回锁定的演出，锁定依旧存在。
    await notifier.setActiveShow(firstId);
    expect(container.read(showProvider).value!.activeShow.locked, isTrue);

    // 修改内容后锁定状态不被重置。
    await notifier.addCue(uri: 'a.mp3', name: 'Cue A');
    expect(container.read(showProvider).value!.activeShow.locked, isTrue);
  });

  testWidgets('锁定演出隐藏编辑入口，解锁后恢复', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);
    await notifier.addCue(uri: 'file:///tmp/a.mp3', name: '锁定测试');
    await notifier.setLocked(
      container.read(showProvider).value!.activeShowId,
      true,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const CueBoxApp()),
    );
    await tester.pumpAndSettle();

    // 锁定：工具栏与 Cue 操作菜单隐藏。
    expect(find.text('列表循环'), findsNothing);
    expect(find.byTooltip('Cue 操作'), findsNothing);

    // 主菜单中提供解锁入口。
    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    expect(find.text('解锁演出项目'), findsOneWidget);

    await tester.tap(find.text('解锁演出项目'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('列表循环'), findsOneWidget);
  });

  testWidgets('新建 Cue List 完整流程不抛异常', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建 Cue List'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '第三场');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('第三场'), findsOneWidget);
  });

  testWidgets('小屏键盘弹出时新建 Cue List 弹窗不溢出', (tester) async {
    // 模拟小屏手机（360x640 逻辑像素）。
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建 Cue List'));
    await tester.pumpAndSettle();

    // 模拟输入法弹出占据底部 40% 高度。
    tester.view.viewInsets = const FakeViewPadding(bottom: 250);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('确定'), findsOneWidget);
  });

  test('Cue List 与 Pad Set 数据互相独立', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);

    await notifier.createShow(name: 'Cue 工程', kind: ShowKind.cue);
    await notifier.addCue(uri: 'a.mp3', name: 'Cue A');

    await notifier.createShow(name: 'Pad 工程', kind: ShowKind.cart);
    await notifier.addCartSlot(uri: 'b.mp3', name: 'Slot B');

    final lib = container.read(showProvider).value!;
    final cueShow = lib.shows.firstWhere((s) => s.name == 'Cue 工程');
    final cartShow = lib.shows.firstWhere((s) => s.name == 'Pad 工程');
    expect(cueShow.cues.length, 1);
    expect(cueShow.cartSlots, isEmpty);
    expect(cartShow.cartSlots.length, 1);
    expect(cartShow.cues, isEmpty);
  });

  test('拖拽移动 Cue 只移动自身，不带动其他子级', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);
    await notifier.addCueWithParams(uri: 'p1.mp3', name: '主级1');
    await notifier.addCueWithParams(uri: 'c1.mp3', name: '子级1');
    await notifier.addCueWithParams(uri: 'c2.mp3', name: '子级2');
    await notifier.addCueWithParams(uri: 'p2.mp3', name: '主级2');

    final cues = [...container.read(showProvider).value!.activeShow.cues];
    await notifier.updateCue(cues[1].copyWith(demoted: true));
    await notifier.updateCue(cues[2].copyWith(demoted: true));

    // 把“子级1”拖到“主级2”之后，只有它自己移动，子级2 不动。
    await notifier.moveCue(cues[1].id, 3);
    final moved = container.read(showProvider).value!.activeShow.cues;
    expect(moved.map((c) => c.name).toList(), ['主级1', '子级2', '主级2', '子级1']);
  });

  test('Pad 可移动到任意位置且每行数量可保存', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);
    await notifier.addCartSlot(uri: 'a.mp3', name: 'A');
    await notifier.addCartSlot(uri: 'b.mp3', name: 'B');
    await notifier.addCartSlot(uri: 'c.mp3', name: 'C');
    final show = container.read(showProvider).value!.activeShow;

    // A 拖到 C 的位置（2 号位被占用）：交换位置。
    await notifier.moveCartSlot(show.cartSlots[0].id, 2);
    var moved = container.read(showProvider).value!.activeShow.cartSlots;
    expect(moved.map((s) => s.name).toList(), ['C', 'B', 'A']);

    // C 拖到空位 5：只移动自己，留下 3、4 空位。
    await notifier.moveCartSlot(moved.first.id, 5);
    moved = container.read(showProvider).value!.activeShow.cartSlots;
    expect(moved.map((s) => s.name).toList(), ['B', 'A', 'C']);
    expect(moved.map((s) => s.gridIndex).toList(), [1, 2, 5]);

    await notifier.setPadColumns(7);
    expect(container.read(showProvider).value!.activeShow.padColumns, 7);
  });

  test('旧数据中 Cue 与 Pad 混在一场时自动拆分为独立工程', () async {
    SharedPreferences.setMockInitialValues({
      'show.data': jsonEncode({
        'name': '旧演出',
        'cues': [
          {'id': 'c1', 'name': '旧 Cue', 'uri': 'a.mp3'},
        ],
        'cartSlots': [
          {'id': 's1', 'name': '旧格块', 'uri': 'b.mp3'},
        ],
      }),
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final lib = await container.read(showProvider.future);
    expect(lib.shows.length, 2);
    expect(lib.shows[0].kind, ShowKind.cue);
    expect(lib.shows[0].cues.length, 1);
    expect(lib.shows[1].kind, ShowKind.cart);
    expect(lib.shows[1].cartSlots.length, 1);
    // 旧数据没有位置信息，自动补成第一个格子。
    expect(lib.shows[1].cartSlots.single.gridIndex, 0);
  });

  test('工程默认参数应用于新加入的音频', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);
    await notifier.updateShowDefaults(
      volume: 0.6,
      fadeInMs: 500,
      fadeOutMs: 800,
      loop: true,
    );
    await notifier.addCue(uri: 'a.mp3', name: '默认参数测试');

    final cue = container.read(showProvider).value!.activeShow.cues.single;
    expect(cue.volume, 0.6);
    expect(cue.fadeInMs, 500);
    expect(cue.fadeOutMs, 800);
    expect(cue.loop, isTrue);
  });

  test('修改全局参数后默认值更新且跟随标记保留', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);
    await notifier.addCue(uri: 'a.mp3', name: 'A');
    await notifier.updateShowDefaults(
      volume: 0.35,
      fadeInMs: 400,
      fadeOutMs: 700,
      loop: true,
    );

    final show = container.read(showProvider).value!.activeShow;
    expect(show.defaultVolume, 0.35);
    expect(show.defaultFadeInMs, 400);
    expect(show.defaultFadeOutMs, 700);
    expect(show.defaultLoop, isTrue);
    expect(show.cues.single.followGlobal, isTrue);
  });

  test('主题切换会更新全局取色并持久化', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 初始为深色。
    expect(currentThemeMode, CueBoxThemeMode.dark);

    // 切到玻璃：全局取色与 provider 状态同步更新。
    await container
        .read(themeModeProvider.notifier)
        .setMode(CueBoxThemeMode.glass);
    expect(currentThemeMode, CueBoxThemeMode.glass);
    expect(container.read(themeModeProvider), CueBoxThemeMode.glass);
    expect(CueBoxColors.background, isNot(CueBoxColors.backgroundTop));

    // 切回深色。
    await container
        .read(themeModeProvider.notifier)
        .setMode(CueBoxThemeMode.dark);
    expect(currentThemeMode, CueBoxThemeMode.dark);
    expect(container.read(themeModeProvider), CueBoxThemeMode.dark);

    // 持久化已写入 prefs。
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kThemeModePrefsKey), CueBoxThemeMode.dark.name);
  });

  test('restoreThemeMode 从本地恢复上次主题', () async {
    SharedPreferences.setMockInitialValues({
      kThemeModePrefsKey: CueBoxThemeMode.glass.name,
    });
    setCueBoxTheme(CueBoxThemeMode.dark);
    await restoreThemeMode();
    expect(currentThemeMode, CueBoxThemeMode.glass);
  });

  test('restoreThemeMode 把旧版明亮主题迁移为浅色', () async {
    SharedPreferences.setMockInitialValues({
      kThemeModePrefsKey: 'light',
    });
    setCueBoxTheme(CueBoxThemeMode.dark);
    await restoreThemeMode();
    expect(currentThemeMode, CueBoxThemeMode.glass);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kThemeModePrefsKey), CueBoxThemeMode.glass.name);
  });

  testWidgets('设置页展示两种主题并可切换', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();

    // 外观区块展示两种主题（明亮已并入浅色）。
    expect(find.text('深色'), findsOneWidget);
    expect(find.text('明亮'), findsNothing);
    expect(find.text('浅色'), findsOneWidget);

    // 点击切换为浅色。
    await tester.tap(find.text('浅色'));
    await tester.pumpAndSettle();
    expect(currentThemeMode, CueBoxThemeMode.glass);

    // 切换主题后仍停留在设置页（导航栈不被重置）。
    expect(find.text('设置'), findsOneWidget);
    expect(find.text('素材文件夹'), findsOneWidget);
  });

  testWidgets('状态栏图标亮度跟随主题（深色用浅色图标，玻璃用深色图标）', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    SystemUiOverlayStyle overlayStyleOf() {
      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.ancestor(
          of: find.byType(MaterialApp),
          matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        ).first,
      );
      return region.value;
    }

    // 深色主题：状态栏应为浅色图标（白色）。
    expect(overlayStyleOf().statusBarIconBrightness, Brightness.light);

    // 切到玻璃：状态栏改为深色图标（黑色）。
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container
        .read(themeModeProvider.notifier)
        .setMode(CueBoxThemeMode.glass);
    await tester.pumpAndSettle();
    expect(overlayStyleOf().statusBarIconBrightness, Brightness.dark);

    // 切回深色：恢复浅色图标。
    await container
        .read(themeModeProvider.notifier)
        .setMode(CueBoxThemeMode.dark);
    await tester.pumpAndSettle();
    expect(overlayStyleOf().statusBarIconBrightness, Brightness.light);
  });

  test('素材根目录支持添加多个并持久化', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 初始为空。
    final roots = await container.read(mediaRootProvider.future);
    expect(roots, isEmpty);

    // 直接写入持久化，模拟两个已选文件夹。
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'media.rootUris',
      '[{"uri":"content://tree/a","name":"演出A"},{"uri":"content://tree/b","name":"演出B"}]',
    );
    container.invalidate(mediaRootProvider);
    final restored = await container.read(mediaRootProvider.future);
    expect(restored.length, 2);
    expect(restored[0].name, '演出A');
    expect(restored[1].name, '演出B');
  });

  test('旧版单根目录数据自动迁移到多根格式', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('media.rootUri', 'content://tree/legacy');
    container.invalidate(mediaRootProvider);
    final roots = await container.read(mediaRootProvider.future);
    expect(roots.length, 1);
    expect(roots.first.uri, 'content://tree/legacy');
    // 迁移后旧键被移除、新键写入。
    expect(prefs.getString('media.rootUri'), isNull);
    expect(prefs.getString('media.rootUris'), contains('content://tree/legacy'));
  });

  test('最后导入目录可记忆与恢复', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // 模拟在 根A/子文件夹 导入过音频。
    final path = [
      MediaItem(uri: 'content://tree/a', name: '根A', isDirectory: true, size: 0, mime: ''),
      MediaItem(uri: 'content://tree/a/doc/1', name: '子文件夹', isDirectory: true, size: 0, mime: ''),
    ];
    await container.read(lastImportPathProvider.notifier).remember(path);

    final saved = await container.read(lastImportPathProvider.future);
    expect(saved.length, 2);
    expect(saved.first.name, '根A');
    expect(saved.last.name, '子文件夹');

    // 重建 container 后仍能恢复。
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('media.lastImportPath'), contains('子文件夹'));
  });
}
