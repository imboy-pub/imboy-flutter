import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/plugins/builtin/register_builtin_plugins.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/message_type_normalizer.dart';

class _FakeMessageTypePlugin implements MessageTypePlugin {
  const _FakeMessageTypePlugin({required this.type, this.isEnabled = true});

  @override
  final String type;

  @override
  String get id => 'fake:$type';

  @override
  final bool isEnabled;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return const SizedBox.shrink();
  }
}

void main() {
  group('MessageTypeRegistry', () {
    test('registers plugin by type', () {
      final registry = MessageTypeRegistry();
      const plugin = _FakeMessageTypePlugin(type: 'text');

      registry.register(plugin);

      expect(registry.resolve('text'), same(plugin));
    });

    test('rejects duplicate type registration', () {
      final registry = MessageTypeRegistry();

      registry.register(const _FakeMessageTypePlugin(type: 'text'));

      expect(
        () => registry.register(const _FakeMessageTypePlugin(type: 'text')),
        throwsStateError,
      );
    });

    test('resolves unknown type to fallback plugin', () {
      final registry = MessageTypeRegistry();
      const fallback = _FakeMessageTypePlugin(type: 'unsupported');

      registry.register(fallback);

      expect(registry.resolve('unknown-type'), same(fallback));
    });

    test('skips inactive plugin and falls back to unsupported', () {
      final registry = MessageTypeRegistry();
      const disabled = _FakeMessageTypePlugin(type: 'image', isEnabled: false);
      const fallback = _FakeMessageTypePlugin(type: 'unsupported');

      registry
        ..register(disabled)
        ..register(fallback);

      expect(registry.resolve('image'), same(fallback));
      expect(registry.activePlugins, isNot(contains(disabled)));
    });
  });

  // 「声明了类型但没注册渲染器」是本项目反复出现的缺陷形态：
  // MessageType.channelMessage 就曾以私有类型发出、全站无 builder，
  // 收发双方只看到「不支持的消息类型」。这条守门把未来的同类漂移变红。
  group('消息类型全覆盖（声明 → 归一 → 有 builder）', () {
    /// 刻意没有独立 builder 的类型及原因：
    /// - textStream：由 flutter_chat_ui 的 textStreamMessageBuilder 直接渲染，
    ///   不走 CustomMessageBuilder 插件链；
    /// - custom：只作控制帧载体（撤回/已读/输入中/reaction），不渲染气泡。
    const allowedWithoutPlugin = <String>{
      MessageType.textStream,
      MessageType.custom,
    };

    test('allTypes 里每个类型都能解析到已注册的渲染器', () {
      final registry = createBuiltinMessageTypeRegistry();

      for (final type in MessageType.allTypes) {
        if (allowedWithoutPlugin.contains(type)) continue;
        final canonical = MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: type,
        );
        expect(canonical, isNotEmpty, reason: '$type 被归一化器判为无效类型');
        expect(
          registry.contains(canonical),
          isTrue,
          reason: '$type 没有注册渲染器 → 界面会渲染成「不支持的消息类型」',
        );
      }
    });

    test('历史别名 channel_message 归一到频道卡片渲染器', () {
      // 旧版「频道消息分享到聊天」写出的私有类型；不进 allTypes（不可发送），
      // 但必须能渲染 —— 已落库的历史行与旧客户端产出都靠这条别名救回。
      expect(
        MessageType.allTypes,
        isNot(contains(MessageType.legacyChannelMessage)),
      );

      final canonical = MessageTypeNormalizer.renderType(
        effectiveMsgType: null,
        rawMsgType: MessageType.legacyChannelMessage,
      );
      expect(canonical, MessageType.channelCard);
      expect(createBuiltinMessageTypeRegistry().contains(canonical), isTrue);
    });

    test('真未知类型仍落 unsupported（别名不等于放开一切）', () {
      expect(
        MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: 'channel_message_v2',
        ),
        isEmpty,
      );
    });
  });
}
