import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_page.dart';
import 'package:imboy/page/contact/contact_setting_tag/contact_setting_tag_provider.dart';

/// 备注标签页 widget 流程测试（5-2）。
///
/// 覆盖（对应 fn:contact:people_info_more_page:002/003 备注/标签编辑面，
/// 真实 UI 位于 contact_setting_tag_page.dart）：
///   流程A 回显与初始按钮态：备注初值=peerRemark，未变更时完成按钮熄灭；
///         标签行空态显示「添加标签」。
///   流程B 修改备注 → 按钮点亮 → 保存成功：changeRemark 收到 uid+新值，
///         onRemarkChanged 回调透传，pop(新值) 返回调用页。
///   流程C 40 字上限：输入 45 字符被截断为 40。
///   流程D 清空文本：按钮熄灭（onChanged 的非空条件）。
///   流程E 服务端失败：changeRemark=false 不回调、不离开页面。
///
/// 网络隔离：ContactSettingTagNotifier.changeRemark 由 Spy 覆写
/// （不触 ContactApi/ContactRepo）。
/// 运行：flutter test test/unit_test/page/contact/contact_setting_tag_widget_flow_test.dart

class _HostPage extends StatelessWidget {
  const _HostPage();

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('host'));
}

class SpyContactSettingTagNotifier extends ContactSettingTagNotifier {
  SpyContactSettingTagNotifier({this.changeRemarkResult = true});

  final bool changeRemarkResult;

  int changeRemarkCalls = 0;
  String? lastUid;
  String? lastRemark;

  @override
  ContactSettingTagState build() => const ContactSettingTagState();

  @override
  Future<bool> changeRemark(String uid, String remark) async {
    changeRemarkCalls++;
    lastUid = uid;
    lastRemark = remark;
    return changeRemarkResult;
  }
}

Future<SpyContactSettingTagNotifier> _openPage(
  WidgetTester tester, {
  required SpyContactSettingTagNotifier spy,
  required ValueChanged<String> onRemarkChanged,
  String peerRemark = '老王',
}) async {
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [contactSettingTagProvider.overrideWith(() => spy)],
        child: MaterialApp(builder: AppLoading.init(), home: const _HostPage()),
      ),
    ),
  );
  await tester.pump();

  final ctx = tester.element(find.byType(_HostPage));
  unawaited(
    Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        builder: (_) => ContactSettingTagPage(
          peerId: '1000000xx',
          peerAvatar: '',
          peerAccount: 'wang_acct',
          peerNickname: '王大力',
          peerGender: 1,
          peerTitle: '',
          peerSign: '',
          peerRegion: '',
          peerSource: '通过搜索添加',
          peerRemark: peerRemark,
          peerTag: '',
          onRemarkChanged: onRemarkChanged,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return spy;
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
  testWidgets('流程A 回显与初始按钮态：备注初值/按钮熄灭/标签空态', (tester) async {
    final spy = await _openPage(
      tester,
      spy: SpyContactSettingTagNotifier(),
      onRemarkChanged: (_) {},
    );

    // 回显：controller 初值 = peerRemark
    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.controller!.text, '老王', reason: '备注初值必须回显 peerRemark');
    expect(field.maxLength, 40, reason: '备注上限 40 字');
    // 未变更：完成按钮熄灭
    expect(_doneButton(tester).onPressed, isNull, reason: '未变更时按钮必须熄灭');
    // 标签行存在且空态显示添加标签
    expect(find.byKey(const Key('contact_tag_row')), findsOneWidget);
    expect(find.text(t.common.addTag), findsOneWidget);
    expect(spy.changeRemarkCalls, 0);
  });

  testWidgets('流程B 修改备注→按钮点亮→保存成功：透传回调并 pop 新值', (tester) async {
    final spy = SpyContactSettingTagNotifier();
    String? reported;
    await _openPage(tester, spy: spy, onRemarkChanged: (v) => reported = v);

    await tester.enterText(find.byType(CupertinoTextField), '王大力');
    await tester.pump();
    expect(_doneButton(tester).onPressed, isNotNull, reason: '有变更时按钮点亮');

    // 直调按钮回调：底部按钮位于测试视口之外，tap 几何命中不可靠
    // （与 confirm_new_friend 流程C 同款处理）。
    _doneButton(tester).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(spy.changeRemarkCalls, 1);
    expect(spy.lastUid, '1000000xx');
    expect(spy.lastRemark, '王大力');
    expect(reported, '王大力', reason: 'onRemarkChanged 必须透传新备注（父页即时刷新契约）');
    // pop(trimmedText) 回宿主页
    expect(find.byType(ContactSettingTagPage), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('流程C 40 字上限：45 字符输入被截断', (tester) async {
    final spy = await _openPage(
      tester,
      spy: SpyContactSettingTagNotifier(),
      onRemarkChanged: (_) {},
    );

    const input = '一二三四五六七八九零一二三四五六七八九零一二三四五六七八九零一二三四五六七八九零一';
    await tester.enterText(find.byType(CupertinoTextField), input);
    await tester.pump();

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.controller!.text.length, 40, reason: '输入超长必须被截断为 40 字');
    expect(spy.changeRemarkCalls, 0);
  });

  testWidgets('流程D 清空文本：按钮熄灭（非空条件）', (tester) async {
    final spy = await _openPage(
      tester,
      spy: SpyContactSettingTagNotifier(),
      onRemarkChanged: (_) {},
    );

    await tester.enterText(find.byType(CupertinoTextField), '临时');
    await tester.pump();
    expect(_doneButton(tester).onPressed, isNotNull);

    await tester.enterText(find.byType(CupertinoTextField), '   ');
    await tester.pump();
    expect(_doneButton(tester).onPressed, isNull, reason: '空白备注不得点亮按钮');
    expect(spy.changeRemarkCalls, 0);
  });

  testWidgets('流程E 服务端失败：不透传回调、不离开页面', (tester) async {
    final spy = SpyContactSettingTagNotifier(changeRemarkResult: false);
    var reported = 0;
    await _openPage(tester, spy: spy, onRemarkChanged: (_) => reported++);

    await tester.enterText(find.byType(CupertinoTextField), '王大力');
    await tester.pump();
    _doneButton(tester).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(spy.changeRemarkCalls, 1);
    expect(reported, 0, reason: '失败不得通知父页');
    expect(
      find.byType(ContactSettingTagPage),
      findsOneWidget,
      reason: '失败留在本页',
    );
  });
}
