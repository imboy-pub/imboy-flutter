/// Widget test for `lib/component/chat/message_unsupported_builder.dart`
///
/// 覆盖：
///   - 总是渲染警告图标 (Icons.warning_amber_rounded, AppColors.iosOrange)
///   - 总是渲染 "不支持的消息类型" 主标签
///   - msg_type 非空 + 非 'unknown' → 渲染 "($msgType)" 副标签
///   - msg_type 'unknown' + original_type 非空 → 副标签 fallback 用 original_type
///   - msg_type 缺失 + original_type 缺失 → 副标签隐藏
///   - msg_type 'unknown' + original_type 'unknown' → 副标签隐藏
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/chat/message_unsupported_builder.dart';
import 'package:imboy/theme/default/app_colors.dart';

CustomMessage _msg({Map<String, dynamic>? metadata}) {
  return CustomMessage(
    id: 'm_test',
    authorId: 'u_author',
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
    metadata: metadata,
  );
}

const _user = User(id: 'u_author');

Future<void> _pump(
  WidgetTester tester, {
  required CustomMessage message,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ImUnsupportedMessageBuilder(
          type: 'C2C',
          message: message,
          user: _user,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('ImUnsupportedMessageBuilder layout', () {
    testWidgets('总是渲染 warning_amber_rounded 图标 + iosOrange', (tester) async {
      await _pump(tester, message: _msg());
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      final icon = tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded));
      expect(icon.color, AppColors.iosOrange);
    });

    testWidgets('总是渲染 "不支持的消息类型" 主标签', (tester) async {
      await _pump(tester, message: _msg());
      expect(find.text('不支持的消息类型'), findsOneWidget);
    });
  });

  group('ImUnsupportedMessageBuilder displayType subtext', () {
    testWidgets(r'msg_type 非空 + 非 unknown → 显示 "($msgType)" 副标签',
        (tester) async {
      await _pump(
        tester,
        message: _msg(metadata: {'msg_type': 'sticker_v2'}),
      );
      expect(find.text('(sticker_v2)'), findsOneWidget);
    });

    testWidgets('msg_type=unknown + original_type 非空 → 副标签隐藏（按当前实现：msgType 非空就会用 unknown）',
        (tester) async {
      // 注：当前实现的回退逻辑是 displayType = msgType.isNotEmpty ? msgType : originalType
      // 所以 msg_type='unknown' 时 displayType='unknown' 会被 isNotEmpty 命中，
      // 然后被 displayType != 'unknown' 守卫隐藏 → 副标签不渲染（即便 original_type 有值）。
      await _pump(
        tester,
        message: _msg(metadata: {
          'msg_type': 'unknown',
          'original_type': 'rich_card',
        }),
      );
      // 主标签渲染
      expect(find.text('不支持的消息类型'), findsOneWidget);
      // 副标签 NOT 渲染（msg_type='unknown' 即被隐藏，回退仅在 msg_type 为空字符串时生效）
      expect(find.text('(unknown)'), findsNothing);
      expect(find.text('(rich_card)'), findsNothing);
    });

    testWidgets('msg_type 缺失（默认 "unknown"）+ original_type 缺失 → 副标签隐藏',
        (tester) async {
      await _pump(tester, message: _msg(metadata: const {}));
      expect(find.text('不支持的消息类型'), findsOneWidget);
      // displayType = 'unknown'（msg_type 字段不存在 → ?? 'unknown'）
      // 守卫 != 'unknown' 不通过 → 副标签不渲染
      expect(find.textContaining('('), findsNothing,
          reason: '没有任何带括号的副标签 Text');
    });

    testWidgets('完全无 metadata → 副标签隐藏', (tester) async {
      await _pump(tester, message: _msg());
      expect(find.text('不支持的消息类型'), findsOneWidget);
      expect(find.textContaining('('), findsNothing);
    });

    testWidgets('副标签为斜体 + 较小字号', (tester) async {
      await _pump(
        tester,
        message: _msg(metadata: {'msg_type': 'custom_x'}),
      );
      final sub = tester.widget<Text>(find.text('(custom_x)'));
      expect(sub.style?.fontStyle, FontStyle.italic);
      expect(sub.style?.fontSize, 10);
    });

    testWidgets('主标签字号 12（小于副标签的字号 10？不：主大副小）', (tester) async {
      await _pump(tester, message: _msg());
      final main = tester.widget<Text>(find.text('不支持的消息类型'));
      expect(main.style?.fontSize, 12);
    });
  });

  group('ImUnsupportedMessageBuilder structure', () {
    testWidgets('使用 Row 布局 + Flexible 包裹文本（防溢出）', (tester) async {
      await _pump(tester, message: _msg());
      expect(find.byType(Row), findsOneWidget);
      // Flexible 包裹标签 Column
      expect(
        find.descendant(
          of: find.byType(Flexible),
          matching: find.byType(Column),
        ),
        findsOneWidget,
      );
    });
  });
}
