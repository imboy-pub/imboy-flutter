import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message_transfer_builder.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, 'test_author_id');
    await StorageService.to.setString(
      Keys.currentUser,
      '{"uid":"test_author_id","nickname":"测试账号","account":"","email":"","mobile":"","avatar":"","role":null,"gender":0,"region":"","sign":"","setting":{}}',
    );
  });

  CustomMessage createTransferMessage({Map<String, dynamic>? metadata}) {
    return CustomMessage(
      id: 'test_transfer_id',
      authorId: 'test_author_id',
      createdAt: DateTime.now(),
      metadata: {'msg_type': 'transfer', ...?metadata},
    );
  }

  Future<void> pumpTransfer(WidgetTester tester, CustomMessage message) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: MessageTransferBuilder(message: message)),
        ),
      ),
    );
  }

  group('MessageTransferBuilder amount 解析', () {
    testWidgets('String amount（旧版本回显）不抛异常且正确渲染', (WidgetTester tester) async {
      // 旧 APK 发送的转账 WS 回显 payload.amount 可能是 String '100'，
      // `as num?` 强转曾抛 TypeError → 被 CustomMessageBuilder catch 兜底
      // 渲染成「不支持的消息类型」。回归用例。
      final message = createTransferMessage(metadata: {'amount': '100'});

      await pumpTransfer(tester, message);

      expect(tester.takeException(), isNull);
      expect(find.text('￥1.00'), findsOneWidget);
    });

    testWidgets('int amount 正常渲染', (WidgetTester tester) async {
      final message = createTransferMessage(metadata: {'amount': 100});

      await pumpTransfer(tester, message);

      expect(tester.takeException(), isNull);
      expect(find.text('￥1.00'), findsOneWidget);
    });

    testWidgets('amount 缺失兜底渲染 ￥0.00', (WidgetTester tester) async {
      final message = createTransferMessage(metadata: {});

      await pumpTransfer(tester, message);

      expect(tester.takeException(), isNull);
      expect(find.text('￥0.00'), findsOneWidget);
    });

    testWidgets('status=accepted 显示已收文案', (WidgetTester tester) async {
      final message = createTransferMessage(
        metadata: {'amount': 100, 'status': 'accepted'},
      );

      await pumpTransfer(tester, message);

      expect(tester.takeException(), isNull);
      expect(find.text('￥1.00'), findsOneWidget);
    });
  });
}
