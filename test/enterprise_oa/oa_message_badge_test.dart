/// EPGZ-06 W1 — OA 代发消息标签组件 widget 测试（plan §4.3）
///
/// 纯展示组件验收点：
/// - 「OA 代发」徽标文案渲染；
/// - 非 E2EE 标记显式标注（不得复用 Human-Human E2EE 标识）；
/// - sender 展示格式 = Human 显示名 + origin 附注（主视图/详情分离语义）。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/public.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('OaDelegatedBadge：渲染「OA 代发」文案', (tester) async {
    await tester.pumpWidget(host(const OaDelegatedBadge()));
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.badgeDelegated), findsOneWidget);
    expect(find.text('OA 代发'), findsOneWidget); // base_locale 实文
  });

  testWidgets('OaNoE2eeMarker：渲染非 E2EE 状态标记', (tester) async {
    await tester.pumpWidget(host(const OaNoE2eeMarker()));
    await tester.pumpAndSettle();

    expect(find.text(t.enterpriseOa.markerNoE2ee), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.eye), findsOneWidget);
  });

  testWidgets('OaDelegatedSenderLine：Human 显示名 + origin 附注', (tester) async {
    await tester.pumpWidget(
      host(
        const OaDelegatedSenderLine(
          presentation: OaDelegatedSenderPresentation(
            humanDisplayName: '张三',
            oaOrigin: 'oa.example.com',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 主文本 = 指定 Human 的显示名（plan §4.3：主视图按 Human 展示）。
    expect(find.text('张三'), findsOneWidget);
    // 附注 = 「经 <origin> 代发」。
    expect(
      find.text(t.enterpriseOa.senderVia(origin: 'oa.example.com')),
      findsOneWidget,
    );
  });

  testWidgets('OaDelegatedSenderLine：可关闭 origin 附注（紧凑列表）', (tester) async {
    await tester.pumpWidget(
      host(
        const OaDelegatedSenderLine(
          presentation: OaDelegatedSenderPresentation(
            humanDisplayName: '张三',
            oaOrigin: 'oa.example.com',
          ),
          showOriginNote: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('张三'), findsOneWidget);
    expect(find.textContaining('oa.example.com'), findsNothing);
  });

  testWidgets('OaDelegatedSenderPresentation：展示数据形态拆分', (tester) async {
    const p = OaDelegatedSenderPresentation(
      humanDisplayName: '李四',
      oaOrigin: 'oa.gz-customer.cn',
    );
    expect(p.primary, '李四');
    expect(p.originNote, 'oa.gz-customer.cn');
  });
}
