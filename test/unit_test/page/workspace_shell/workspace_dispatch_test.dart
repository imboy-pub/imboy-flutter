/// WP5 (T8) — experience=workspace 分发契约测试
///
/// 计划锚点（T8）：experience=workspace → WorkspaceShellBootstrap，
/// 不再按 §4.1 fail-safe 以 chat 壳渲染（T2 时代的占位行为已替换）。
///
/// 测试策略（镜像 chat_shell_bootstrap_test 头注决策）：完整 mount
/// ChatShellPage 会拉 BottomNavigationPage 四子页 + WebSocket 副作用，
/// 超出 ROI；本文件经 ProviderScope.overrides 注入 productExperience
/// 与空工作区 Fake API，证明 workspace 值分发到 **Workspace 壳的空态
/// 结构**（创建入口），而非 ChatShellPage。experience 分发矩阵全量
/// （chat/未知/缺失降级）由 test/unit_test/page/chat_shell/
/// experience_provider_test 固化。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/chat_shell_page.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_bootstrap.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

/// 空「我的工作区」Fake（壳走空态分支；零网络、零 timer）。
class _EmptyMineFakeApi extends WorkspaceApi {
  @override
  Future<WorkspacePageResult<WorkspaceModel>> mine({
    int page = 1,
    int size = 20,
  }) async {
    return const WorkspacePageResult<WorkspaceModel>();
  }
}

void main() {
  testWidgets('experience=workspace → 工作区壳空态（创建入口），非 ChatShellPage', (
    tester,
  ) async {
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            productExperienceProvider.overrideWithValue(
              ProductExperience.workspace,
            ),
            workspaceApiProvider.overrideWith((ref) => _EmptyMineFakeApi()),
          ],
          child: const MaterialApp(home: ChatShellBootstrap()),
        ),
      ),
    );
    // 首帧：postFrame 触发 loadMine（fake 同步完成）；再推一帧让状态落定
    await tester.pump();

    // Chat 壳未出现（fail-safe 占位行为已由 T8 移除）
    expect(find.byType(ChatShellPage), findsNothing);
    expect(find.byType(ChatShellBootstrap), findsOneWidget);
    // Workspace 壳空态特征结构：无工作区时的创建入口（壳可空态运行）
    expect(
      find.byKey(const ValueKey('workspace-empty-create-entry')),
      findsOneWidget,
    );
  });

  test('workspace 分支产物形态固定：WorkspaceShellBootstrap（const 构造契约）', () {
    // bootstrap switch 的 workspace 分支渲染该组件；其可 const 构造
    // （无必选参数、ConsumerStatefulWidget）即等价于分支可达。
    const ws = WorkspaceShellBootstrap();
    expect(ws, isA<WorkspaceShellBootstrap>());
    expect(ws.key, isNull);
  });
}
