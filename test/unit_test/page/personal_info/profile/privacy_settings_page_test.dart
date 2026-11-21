import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/personal_info/profile/profile_provider.dart';
import 'package:imboy/page/personal_info/profile/widgets/privacy_settings_page.dart';

/// UX-03:LOCAL:01 spy：记录隐私开关提交并模拟后端确认（成功回写 state），
/// 或按 [fail] 返回失败且不动 state（受控开关必须保持原位）。
class _RecordingProfileNotifier extends ProfileNotifier {
  _RecordingProfileNotifier(this._initial, this.updates, {this.fail = false});

  final ProfileState _initial;
  final List<(String, bool)> updates;
  final bool fail;

  @override
  ProfileState build() => _initial;

  @override
  Future<bool> updateUserInfo(String field, dynamic value) async {
    updates.add((field, value as bool));
    if (fail) return false;
    state = switch (field) {
      'allow_search' => state.copyWith(allowSearch: value),
      'allow_add_by_phone' => state.copyWith(allowAddByPhone: value),
      'allow_add_by_qr' => state.copyWith(allowAddByQR: value),
      'show_online_status' => state.copyWith(showOnlineStatus: value),
      'allow_nearby_visible' => state.copyWith(allowNearbyVisible: value),
      _ => state,
    };
    return true;
  }
}

GoRouter _router() {
  Widget stub(String label) => Scaffold(body: Center(child: Text(label)));
  return GoRouter(
    initialLocation: '/privacy',
    routes: [
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacySettingsPage()),
      GoRoute(
        path: '/logout_account',
        builder: (_, _) => stub('logout_account stub'),
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester, {
  ProfileState? initial,
  List<(String, bool)>? updates,
  bool fail = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(() {
    tester.view.resetDevicePixelRatio();
    tester.view.resetPhysicalSize();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileProvider.overrideWith(
          () => _RecordingProfileNotifier(
            initial ?? ProfileState(),
            updates ?? [],
            fail: fail,
          ),
        ),
      ],
      child: TranslationProvider(
        child: MaterialApp.router(routerConfig: _router()),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('online visibility switch defaults to off', (tester) async {
    final updates = <(String, bool)>[];
    await _pump(tester, updates: updates);

    expect(find.text('显示在线状态'), findsOneWidget);
    final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
    expect(switches, hasLength(5));
    expect(switches[3].value, isFalse);

    await _unmount(tester);
  });

  group('PrivacySettingsPage 入口可达（UX-03:LOCAL:01）', () {
    testWidgets('隐私权利面板完整：5 开关 + 清空记录 + 注销账号均在场', (tester) async {
      await _pump(tester);

      expect(find.text(t.common.searchSettings), findsOneWidget);
      expect(find.text(t.common.allowSearchByAccount), findsOneWidget);
      expect(find.text(t.common.allowAddByPhone), findsOneWidget);
      expect(find.text(t.common.allowAddByQR), findsOneWidget);
      expect(find.text(t.common.showOnlineStatus), findsOneWidget);
      expect(find.text(t.common.allowNearbyVisible), findsOneWidget);
      // 数据权利动作（清除/删除）是权利入口，任何开关状态都不得移除
      expect(find.text(t.common.clearChatRecords), findsOneWidget);
      expect(find.text(t.common.deleteAccountAction), findsOneWidget);
      expect(
        find.byType(Switch),
        findsNWidgets(5),
        reason: '隐私开关数量回归（新增/删除开关需同步更新本断言）',
      );

      await _unmount(tester);
    });

    testWidgets('全拒绝始态（所有隐私开关关闭）仍保留全部权利访问', (tester) async {
      await _pump(
        tester,
        initial: ProfileState(
          allowSearch: false,
          allowAddByPhone: false,
          allowAddByQR: false,
          showOnlineStatus: false,
          allowNearbyVisible: false,
        ),
      );

      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(5));
      for (final sw in switches) {
        expect(sw.value, isFalse, reason: '全拒绝态所有开关为关');
        expect(sw.onChanged, isNotNull, reason: '权限全拒后隐私面板控件不得被锁死（权利访问仍在）');
      }
      // 基础通讯与数据权利入口在全拒绝态下依旧在场
      expect(find.text(t.common.clearChatRecords), findsOneWidget);
      expect(find.text(t.common.deleteAccountAction), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('PrivacySettingsPage 开关合同（UX-03:LOCAL:01 拒绝与撤回）', () {
    testWidgets('关闭 allow_search 提交 allow_search=false 并经后端确认后生效', (
      tester,
    ) async {
      final updates = <(String, bool)>[];
      await _pump(tester, updates: updates);

      final first = find.byType(Switch).first;
      expect(tester.widget<Switch>(first).value, isTrue);
      await tester.tap(first);
      await tester.pumpAndSettle();

      expect(updates, [
        ('allow_search', false),
      ], reason: '拒绝开关必须把拒绝决定提交到对应后端字段');
      expect(
        tester.widget<Switch>(first).value,
        isFalse,
        reason: '后端确认后开关才落位（受控组件）',
      );

      await _unmount(tester);
    });

    testWidgets('更新失败：开关保持原位，不产生假成功投影', (tester) async {
      final updates = <(String, bool)>[];
      await _pump(tester, updates: updates, fail: true);

      final first = find.byType(Switch).first;
      await tester.tap(first);
      await tester.pumpAndSettle();

      expect(updates, [('allow_search', false)], reason: '用户手势已提交');
      expect(
        tester.widget<Switch>(first).value,
        isTrue,
        reason: '后端未确认时开关必须弹回原位，不得显示假成功状态',
      );
      // 失败不清空其它权利入口
      expect(find.text(t.common.clearChatRecords), findsOneWidget);
      expect(find.text(t.common.deleteAccountAction), findsOneWidget);

      await _unmount(tester);
    });
  });

  group('PrivacySettingsPage 数据权利动作（UX-03:LOCAL:01/02）', () {
    testWidgets('清空聊天记录必须显式确认：取消不执行任何动作', (tester) async {
      await _pump(tester);

      await tester.tap(find.text(t.common.clearChatRecords));
      await tester.pumpAndSettle();
      expect(
        find.byType(CupertinoAlertDialog),
        findsOneWidget,
        reason: '破坏性动作必须先出确认对话框',
      );
      expect(find.text(t.common.buttonCancel), findsOneWidget);

      await tester.tap(find.text(t.common.buttonCancel));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(
        find.byType(PrivacySettingsPage),
        findsOneWidget,
        reason: '取消后留在隐私面板',
      );
      expect(find.text('logout_account stub'), findsNothing);

      await _unmount(tester);
    });

    testWidgets('注销账号：确认后进入 /logout_account（真实后端状态页），本页不伪造状态', (tester) async {
      await _pump(tester);

      await tester.tap(find.text(t.common.deleteAccountAction));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsOneWidget);

      await tester.tap(find.text(t.common.buttonConfirm));
      await tester.pumpAndSettle();
      expect(
        find.text('logout_account stub'),
        findsOneWidget,
        reason: '删除申请/执行/完成/保留状态由 /logout_account 按后端真实状态区分，本页只做入口',
      );

      await _unmount(tester);
    });
  });

  group('PrivacySettingsPage 联系方式（UX-03:LOCAL:02 不擅填）', () {
    testWidgets('隐私面板不自行填充任何联系方式（联系渠道仅来自政策文档）', (tester) async {
      await _pump(tester);

      final contactPattern = RegExp(
        r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
        r'|1[3-9]\d{9}'
        r'|mailto:'
        r'|tel:',
      );
      for (final text in tester.widgetList<Text>(find.byType(Text))) {
        final content = text.data ?? '';
        expect(
          contactPattern.hasMatch(content),
          isFalse,
          reason:
              '隐私面板不得自填联系方式（发现: "$content"）；'
              '联系渠道由外部审定的政策文档承载',
        );
      }

      await _unmount(tester);
    });
  });
}
