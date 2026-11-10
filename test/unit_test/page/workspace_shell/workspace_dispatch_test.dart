import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_page.dart';
import 'package:imboy/page/chat_shell/chat_shell_bootstrap.dart';
import 'package:imboy/page/chat_shell/experience_provider.dart';
import 'package:imboy/page/chat_shell/personal_navigation_layout.dart';
import 'package:imboy/page/web_shell/web_shell_bootstrap.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_bootstrap.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

void main() {
  testWidgets('旧服务端和本地 workspace 配置不能绕过企业选择；明确选择后才切企业布局', (tester) async {
    await StorageService.to.setString(
      Keys.effectiveProductExperience,
      'workspace',
    );
    await StorageService.to.setString(Keys.localProductExperience, 'workspace');
    final container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(
          UserModel(uid: 'dispatch-user', account: 'synthetic'),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(() async {
      await StorageService.to.remove(Keys.effectiveProductExperience);
      await StorageService.to.remove(Keys.localProductExperience);
      await StorageService.to.remove(
        '${Keys.localProductExperience}_dispatch-user',
      );
    });
    late Widget result;
    void expectPersonalEntry() {
      expect(
        container.read(productExperienceProvider),
        ProductExperience.personal,
      );
      expect(result, isA<PersonalNavigationLayout>());
      final layout = result as PersonalNavigationLayout;
      expect(layout.mobileBuilder(null), isA<BottomNavigationPage>());
      expect(layout.desktopEntry, isA<WebShellBootstrap>());
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            result = const ChatShellBootstrap().build(context, ref);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(container.read(workspaceShellProvider).organizationId, isEmpty);
    expectPersonalEntry();
    await expectLater(
      container
          .read(productExperienceProvider.notifier)
          .select(ProductExperience.workspace),
      throwsStateError,
    );
    await tester.pump();
    expect(container.read(workspaceShellProvider).organizationId, isEmpty);
    expectPersonalEntry();
    await container
        .read(workspaceShellProvider.notifier)
        .selectOrganization('org-a', () async => '');
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.workspace);
    await tester.pump();
    expect(container.read(workspaceShellProvider).organizationId, 'org-a');
    expect(
      container.read(productExperienceProvider),
      ProductExperience.workspace,
    );
    expect(result, isA<WorkspaceShellBootstrap>());
    await container
        .read(productExperienceProvider.notifier)
        .select(ProductExperience.personal);
    await tester.pump();
    expectPersonalEntry();
  });
}
