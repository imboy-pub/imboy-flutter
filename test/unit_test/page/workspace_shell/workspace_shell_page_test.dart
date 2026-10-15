import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat_shell/chat_shell_page.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/workspace_shell/enterprise_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_page.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/model/workspace_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

class _Shell extends WorkspaceShellNotifier {
  _Shell(this.initial);
  final WorkspaceShellState initial;
  @override
  WorkspaceShellState build() => initial;
}

void main() {
  for (final organizationId in ['', 'org-a']) {
    for (final hasWorkspace in [false, true]) {
      testWidgets('企业=$organizationId，工作区=$hasWorkspace：只分发个人或企业布局', (
        tester,
      ) async {
        final container = ProviderContainer(
          overrides: [
            currentUserProvider.overrideWithValue(
              UserModel(uid: 'mode-a', account: 'synthetic'),
            ),
            workspaceShellProvider.overrideWith(
              () => _Shell(
                WorkspaceShellState(
                  organizationId: organizationId,
                  currentWorkspaceId: hasWorkspace ? 'ws-a' : '',
                  workspaces: hasWorkspace
                      ? const [
                          WorkspaceModel(
                            id: 'ws-a',
                            name: 'synthetic',
                            ownerId: 'mode-a',
                            organizationId: 'org-a',
                          ),
                        ]
                      : const [],
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        late Widget result;
        // 执行真实分发，子页的网络/SQLite 挂载由企业布局组件测试覆盖。
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Consumer(
              builder: (context, ref, _) {
                result = const WorkspaceShellPage().build(context, ref);
                return const SizedBox();
              },
            ),
          ),
        );
        if (organizationId.isEmpty) {
          expect(result, isA<ChatShellPage>());
          final personal = result as ChatShellPage;
          expect(personal.mobileEntry, isA<BottomNavigationPage>());
          expect(personal.desktopEntry, isA<WebShellBootstrap>());
        } else {
          expect(result, isA<EnterpriseShellPage>());
          expect(
            (result as EnterpriseShellPage).organizationId,
            organizationId,
          );
        }
      });
    }
  }
}
