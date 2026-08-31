/// WP5 (T9) — Workspace Members 视图治理测试
///
/// 计划锚点（T9 VALIDATE）：
/// - Owner/Member/Guest 三种角色徽标与「Guest 只读」可见性规则；
/// - 非工作区 Owner 无任何治理写入口（只读）；
/// - archived 工作区：写操作禁用（邀请按钮 disabled + 恢复入口）；
/// - 移除成员 409 冲突时服务端冲突清单文本透出（EasyLoading toast，
///   builder 注入 AppLoading.init 的既有惯例见 e2ee_backup_export 测试）。
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart' as app_loading;
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/workspace/workspace_members_page.dart';
import 'package:imboy/page/workspace/workspace_data_providers.dart';
import 'package:imboy/page/workspace_shell/workspace_shell_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/workspace_api.dart';
import 'package:imboy/store/model/workspace_model.dart';

const String _wsId = '9001';
const String _ownerUid = '1001';
const String _guestUid = '1003';

WorkspaceModel _ws({WorkspaceStatus status = WorkspaceStatus.active}) =>
    WorkspaceModel(id: _wsId, name: '官网改版', ownerId: _ownerUid, status: status);

List<WorkspaceMemberModel> get _seedMembers => const [
  WorkspaceMemberModel(
    workspaceId: _wsId,
    userId: _ownerUid,
    role: WorkspaceMemberRole.owner,
    nickname: '李雷',
    account: 'leilei',
  ),
  WorkspaceMemberModel(
    workspaceId: _wsId,
    userId: '1002',
    role: WorkspaceMemberRole.member,
    nickname: '韩梅梅',
    account: 'hanmeimei',
  ),
  WorkspaceMemberModel(
    workspaceId: _wsId,
    userId: _guestUid,
    role: WorkspaceMemberRole.guest,
    nickname: '访客王',
    account: 'wang',
  ),
];

/// 可控 Fake：members() 返回种子列表；removeMember 可注入 409 冲突。
class _MembersFakeApi extends WorkspaceApi {
  final Map<EntityId, WorkspaceApiException> removeErrors;

  _MembersFakeApi({this.removeErrors = const {}});

  @override
  Future<WorkspacePageResult<WorkspaceMemberModel>> members(
    EntityId workspaceId, {
    int page = 1,
    int size = 20,
  }) async {
    return WorkspacePageResult<WorkspaceMemberModel>(
      list: _seedMembers,
      total: _seedMembers.length,
      totalPage: 1,
    );
  }

  @override
  Future<void> removeMember({
    required EntityId workspaceId,
    required EntityId userId,
  }) async {
    final err = removeErrors[userId];
    if (err != null) throw err;
  }

  @override
  Future<WorkspaceModel> detail(EntityId workspaceId) => Future.value(_ws());
}

Future<void> _pumpMembersPage(
  WidgetTester tester, {
  required EntityId currentUid,
  required _MembersFakeApi api,
  Size size = const Size(430, 1400),
  double devicePixelRatio = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = devicePixelRatio;
  addTearDown(tester.view.reset);

  // 当前用户身份经 StorageService（UserRepoLocal.currentUid 数据源）
  await StorageService.to.setString(Keys.currentUid, currentUid);
  addTearDown(() => StorageService.to.remove(Keys.currentUid));

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          workspaceApiProvider.overrideWith((ref) => api),
          currentWorkspaceProvider.overrideWithValue(_ws()),
        ],
        child: MaterialApp(
          // EasyLoading toast host（移除冲突清单断言依赖）
          builder: app_loading.AppLoading.init(),
          home: const WorkspaceMembersPage(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('三种角色徽标 Owner/Member/Guest 独立展示', (tester) async {
    await _pumpMembersPage(
      tester,
      currentUid: _guestUid, // 当前用户是 Guest → 只读视角仍能看到全部徽标
      api: _MembersFakeApi(),
    );

    expect(
      find.byKey(const ValueKey('workspace-role-badge-owner')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-role-badge-member')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-role-badge-guest')),
      findsOneWidget,
    );
  });

  testWidgets('Guest 只读：无邀请/移除/改角色/转移/Branding/归档任何治理入口', (tester) async {
    await _pumpMembersPage(
      tester,
      currentUid: _guestUid,
      api: _MembersFakeApi(),
    );

    expect(find.byKey(const ValueKey('workspace-invite-entry')), findsNothing);
    expect(
      find.byKey(const ValueKey('workspace-branding-entry')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('workspace-archive-entry')), findsNothing);
    for (final uid in const [_ownerUid, '1002', _guestUid]) {
      expect(
        find.byKey(ValueKey('workspace-member-remove-$uid')),
        findsNothing,
        reason: 'Guest 不能移除任何人（含自己）',
      );
      expect(find.byKey(ValueKey('workspace-member-role-$uid')), findsNothing);
      expect(
        find.byKey(ValueKey('workspace-member-transfer-$uid')),
        findsNothing,
      );
    }
  });

  testWidgets('非 Owner 的 Member 同样只读', (tester) async {
    await _pumpMembersPage(tester, currentUid: '1002', api: _MembersFakeApi());

    expect(find.byKey(const ValueKey('workspace-invite-entry')), findsNothing);
    expect(
      find.byKey(ValueKey('workspace-member-remove-$_guestUid')),
      findsNothing,
    );
  });

  testWidgets('Owner 视角：邀请/Branding/归档入口 + 其他人可移除/改角色/转移', (tester) async {
    await _pumpMembersPage(
      tester,
      currentUid: _ownerUid,
      api: _MembersFakeApi(),
    );

    expect(
      find.byKey(const ValueKey('workspace-invite-entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-branding-entry')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('workspace-archive-entry')),
      findsOneWidget,
    );
    // 对他人（含 Guest 目标转移按钮不出现——目标须为非 Guest）
    expect(
      find.byKey(ValueKey('workspace-member-remove-1002')),
      findsOneWidget,
    );
    expect(find.byKey(ValueKey('workspace-member-role-1002')), findsOneWidget);
    expect(
      find.byKey(ValueKey('workspace-member-transfer-1002')),
      findsOneWidget,
    );
    // Guest 不可被转移 Owner（T9：目标须为非 Guest active 成员）
    expect(
      find.byKey(ValueKey('workspace-member-transfer-$_guestUid')),
      findsNothing,
    );
    // 自己不可被移除/改角色
    expect(
      find.byKey(ValueKey('workspace-member-remove-$_ownerUid')),
      findsNothing,
    );
  });

  testWidgets('archived 工作区：归档横幅 + 邀请写操作禁用 + 显示恢复入口', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await StorageService.to.setString(Keys.currentUid, _ownerUid);
    addTearDown(() => StorageService.to.remove(Keys.currentUid));

    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [
            workspaceApiProvider.overrideWith((ref) => _MembersFakeApi()),
            currentWorkspaceProvider.overrideWithValue(
              _ws(status: WorkspaceStatus.archived),
            ),
          ],
          child: MaterialApp(home: const WorkspaceMembersPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workspace-archived-banner')),
      findsOneWidget,
    );
    final inviteButton = tester.widget<FilledButton>(
      find.byKey(const ValueKey('workspace-invite-entry')),
    );
    expect(inviteButton.onPressed, isNull, reason: 'archived 下写操作必须禁用');
    expect(
      find.byKey(const ValueKey('workspace-restore-entry')),
      findsOneWidget,
    );
  });

  testWidgets('360dp 窄屏 Owner 视角：带按钮行昵称独占整行完整可见（批次W2R2FIX 回归锚点）', (
    tester,
  ) async {
    // 真机 MRD-AL00 = 360dp 宽。回归背景：「昵称+徽标同行」布局下昵称被
    // 按钮行+徽标挤到 ~25dp——首字+省略号都放不下时 ellipsis 渲染空白
    // （语义树仍有文本、视觉消失）；@账号无 maxLines 折成两行。
    await _pumpMembersPage(
      tester,
      currentUid: _ownerUid,
      api: _MembersFakeApi(),
      size: const Size(720, 1440),
      devicePixelRatio: 2.0,
    );

    const tile1002 = ValueKey('workspace-member-tile-1002');
    final nicknameFinder = find.descendant(
      of: find.byKey(tile1002),
      matching: find.text('韩梅梅'),
    );
    final badgeFinder = find.byKey(
      const ValueKey('workspace-role-badge-member'),
    );

    // 昵称渲染宽度保底 ≥40dp（修复前 Flexible 挤压下仅 ~25dp 且渲染空白）
    final paragraph = tester.renderObject<RenderParagraph>(nicknameFinder);
    expect(
      paragraph.size.width,
      greaterThanOrEqualTo(40),
      reason: '昵称须独占整行宽度，不被徽标/按钮挤压到渲染空白',
    );
    // 徽标换行到昵称下方的次要行（与 @账号 同行）
    final nicknameTop = tester.getTopLeft(nicknameFinder).dy;
    final badgeTop = tester.getTopLeft(badgeFinder).dy;
    expect(badgeTop, greaterThan(nicknameTop), reason: '徽标不应与昵称同行争宽');
    // 无任何 RenderFlex 溢出
    expect(tester.takeException(), isNull);
  });

  testWidgets('移除成员 409 冲突：服务端冲突清单文本透出（未完成任务），不得伪装成功', (tester) async {
    await _pumpMembersPage(
      tester,
      currentUid: _ownerUid,
      api: _MembersFakeApi(
        removeErrors: {
          '1002': const WorkspaceApiException(
            409,
            'membership_conflict：该用户仍有未完成任务（官网首页、落地页改版），'
            '须先改派或完成后再移除',
          ),
        },
      ),
    );

    await tester.tap(find.byKey(ValueKey('workspace-member-remove-1002')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.workspace.removeMemberConfirm));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 冲突清单原样展示服务端消息（_guardRun → AppLoading.showBackendError）；
    // 用 envelope code 前缀区分于确认弹窗里的 i18n 描述文案
    expect(find.textContaining('membership_conflict'), findsOneWidget);
    // 清理 EasyLoading 自动消失 Timer，避免 Pending timers
    await tester.pump(const Duration(seconds: 6));
  });
}
