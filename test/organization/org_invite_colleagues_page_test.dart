/// APP-M02 邀请同事页 widget 测试：
/// 三个入口行 / 码缺失引导条（建码闭环）/ 分段切换 / 可能的同事列表
/// （富化展示 + canGovern 预隐藏撤销）/ 空态 CTA 切回邀请 Tab / ··· 菜单。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/org_invite_colleagues_page.dart';

/// OrganizationApi 子类桩：只覆写页面触达的方法，不打真实网络。
class _FakeInviteApi extends OrganizationApi {
  _FakeInviteApi({
    this.code = 'ABCD2345',
    this.canGovern = false,
    this.invitations = const <OrgInvitation>[],
  });

  final String code;
  final bool canGovern;
  final List<OrgInvitation> invitations;
  int createCalls = 0;

  @override
  Future<OrganizationInviteCode> getInviteCode(EntityId orgId) async =>
      OrganizationInviteCode(
        organizationId: orgId,
        code: code,
        status: 'active',
      );

  @override
  Future<Organization> detail(EntityId orgId) async => Organization(
    id: orgId,
    name: '演示企业',
    memberRole: canGovern ? 'owner' : 'member',
  );

  @override
  Future<List<OrgInvitation>> orgInvitations(
    EntityId orgId, {
    String? status,
    int limit = 20,
  }) async => invitations;

  @override
  Future<OrganizationInviteCode> createInviteCode(EntityId orgId) async {
    createCalls++;
    return OrganizationInviteCode(
      organizationId: orgId,
      code: 'NEWCODE1',
      status: 'active',
    );
  }
}

Map<String, dynamic> _invitationRow({int id = 501}) => <String, dynamic>{
  'invitation_id': id,
  'organization_id': 10,
  'target_user_id': 402,
  'invited_by': 401,
  'status': 'pending',
  'created_at': '1700000000',
  'target_nickname': '李源炳',
  'target_account': 'lyb',
  'target_avatar': '',
  'inviter_name': '老板',
};

Widget _app(Widget home) => TranslationProvider(child: MaterialApp(home: home));

Future<void> _pump(WidgetTester tester, OrganizationApi api) async {
  await tester.pumpWidget(
    _app(OrgInviteColleaguesPage(orgId: '10', orgName: '演示企业', api: api)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('邀请 Tab：三种入口齐备；有码显示有效期提示、无引导条', (tester) async {
    await _pump(tester, _FakeInviteApi());
    expect(find.byKey(const ValueKey('org-invite-wechat')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-invite-face-to-face')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('org-invite-from-group')), findsOneWidget);
    expect(find.textContaining('邀请码 7 天内有效'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-invite-banner-action')),
      findsNothing,
    );
  });

  testWidgets('码缺失：引导条出现，点击生成后引导条消失（建码闭环）', (tester) async {
    final api = _FakeInviteApi(code: '');
    await _pump(tester, api);
    expect(find.textContaining('暂无有效邀请码'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('org-invite-banner-action')));
    await tester.pumpAndSettle();
    expect(api.createCalls, 1);
    expect(
      find.byKey(const ValueKey('org-invite-banner-action')),
      findsNothing,
    );
    expect(find.textContaining('邀请码 7 天内有效'), findsOneWidget);
  });

  testWidgets('可能的同事：展示富化昵称与邀请人；治理角色可见撤销', (tester) async {
    final api = _FakeInviteApi(
      canGovern: true,
      invitations: [OrgInvitation.fromJson(_invitationRow())],
    );
    await _pump(tester, api);
    await tester.tap(find.text('可能的同事'));
    await tester.pumpAndSettle();
    expect(find.text('李源炳'), findsOneWidget);
    expect(find.textContaining('老板'), findsOneWidget);
    expect(find.byKey(const ValueKey('org-invite-revoke-501')), findsOneWidget);
  });

  testWidgets('普通成员：撤销入口预先隐藏（服务端 403 兜底不变）', (tester) async {
    final api = _FakeInviteApi(
      canGovern: false,
      invitations: [OrgInvitation.fromJson(_invitationRow())],
    );
    await _pump(tester, api);
    await tester.tap(find.text('可能的同事'));
    await tester.pumpAndSettle();
    expect(find.text('李源炳'), findsOneWidget);
    expect(find.byKey(const ValueKey('org-invite-revoke-501')), findsNothing);
  });

  testWidgets('空态 CTA「去邀请同事」切回邀请 Tab', (tester) async {
    await _pump(tester, _FakeInviteApi());
    await tester.tap(find.text('可能的同事'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('org-invite-possible-cta')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('org-invite-possible-cta')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('org-invite-wechat')), findsOneWidget);
  });

  testWidgets('··· 菜单：复制/微信邀请/重新加载三行；重新加载只刷新不触发分享', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => null,
        );
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });
    await _pump(tester, _FakeInviteApi());
    await tester.tap(find.byKey(const ValueKey('org-invite-more')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('org-invite-sheet-copy')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('org-invite-sheet-wechat')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('org-invite-sheet-reload')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('org-invite-sheet-reload')));
    await tester.pumpAndSettle();
    // 菜单已关闭、页面仍在邀请 Tab（未触发分享链路）。
    expect(find.byKey(const ValueKey('org-invite-wechat')), findsOneWidget);
  });
}
