import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/extra_item.dart';

/// ExtraItem / ExtraItems 渲染 + 分组过滤契约测试
///
/// ExtraItem（TypeA 纯 StatelessWidget）：渲染 + 点击。
/// ExtraItems：build 期仅依赖 props（type/options）+ Theme + i18n；onPressed 回调
/// （openCallScreen / context.push / 各 handler）在 pump 期间不会触发，故重依赖
/// （location/webrtc）不进入执行路径，可在 host 层稳定渲染其分组/过滤逻辑。
void main() {
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
    await tester.tap(find.byType(InkWell));
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

  /// 翻到附加面板第 2 页。
  ///
  /// 面板已从「分区标题 + 长列表」重构为 CarouselSlider 分页，只构建当前页，
  /// 所以第 2 页的项在首帧 find 不到，必须先滑动。
  Future<void> swipeToPage2(WidgetTester tester) async {
    await tester.drag(find.byType(PageView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();
  }

  group('ExtraItems C2G (群聊)', () {
    testWidgets('第 1 页是通用项 + 群通话', (tester) async {
      await pumpItems(tester, type: 'C2G');

      expect(find.text(t.main.album), findsOneWidget);
      expect(find.text(t.common.groupCall), findsOneWidget);
      // 单聊专属项不串场
      expect(find.text(t.common.transfer), findsNothing);
    });

    testWidgets('群协作三项（投票/日程/作业）在第 2 页', (tester) async {
      await pumpItems(tester, type: 'C2G');

      // ⚠️ 这三项曾要求"无需翻页"（见 git 历史里的旧用例名）。面板改成分页
      // 轮播后它们被挤到第 2 页，群聊最核心的协作入口现在要滑一下才看得见。
      // 这是待产品确认的 UX 退化，不是测试问题——此处先钉住现状。
      expect(find.text(t.groupVote.title), findsNothing, reason: '当前在第 1 页');

      await swipeToPage2(tester);

      expect(find.text(t.groupVote.title), findsOneWidget);
      expect(find.text(t.groupSchedule.title), findsOneWidget);
      expect(find.text(t.groupTask.title), findsOneWidget);
    });
  });

  group('ExtraItems C2C (单聊) 不串场群工具', () {
    testWidgets('两页都不出现任何群工具项', (tester) async {
      await pumpItems(tester, type: 'C2C');

      void expectNoGroupTools() {
        expect(find.text(t.groupVote.title), findsNothing);
        expect(find.text(t.groupSchedule.title), findsNothing);
        expect(find.text(t.groupTask.title), findsNothing);
        expect(find.text(t.common.groupCall), findsNothing);
      }

      expectNoGroupTools();
      await swipeToPage2(tester);
      expectNoGroupTools();
    });

    testWidgets('单聊专属项：语音通话在第 1 页，视频通话/转账在第 2 页', (tester) async {
      await pumpItems(tester, type: 'C2C');

      expect(find.text(t.common.voiceCall), findsOneWidget);

      await swipeToPage2(tester);

      expect(find.text(t.common.videoCall), findsOneWidget);
      expect(find.text(t.common.transfer), findsOneWidget);
    });
  });
}
