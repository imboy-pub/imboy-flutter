/// M04 内容完整性 App 腿补测（IMBOY_AUTOTEST_V2.1 / AT04）— 断言 4
///
/// 非法 payload 消息的安全降级展示：恶意/损坏的载荷（非 Map/非 String、
/// 未知 msg_type）不得把原始字节渲染上屏，也不得让渲染链路崩溃，
/// 必须落「[无效消息] / 不支持的消息类型」占位。
///
/// 覆盖链路：MessageModel.toTypeMessage()（mapper 真实转换）→ UI 渲染
/// （ImUnsupportedMessageBuilder 真实组件）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show CustomMessage, MessageStatus, TextMessage, User;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message_unsupported_builder.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helper/sqflite_test_helper.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // 作者=当前用户：避免 toTypeMessage 联系人分支走 autoFetch 网络同步
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '100',
      Keys.currentUser: '{"uid": "100", "nickname": "测试用户", "account": "", "email": "", "mobile": "", "avatar": "", "role": null, "gender": 0, "region": "", "sign": "", "setting": {}}',
    });
    await StorageService.init();
  });

  setUp(() => mockSqfliteSqlcipher());

  testWidgets('payload 为非法标量（int）→ 降级「[无效消息]」占位，原始载荷不上屏', (tester) async {
    final model = MessageModel(
      'm-m04-invalid-payload',
      autoId: 1,
      type: 'C2C',
      status: IMBoyMessageStatus.delivered,
      fromId: 200,
      toId: 100,
      // 非法：payload 既不是 Map 也不是 String（伪造/损坏行）
      payload: 987654321,
      isAuthor: 0,
      conversationUk3: 'C2C_100_200',
      msgType: 'text',
    );

    final message = await model.toTypeMessage();
    expect(message, isA<TextMessage>());
    final text = message as TextMessage;
    // 安全降级：占位文案 + error 状态 + 结构化错误标记
    expect(text.text, t.chat.invalidMessagePlaceholder);
    expect(text.status, MessageStatus.error);
    expect(text.metadata?['error'], 'invalid_payload');
    expect(text.text, isNot(contains('987654321')));

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(home: Scaffold(body: Text(text.text))),
      ),
    );
    await tester.pump();

    // UI 呈现占位，不呈现原始载荷
    expect(find.text(t.chat.invalidMessagePlaceholder), findsOneWidget);
    expect(find.textContaining('987654321'), findsNothing);
  });

  testWidgets('未知 msg_type → unsupported 降级卡片，payload 正文不上屏', (tester) async {
    final model = MessageModel(
      'm-m04-unknown-type',
      autoId: 2,
      type: 'C2C',
      status: IMBoyMessageStatus.delivered,
      // 作者=当前用户（100）：跳过联系人查询，避免测试环境触发网络同步
      fromId: 100,
      toId: 200,
      payload: {'text': 'top secret body', 'extra': 'leak-me-not'},
      isAuthor: 1,
      conversationUk3: 'C2C_100_200',
      // 未知类型：客户端没有对应 builder，也不在归一化白名单
      msgType: 'mysterious_widget',
    );

    final message = await model.toTypeMessage();
    expect(message, isA<CustomMessage>());
    final custom = message as CustomMessage;
    expect(custom.metadata?['unsupported'], true);
    expect(custom.metadata?['error'], 'unknown_msg_type');
    // 归一化器把未知类型折叠为 'unsupported'；原始名保留在 msg_type
    // （unsupported builder 副标签用它渲染「(mysterious_widget)」）
    expect(custom.metadata?['original_type'], 'unsupported');
    expect(custom.metadata?['msg_type'], 'mysterious_widget');

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ImUnsupportedMessageBuilder(
                type: 'C2C',
                message: custom,
                user: const User(id: '100'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 安全降级卡片：类型占位 + 原始 msg_type 副标签；正文/附加字段不上屏
    expect(find.text(t.chat.unsupportedMessageType), findsOneWidget);
    expect(find.textContaining('mysterious_widget'), findsWidgets);
    expect(find.textContaining('top secret'), findsNothing);
    expect(find.textContaining('leak-me-not'), findsNothing);
  });

  // PRODUCT_DEFECT-M04-APP-01：非法 text 字段也应走现有 invalid_payload
  // 占位分支，不能强制转型崩溃，也不能把对象 toString 后展示。
  for (final msgType in ['text', 'textStream']) {
    for (final entry in <String, Object>{
      'int': 12345,
      'Map': {'nested': '12345'},
      'List': ['12345'],
      'bool': true,
    }.entries) {
      testWidgets(
        'PRODUCT_DEFECT-M04-APP-01 $msgType 正文为 ${entry.key} → 无效消息占位且原文不上屏',
        (tester) async {
          final model = _textModel(msgType, payload: {'text': entry.value});
          final message = await model.toTypeMessage();
          expect(message, isA<TextMessage>());
          final text = message as TextMessage;
          expect(text.text, t.chat.invalidMessagePlaceholder);
          expect(text.status, MessageStatus.error);
          expect(text.metadata?['error'], 'invalid_payload');
          expect(text.metadata?.containsKey('text'), isFalse);
          expect(text.text, isNot(contains('12345')));

          await _pumpText(tester, text);
          expect(find.text(t.chat.invalidMessagePlaceholder), findsOneWidget);
          expect(find.textContaining('12345'), findsNothing);
          expect(find.textContaining('nested'), findsNothing);
          expect(find.text('true'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final entry in <String, Map<String, dynamic>>{
      'String': {'text': '正常正文 12345'},
      'null': {'text': null},
      'missing': {},
    }.entries) {
      testWidgets('$msgType 正文为 ${entry.key} → 保留既有正常/空串语义', (tester) async {
        final model = _textModel(msgType, payload: entry.value);
        final message = await model.toTypeMessage();
        expect(message, isA<TextMessage>());
        final text = message as TextMessage;
        final expectedText = entry.value['text'] as String? ?? '';
        expect(text.text, expectedText);
        expect(text.status, MessageStatus.delivered);
        expect(text.metadata?['error'], isNull);
        if (msgType == 'textStream') {
          expect(text.metadata?['index'], 0);
          expect(text.metadata?['is_end'], false);
        }

        await _pumpText(tester, text);
        expect(find.text(expectedText), findsOneWidget);
        expect(find.text(t.chat.invalidMessagePlaceholder), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$msgType 已撤回消息保持撤回优先级，不改为无效正文', (tester) async {
      final model = _textModel(
        msgType,
        payload: {'text': 12345},
        status: IMBoyMessageStatus.peerRevoked,
      );
      final message = await model.toTypeMessage();
      expect(message, isA<CustomMessage>());
      expect(message.metadata?['status'], IMBoyMessageStatus.peerRevoked);
      expect(message.metadata?['error'], isNull);
    });
  }
}

MessageModel _textModel(
  String msgType, {
  required Map<String, dynamic> payload,
  int status = IMBoyMessageStatus.delivered,
}) => MessageModel(
  'm-m04-$msgType',
  autoId: 3,
  type: 'C2C',
  status: status,
  // 作者=当前用户：避免联系人查询引发 DB/网络旁路。
  fromId: 100,
  toId: 200,
  payload: payload,
  isAuthor: 1,
  conversationUk3: 'C2C_100_200',
  msgType: msgType,
);

Future<void> _pumpText(WidgetTester tester, TextMessage message) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: MaterialApp(home: Scaffold(body: Text(message.text))),
    ),
  );
  await tester.pump();
}
