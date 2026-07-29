// Patrol 冒烟：验证 Patrol 链路打通，并覆盖 integration_test 碰不到的原生层。
//
// 与 integration_test/smoke/smoke_test.dart 的区别：
//   smoke_test  → 进程内，只能看见 Flutter widget，原生权限弹窗会挡住它且无法关闭
//   本文件      → 同样进程内跑 Dart，但可通过 $.native 操作系统级 UI
//
// 运行（Android 真机）：
//   source scripts/test.env
//   patrol test --target integration_test/patrol/app_launch_test.dart \
//     --dart-define=APP_ENV=pro \
//     --dart-define=API_BASE_URL=https://pro.imboy.pub \
//     --dart-define=TEST_PHONE="$TEST_PHONE" \
//     --dart-define=TEST_PASSWORD="$TEST_PASSWORD"

import 'package:flutter/material.dart';
// findsWidgets 等 matcher 不由 patrol_finders 导出，需直接取自 flutter_test
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/main.dart' as app;
import 'package:patrol/patrol.dart';

void main() {
  patrolTest('App 启动：放行原生权限弹窗后主界面可见', ($) async {
    app.main();

    // 启动动画 + 路由初始化；网络初始化最多 15s（与 smoke_test 对齐）
    await $.pump(const Duration(seconds: 10));
    // patrol 的 pumpAndSettle：duration 是帧间隔，timeout 才是等待上限
    await $.pumpAndSettle(timeout: const Duration(seconds: 5));

    // ── Patrol 独有能力：处理系统权限弹窗 ──
    // IMBoy 冷启动可能弹通知/存储/定位授权，这类弹窗在 Flutter 视图之外，
    // integration_test 既看不见也点不掉，会导致后续断言全部失败。
    // 最多放行 3 次（华为 EMUI 会连续弹多个）。
    for (var i = 0; i < 3; i++) {
      if (!await $.platform.mobile.isPermissionDialogVisible(
        timeout: const Duration(seconds: 3),
      )) {
        break;
      }
      await $.platform.mobile.grantPermissionWhenInUse();
      await $.pumpAndSettle();
    }

    expect(
      $(MaterialApp),
      findsOneWidget,
      reason: 'MaterialApp 应唯一存在，未找到则启动流程异常',
    );
    expect(
      $(Scaffold),
      findsWidgets,
      reason: '启动后应有 Scaffold，实际未找到 — App 可能崩溃',
    );
  });
}
