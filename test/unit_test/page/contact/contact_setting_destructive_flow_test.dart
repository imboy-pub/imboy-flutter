import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/contact_setting/contact_setting_page.dart';
import 'package:imboy/page/contact/contact_setting/contact_setting_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';

/// 联系人设置页破坏性流程 widget 测试（一段流程覆盖多个功能行）。
///
/// 覆盖（对应 fn:contact:people_info_more_page:001/004/005/006/007/008/010，
/// 真实 UI 位于 contact_setting_page.dart，功能行页面归属偏差已记入
/// F00 receipt，不改写台账原始行）：
///   流程A 删除联系人：红字入口 → 二次确认（备注回显）→ 取消不删除；
///         确认后调用删除，服务端失败（spy=false）时不离开页面。
///   流程B 黑名单开关：开/关确认框文案区分、取消不切换、图标红/灰联动。
///   流程C 举报：actionSheet 弹出四种理由面板（不提交、不发包）。
///
/// 网络隔离：ContactSettingNotifier 全部方法由 Spy 覆写（记录调用并返回
/// 可控值）；不点举报理由、不确认黑名单，避免触发 DenylistApi/ReportApi。
/// 运行：flutter test test/unit_test/page/contact/contact_setting_destructive_flow_test.dart
class SpyContactSettingNotifier extends ContactSettingNotifier {
  SpyContactSettingNotifier({this.initialInDenylist = false});

  final bool initialInDenylist;
  int deleteCalls = 0;
  int toggleCalls = 0;
  bool deleteResult = false;

  @override
  ContactSettingState build() =>
      ContactSettingState(isInDenylist: initialInDenylist, peerRemark: '老王');

  @override
  Future<void> initData(String peerId) async {}

  @override
  Future<bool> deleteContact(String uid) async {
    deleteCalls++;
    return deleteResult;
  }

  @override
  Future<bool> toggleDenylist({
    required String peerId,
    required bool addToDenylist,
    required Map<String, dynamic> peerData,
  }) async {
    toggleCalls++;
    return true;
  }
}

ContactSettingPage _page() => const ContactSettingPage(
  peerId: '1000000xx',
  peerAccount: 'wang_acct',
  peerAvatar: '',
  peerTitle: '',
  peerNickname: '王大力',
  peerGender: 1,
  peerSign: '',
  peerRegion: '',
  peerSource: '通过搜索添加',
  peerRemark: '老王',
  peerTag: '',
);

Future<SpyContactSettingNotifier> _pump(
  WidgetTester tester, {
  bool initialInDenylist = false,
  bool deleteResult = false,
}) async {
  // 每个 ProviderScope 用全新 spy 实例（Notifier 不可跨 container 复用）。
  final spy = SpyContactSettingNotifier(initialInDenylist: initialInDenylist)
    ..deleteResult = deleteResult;
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [contactSettingProvider.overrideWith(() => spy)],
        child: MaterialApp(builder: AppLoading.init(), home: _page()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return spy;
}

void main() {
  testWidgets('流程A-1 删除联系人：红字入口 → 二次确认含备注回显 → 取消不删除', (tester) async {
    final spy = await _pump(tester);

    // 删除入口存在且 destructive 渲染为 iosRed。
    // 该 tile 的 title 是 Center(child: Text(...))，样式经 DefaultTextStyle
    // 穿透（见 ios_settings_ui.dart 注释），Text.style 本身为 null。
    final deleteTile = find.text(t.common.deleteContact);
    expect(deleteTile, findsOneWidget);
    final inheritedStyle = DefaultTextStyle.of(tester.element(deleteTile))
        .style;
    expect(
      inheritedStyle.color,
      AppColors.getIosRed(Brightness.light),
      reason: 'fn:…:001 删除联系人必须使用破坏性红字',
    );

    // 点击 → 二次确认框：标题 + 内容回显备注（备注优先于昵称）
    await tester.tap(deleteTile);
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    expect(find.text(t.common.deleteContact), findsNWidgets(2));
    expect(
      find.text(t.common.tipDeleteContact(param: '老王')),
      findsOneWidget,
      reason: 'fn:…:004 确认框内容必须回显备注（备注非空时不回退昵称）',
    );

    // 取消 → 框关闭且未调用删除
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsNothing);
    expect(spy.deleteCalls, 0, reason: '取消后不得发起删除调用');
  });

  testWidgets('流程A-2 删除联系人：确认后调用删除，服务端失败不离开页面', (tester) async {
    final spy = await _pump(tester, deleteResult: false);

    await tester.tap(find.text(t.common.deleteContact));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.common.buttonConfirm).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(spy.deleteCalls, 1, reason: '确认后应恰好调用一次删除');
    expect(
      find.byType(ContactSettingPage),
      findsOneWidget,
      reason: 'fn:…:005 服务端删除失败时不得跳转首页（先 API 后本地的保护语义）',
    );
  });

  testWidgets('流程B-1 黑名单开关（未拉黑）：加入确认文案 + 取消不切换 + 图标非红', (tester) async {
    final spyOff = await _pump(tester);
    CupertinoSwitch sw = tester.widget(find.byType(CupertinoSwitch));
    expect(sw.value, isFalse);
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.nosign)).color,
      isNot(AppColors.getIosRed(Brightness.light)),
      reason: 'fn:…:010 未拉黑时图标不得为红色',
    );
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(
      find.text(t.common.addedToDenylistTips),
      findsOneWidget,
      reason: 'fn:…:006 加入黑名单必须弹确认框说明后果',
    );
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isFalse,
    );
    expect(spyOff.toggleCalls, 0, reason: '取消后不得切换黑名单');
  });

  testWidgets('流程B-2 黑名单开关（已拉黑）：移出确认文案 + 图标红', (tester) async {
    final spyOn = await _pump(tester, initialInDenylist: true);
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isTrue,
      reason: 'fn:…:010 spy 初始 isInDenylist=true 时开关应渲染为开',
    );
    expect(
      tester.widget<Icon>(find.byIcon(CupertinoIcons.nosign)).color,
      AppColors.getIosRed(Brightness.light),
      reason: 'fn:…:010 拉黑后图标应变红',
    );
    await tester.tap(find.byType(CupertinoSwitch));
    await tester.pumpAndSettle();
    expect(
      find.text(t.common.confirmRemoveFromDenylist),
      findsOneWidget,
      reason: 'fn:…:007 移出黑名单必须弹确认框',
    );
    await tester.tap(find.text(t.common.buttonCancel));
    await tester.pumpAndSettle();
    expect(
      tester.widget<CupertinoSwitch>(find.byType(CupertinoSwitch)).value,
      isTrue,
    );
    expect(spyOn.toggleCalls, 0);
  });

  testWidgets('流程C 举报：actionSheet 弹出四种理由面板（不提交）', (tester) async {
    final spy = await _pump(tester);

    await tester.tap(find.text(t.complaint.complaint));
    await tester.pumpAndSettle();
    expect(find.text(t.complaintReason.spam), findsOneWidget);
    expect(find.text(t.complaintReason.harassment), findsOneWidget);
    expect(find.text(t.complaintReason.inappropriate), findsOneWidget);
    expect(
      find.text(t.complaintReason.other),
      findsOneWidget,
      reason: 'fn:…:008 举报面板必须提供四种理由',
    );
    // 不点任何理由：不触发 ReportApi（fn:…:009 提交路径由真实后端流程覆盖）
    expect(spy.toggleCalls, 0);
    expect(spy.deleteCalls, 0);
  });
}
