// Patrol 链路握手验证（诊断用，不依赖 IMBoy 业务代码）。
//
// 目的：把「patrol 基础设施是否通」与「IMBoy 启动是否卡住」两件事分开。
//   - 本文件不调 app.main()，只挂一个最小 widget 树 + 调一次原生通道
//   - 若本文件 PASS 而 app_launch_test 挂起 → 问题在 IMBoy 启动流程
//   - 若本文件也挂起 → 问题在 patrol 握手 / instrumentation 层
//
// 运行：
//   patrol test --target integration_test/patrol/handshake_test.dart \
//     --device XWE6R19916004085

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('握手：Dart 测试可运行且原生通道可调用', ($) async {
    // ① Dart 侧：最小 widget 树，不触碰 IMBoy 的任何初始化
    await $.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('patrol-handshake-ok'))),
      ),
    );
    expect($('patrol-handshake-ok'), findsOneWidget);

    // ② 原生侧：调一次 native 通道，证明 Dart ↔ 原生 automator 双向通
    //    此刻不该有权限弹窗，预期返回 false —— 重点是「能返回」而非返回值。
    final visible = await $.platform.mobile.isPermissionDialogVisible(
      timeout: const Duration(seconds: 2),
    );
    expect(visible, isA<bool>(), reason: '原生通道应返回布尔值，挂起则说明握手未完成');
  });
}
