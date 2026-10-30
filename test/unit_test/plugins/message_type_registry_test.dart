import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/plugins/builtin/register_builtin_plugins.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/plugins/registry/message_type_registry.dart';
import 'package:imboy/service/message_actions.dart';
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

    // 线上实测集合（2026-10-30 生产 imboy_pro 的 msg_c2c/msg_c2g 全量 distinct）：
    // 把「真实下发过的类型」单独钉一遍，防止有人从 allTypes 里删掉某个看起来
    // 没人用的类型，导致存量消息第二天集体变成「不支持」。
    test('线上实测出现过的 msg_type 全部可渲染', () {
      const seenInProduction = <String>[
        'text',
        'image',
        'voice',
        'video',
        'file',
        'location',
        'quote',
        'expression',
        'redPacket',
        'transfer',
        'visitCard',
        'channel_card',
        'channel_message', // 历史脏值，靠别名救回
        'groupSchedule',
        'groupTask',
        'groupVote',
      ];
      final registry = createBuiltinMessageTypeRegistry();

      for (final type in seenInProduction) {
        final canonical = MessageTypeNormalizer.renderType(
          effectiveMsgType: null,
          rawMsgType: type,
        );
        expect(canonical, isNotEmpty, reason: '线上类型 $type 被判为无效');
        expect(
          registry.contains(canonical),
          isTrue,
          reason: '线上类型 $type 没有渲染器 → 存量消息会显示「不支持」',
        );
      }
    });
  });

  // 服务端把某个值写进 action，就等于把这条消息交给客户端的 action 分发。
  // 分发集合之外的 action 必须由调用方降级成普通消息，绝不能静默丢弃——
  // 历史事故：转发消息写了 action=forward，default 分支只打日志就 return true，
  // 整条消息不落库不渲染，收发双方都以为转发失败。
  group('action 分发集合', () {
    test('控制类 action 均已实现', () {
      for (final action in <String>[
        C2SAction.messageRead,
        C2SAction.messageReadAck,
        C2SAction.messageRevoke,
        C2SAction.messageRevokeAck,
        C2SAction.messageEdit,
        C2SAction.messageEditAck,
        C2SAction.messageInput,
        C2SAction.messageReaction,
        C2SAction.e2eeRoomKey,
      ]) {
        expect(
          MessageActions.handlesAction(action),
          isTrue,
          reason: '$action 已实现却没进 knownActions → 会被降级成普通消息',
        );
      }
    });

    test('服务端写出的非控制 action 不被误判为已实现', () {
      // forward/message_revoke_error 由服务端写入但客户端没有对应分发。
      // 未知 action 按既定设计忽略并回 ACK（见 inbound_ack_ordering_test），
      // 所以这里只能保证「不误判」，真正的防线在服务端：内容消息不许写 action。
      expect(MessageActions.handlesAction('forward'), isFalse);
      expect(MessageActions.handlesAction('message_revoke_error'), isFalse);
      expect(MessageActions.handlesAction('message_edit_error'), isFalse);
    });

    test('内容类型识别用于暴露 action/msg_type 冲突', () {
      // 服务端把内容类型同时写进 msg_type 和未实现的 action ⇒ 消息被吞。
      // 该组合一定是服务端缺陷，客户端至少要能在日志里指出来。
      expect(MessageActions.isContentMsgType(MessageType.text), isTrue);
      expect(MessageActions.isContentMsgType(MessageType.image), isTrue);
      // custom 是控制帧载体；forward 属于「类型未注册」，都不是内容冲突
      expect(MessageActions.isContentMsgType(MessageType.custom), isFalse);
      expect(MessageActions.isContentMsgType('forward'), isFalse);
      expect(MessageActions.isContentMsgType(''), isFalse);
    });
  });
}
