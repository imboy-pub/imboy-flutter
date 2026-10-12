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
                createdAt: '2026-10-08T03:32:00Z',
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
    expect(find.textContaining('坐席 · 10/08'), findsOneWidget);
    expect(find.textContaining('已发送'), findsOneWidget);
    expect(find.textContaining('business_identity'), findsNothing);
    expect(find.textContaining('已读'), findsNothing);
    final body = tester.widget<Text>(find.text('您好，请问有什么可以帮您？'));
    expect(body.style?.color, AppColors.sentMessageText);
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
                createdAt: 'invalid',
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
    expect(find.textContaining('invalid'), findsNothing);
    expect(find.textContaining('已发送'), findsNothing);
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
