/// Reaction 按钮触达区域回归保护测试（DESIGN.md §13.2 Hard Rule 1）
///
/// L-fix-1：审计发现 `MessageActionMenu` 中的 6 个 emoji Reaction 按钮原触达
/// 仅约 36×36pt（emoji fontSize:20 + padding:8），不达 iOS HIG 44×44pt 硬指标。
/// 修复：在 `GestureDetector` 内层包 `ConstrainedBox(minWidth/minHeight: 44)`,
/// 视觉气泡保持紧凑外观，仅扩展 hit area。
///
/// 本测试通过 `tester.getSize(finder)` 钉死每个 Reaction 按钮的渲染尺寸 ≥44pt,
/// 防止未来缩水。
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/message_action_menu.dart';

void main() {
  // DESIGN.md §13.2 Hard Rule 1 / iOS HIG: 最小可触区域 44×44pt
  const double minTouchTarget = 44.0;

  // 与 _buildReactionSection 内部硬列表保持同步
  const reactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  TextMessage buildMessage() {
    return TextMessage(
      authorId: 'u_me',
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      id: 'm_test',
      text: 'hi',
    );
  }

  Future<void> pumpMenu(WidgetTester tester) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: MessageActionMenu(
                  message: buildMessage(),
                  isSentByMe: true,
                  onReply: () {},
                  onCopy: () {},
                  onEdit: () {},
                  onDelete: () {},
                  onForward: () {},
                  onReaction: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('MessageActionMenu Reaction 按钮触达区域', () {
    testWidgets('每个 Reaction emoji 按钮触达 ≥ 44×44pt', (tester) async {
      await pumpMenu(tester);

      for (final emoji in reactions) {
        final finder = find.byKey(ValueKey<String>('reaction_$emoji'));
        expect(
          finder,
          findsOneWidget,
          reason: 'Reaction "$emoji" 节点未找到（key 应为 reaction_$emoji）',
        );
        final size = tester.getSize(finder);
        expect(
          size.width,
          greaterThanOrEqualTo(minTouchTarget),
          reason:
              'Reaction "$emoji" 触达宽度 ${size.width}pt < 44pt（DESIGN.md §13.2）',
        );
        expect(
          size.height,
          greaterThanOrEqualTo(minTouchTarget),
          reason:
              'Reaction "$emoji" 触达高度 ${size.height}pt < 44pt（DESIGN.md §13.2）',
        );
      }
    });

    testWidgets('Reaction 区域共渲染 6 个 emoji 按钮', (tester) async {
      await pumpMenu(tester);
      // 共 6 个 emoji（与 reactions 列表长度一致）
      for (final emoji in reactions) {
        expect(find.text(emoji), findsOneWidget);
      }
    });
  });
}
