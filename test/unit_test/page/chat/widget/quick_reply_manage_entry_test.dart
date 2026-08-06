import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/chat/widget/chat_input.dart';
import 'package:imboy/service/storage.dart';

/// BUG#101 回归：快捷回复条的「管理」入口必须**不滚动即可触达**。
///
/// 原实现把「管理」当成横向 ListView 的末尾一项（index == replies.length）。
/// 8 条默认快捷回复在真机 360pt 逻辑宽下把它顶出屏幕，而横滑手势会让输入框
/// 失焦 → 键盘收起 → 整条栏消失，用户永远够不到。
///
/// ⚠️ 断言方式：`findsOneWidget` 在这里毫无意义 —— 懒构建的 ListView 根本不会
/// 构建屏幕外的 item，改动前它压根不存在；就算存在（换成非懒列表）也只说明
/// 「在 widget 树里」，不说明「在屏幕内」。所以这里用 `tester.getRect` 做布局
/// 断言，钉死按钮矩形完整落在 viewport 之内。
void main() {
  /// 华为 MRD_AL00 真机：720x1560 物理像素 / dpr 2.0 → 360x780 逻辑
  const physicalSize = Size(720, 1560);
  const devicePixelRatio = 2.0;
  const logicalWidth = 720 / devicePixelRatio;

  setUpAll(() async {
    Env.uploadKey = 'test_dummy_upload_key';
    Env.uploadScene = 'test_scene';
    IMBoyCacheManager.debugLogEnabled = false;
    await StorageService.to.setString(Keys.currentUid, 'tsid_uid_101');
  });

  tearDownAll(() async {
    IMBoyCacheManager.debugLogEnabled = true;
    await StorageService.to.remove(Keys.currentUid);
  });

  testWidgets('「管理」入口在 360pt 窄屏、无横向滚动的情况下完整可见', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;

    final composerHeight = ValueNotifier<double>(52);
    addTearDown(composerHeight.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const Spacer(),
                  ChatInput(
                    type: 'C2C',
                    peerId: 'peer_101',
                    onSendPressed: (_) async => true,
                    composerHeight: composerHeight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // 聚焦输入框 → 空文本 → 快捷回复条出现（_syncQuickRepliesVisibility）
    await tester.tap(find.byKey(const Key('chat_message_input')));
    // 快捷回复列表是异步从 StorageService 加载的，多 pump 几帧等它落地
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final manage = find.byKey(const Key('quick_reply_manage_button'));
    expect(manage, findsOneWidget, reason: '快捷回复条未渲染或「管理」入口缺失');

    final rect = tester.getRect(manage);

    // 核心断言：矩形完整落在 viewport 横向范围内 —— 不需要滑动就够得到
    expect(rect.left, greaterThanOrEqualTo(0), reason: '「管理」左边界越出屏幕左侧：$rect');
    expect(
      rect.right,
      lessThanOrEqualTo(logicalWidth),
      reason: '「管理」右边界越出屏幕右侧（原 BUG#101 现象）：$rect / 屏宽 $logicalWidth',
    );

    // DESIGN.md：最小触达区 ≥ 44x44pt
    expect(rect.width, greaterThanOrEqualTo(44));
    expect(rect.height, greaterThanOrEqualTo(44));

    // 至少还能看到 2 条快捷回复，固定尾部没把滚动区挤没
    expect(
      find.byType(ElevatedButton).evaluate().length,
      greaterThanOrEqualTo(2),
      reason: '固定尾部按钮把快捷回复挤得只剩 1 条以下',
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('「管理」不在横向滚动区内 —— 滚动快捷回复不改变它的位置', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = devicePixelRatio;

    final composerHeight = ValueNotifier<double>(52);
    addTearDown(composerHeight.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const Spacer(),
                  ChatInput(
                    type: 'C2C',
                    peerId: 'peer_101',
                    onSendPressed: (_) async => true,
                    composerHeight: composerHeight,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_message_input')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    final manage = find.byKey(const Key('quick_reply_manage_button'));
    final before = tester.getRect(manage);

    // 把快捷回复横向拖到底
    await tester.drag(find.byType(ListView).first, const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(tester.getRect(manage), before, reason: '「管理」跟着内容一起滚了，说明它仍在滚动区内');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
