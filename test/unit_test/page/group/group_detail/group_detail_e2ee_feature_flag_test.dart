import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/page/group/group_detail/group_detail_provider.dart';
import 'package:imboy/service/storage.dart';

/// ENT-APP-02 行为矩阵补充：E2EE feature flag 关闭 → tile 整项隐藏。
///
/// 为什么单独成文件：`AppFeatureRegistry._cache` 是进程内静态缓存且无失效
/// 钩子；`flutter test` 每个文件运行在独立 isolate —— 本文件把 flag=false
/// 的 snapshot 注入放在**任何 isEnabled(e2ee) 首次求值之前**，与主矩阵
/// 文件（flag 默认 true）互不污染。
///
/// 其余 mock 与主矩阵文件一致（sqflite 空库 / connectivity offline /
/// secure storage map / 注入固定 state）。
class _FixedStateNotifier extends GroupDetailNotifier {
  _FixedStateNotifier(this.fixed);
  final GroupDetailState fixed;

  @override
  GroupDetailState build() => fixed;

  @override
  void setLoading(bool value) {}
  @override
  void setTitle(String title) {}
  @override
  void setMemberCount(int count) {}
  @override
  void setRoleInfo(int role, bool isAdmin) {}
  @override
  void setMemberList(list) {}
  @override
  void setMyGroupAlias(String? alias) {}
  @override
  void setGroupRemark(String? remark) {}
  @override
  void setGroup(group) {}
  @override
  void addMember(member) {}
  @override
  void removeMember(int userId) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LocaleSettings.setLocaleRaw('zh-CN');
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, '90001');
    await StorageService.setMap(Keys.currentUser, <String, dynamic>{
      'user_id': '90001',
      'nickname': '矩阵测试用户',
    });

    // flag=false 必须在首次 isEnabled(e2ee) 求值（即页面 build）前写入
    await StorageService.setMap(Keys.appFeatures, <String, dynamic>{
      'e2ee': false,
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async => null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async => <String>['none'],
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
          (call) async {
            switch (call.method) {
              case 'openDatabase':
                return 1;
              case 'query':
                return <String, dynamic>{
                  'columns': <String>[],
                  'rows': <List<Object?>>[],
                };
              case 'getDatabasePath':
              case 'getDatabasesPath':
                return '/tmp/imboy_matrix_test';
              default:
                return null;
            }
          },
        );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          null,
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('com.davidmartos96.sqflite_sqlcipher'),
          null,
        );
    await StorageService.to.remove(Keys.currentUid);
  });

  testWidgets('feature flag 关闭 → E2EE tile 整项隐藏（owner 也不显示）', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupDetailProvider.overrideWith(
            () => _FixedStateNotifier(
              const GroupDetailState(role: 4, title: '矩阵测试群', memberCount: 3),
            ),
          ),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            builder: AppLoading.init(),
            home: const GroupDetailPage(
              groupId: '1001',
              title: '矩阵测试群',
              memberCount: 3,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(t.group.e2eeTitle), findsNothing);
    // 对照：免打扰 tile 仍在（flag 只影响 E2EE 项）
    expect(find.text(t.common.muteNotifications), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
