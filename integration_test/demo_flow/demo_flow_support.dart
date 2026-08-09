import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/conversation/widget/conversation_item.dart';

import '../flows/test_utils.dart';

bool isConversationList(WidgetTester tester) {
  return tester.any(
        find.byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == 'ConversationPage',
        ),
      ) ||
      (tester.any(find.byIcon(Icons.search)) &&
          tester.any(find.byIcon(Icons.add_circle_outline)));
}

Future<bool> openConversationTab(WidgetTester tester) async {
  if (isConversationList(tester)) return true;

  await tapAny(tester, [
    find.byKey(const Key('tab_conversations')),
    find.byIcon(Icons.chat_bubble),
    find.byIcon(Icons.chat_bubble_outline),
    find.text('消息'),
    find.text('会话'),
    find.text('Chats'),
  ]);

  for (int i = 0; i < 10; i++) {
    await settle(tester, maxSeconds: 1);
    if (isConversationList(tester)) return true;
  }
  return false;
}

Future<Finder?> waitForConversationType(
  WidgetTester tester,
  String type,
) async {
  for (int i = 0; i < 60; i++) {
    final finder = find.byWidgetPredicate(
      (widget) => widget is ConversationItem && widget.model.type == type,
    );
    if (tester.any(finder)) return finder;
    await tester.pump(const Duration(milliseconds: 500));
  }
  return null;
}

Future<void> dismissRecoveryGuideIfVisible(WidgetTester tester) async {
  for (int i = 0; i < 20; i++) {
    final later = find.byWidgetPredicate(
      (widget) =>
          widget is Text && ['稍后', 'Later'].contains(widget.data?.trim()),
    );
    if (tester.any(later)) {
      await safeTap(tester, later.first);
      await settle(tester, maxSeconds: 1);
      return;
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}
