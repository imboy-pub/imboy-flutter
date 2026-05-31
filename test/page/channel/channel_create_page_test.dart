import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_create_page.dart';

// ChannelCreatePage 渲染与表单校验契约
// CreateChannelNotifier.build() 返回 const CreateChannelState()，纯净无网络；
// 页面无 initState 网络加载，头像/创建仅在用户交互时触发 → 渲染可测。
Future<void> _pump(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      child: TranslationProvider(
        child: const MaterialApp(home: ChannelCreatePage()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('renders without error', (WidgetTester tester) async {
    await _pump(tester);
    expect(find.byType(ChannelCreatePage), findsOneWidget);
    // 频道名称/描述/自定义 ID 表单输入框
    expect(find.byType(TextFormField), findsWidgets);
  });

  testWidgets('renders top-of-form fields (avatar title + name + confirm)', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    // 顶部可见元素（ListView 懒加载下仍在视口内）
    expect(find.text(t.account.avatar), findsOneWidget);
    expect(find.text(t.channel.nameLabel), findsWidgets);
    // AppBar 确认按钮（默认非创建中状态展示文本）
    expect(find.text(t.common.confirm), findsOneWidget);
  });

  testWidgets('empty name submit triggers form validation, stays on page', (
    WidgetTester tester,
  ) async {
    await _pump(tester);
    // 点击确认（名称为空）→ _formKey.validate() 失败提前 return，
    // 不调用 createChannelProvider、不导航；仅展示必填校验提示。
    await tester.tap(find.text(t.common.confirm));
    await tester.pump();
    expect(find.text(t.channel.nameRequired), findsOneWidget);
    expect(find.byType(ChannelCreatePage), findsOneWidget);
  });
}
