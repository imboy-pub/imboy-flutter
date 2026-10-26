import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/presentation/cs_message_bubble.dart';
import 'package:imboy/modules/enterprise/domain/enterprise_models.dart';
import 'package:imboy/theme/default/app_colors.dart';

void main() {
  testWidgets('坐席消息显示时间与已发送，隐藏内部身份标识', (tester) async {
    LocaleSettings.setLocale(AppLocale.zhCn);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: CsMessageBubble(
              message: const EnterpriseMessage(
                id: '123',
                conversationId: '456',
                organizationId: '789',
                senderType: EnterpriseSenderType.businessIdentity,
                content: '您好，请问有什么可以帮您？',
                createdAtMs: 1791447120000, // 2026-10-08T03:32:00Z
              ),
              isSeat: true,
              actorLabel: 'business_identity',
              assets: const [],
              bytesLoader: (_) async => null,
              onView: (_) {},
            ),
          ),
        ),
      ),
    );
    // 期望日期由 fixture 的 UTC 时刻换算查看者本地日（MM-dd），
    // 断言才与运行时区无关（03:32Z 在纽约本地是 10/07）。
    final localDay = DateTime.fromMillisecondsSinceEpoch(
      1791447120000,
      isUtc: true,
    ).toLocal();
    final expectedDate =
        '${localDay.month.toString().padLeft(2, '0')}/${localDay.day.toString().padLeft(2, '0')}';
    expect(find.textContaining('坐席 · $expectedDate'), findsOneWidget);
    expect(find.textContaining('已发送'), findsOneWidget);
    expect(find.textContaining('business_identity'), findsNothing);
    expect(find.textContaining('已读'), findsNothing);
    final body = tester.widget<Text>(find.text('您好，请问有什么可以帮您？'));
    expect(body.style?.color, AppColors.sentMessageText);
  });

  testWidgets('R08-FL：真实 wire 秒 JSON → 模型 → 本地日期展示', (tester) async {
    LocaleSettings.setLocale(AppLocale.zhCn);
    // 后端真实出站形状：created_at 为 Unix 秒整数（eb_pg_store_sql ts→to_unix）。
    // 计划 6.1 T1 瞬间：1789600000 秒 ≡ 2026-09-16T23:06:40Z。
    final message = EnterpriseMessage.fromJson(const {
      'id': 7266418340025468934,
      'conversation_id': 7266418340025468933,
      'organization_id': 7266418340025468930,
      'sender_type': 'business_identity',
      'sender_business_identity_id': 7266418340025468931,
      'body': 'wire seconds body',
      'created_at': 1789600000,
      'retain_until': 2000000000,
    });
    expect(message.createdAtMs, 1789600000000, reason: '秒合同 ×1000');
    expect(message.retainUntilMs, 2000000000000);

    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: CsMessageBubble(
              message: message,
              isSeat: true,
              actorLabel: '坐席',
              assets: const [],
              bytesLoader: (_) async => null,
              onView: (_) {},
            ),
          ),
        ),
      ),
    );
    final localDay = DateTime.fromMillisecondsSinceEpoch(
      1789600000000,
      isUtc: true,
    ).toLocal();
    final expectedDate =
        '${localDay.month.toString().padLeft(2, '0')}/${localDay.day.toString().padLeft(2, '0')}';
    // 数字秒不再被字符串 parser 丢弃（旧实现 tryParse('1789600000') 失败→不显示）。
    expect(find.textContaining(expectedDate), findsOneWidget);
  });

  testWidgets('时间缺失不显示假时间，访客消息不标记已发送', (tester) async {
    LocaleSettings.setLocale(AppLocale.zhCn);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: Scaffold(
            body: CsMessageBubble(
              message: const EnterpriseMessage(
                id: '123',
                conversationId: '456',
                organizationId: '789',
                content: '访客问题',
                createdAtMs: 0, // 未知
              ),
              isSeat: false,
              actorLabel: '张**',
              assets: const [],
              bytesLoader: (_) async => null,
              onView: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('客户'), findsOneWidget);
    // 0=未知：不渲染任何时间片段，也不回填当前时间。
    expect(find.textContaining('已发送'), findsNothing);
    final visitorLabel = tester.widget<Text>(find.text('客户'));
    expect(visitorLabel.data, '客户');
  });
  testWidgets('only server receipt marks seat message as read', (tester) async {
    LocaleSettings.setLocale(AppLocale.zhCn);
    await tester.pumpWidget(
      TranslationProvider(
        child: MaterialApp(
          home: CsMessageBubble(
            message: const EnterpriseMessage(
              id: '123',
              conversationId: '456',
              organizationId: '789',
              content: 'body',
            ),
            isSeat: true,
            actorLabel: '坐席',
            assets: const [],
            bytesLoader: (_) async => null,
            onView: (_) {},
            serverReadAt: DateTime.utc(2026, 10, 12),
          ),
        ),
      ),
    );
    expect(find.textContaining('已读'), findsOneWidget);
  });
}
