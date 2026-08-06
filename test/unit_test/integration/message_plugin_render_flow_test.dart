import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message.dart' show CustomMessageBuilder;
import 'package:imboy/config/const.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    hide CustomMessageBuilder;

class _LabelPlugin implements MessageTypePlugin {
  const _LabelPlugin({required this.type, required this.label});

  @override
  final String type;

  final String label;

  @override
  String get id => 'label:$type';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return Text(label);
  }
}

CustomMessage _createMessage({
  required String msgType,
  Map<String, dynamic>? metadata,
}) {
  return CustomMessage(
    id: 'msg-$msgType',
    authorId: 'test_author_id',
    createdAt: DateTime.now(),
    metadata: {'msg_type': msgType, ...?metadata},
  );
}

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

  group('message plugin render flow', () {
    testWidgets('text renders through injected registry', (tester) async {
      final registry = MessageTypeRegistry()
        ..register(
          const _LabelPlugin(type: MessageType.text, label: 'plugin:text'),
        )
        ..register(
          const _LabelPlugin(
            type: MessageType.unsupported,
            label: 'plugin:unsupported',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(
              type: 'C2C',
              message: _createMessage(
                msgType: MessageType.text,
                metadata: {'text': 'hello'},
              ),
              registry: registry,
            ),
          ),
        ),
      );

      expect(find.text('plugin:text'), findsOneWidget);
    });

    testWidgets('image renders through injected registry', (tester) async {
      final registry = MessageTypeRegistry()
        ..register(
          const _LabelPlugin(type: MessageType.image, label: 'plugin:image'),
        )
        ..register(
          const _LabelPlugin(
            type: MessageType.unsupported,
            label: 'plugin:unsupported',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(
              type: 'C2C',
              message: _createMessage(
                msgType: MessageType.image,
                metadata: {'uri': '', 'width': 100, 'height': 100},
              ),
              registry: registry,
            ),
          ),
        ),
      );

      expect(find.text('plugin:image'), findsOneWidget);
    });

    testWidgets('unknown types fall back through injected registry', (
      tester,
    ) async {
      final registry = MessageTypeRegistry()
        ..register(
          const _LabelPlugin(
            type: MessageType.unsupported,
            label: 'plugin:unsupported',
          ),
        );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CustomMessageBuilder(
              type: 'C2C',
              message: _createMessage(msgType: 'unknown_type'),
              registry: registry,
            ),
          ),
        ),
      );

      expect(find.text('plugin:unsupported'), findsOneWidget);
    });
  });
}
