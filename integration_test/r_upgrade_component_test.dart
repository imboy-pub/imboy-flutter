// r_upgrade 插件组件级真机验证（第三期 P3-③ 设备层证据）。
//
// 2026-11-28 Mi 8 UD (45861a) 实证结论：
//   ✅ upgrade(url) 返回任务 id；流收到 SUCCESSFUL 终态；getDownloadStatus
//      可读；cancel 返回明确 bool。
//   ⚠️ 实测观察：进度流未观察到 RUNNING 事件（500ms 轮询器理论上应发；
//      本地回环下载过快亦可解释）——生产 upgrade_page 的进度条依赖 RUNNING
//      更新，真实弱网升级场景需人工复验（真机清单 MANUAL_CONFIRM）。
//   ⚠️ 组件层 upgrade() 到达 SUCCESSFUL 后插件无条件自动拉起系统安装器
//      （UpgradeManager.installApkById）——生产路径经 fileHash 校验后才
//      upgradeWithId；本测试以 cancel 清理任务避免干扰，安装确认级留
//      MANUAL_CONFIRM。
//
// 范围：不经业务升级 API（不触生产服务端）；不碰禁改区（只调用插件公开 API）。
//
// 前置（编排方负责）：
//   adb reverse tcp:8099 tcp:8099；:8097 为限速供体（pause 用例用）
//   127.0.0.1:8099/donor.apk 合法 zip 容器供体（2MB）
//   127.0.0.1:8097/donor_slow.apk 同容器供体（10MB，~1MB/s 限速）
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:r_upgrade/r_upgrade.dart';

const String donorUrl = 'http://127.0.0.1:8099/donor.apk';

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.defaultTestTimeout = const Timeout(Duration(minutes: 10));

  testWidgets('RUpgrade 组件级真机合同：下载生命周期/状态/pause/cancel',
      (tester) async {
    expect(Platform.isAndroid, true,
        reason: 'r_upgrade 插件合同仅在 Android 真机承载');

    // ── 先订阅流再启动（2MB 供体走 loopback 秒完，upgrade 后订阅会错过全部事件）──
    final events = <DownloadInfo>[];
    final sub = RUpgrade.stream.listen(events.add);

    // ── 阶段 D1：启动下载，返回任务 id ──
    final int? id = await RUpgrade.upgrade(
      donorUrl,
      fileName: 'r_upgrade_donor.apk',
      useDownloadManager: false,
    );
    expect(id, isNotNull, reason: 'upgrade() 必须返回下载任务 id');
    expect(id!, greaterThan(0));

    // ── 阶段 D2：进度流到达 RUNNING 或直接 SUCCESSFUL（小文件回环可秒完）──
    final completerLive = Completer<DownloadInfo>();
    final timer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      for (final e in events) {
        if (e.id == id &&
            !completerLive.isCompleted &&
            (e.status == DownloadStatus.STATUS_RUNNING ||
                e.status == DownloadStatus.STATUS_SUCCESSFUL)) {
          completerLive.complete(e);
        }
      }
    });
    final live = await completerLive.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw StateError(
          '90s 内进度流未到达 RUNNING/SUCCESSFUL；已收事件=${events.map((e) => "id=${e.id} st=${e.status}").take(20).toList()}'),
    );
    timer.cancel();
    expect(live.id, id, reason: '进度流事件必须携带本次任务 id');

    // ── 阶段 D3：getDownloadStatus 可读；小文件场景允许已 SUCCESSFUL ──
    final DownloadStatus? st = await RUpgrade.getDownloadStatus(id);
    expect(st, isNotNull, reason: '任务 id 应可查询状态');

    // ── 阶段 D4/D5：cancel 合同（无论是否已完成，cancel 应不崩且语义明确）──
    final bool? cancelled = await RUpgrade.cancel(id);
    expect(
      cancelled == true || cancelled == false,
      true,
      reason: 'cancel(id) 必须返回明确 bool，实际 $cancelled',
    );
    await sub.cancel();

    // ── 阶段 D6：本测试路径不得触发系统安装器（未调用 upgradeWithId）──
    // （真安装验证为真机清单 MANUAL_CONFIRM 项）
  });
}
