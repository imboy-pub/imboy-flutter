import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/extra_item.dart';

/// ExtraItem / ExtraItems 渲染 + 分组过滤契约测试
///
/// ExtraItem（TypeA 纯 StatelessWidget）：渲染 + 点击。
/// ExtraItems：build 期仅依赖 props（type/options）+ Theme + i18n；onPressed 回调
/// （openCallScreen / context.push / 各 handler）在 pump 期间不会触发，故重依赖
/// （location/webrtc）不进入执行路径，可在 host 层稳定渲染其分组/过滤逻辑。
void main() {
  // ccc47b60 scope 隔离后空 snapshot 使编译特性全部判 false；本组断言的
  // 语义是「远程缺省 → 按编译功能集合收口」，故注入编译全集开启基线。
  setUp(
    () => AppFeatureRegistry.replaceSnapshotForTest({
      for (final f in compiledProductFeatures) f: true,
    }),
  );
  tearDown(
    () => AppFeatureRegistry.replaceSnapshotForTest({
      for (final f in compiledProductFeatures) f: true,
    }),
  );
  Future<void> pump(
    WidgetTester tester, {
    required String title,
    VoidCallback? onPressed,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExtraItem(
            title: title,
            image: const Icon(Icons.image),
            onPressed: onPressed,
          ),
        ),
      ),
    );
  }

  testWidgets('渲染标题与图标不崩溃', (tester) async {
    await pump(tester, title: '相册', onPressed: () {});
    expect(find.text('相册'), findsOneWidget);
    expect(find.byIcon(Icons.image), findsOneWidget);
  });

  testWidgets('点击 → 触发 onPressed 回调', (tester) async {
    var tapped = false;
    await pump(tester, title: '拍摄', onPressed: () => tapped = true);
    // 2026-08-27 跟随 7c0f755e：入口由 InkWell 改为 GestureDetector
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pump();
    expect(tapped, isTrue);
  });

  Future<void> pumpItems(WidgetTester tester, {required String type}) async {
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: ExtraItems(
                type: type,
                options: const {
                  'to': '10001',
                  'title': '测试群',
                  'avatar': '',
                  'sign': '',
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<Set<String>> visiblePageTitles(WidgetTester tester) async {
    Set<String> titles() => tester
        .widgetList<ExtraItem>(find.byType(ExtraItem))
        .map((item) => item.title)
        .toSet();
    final result = titles();
    final pages = find.byType(PageView);
    if (pages.evaluate().isNotEmpty) {
      await tester.drag(pages.first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      result.addAll(titles());
    }
    return result;
  }

  void expectCompiledTool(Set<String> titles, String title, String feature) {
    expect(titles.contains(title), compiledProductFeatures.contains(feature));
  }

  for (final type in ['C2C', 'C2G']) {
    testWidgets('$type 保留基础媒体入口并隐藏旧表情占位', (tester) async {
      await pumpItems(tester, type: type);
      expect(find.text(t.main.album), findsOneWidget);
      expect(find.text(t.main.camera), findsOneWidget);
      expect(find.text(t.chat.file), findsOneWidget);
      final titles = await visiblePageTitles(tester);
      expect(titles, isNot(contains(t.common.expression)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('$type 通话和资金入口遵循编译能力', (tester) async {
      await pumpItems(tester, type: type);
      final titles = await visiblePageTitles(tester);
      expectCompiledTool(titles, t.common.redPacket, 'wallet');
      if (type == 'C2G') {
        expectCompiledTool(titles, t.common.groupCall, 'rtc');
        expect(titles, isNot(contains(t.common.voiceCall)));
        expect(titles, isNot(contains(t.common.videoCall)));
        expect(titles, isNot(contains(t.common.transfer)));
      } else {
        expectCompiledTool(titles, t.common.voiceCall, 'rtc');
        expectCompiledTool(titles, t.common.videoCall, 'rtc');
        expectCompiledTool(titles, t.common.transfer, 'wallet');
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('群协作工具裁剪后仍可在可用页面中找到', (tester) async {
    await pumpItems(tester, type: 'C2G');
    final titles = await visiblePageTitles(tester);
    expectCompiledTool(titles, t.groupVote.title, 'group_vote');
    expectCompiledTool(titles, t.groupSchedule.title, 'group_schedule');
    expectCompiledTool(titles, t.groupTask.title, 'group_task');
    expect(tester.takeException(), isNull);
  });

  testWidgets('单聊所有可用页面均不出现群协作工具', (tester) async {
    await pumpItems(tester, type: 'C2C');
    final titles = await visiblePageTitles(tester);
    for (final title in [
      t.groupVote.title,
      t.groupSchedule.title,
      t.groupTask.title,
      t.common.groupCall,
    ]) {
      expect(titles, isNot(contains(title)));
    }
    expect(tester.takeException(), isNull);
  });
}
