import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message.dart';
import 'package:imboy/component/chat/message_history_bundle_builder.dart';
import 'package:imboy/component/chat/message_unsupported_builder.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/messaging/application/history_bundle/history_bundle_types.dart';
import 'package:imboy/plugins/builtin/register_builtin_plugins.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/message_type_normalizer.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helper/sqflite_test_helper.dart';

/// W3-I / chat_history_bundle_v1：类型注册 + COMP-01 旧客户端兼容 fixture。
///
/// COMP-01 证明：一个**不含** bundle 插件的 registry（旧客户端形态）对
/// `chat_history_bundle` 的 resolve 落到 unsupported fallback，气泡渲染
/// 「不支持的消息类型」而不是崩溃/空白——新类型消息在旧客户端安全降级。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('chat_history_bundle 类型注册', () {
    test('常量值与 HistoryBundleContract.msgType 冻结值一致', () {
      expect(MessageType.chatHistoryBundle, HistoryBundleContract.msgType);
      expect(MessageType.chatHistoryBundle, 'chat_history_bundle');
      expect(MessageType.allTypes, contains(MessageType.chatHistoryBundle));
    });

    test('MsgTypeEnum 双向映射', () {
      expect(MsgTypeEnum.chatHistoryBundle.value, 'chat_history_bundle');
      expect(
        MsgTypeEnumExtension.fromValue('chat_history_bundle'),
        MsgTypeEnum.chatHistoryBundle,
      );
    });

    test('归一化器把 chat_history_bundle 判为有效并原样保留', () {
      expect(
        MessageTypeNormalizer.normalize(
          msgType: 'chat_history_bundle',
          payload: {},
        ),
        'chat_history_bundle',
      );
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: 'chat_history_bundle',
        ),
        'chat_history_bundle',
      );
    });

    test('builtin registry 注册并解析到 bundle 插件', () {
      final registry = createBuiltinMessageTypeRegistry();

      expect(registry.contains(MessageType.chatHistoryBundle), isTrue);
      final plugin = registry.resolve(MessageType.chatHistoryBundle);
      expect(plugin, isA<ChatHistoryBundleMessageTypePlugin>());
      expect(plugin.type, MessageType.chatHistoryBundle);
      expect(plugin.isEnabled, isTrue);
    });
  });

  group('COMP-01 旧客户端 unsupported fallback fixture', () {
    // 仿 message_type_registry_test：模拟旧客户端 registry——
    // 只有 unsupported fallback，没有任何 bundle 插件注册。
    test('不含 bundle 插件的 registry resolve → unsupported fallback', () {
      final oldClientRegistry = MessageTypeRegistry()
        ..register(const UnsupportedMessageTypePlugin());

      expect(
        oldClientRegistry.contains(MessageType.chatHistoryBundle),
        isFalse,
      );
      final resolved = oldClientRegistry.resolve(MessageType.chatHistoryBundle);
      expect(resolved.type, MessageType.unsupported);
    });

    test('空 registry（连 fallback 都没有）resolve 抛 StateError 而非静默', () {
      final emptyRegistry = MessageTypeRegistry();

      expect(
        () => emptyRegistry.resolve(MessageType.chatHistoryBundle),
        throwsStateError,
      );
    });

    testWidgets('widget 层：旧 registry 下 bundle 消息渲染 unsupported 气泡', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await StorageService.init();
      await StorageService.to.setString(Keys.currentUid, 'user1');
      await StorageService.to.setString(
        Keys.currentUser,
        '{"uid": "user1", "nickname": "测试用户", "account": "", "email": "", '
        '"mobile": "", "avatar": "", "role": null, "gender": 0, "region": "", '
        '"sign": "", "setting": {}}',
      );
      await LocaleSettings.setLocale(AppLocale.zhCn);
      mockSqfliteSqlcipher();

      final oldClientRegistry = MessageTypeRegistry()
        ..register(const UnsupportedMessageTypePlugin());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(
              type: 'C2C',
              message: CustomMessage(
                id: 'bundle_old_client',
                authorId: 'user1',
                metadata: const <String, dynamic>{
                  'msg_type': MessageType.chatHistoryBundle,
                  'bundle_version': 1,
                  'entries': [
                    {
                      'msg_type': 'text',
                      'payload': {'text': 'hi'},
                    },
                  ],
                },
              ),
              registry: oldClientRegistry,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 旧客户端看到的是「不支持的消息类型」，不崩溃、不空白
      expect(find.text('不支持的消息类型'), findsOneWidget);
      expect(
        find.byKey(const Key('history_bundle_bubble_bundle_old_client')),
        findsNothing,
      );
    });
  });
}
