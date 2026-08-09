import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/component/ui/app_loading.dart';

/// 真机取证背景（2026-08-09）：uiautomator dump 在 toast 的 2s 生命周期内
/// 连续抓取都读不到 toast 文本。
///
/// 结论（widget 测试实测）：**机制问题，非 dump 时机**——
/// 1. `find.text` 能找到渲染的 toast 文本（用户视觉可见）；
/// 2. 但 `tester.getSemantics(find.text(...)).label` 实测为 ''——
///    EasyLoading 的 container 用 Opacity 驱动动画（container.dart:142-167），
///    opacity 为 0 时 Opacity 从语义树排除子树，且 isPersistentCallbacks
///    分支把动画启动推迟到帧尾（container.dart:102-112），toast 文本
///    从不稳定地出现在 Flutter 语义树 → uiautomator 读不到是必然。
///
/// 所以本用例锁定可见性契约（渲染 + 自动消失），语义树不可达是
/// EasyLoading 组件层机制，记为无障碍发现项，不在此断言。
///
/// ⚠️ 不能 `await AppLoading.showError()`：easyloading 的 show* 返回的
/// future 要等 overlay 的 AnimationController 动画 complete 才完成
/// （container.dart:87-92），testWidgets 里 await 会阻塞事件循环、
/// pump 不进 → 死锁超时（曾实测 10min TimeoutException）。
/// 一律 unawaited + 显式 pump 推进动画帧。真实 app 事件循环自动流转，
/// 无此问题。
void main() {
  testWidgets('showError toast 文本渲染且自动消失', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: AppLoading.init(),
        home: const Scaffold(body: SizedBox()),
      ),
    );

    unawaited(AppLoading.showError('转账参数不合法'));
    // pumpAndSettle 代替手工 pump 序列：EasyLoading 的展示链是
    // postFrame forward → 动画 complete → completer.complete →
    // whenComplete 里注册 2s Timer，帧序脆弱，settle 到无帧调度最稳
    await tester.pumpAndSettle();

    // toast 文本渲染在 overlay（用户可见）
    expect(find.text('转账参数不合法'), findsOneWidget);

    // 默认 duration 2s：Timer 触发 dismiss → reverse 动画 → _reset
    // markNeedsBuild → 再 settle 让 overlay rebuild，toast 才真正移除
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('转账参数不合法'), findsNothing);
  });

  testWidgets('连续两次 showError 后显示的是最后一次（覆盖式）', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: AppLoading.init(),
        home: const Scaffold(body: SizedBox()),
      ),
    );

    unawaited(AppLoading.showError('转账参数不合法'));
    await tester.pumpAndSettle();
    // sendTransfer 失败时内部先弹服务端 msg，_handleSend 再弹通用提示，
    // 两次 showError 连续调用，用户最终应看到后一次（覆盖式）。
    unawaited(AppLoading.showError('操作失败，请稍后再试'));
    await tester.pumpAndSettle();

    expect(find.text('操作失败，请稍后再试'), findsOneWidget);
    expect(find.text('转账参数不合法'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
