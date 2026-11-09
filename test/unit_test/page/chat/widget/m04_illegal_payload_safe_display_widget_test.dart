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

  // PRODUCT_DEFECT-M04-APP-01：text 消息 payload['text'] 为非字符串
  // （如 {'text': 12345} / {'text': {...}}）时，mapper 走
  // `(payloadData['text'] ?? '') as String` 硬转型 → TypeError 直接抛出，
  // 「[无效消息]」降级分支接不住（降级只覆盖 payload 整体非 Map/String
  // 的情形）。期望修复规则：非法 text 字段也应安全降级为
  // t.chat.invalidMessagePlaceholder（或 toString 兜底），不应让
  // toTypeMessage 抛异常。修复后去掉 skip 即可转正。
  testWidgets(
    'PRODUCT_DEFECT-M04-APP-01 复现：text 字段非字符串 → 期望「[无效消息]」降级'
    '（当前：TypeError 未降级，skip 待修复）',
    (tester) async {
      final model = MessageModel(
        'm-m04-text-field-int',
        autoId: 3,
        type: 'C2C',
        status: IMBoyMessageStatus.delivered,
        // 作者=当前用户：隔离缺陷本体（text 字段硬转型），避免联系人分支
        // 在测试环境引发 DB/网络旁路
        fromId: 100,
        toId: 200,
        payload: {'text': 12345},
        isAuthor: 1,
        conversationUk3: 'C2C_100_200',
        msgType: 'text',
      );

      final message = await model.toTypeMessage();
      // 期望（修复后）：TextMessage 且 text == '[无效消息]'（或原文安全 toString）
      expect(message, isA<TextMessage>());
      final text = message as TextMessage;
      expect(text.text, isNot(contains('12345')));
      expect(find.textContaining('12345'), findsNothing);
    },
    skip: true, // PRODUCT_DEFECT-M04-APP-01：非法 text 字段硬转型崩溃，待修复后转正
  );
}
