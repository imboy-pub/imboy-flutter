/// 账户 Sheet「退出登录」回归测试（W2R4 复测 adjoining 发现修复）。
///
/// 误接历史：退出登录 tile 的 onTap 曾 push `/logout_account`（注销账号页）——
/// `t.account.logOut`（退出登录）与 `logoutAccount`（注销账号）是两个语义。
/// 修复后：弹确认框执行真退出（镜像设置页 `_handleLogout`），绝不再进注销页。
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace_shell/workspace_account_menu.dart';

Future<ProviderContainer> _pumpButton(WidgetTester tester) async {
  final container = ProviderContainer();
  await tester.pumpWidget(
    TranslationProvider(
      child: UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: WorkspaceAccountButton())),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

void main() {
  testWidgets('退出登录：弹确认框而非跳注销页；取消不导航', (tester) async {
    final container = await _pumpButton(tester);
    addTearDown(container.dispose);

    await tester.tap(
      find.byKey(const ValueKey('workspace-shell-account-entry')),
    );
    await tester.pumpAndSettle();

    // 账户 sheet 内有「退出登录」tile
    expect(find.text(t.account.logOut), findsOneWidget);

    await tester.tap(find.text(t.account.logOut));
    await tester.pumpAndSettle();

    // 确认弹窗出现（误接时期这里是直接路由到注销账号页）
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text(t.account.areYouSureLogOut), findsOneWidget);

    // 取消 → 弹窗关闭、留在原地（本测试环境无 GoRouter：
    // 取消路径不得触达 GoRouter.of）
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
  });
}
