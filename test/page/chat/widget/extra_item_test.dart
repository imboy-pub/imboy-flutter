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

  group('ExtraItems C2G (群聊)', () {
    testWidgets('渲染媒体/群协作/资金三个分区标题', (tester) async {
      // Arrange & Act
      await pumpItems(tester, type: 'C2G');

      // Assert
      expect(find.text(t.chat.extraPanelMedia), findsOneWidget);
      expect(find.text(t.chat.extraPanelCollab), findsOneWidget);
      expect(find.text(t.chat.extraPanelFunds), findsOneWidget);
    });

    testWidgets('出现投票/日程/任务三个群工具项（无需翻页）', (tester) async {
      // Arrange & Act
      await pumpItems(tester, type: 'C2G');

      // Assert
      expect(find.text(t.groupVote.title), findsOneWidget);
      expect(find.text(t.groupSchedule.title), findsOneWidget);
      expect(find.text(t.groupTask.title), findsOneWidget);
    });
  });

  group('ExtraItems C2C (单聊) 不串场群工具', () {
    testWidgets('不渲染"群协作"分区标题', (tester) async {
      // Arrange & Act
      await pumpItems(tester, type: 'C2C');

      // Assert
      expect(find.text(t.chat.extraPanelCollab), findsNothing);
    });

    testWidgets('不出现任何群工具项，但媒体/资金分区与单聊专属项仍在', (tester) async {
      // Arrange & Act
      await pumpItems(tester, type: 'C2C');

      // Assert：群工具项一律缺席
      expect(find.text(t.groupVote.title), findsNothing);
      expect(find.text(t.groupSchedule.title), findsNothing);
      expect(find.text(t.groupTask.title), findsNothing);

      // 通用分区仍在，单聊专属项（语音通话/转账）回归可见
      expect(find.text(t.chat.extraPanelMedia), findsOneWidget);
      expect(find.text(t.chat.extraPanelFunds), findsOneWidget);
      expect(find.text(t.common.voiceCall), findsOneWidget);
      expect(find.text(t.common.transfer), findsOneWidget);
    });
  });
}
