import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:cuebox/app.dart';
import 'package:cuebox/features/show/show_models.dart';
import 'package:cuebox/features/show/show_providers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('CueBox 骨架可以构建并显示主框架', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();
    expect(find.text('我的演出'), findsOneWidget);
    expect(find.text('还没有 Cue'), findsOneWidget);
    expect(find.text('GO'), findsOneWidget);
  });

  testWidgets('右上角菜单包含新建工程、素材库与设置', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    expect(find.text('新建 Cue 工程'), findsOneWidget);
    expect(find.text('新建 Cart 工程'), findsOneWidget);
    expect(find.text('素材库'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);

    await tester.tap(find.text('新建 Cart 工程'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '格块工程');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(find.text('格块还是空的'), findsOneWidget);
  });

  testWidgets('从菜单进入设置页', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('设置'));
    await tester.pumpAndSettle();
    expect(find.text('清空演出数据'), findsOneWidget);
    expect(find.text('关于'), findsOneWidget);
  });

  testWidgets('添加 Cue 后列表与 GO 按钮渲染', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    await container.read(showProvider.notifier).addCue(
          uri: 'file:///tmp/test.mp3',
          name: '测试音效',
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CueBoxApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('测试音效'), findsOneWidget);
    expect(find.text('GO'), findsOneWidget);
    expect(find.textContaining('即将触发'), findsNothing);
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
      UncontrolledProviderScope(
        container: container,
        child: const CueBoxApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 锁定：工具栏与 Cue 操作菜单隐藏。
    expect(find.text('列表循环'), findsNothing);
    expect(find.byTooltip('Cue 操作'), findsNothing);

    // 主菜单中提供解锁入口。
    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    expect(find.text('解锁工程'), findsOneWidget);

    await tester.tap(find.text('解锁工程'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('列表循环'), findsOneWidget);
  });

  testWidgets('新建 Cue 工程完整流程不抛异常', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: CueBoxApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('主菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('新建 Cue 工程'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '第三场');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('第三场'), findsOneWidget);
  });

  test('Cue 工程与 Cart 工程数据互相独立', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container.read(showProvider.future);
    final notifier = container.read(showProvider.notifier);

    await notifier.createShow(name: 'Cue 工程', kind: ShowKind.cue);
    await notifier.addCue(uri: 'a.mp3', name: 'Cue A');

    await notifier.createShow(name: 'Cart 工程', kind: ShowKind.cart);
    await notifier.addCartSlot(uri: 'b.mp3', name: 'Slot B');

    final lib = container.read(showProvider).value!;
    final cueShow = lib.shows.firstWhere((s) => s.name == 'Cue 工程');
    final cartShow = lib.shows.firstWhere((s) => s.name == 'Cart 工程');
    expect(cueShow.cues.length, 1);
    expect(cueShow.cartSlots, isEmpty);
    expect(cartShow.cartSlots.length, 1);
    expect(cartShow.cues, isEmpty);
  });

  test('旧数据中 Cue 与 Cart 混在一场时自动拆分为独立工程', () async {
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
}
