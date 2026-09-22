/// FULL-05 — Application 消息来源的展示面测试（能力项 1 的 UI 证据）。
///
/// 钉住三件事：
/// 1. 会话气泡对「Application 代发 / 人工经应用 / Human 直发」三者渲染**不同**
///    （代发两类展示不同徽标文案；Human 直发零额外装饰）；
/// 2. 企业托管消息**必然**出现非 E2EE 标记，且**不出现** Human-Human 的加密标识；
/// 3. 详情/审计面（[hostedMessageAuditLines]）逐条保留代发与非 E2EE 事实。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/public.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

Map<String, dynamic> originOf(String senderKind, {String senderUserId = ''}) =>
    <String, dynamic>{
      'kind': EnterpriseMessageOrigin.wireKind,
      'application_id': '7001',
      'sender_kind': senderKind,
      if (senderUserId.isNotEmpty) 'sender_user_id': senderUserId,
    };

void main() {
  group('气泡装饰：三类来源可区分', () {
    testWidgets('Application 代发：出现「应用代发」徽标 + 非 E2EE 标记', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) =>
                HostedMessageBubbleDecoration.decorate(
                  context: context,
                  metadata: <String, dynamic>{
                    'origin': originOf('application'),
                  },
                  child: const Text('正文'),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.enterpriseApp.badgeAppDelegated), findsOneWidget);
      expect(find.text(t.enterpriseApp.badgeHumanDelegated), findsNothing);
      // 企业托管恒非 E2EE → 标记必须在（这是「不得伪装成 E2EE」的可见证据）。
      expect(find.text(t.enterpriseOa.markerNoE2ee), findsOneWidget);
      expect(find.text('正文'), findsOneWidget);
    });

    testWidgets('人工经应用：出现不同文案的徽标', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) =>
                HostedMessageBubbleDecoration.decorate(
                  context: context,
                  metadata: <String, dynamic>{
                    'origin': originOf('human', senderUserId: '9001'),
                  },
                  child: const Text('正文'),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.enterpriseApp.badgeHumanDelegated), findsOneWidget);
      expect(find.text(t.enterpriseApp.badgeAppDelegated), findsNothing);
    });

    testWidgets('Human 直发：零额外装饰（child 原样）', (tester) async {
      final Widget child = const Text('正文');
      late Widget decorated;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) {
              decorated = HostedMessageBubbleDecoration.decorate(
                context: context,
                metadata: <String, dynamic>{'text': 'hello'},
                child: child,
              );
              return decorated;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(identical(decorated, child), isTrue, reason: '普通消息必须原样返回');
      expect(find.text(t.enterpriseApp.badgeAppDelegated), findsNothing);
      expect(find.text(t.enterpriseApp.badgeHumanDelegated), findsNothing);
      expect(find.text(t.enterpriseOa.markerNoE2ee), findsNothing);
    });

    testWidgets('两个代发分支的徽标文案互不相同（可区分性本体）', (tester) async {
      expect(
        t.enterpriseApp.badgeAppDelegated ==
            t.enterpriseApp.badgeHumanDelegated,
        isFalse,
      );
    });
  });

  group('非 E2EE 标记不被伪装成 E2EE', () {
    testWidgets('企业托管 + e2ee 载荷：仍展示「来源信息不一致」警示', (tester) async {
      await tester.pumpWidget(
        host(
          Builder(
            builder: (BuildContext context) =>
                HostedMessageBubbleDecoration.decorate(
                  context: context,
                  metadata: <String, dynamic>{
                    'origin': originOf('application'),
                    'e2ee': <String, dynamic>{'devices': <String, dynamic>{}},
                  },
                  child: const Text('正文'),
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(t.enterpriseApp.originMismatchTitle), findsOneWidget);
      // 徽标仍在（分类未降级）。
      expect(find.text(t.enterpriseApp.badgeAppDelegated), findsOneWidget);
    });
  });

  group('审计/详情面事实保留', () {
    test('代发消息的审计行同时含 sender 类型、应用 id、非 E2EE 事实', () {
      final List<HostedAuditLine> lines = hostedMessageAuditLines(
        resolveHostedMessageFacts(
          payload: <String, dynamic>{
            'origin': originOf('human', senderUserId: '9001'),
          },
          senderDisplayName: '张三',
        ).audit,
      );
      final List<String> values = lines
          .map((HostedAuditLine l) => l.value)
          .toList();
      expect(values, contains(t.enterpriseApp.originHosted));
      expect(values, contains(t.enterpriseApp.originSenderHuman));
      expect(values, contains(t.enterpriseApp.originApplicationId(id: '7001')));
      expect(values, contains(t.enterpriseApp.originNonE2ee));
      expect(values, isNot(contains(t.enterpriseApp.originE2ee)));
    });

    test('application 代发与 human 代发的审计 sender 行不同', () {
      final List<String> appValues = hostedMessageAuditLines(
        resolveHostedMessageFacts(
          payload: <String, dynamic>{'origin': originOf('application')},
        ).audit,
      ).map((HostedAuditLine l) => l.value).toList();
      final List<String> humanValues = hostedMessageAuditLines(
        resolveHostedMessageFacts(
          payload: <String, dynamic>{
            'origin': originOf('human', senderUserId: '9001'),
          },
        ).audit,
      ).map((HostedAuditLine l) => l.value).toList();
      expect(appValues, contains(t.enterpriseApp.originSenderApplication));
      expect(appValues, isNot(contains(t.enterpriseApp.originSenderHuman)));
      expect(humanValues, contains(t.enterpriseApp.originSenderHuman));
    });

    test('普通 Human 加密消息的审计行标 E2EE（不误标企业托管）', () {
      final List<String> values = hostedMessageAuditLines(
        resolveHostedMessageFacts(
          payload: <String, dynamic>{'text': 'hi'},
          e2ee: <String, dynamic>{'devices': <String, dynamic>{}},
        ).audit,
      ).map((HostedAuditLine l) => l.value).toList();
      expect(values, contains(t.enterpriseApp.originE2ee));
      expect(values, isNot(contains(t.enterpriseApp.originHosted)));
    });

    test('来源不可识别时审计行给出告警而不是静默', () {
      final List<HostedAuditLine> lines = hostedMessageAuditLines(
        resolveHostedMessageFacts(
          payload: <String, dynamic>{
            'origin': <String, dynamic>{'kind': 'weird', 'application_id': '1'},
          },
        ).audit,
      );
      expect(
        lines.any(
          (HostedAuditLine l) => l.value == t.enterpriseApp.originNonE2ee,
        ),
        isTrue,
      );
    });

    testWidgets('详情弹层可打开并渲染事实行', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showHostedMessageAuditSheet(
                    context,
                    facts: resolveHostedMessageFacts(
                      payload: <String, dynamic>{
                        'origin': originOf('application'),
                      },
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text(t.enterpriseApp.originTitle), findsWidgets);
      expect(
        find.text(t.enterpriseApp.originSenderApplication),
        findsOneWidget,
      );
      expect(find.text(t.enterpriseApp.originNonE2ee), findsOneWidget);
    });
  });

  group('通知面前缀', () {
    test('代发 → 前缀非空；普通 → 空前缀', () {
      expect(
        hostedMessageNotificationPrefix(<String, dynamic>{
          'origin': originOf('application'),
        }),
        '${t.enterpriseApp.badgeAppDelegated} · ',
      );
      expect(
        hostedMessageNotificationPrefix(<String, dynamic>{
          'origin': originOf('human', senderUserId: '9001'),
        }),
        '${t.enterpriseApp.badgeHumanDelegated} · ',
      );
      expect(
        hostedMessageNotificationPrefix(<String, dynamic>{'text': 'hi'}),
        isEmpty,
      );
      expect(hostedMessageNotificationPrefix(null), isEmpty);
    });
  });
}
