import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_provider.dart';
import 'package:imboy/page/contact/confirm_new_friend/confirm_new_friend_page.dart';
import 'package:imboy/page/contact/confirm_new_friend/confirm_new_friend_provider.dart';
import 'package:imboy/page/contact/new_friend/new_friend_provider.dart';
import 'package:imboy/service/storage.dart';

/// 确认新好友页 widget 流程测试（5-1）。
///
/// 覆盖（对应 fn:contact:new_friend / confirm 域功能行，校准注记见
/// acceptance-calibration-notes.json；格验收仍以正式设备格为准）：
///   流程A 回显与默认值：验证消息斜体、备注初值=申请人昵称、标签空态
///         「添加标签」、完成按钮文案。
///   流程B 修改备注后提交：confirm 收到 remark=新值 + 当前登录者资料 +
///         空 tag 拼接格式；成功后重载新好友列表（initData 1 次）并 pop。
///   流程C 提交中禁用：confirm 未返回时完成按钮不可再点（转圈）。
///   流程D 服务端失败：confirm=false 时不重载列表、不离开页面。
///   流程E 已选标签的提交格式：tag 以 "tag," 拼接进 payload。
///
/// 网络隔离：ConfirmNewFriendNotifier / NewFriendNotifier /
/// NewFriendRemindNotifier 全部由 Spy 覆写；登录态经
/// SharedPreferences.setMockInitialValues 注入（UserRepoLocal.current
/// 走 StorageService→SharedPreferences，无需 GetX/SQLite）。
/// 运行：flutter test test/unit_test/page/contact/confirm_new_friend_widget_flow_test.dart

class _HostPage extends StatelessWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('host'));
}

class SpyConfirmNewFriendNotifier extends ConfirmNewFriendNotifier {
  SpyConfirmNewFriendNotifier({
    bool confirmResult = true,
    String initialTag = '',
  }) : _confirmResult = confirmResult,
       initialTag = initialTag;

  bool _confirmResult;
  final String initialTag;

  int confirmCalls = 0;
  Map<String, dynamic>? lastPayload;
  String? lastFrom;
  String? lastTo;

  /// 非 null 时 confirm 挂起直到 complete —— 用于模拟网络在途
  /// （async 方法体无 await 点时同步完成，转圈态一帧即逝，无法断言）。
  Completer<bool>? gate;

  @override
  ConfirmNewFriendState build() => ConfirmNewFriendState(peerTag: initialTag);

  @override
  Future<bool> confirm({
    required String from,
    required String to,
    required Map<String, dynamic> payload,
  }) async {
    confirmCalls++;
    lastFrom = from;
    lastTo = to;
    lastPayload = payload;
    if (gate != null) return gate!.future;
    return _confirmResult;
  }
}

class SpyNewFriendNotifier extends NewFriendNotifier {
  int initDataCalls = 0;

  @override
  NewFriendState build() => NewFriendState();

  @override
  Future<void> initData() async {
    initDataCalls++;
  }
}

class SpyNewFriendRemindNotifier extends NewFriendRemindNotifier {
  int countCalls = 0;

  @override
  Set<String> build() => <String>{};

  @override
  Future<void> countReminders() async {
    countCalls++;
  }
}

const _peerPayload =
    '{"apply_id":1,"from_nickname":"申请人","from_avatar":"","scene":"search"}';

Future<void> _openPage(
  WidgetTester tester, {
  required SpyConfirmNewFriendNotifier spyConfirm,
  required SpyNewFriendNotifier spyList,
  required SpyNewFriendRemindNotifier spyRemind,
  String nickname = '申请人',
}) async {
  // UserRepoLocal.current 从 SharedPreferences 读登录者资料。
  // 注意：flutter_test_config 已在框架初始化阶段执行
  // setMockInitialValues({}) + StorageService.init()；此刻再调
  // setMockInitialValues 不会替换 StorageService 已缓存的 store——
  // 必须直接写 StorageService（setMap 走已绑定实例）。
  await StorageService.setMap(Keys.currentUser, {
    'uid': '116151519723915264',
    'account': '50008',
    'nickname': '当前用户',
    'avatar': '',
    'sign': '',
    'gender': 1,
    'mobile': '13800000001',
    'email': '',
  });

  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          confirmNewFriendProvider.overrideWith(() => spyConfirm),
          newFriendProvider.overrideWith(() => spyList),
          newFriendRemindProvider.overrideWith(() => spyRemind),
        ],
        child: MaterialApp(builder: AppLoading.init(), home: const _HostPage()),
      ),
    ),
  );
  await tester.pump();

  final ctx = tester.element(find.byType(_HostPage));
  // 不 await：push 的 Future 在页面 pop 时才完成，测试体必须继续 pump。
  unawaited(
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => ConfirmNewFriendPage(
          from: '116151603672909824',
          to: '116151519723915264',
          msg: '我是申请人',
          nickname: nickname,
          payload: _peerPayload,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

CupertinoButton _doneButton(WidgetTester tester) =>
    tester.widget<CupertinoButton>(
      find
          .ancestor(
            of: find.text(t.common.buttonAccomplish),
            matching: find.byType(CupertinoButton),
          )
          .first,
    );

void main() {
  testWidgets('流程A 回显与默认值：验证消息/备注初值/标签空态/完成按钮', (tester) async {
    await _openPage(
      tester,
      spyConfirm: SpyConfirmNewFriendNotifier(),
      spyList: SpyNewFriendNotifier(),
      spyRemind: SpyNewFriendRemindNotifier(),
    );

    // 验证消息原文展示（带引号装饰）
    expect(find.text('"我是申请人"'), findsOneWidget);
    // 备注初值 = 申请人昵称
    expect(find.text('申请人'), findsWidgets);
    // 标签空态 subtitle = 添加标签
    expect(find.text(t.common.addTag), findsOneWidget);
    // 完成按钮存在且可点
    expect(find.text(t.common.buttonAccomplish), findsOneWidget);
    expect(_doneButton(tester).onPressed, isNotNull);
  });

  testWidgets('流程B 修改备注后提交：payload 带新备注与当前登录者资料，成功后重载并返回', (tester) async {
    final spyConfirm = SpyConfirmNewFriendNotifier();
    final spyList = SpyNewFriendNotifier();
    final spyRemind = SpyNewFriendRemindNotifier();
    await _openPage(
      tester,
      spyConfirm: spyConfirm,
      spyList: spyList,
      spyRemind: spyRemind,
    );

    await tester.enterText(find.byType(CupertinoTextField), '王大力');
    await tester.pump();
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(spyConfirm.confirmCalls, 1, reason: 'confirm 恰好提交一次');
    expect(spyConfirm.lastFrom, '116151603672909824');
    expect(spyConfirm.lastTo, '116151519723915264');
    final to = spyConfirm.lastPayload!['to'] as Map<String, dynamic>;
    expect(to['remark'], '王大力', reason: '提交修改后的备注');
    expect(to['account'], '50008', reason: 'payload.to 携带当前登录者资料');
    expect(to['nickname'], '当前用户');
    expect(to['tag'], '', reason: '未选标签时提交空串（页面契约：tag 为 "标签," 拼接格式的空态）');
    expect(spyList.initDataCalls, 1, reason: '成功后必须重载新好友列表（父页按钮刷新契约）');
    // countReminders 位于被 spy 覆写的 confirm() 内部实现，spy 下不触发；
    // 角标重算契约由 provider 实现注释钉住（confirm_new_friend_provider.dart:131）。
    // pop 成功回到宿主页
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ConfirmNewFriendPage), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('流程C 提交中：confirm 未返回前完成按钮禁用且出现转圈', (tester) async {
    final spyConfirm = SpyConfirmNewFriendNotifier();
    final spyList = SpyNewFriendNotifier();
    final spyRemind = SpyNewFriendRemindNotifier();
    await _openPage(
      tester,
      spyConfirm: spyConfirm,
      spyList: spyList,
      spyRemind: spyRemind,
    );

    // 模拟网络在途：gate 挂起 confirm，直接调用按钮回调（不依赖几何命中）。
    final gate = Completer<bool>();
    spyConfirm.gate = gate;
    _doneButton(tester).onPressed!.call();
    await tester.pump();
    expect(spyConfirm.confirmCalls, 1, reason: '回调必须已触发 confirm');
    expect(
      find.byType(CupertinoActivityIndicator),
      findsOneWidget,
      reason: '提交在途必须显示转圈',
    );
    // 转圈态下按钮 child 已换成指示器（文本消失），经指示器反查按钮。
    final busyButton = tester.widget<CupertinoButton>(
      find
          .ancestor(
            of: find.byType(CupertinoActivityIndicator),
            matching: find.byType(CupertinoButton),
          )
          .first,
    );
    expect(busyButton.onPressed, isNull, reason: '提交在途按钮必须禁用');

    // 放行 → 成功 → 重载列表 → pop 回宿主页（路由过渡 ~300ms，一次泵足）
    gate.complete(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ConfirmNewFriendPage), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('流程D 服务端失败：不重载列表、不离开页面', (tester) async {
    final spyConfirm = SpyConfirmNewFriendNotifier(confirmResult: false);
    final spyList = SpyNewFriendNotifier();
    final spyRemind = SpyNewFriendRemindNotifier();
    await _openPage(
      tester,
      spyConfirm: spyConfirm,
      spyList: spyList,
      spyRemind: spyRemind,
    );

    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(spyConfirm.confirmCalls, 1);
    expect(spyList.initDataCalls, 0, reason: '失败不得重载列表（父页按钮维持原状）');
    expect(
      find.byType(ConfirmNewFriendPage),
      findsOneWidget,
      reason: '失败留在本页引导用户重试',
    );
  });

  testWidgets('流程E 已选标签的提交格式：tag 以 "tag," 拼接', (tester) async {
    final spyConfirm = SpyConfirmNewFriendNotifier(initialTag: '同事');
    final spyList = SpyNewFriendNotifier();
    final spyRemind = SpyNewFriendRemindNotifier();
    await _openPage(
      tester,
      spyConfirm: spyConfirm,
      spyList: spyList,
      spyRemind: spyRemind,
    );

    // 标签 subtitle 回显已选标签
    expect(find.text('同事'), findsOneWidget);
    await tester.tap(find.text(t.common.buttonAccomplish));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final to = spyConfirm.lastPayload!['to'] as Map<String, dynamic>;
    expect(to['tag'], '同事,', reason: '历史契约：tag 以尾随逗号拼接提交');
  });
}
