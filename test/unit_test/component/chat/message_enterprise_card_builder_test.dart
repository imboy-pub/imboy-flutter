/// V3-23 — 企业应用代发卡片（链接卡片 / 业务操作卡片）渲染与来源标识测试。
///
/// 覆盖 matrix spec §5 落点 D1/D2/D4 的验收面：
/// 1. wire 类型 `link_card` / `business_action_card` 有效、注册表有渲染器
///    （spec §5 D1/D2）；
/// 2. 合法 payload 成功渲染；畸形 payload 安全降级（不崩溃、不猜测）；
/// 3. 企业托管 origin 三态（application / human / unrecognized）叠加在新卡片
///    消息上的标识展示——与「Human 直发零装饰」可区分（spec §5 D4：判定
///    复用 enterprise_message_origin，不回落 humanDirect）。
library;

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/chat/message_business_action_card_builder.dart';
import 'package:imboy/component/chat/message_link_card_builder.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/public.dart';
import 'package:imboy/plugins/builtin/register_builtin_plugins.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';
import 'package:imboy/service/message_type_normalizer.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

/// 经 plugin 链构建消息（与消息列表同一条渲染入口）。
Widget pluginHost(MessageTypePlugin plugin, CustomMessage message) =>
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => plugin.build(
            message,
            MessageRenderContext(
              context: context,
              type: plugin.type,
              user: const User(id: 'me'),
              isSentByMe: false,
              bubbleWrapper: (child) => child,
            ),
          ),
        ),
      ),
    );

CustomMessage cardMessage(
  String type,
  Map<String, dynamic> payload, {
  String authorId = 'me',
}) => CustomMessage(id: 'msg_$type', authorId: authorId, metadata: payload);

/// 一个自洽的企业托管 origin（后端 `enterprise_message_logic:origin/3` 形状）。
Map<String, dynamic> hostedOrigin(
  String senderKind, {
  String senderUserId = '',
}) => <String, dynamic>{
  'kind': EnterpriseMessageOrigin.wireKind,
  'application_id': '7001',
  'sender_kind': senderKind,
  if (senderUserId.isNotEmpty) 'sender_user_id': senderUserId,
};

Map<String, dynamic> linkPayload() => <String, dynamic>{
  'title': '季度报表',
  'url': 'https://oa.example.com/report/q4',
  'description': '第四季度经营数据',
};

Map<String, dynamic> actionPayload({bool withUrl = true}) => <String, dynamic>{
  'title': '审批采购单',
  'action_type': 'purchase.approve',
  if (withUrl) 'url': 'https://oa.example.com/approve/42',
  'description': '请审批 11 月采购单',
  'action_params': <String, dynamic>{'order_id': '42'},
};

void main() {
  group('wire 类型：声明 → 归一 → 有渲染器（spec §5 D1/D2）', () {
    test('link_card / business_action_card 是有效类型且有渲染器', () {
      expect(MessageType.linkCard, 'link_card');
      expect(MessageType.businessActionCard, 'business_action_card');
      expect(MessageType.allTypes, contains(MessageType.linkCard));
      expect(MessageType.allTypes, contains(MessageType.businessActionCard));
      for (final String type in <String>[
        MessageType.linkCard,
        MessageType.businessActionCard,
      ]) {
        expect(
          MessageTypeNormalizer.normalize(msgType: type, payload: {}),
          type,
          reason: '$type 被归一化器判为无效类型',
        );
        expect(
          createBuiltinMessageTypeRegistry().contains(type),
          isTrue,
          reason: '$type 没有注册渲染器 → 界面会渲染成「不支持的消息类型」',
        );
      }
    });
  });

  group('链接卡片渲染（spec §5 D2）', () {
    testWidgets('合法 payload：渲染标题/摘要/host/打开链接', (tester) async {
      await tester.pumpWidget(
        pluginHost(
          const _LinkCardPlugin(),
          cardMessage(MessageType.linkCard, linkPayload()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('季度报表'), findsOneWidget);
      expect(find.text('第四季度经营数据'), findsOneWidget);
      expect(find.text('oa.example.com'), findsOneWidget);
      expect(find.text(t.enterpriseApp.cardLinkOpen), findsOneWidget);
    });

    testWidgets('畸形 payload：缺标题 → 降级占位，不崩溃', (tester) async {
      await tester.pumpWidget(
        pluginHost(
          const _LinkCardPlugin(),
          cardMessage(MessageType.linkCard, <String, dynamic>{
            'url': 'https://oa.example.com/x',
          }),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.enterpriseApp.cardPayloadInvalid), findsOneWidget);
    });

    testWidgets('畸形 payload：javascript: 协议 / 缺 host → 降级占位', (tester) async {
      for (final Map<String, dynamic> bad in <Map<String, dynamic>>[
        <String, dynamic>{'title': 'x', 'url': 'javascript:alert(1)'},
        <String, dynamic>{'title': 'x', 'url': 'https://'},
        <String, dynamic>{'title': 'x', 'url': 'https://${'a' * 2100}'},
        <String, dynamic>{'title': 'x'}, // 缺 url
      ]) {
        await tester.pumpWidget(
          pluginHost(
            const _LinkCardPlugin(),
            cardMessage(MessageType.linkCard, bad),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(t.enterpriseApp.cardPayloadInvalid), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });

    testWidgets('message 为 null（渲染上下文异常）→ 降级占位不崩溃', (tester) async {
      await tester.pumpWidget(
        host(const LinkCardMessageBuilder(user: User(id: 'me'), message: null)),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.enterpriseApp.cardPayloadInvalid), findsOneWidget);
    });
  });

  group('业务操作卡片渲染（spec §5 D2；跳转依赖登记）', () {
    testWidgets('合法 payload（带 url）：渲染标题/动作类型/执行操作', (tester) async {
      await tester.pumpWidget(
        pluginHost(
          const _ActionCardPlugin(),
          cardMessage(MessageType.businessActionCard, actionPayload()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('审批采购单'), findsOneWidget);
      expect(find.text('purchase.approve'), findsOneWidget);
      expect(find.text(t.enterpriseApp.cardActionBadge), findsOneWidget);
      expect(find.text(t.enterpriseApp.cardActionOpen), findsOneWidget);
    });

    testWidgets('合法 payload（无 url）：按钮提示暂无可执行操作（不伪造跳转）', (tester) async {
      await tester.pumpWidget(
        pluginHost(
          const _ActionCardPlugin(),
          cardMessage(
            MessageType.businessActionCard,
            actionPayload(withUrl: false),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.enterpriseApp.cardActionUnavailable), findsOneWidget);
      expect(find.text(t.enterpriseApp.cardActionOpen), findsNothing);
    });

    testWidgets('畸形 payload：缺 action_type / url 非法 / params 非 Map → 降级', (
      tester,
    ) async {
      for (final Map<String, dynamic> bad in <Map<String, dynamic>>[
        <String, dynamic>{'title': 'x'}, // 缺 action_type
        <String, dynamic>{'action_type': 'a.b'}, // 缺 title
        <String, dynamic>{
          'title': 'x',
          'action_type': 'a.b',
          'url': 'ftp://example.com/f',
        }, // url 协议非法
        <String, dynamic>{
          'title': 'x',
          'action_type': 'a.b',
          'action_params': 'not-a-map',
        }, // params 非 Map
      ]) {
        await tester.pumpWidget(
          pluginHost(
            const _ActionCardPlugin(),
            cardMessage(MessageType.businessActionCard, bad),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(t.enterpriseApp.cardPayloadInvalid), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });

  group('企业托管三态 × 新卡片消息的标识展示（spec §5 D4）', () {
    Future<void> pumpDecorated(
      WidgetTester tester, {
      required Map<String, dynamic>? origin,
    }) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) =>
                HostedMessageBubbleDecoration.decorate(
                  context: context,
                  metadata: <String, dynamic>{
                    ...linkPayload(),
                    'origin': ?origin,
                  },
                  child: _LinkCardPlugin().build(
                    cardMessage(MessageType.linkCard, linkPayload()),
                    MessageRenderContext(
                      context: context,
                      type: MessageType.linkCard,
                      user: const User(id: 'me'),
                      isSentByMe: false,
                      bubbleWrapper: (child) => child,
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('application 代发：「应用代发」徽标 + 非 E2EE 标记 + 卡片内容', (tester) async {
      await pumpDecorated(tester, origin: hostedOrigin('application'));
      expect(find.text(t.enterpriseApp.badgeAppDelegated), findsOneWidget);
      expect(find.text(t.enterpriseApp.badgeHumanDelegated), findsNothing);
      expect(find.text(t.enterpriseOa.markerNoE2ee), findsOneWidget);
      expect(find.text('季度报表'), findsOneWidget);
    });

    testWidgets('human 经应用：不同文案徽标 + 非 E2EE 标记 + 卡片内容', (tester) async {
      await pumpDecorated(
        tester,
        origin: hostedOrigin('human', senderUserId: '9001'),
      );
      expect(find.text(t.enterpriseApp.badgeHumanDelegated), findsOneWidget);
      expect(find.text(t.enterpriseApp.badgeAppDelegated), findsNothing);
      expect(find.text(t.enterpriseOa.markerNoE2ee), findsOneWidget);
      expect(find.text('季度报表'), findsOneWidget);
    });

    testWidgets('origin 不可识别：fail-closed 提示，不回落 humanDirect', (tester) async {
      await pumpDecorated(
        tester,
        origin: <String, dynamic>{
          'kind': 'some_other_kind',
          'application_id': '7001',
        },
      );
      expect(find.text(t.enterpriseApp.originMismatchTitle), findsOneWidget);
      // 不得回落成普通 Human 消息（零装饰）——不可识别必须可见。
      expect(find.text(t.enterpriseOa.markerNoE2ee), findsOneWidget);
      expect(find.text('季度报表'), findsOneWidget);
    });

    testWidgets('无 origin（Human 直发）：零额外装饰，卡片内容原样', (tester) async {
      await pumpDecorated(tester, origin: null);
      expect(find.text(t.enterpriseApp.badgeAppDelegated), findsNothing);
      expect(find.text(t.enterpriseApp.badgeHumanDelegated), findsNothing);
      expect(find.text(t.enterpriseOa.markerNoE2ee), findsNothing);
      expect(find.text('季度报表'), findsOneWidget);
    });
  });
}

/// 测试用的 plugin 壳（复用注册表里的真实 build 实现）。
class _LinkCardPlugin implements MessageTypePlugin {
  const _LinkCardPlugin();

  @override
  String get id => 'test:${MessageType.linkCard}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.linkCard;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) =>
      LinkCardMessageBuilder(message: message, user: context.user);
}

class _ActionCardPlugin implements MessageTypePlugin {
  const _ActionCardPlugin();

  @override
  String get id => 'test:${MessageType.businessActionCard}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.businessActionCard;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) =>
      BusinessActionCardMessageBuilder(message: message, user: context.user);
}
