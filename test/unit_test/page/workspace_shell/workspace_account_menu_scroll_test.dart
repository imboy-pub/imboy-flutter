/// 账户 Sheet 内容超屏回归测试（RenderFlex overflowed by 44px 修复）。
///
/// Sheet 内容是 min-size Column：身份卡 + 多工作区列表 + 最多 9 行动作
/// 叠起来可能超过一屏。修复后内容包 SingleChildScrollView——不足一屏
/// 收缩贴合、超屏滚动，不再触发 Column 底部溢出。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace_shell/workspace_account_menu.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// 注入 6 个工作区（每个置顶回填一次，最终全部在列表内）。
Future<ProviderContainer> _seededContainer() async {
  final container = ProviderContainer();
  for (var i = 0; i < 6; i++) {
    container
        .read(workspaceShellProvider.notifier)
        .applyCreated(
          WorkspaceCreateResult(
            workspace: WorkspaceModel(
              id: '910$i',
              name: '工作区 $i 号',
              ownerId: '1001',
            ),
            channelId: '920$i',
            groupId: '930$i',
            status: 'created',
          ),
        );
  }
  return container;
}

Future<void> _pumpButton(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // 矮屏（560 高）：内容必然超过一屏，复现修复前的溢出场景
  tester.view.physicalSize = const Size(430, 560);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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
}

void main() {
  testWidgets('多工作区 + 矮屏：Sheet 内容超屏可滚动，不 Column 溢出', (tester) async {
    final container = await _seededContainer();
    addTearDown(container.dispose);
    await _pumpButton(tester, container);

    await tester.tap(
      find.byKey(const ValueKey('workspace-shell-account-entry')),
    );
    await tester.pumpAndSettle();

    // 修复前：min-size Column 直接底部溢出（RenderFlex overflowed by N px）
    expect(tester.takeException(), isNull);

    final sheetScrollable = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.byType(Scrollable),
    );
    expect(sheetScrollable, findsOneWidget);

    // 超屏内容经滚动可达：最底部「退出登录」tile 能进入视口
    await tester.scrollUntilVisible(
      find.text(t.account.logOut),
      120,
      scrollable: sheetScrollable,
    );
    expect(find.text(t.account.logOut), findsOneWidget);
  });
}
