/// WP5 (T9) — Workspace Channel 详情视图结构契约测试（I6）
///
/// 计划锚点（T9 GOTCHA / I6 不变量）：Workspace 的 Channel 视图**不提供
/// 聊天式输入框**（无 ChatInput / 聊天 Composer），只有发帖/评论入口；
/// 需要讨论的文案引导至 Group（General）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_detail_page.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/page/workspace/workspace_channel_detail_page.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, {Widget? detailEntry}) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: WorkspaceChannelDetailPage(
            channelId: '9002',
            detailEntry: detailEntry ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('频道详情视图无聊天式输入框（I6：不出现 ChatInput）', (tester) async {
    await pumpPage(tester);
    expect(find.byType(ChatInput), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('讨论引导文案存在并指向 Group（I6）', (tester) async {
    await pumpPage(tester);
    final guide = find.byKey(const ValueKey('workspace-channel-discuss-guide'));
    expect(guide, findsOneWidget);
    expect(find.textContaining('General'), findsWidgets);
  });

  testWidgets('内容区默认复用现有频道内容页（发帖/评论模型，非聊天页）', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final entry = defaultWorkspaceChannelDetailEntry('9002');
    expect(entry, isA<ChannelDetailPage>());
    expect((entry as ChannelDetailPage).channelId, '9002');
  });

  testWidgets('注入内容区正常渲染在引导横幅下方', (tester) async {
    await pumpPage(
      tester,
      detailEntry: const SizedBox(key: ValueKey('detail-entry-probe')),
    );
    expect(find.byKey(const ValueKey('detail-entry-probe')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('detail-entry-probe'))).dy,
      greaterThanOrEqualTo(
        tester
            .getBottomRight(
              find.byKey(const ValueKey('workspace-channel-discuss-guide')),
            )
            .dy,
      ),
      reason: '内容区不得叠在讨论引导横幅之上（紧贴其下方亦合规）',
    );
  });
}
