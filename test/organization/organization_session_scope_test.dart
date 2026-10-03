/// Synthetic local storage/notification tests; no login or resource launch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/modules/organization/presentation/organization_session_scope.dart';

class _Probe extends StatefulWidget {
  const _Probe(this.uid, this.disposed);
  final String uid;
  final List<String> disposed;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final String owner;
  @override
  void initState() {
    super.initState();
    owner = widget.uid;
  }

  @override
  void dispose() {
    widget.disposed.add(owner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('owner:$owner');
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({Keys.currentUid: '91001'});
    await StorageService.init();
    await UserRepoLocal.to.changeInfo({'uid': '91001', 'account': 'synthetic'});
  });
  testWidgets('真实仓库通知改变UID后销毁旧组织子树', (tester) async {
    final disposed = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OrganizationSessionBoundary(
            builder: (uid) => _Probe(uid, disposed),
          ),
        ),
      ),
    );
    expect(find.text('owner:91001'), findsOneWidget);
    await StorageService.to.setString(Keys.currentUid, '91002');
    await UserRepoLocal.to.changeInfo({'uid': '91002', 'account': 'synthetic'});
    await tester.pumpAndSettle();
    expect(disposed, ['91001']);
    expect(find.text('owner:91002'), findsOneWidget);
  });
  testWidgets('匿名状态不构造组织业务子树', (tester) async {
    await StorageService.to.remove(Keys.currentUid);
    await UserRepoLocal.to.changeInfo({});
    var builds = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: OrganizationSessionBoundary(
            builder: (uid) {
              builds++;
              return const Text('business-tree');
            },
          ),
        ),
      ),
    );
    expect(builds, 0);
    expect(find.text('business-tree'), findsNothing);
  });
  testWidgets('同UID新会话代次销毁旧状态', (tester) async {
    final session = ValueNotifier<OrganizationSessionScope>((
      uid: '91001',
      generation: 1,
    ));
    addTearDown(session.dispose);
    final disposed = <String>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          organizationSessionScopeProvider.overrideWith((ref) {
            void changed() => ref.invalidateSelf();
            session.addListener(changed);
            ref.onDispose(() => session.removeListener(changed));
            return session.value;
          }),
        ],
        child: MaterialApp(
          home: OrganizationSessionBoundary(
            builder: (uid) => _Probe(uid, disposed),
          ),
        ),
      ),
    );
    session.value = (uid: '91001', generation: 2);
    await tester.pumpAndSettle();
    expect(disposed, ['91001']);
    expect(find.text('owner:91001'), findsOneWidget);
  });
}
