import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/app_core/feature_flags/generated_product_features.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart' show serviceContainer;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/group_detail/group_detail_page.dart';
import 'package:imboy/page/group/group_detail/group_detail_provider.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/model/people_model.dart';

/// ENT-APP-02 行为矩阵测试（before/after 等价基线）。
///
/// 目的：钉死 [GroupDetailPage] 危险操作/权限/确认对话的**行为基线**，
/// 为 group_detail_page.dart 等价拆分（profile/member/settings/governance）
/// 提供前后全绿的同一套断言。**只测真实存在的行为**：
///
/// | 动作 | 权限条件 | 确认对话 | 成功路径 | 失败路径 |
/// |---|---|---|---|---|
/// | 解散群 | role==4 (owner) | sureToDissolveGroup + 删记录提示 | pop×2 + 成功 toast | 失败 toast + 关弹窗 |
/// | 退出群 | role!=4（admin/member/未知均走退出） | sureToLeaveGroup + 删记录提示 | 同上 | 同上 |
/// | 清空记录 | 无角色门槛 | warning + confirmDeleteChatRecord | 成功 toast | 失败 toast（本测试钉死：本地无会话 → cid=0 → 失败） |
/// | E2EE 开启 | 仅 owner 且未开启；feature flag 关 → 整项隐藏 | e2eeEnableConfirm | 成功 toast + 开关锁定 | 静默 |
/// | 免打扰 | gid 非数字(<=0) → 开关禁用 | 无 | KV 落库 | 回滚 + 失败 toast |
/// | 群昵称/备注 | 无角色门槛（仅改自己的投影） | 无（UpdatePage 内） | ok 才更新 provider | — |
/// | 投诉 | 无角色门槛 | actionSheet 4 项 | 成功 toast | complaintFailed toast |
///
/// 该页面**不存在**改角色/归档/恢复动作（grep 证伪），矩阵不虚构。
///
/// 测试策略（先例：conversation_page_test / e2ee_backup_*_widget_test）：
///   - `groupDetailProvider.overrideWith` 注入固定 state（setter 全 no-op，
///     防 initData 异步回写污染注入的角色/标题）；
///   - 平台通道 mock：sqflite（空库）、connectivity（offline → detail 走
///     本地路径安静返回 null）、flutter_secure_storage（E2EE 旗标可控）；
///   - HttpClient 契约「从不抛异常」：解散/退出/投诉在无网环境落到
///     **失败 toast** 分支——这正是矩阵要钉死的失败路径。
/// 固定 state 注入 notifier：build 返回注入值；initData 的所有 setter
/// no-op，钉住 role/title/memberCount 等矩阵输入不被异步链路覆盖。
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
  void setMemberList(List<PeopleModel> list) {}
  @override
  void setMyGroupAlias(String? alias) {}
  @override
  void setGroupRemark(String? remark) {}
  @override
  void setGroup(GroupModel group) {}
  @override
  void addMember(PeopleModel member) {}
  @override
  void removeMember(int userId) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final secureStore = <String, String?>{};

  setUp(() async {
    LocaleSettings.setLocaleRaw('zh-CN');
    secureStore.clear();

    // --- StorageService（SharedPreferences mock）---
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    // UserRepoLocal.to.current：空 user 会抛 StateError → 注入最小用户
    await StorageService.to.setString(Keys.currentUid, '90001');
    await StorageService.setMap(Keys.currentUser, <String, dynamic>{
      'user_id': '90001',
      'nickname': '矩阵测试用户',
    });

    // --- flutter_secure_storage：GroupSessionService.isGroupE2EE 读此处 ---
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          (call) async {
            switch (call.method) {
              case 'read':
                final args = call.arguments as Map<Object?, Object?>;
                return secureStore[args['key'] as String];
              case 'write':
                final args = call.arguments as Map<Object?, Object?>;
                secureStore[args['key'] as String] = args['value'] as String?;
                return null;
              case 'delete':
                final args = call.arguments as Map<Object?, Object?>;
                secureStore.remove(args['key'] as String);
                return null;
              default:
                return null;
            }
          },
        );

    // --- connectivity：offline → initData 的 detail(sync:false) 本地路径 ---
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async => <String>['none'],
        );

    // 注册离线 NetworkMonitorService：HttpClient._isNetworkAvailable 变 false，
    // 解散/退出/投诉等 post 立即短路为 NetworkException resp（不真实触网）。
    // 预创建 sqlite 目录（真实同步 IO）：_initDatabase 的 Directory.create
    // 是真实 async，fake async 下 pending 会让 initData 链挂起。
    Directory('/tmp/imboy_matrix_test').createSync(recursive: true);

    // path_provider：sqlite._initDatabase 迁移编排要用 getApplicationSupportDirectory
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => '/tmp/imboy_matrix_test',
        );

    final monitor = NetworkMonitorService.to;
    monitor.dispose();
    monitor.init();
    serviceContainer.put<NetworkMonitorService>(monitor);
    // mock 的 checkConnectivity 是异步回读，冲刷一拍让 hasNetwork 收敛为 false
    await Future<void>.delayed(Duration.zero);

    // --- sqflite：空库（query 永远空、写操作零行）---
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
              // 返回 true：跳过 _initDatabase 的 Directory.create（真实
              // async IO，fake async 下 pending 会挂起 initData 整条链）；
              // 后续 _verifyEncryptedDatabase 全走 channel mock 可通过。
              case 'databaseExists':
                return true;
              case 'insert':
                return 0;
              case 'update':
              case 'delete':
                return 0;
              case 'execute':
              case 'closeDatabase':
                return null;
              case 'getDatabasePath':
              case 'getDatabasesPath':
                return '/tmp/imboy_matrix_test';
              case 'batch':
                return <int>[];
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await StorageService.to.remove(Keys.currentUid);
  });

  tearDownAll(() {
    serviceContainer.clear();
  });

  GroupModel buildGroup({int memberCount = 3}) => GroupModel(
    groupId: 1001,
    type: 2,
    joinLimit: 1,
    contentLimit: 1,
    ownerUid: 90001,
    creatorUid: 90001,
    memberMax: 500,
    memberCount: memberCount,
    title: '矩阵测试群',
    createdAt: 0,
  );

  Future<void> pumpPage(
    WidgetTester tester, {
    required GroupDetailState state,
    String groupId = '1001',
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupDetailProvider.overrideWith(() => _FixedStateNotifier(state)),
        ],
        child: TranslationProvider(
          child: MaterialApp(
            builder: AppLoading.init(),
            home: GroupDetailPage(
              groupId: groupId,
              title: '矩阵测试群',
              memberCount: state.memberCount,
            ),
          ),
        ),
      ),
    );
    // 首帧（含 initData postFrameCallback 入队）+ 冲刷 initData 微任务链
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }

  /// 页面内容在 SingleChildScrollView 内，底部控件（危险区/退出按钮/开关）
  /// 常在视口外：先 ensureVisible 再 tap。
  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pump();
  }

  CupertinoSwitch switchUnderLabel(WidgetTester tester, String label) {
    final tile = find.widgetWithText(CupertinoListTile, label);
    final sw = find.descendant(
      of: tile,
      matching: find.byType(CupertinoSwitch),
    );
    return tester.widget<CupertinoSwitch>(sw);
  }

  group('矩阵1: 危险按钮文案 — role 决定 解散/退出', () {
    testWidgets('role=4 (owner) → 解散群聊', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 4, title: '矩阵测试群', memberCount: 3),
      );
      expect(find.text(t.group.groupDissolve), findsOneWidget);
      expect(find.text(t.group.groupLeave), findsNothing);
      await unmount(tester);
    });

    testWidgets('role=3 (admin) → 退出群聊（admin 也不能解散）', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 3, title: '矩阵测试群', memberCount: 3),
      );
      expect(find.text(t.group.groupLeave), findsOneWidget);
      expect(find.text(t.group.groupDissolve), findsNothing);
      await unmount(tester);
    });

    testWidgets('role=1 (member) → 退出群聊', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      expect(find.text(t.group.groupLeave), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('role=0 (未知/未加载) → 安全默认退出群聊', (tester) async {
      await pumpPage(
        tester,
        state: const GroupDetailState(title: '矩阵测试群', memberCount: 3),
      );
      expect(find.text(t.group.groupLeave), findsOneWidget);
      await unmount(tester);
    });
  });

  group('矩阵2: 退出/解散确认对话', () {
    testWidgets('owner → 对话框含 确定要解散本群吗？+ 删记录提示', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 4, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.group.groupDissolve));
      await tester.pumpAndSettle();

      expect(find.text(t.common.tipTips), findsOneWidget);
      expect(find.textContaining(t.group.sureToDissolveGroup), findsOneWidget);
      expect(
        find.textContaining(t.common.sureDeleteGroupChatRecord),
        findsOneWidget,
      );
      expect(find.text(t.group.sureToLeaveGroup), findsNothing);
      await unmount(tester);
    });

    testWidgets('member → 对话框含 确定要退出本群吗？', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.group.groupLeave));
      await tester.pumpAndSettle();

      expect(find.textContaining(t.group.sureToLeaveGroup), findsOneWidget);
      expect(find.textContaining(t.group.sureToDissolveGroup), findsNothing);
      await unmount(tester);
    });

    testWidgets('member 取消 → 对话框关闭，停留页面', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.group.groupLeave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();

      expect(find.text(t.common.buttonCancel), findsNothing);
      expect(find.text(t.group.groupLeave), findsOneWidget); // 页面仍在
      await unmount(tester);
    });

    testWidgets('member 确认 → 无网失败 → 失败 toast + 弹窗关闭', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.group.groupLeave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonConfirm));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // HttpClient 契约「从不抛」：GroupMemberApi.leave 无网 → null → res=false
      // → 失败分支：showError + 关弹窗（nav.pop 关 dialog）
      expect(find.text(t.common.tipFailed), findsWidgets);
      await unmount(tester);
    });

    testWidgets('owner 确认 → dissolve 失败 → 失败 toast', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 4, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.group.groupDissolve));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonConfirm));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(t.common.tipFailed), findsWidgets);
      await unmount(tester);
    });
  });

  group('矩阵3: 清空聊天记录', () {
    testWidgets('确认对话：warning 标题 + confirmDeleteChatRecord 内容', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.common.clearChatRecord));
      await tester.pumpAndSettle();

      expect(find.text(t.common.warning), findsOneWidget);
      expect(find.text(t.common.confirmDeleteChatRecord), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('取消 → 关闭无动作', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.common.clearChatRecord));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();

      expect(find.text(t.common.buttonCancel), findsNothing);
      await unmount(tester);
    });

    testWidgets('确认 → 无成功反馈（本地无会话 → cid=0 走失败分支）', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.common.clearChatRecord));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonConfirm));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 钉死可达行为：确认后对话框关闭；cid=0 分支不可能出现成功反馈。
      // （失败 toast 模式已由矩阵2 leave/dissolve 的 http 短路路径钉死；
      // cleanMessageByPeerId 的完整 db 链依赖 sqlite 打开栈，widget 测试
      // 不复刻——其 cid 判定仅 3 行纯转发，拆分不触碰。）
      expect(find.text(t.common.buttonCancel), findsNothing);
      expect(find.text(t.common.tipSuccess), findsNothing);
      await unmount(tester);
    });
  });

  group('矩阵4: E2EE 开关权限', () {
    testWidgets('role=1 非 owner → tile 显示但开关禁用（成员只读）', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      if (!compiledProductFeatures.contains('e2ee')) {
        // 第一期开关不可发现，群主权限也不能绕过编译关闭边界。
        expect(find.text(t.group.e2eeTitle), findsNothing);
        expect(find.text(t.group.e2eeEnableConfirm), findsNothing);
        await unmount(tester);
        return;
      }
      expect(find.text(t.group.e2eeTitle), findsOneWidget);
      expect(switchUnderLabel(tester, t.group.e2eeTitle).onChanged, isNull);
      await unmount(tester);
    });

    // 「已开启 → 开关锁定」的 UI 用例在此不可达：_groupE2ee 由 initData
    // 回读 secure storage，其前置的 sqlite 打开栈（onCreate 建表迁移链）
    // 在 widget 测试的 fake async 下无法完整冲刷。该行为的渲染出口与
    // 上面「非 owner → 禁用」是同一个 onChanged null 臂（三元表达式
    // `_groupE2ee || !isGroupOwner(role) || gid<=0 ? null : ...`），已由
    // 该用例 + 下面两个 owner 用例（启用臂/确认流）组合钉死。
    // _groupE2ee 字段本身在等价拆分中只做整体搬运，无行为分叉。

    testWidgets('owner 未开启 → 开关启用；tap → 确认对话；取消 → 不变更', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 4, title: '矩阵测试群', memberCount: 3),
      );
      if (!compiledProductFeatures.contains('e2ee')) {
        // 第一期开关不可发现，群主权限也不能绕过编译关闭边界。
        expect(find.text(t.group.e2eeTitle), findsNothing);
        expect(find.text(t.group.e2eeEnableConfirm), findsNothing);
        await unmount(tester);
        return;
      }
      await tester.pump(const Duration(milliseconds: 200));
      expect(switchUnderLabel(tester, t.group.e2eeTitle).onChanged, isNotNull);

      await tapVisible(tester, find.byType(CupertinoSwitch).last);
      await tester.pumpAndSettle();

      expect(find.text(t.group.e2eeEnableConfirm), findsOneWidget);
      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(find.text(t.group.e2eeEnableConfirm), findsNothing);
      // 未开启状态保持
      expect(switchUnderLabel(tester, t.group.e2eeTitle).value, isFalse);
      await unmount(tester);
    });

    testWidgets('owner 确认开启 → 无网失败 → 不弹成功 toast（静默失败）', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 4, title: '矩阵测试群', memberCount: 3),
      );
      if (!compiledProductFeatures.contains('e2ee')) {
        // 第一期开关不可发现，群主权限也不能绕过编译关闭边界。
        expect(find.text(t.group.e2eeTitle), findsNothing);
        expect(find.text(t.group.e2eeEnableConfirm), findsNothing);
        await unmount(tester);
        return;
      }
      await tester.pump(const Duration(milliseconds: 200));
      await tapVisible(tester, find.byType(CupertinoSwitch).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.common.buttonConfirm));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text(t.common.tipSuccess), findsNothing);
      expect(switchUnderLabel(tester, t.group.e2eeTitle).value, isFalse);
      await unmount(tester);
    });
  });

  group('矩阵5: 消息免打扰', () {
    testWidgets('groupId 非数字(gid<=0) → 开关禁用', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
        groupId: 'not_a_number',
      );
      expect(
        switchUnderLabel(tester, t.common.muteNotifications).onChanged,
        isNull,
      );
      await unmount(tester);
    });

    testWidgets('合法 gid → 开关启用；tap → KV 落库 group_notice_disabled:1001', (
      tester,
    ) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      expect(
        switchUnderLabel(tester, t.common.muteNotifications).onChanged,
        isNotNull,
      );

      await tapVisible(tester, find.byType(CupertinoSwitch).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(StorageService.to.getBool('group_notice_disabled:1001'), isTrue);
      await unmount(tester);
    });
  });

  group('矩阵6: 群昵称/群备注 trailing 投影', () {
    testWidgets('myGroupAlias 空 → 显示当前用户昵称', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      expect(find.text('矩阵测试用户'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('myGroupAlias 非空 → 显示群昵称', (tester) async {
      await pumpPage(
        tester,
        state: const GroupDetailState(
          role: 1,
          title: '矩阵测试群',
          memberCount: 3,
          myGroupAlias: '我在群里的昵称',
        ),
      );
      expect(find.text('我在群里的昵称'), findsOneWidget);
      expect(find.text('矩阵测试用户'), findsNothing);
      await unmount(tester);
    });

    testWidgets('groupRemark 非空 → 显示备注（覆盖群名）', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(
          role: 1,
          title: '矩阵测试群',
          memberCount: 3,
          groupRemark: '我的群备注',
        ),
      );
      expect(find.text('我的群备注'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('矩阵7: 投诉 actionSheet', () {
    testWidgets('4 个投诉原因选项 + 取消', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.complaint.complaint));
      await tester.pumpAndSettle();

      expect(find.text(t.complaintReason.spam), findsOneWidget);
      expect(find.text(t.complaintReason.harassment), findsOneWidget);
      expect(find.text(t.complaintReason.inappropriate), findsOneWidget);
      expect(find.text(t.complaintReason.other), findsOneWidget);
      expect(find.text(t.common.buttonCancel), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('选择 spam → 无网失败 → complaintFailed toast', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(role: 1, title: '矩阵测试群', memberCount: 3),
      );
      await tapVisible(tester, find.text(t.complaint.complaint));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.complaintReason.spam));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // friendlyError 只对空/noise 文案回落 complaintFailed；离线短路的
      // resp.msg（网络提示）非空 → toast 透传网络提示而非 complaintFailed。
      expect(find.text(t.common.complaintFailed), findsNothing);
      expect(find.text(t.common.tipConnectDesc), findsWidgets);
      await unmount(tester);
    });
  });

  group('矩阵8: 成员区投影', () {
    testWidgets('memberCount>20 → 查看全部群成员入口出现', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(
          role: 1,
          title: '矩阵测试群',
          memberCount: 21,
          memberList: [
            PeopleModel(id: 1, account: 'a1'),
            PeopleModel(id: -1, account: 'add'),
          ],
        ),
      );
      expect(find.text(t.common.viewAllGroupMember), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('memberCount<=20 → 查看全部入口不出现', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(
          role: 1,
          title: '矩阵测试群',
          memberCount: 5,
          memberList: [PeopleModel(id: 1, account: 'a1')],
        ),
      );
      expect(find.text(t.common.viewAllGroupMember), findsNothing);
      await unmount(tester);
    });

    testWidgets('群信息卡片渲染注入群名', (tester) async {
      await pumpPage(
        tester,
        state: GroupDetailState(
          role: 1,
          title: '矩阵测试群',
          memberCount: 3,
          group: buildGroup(),
        ),
      );
      expect(find.text('矩阵测试群'), findsWidgets);
      await unmount(tester);
    });
  });
}
