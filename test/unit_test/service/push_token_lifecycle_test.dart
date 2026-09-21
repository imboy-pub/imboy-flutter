// EPGZ-07 W1 — Flutter push token 生命周期 RED 测试骨架
//
// 状态：RED / skip 占位（pending impl）。Dart 不支持调用未实现符号
//（编译期失败，无法像 Erlang 侧那样以 undefined module 表达 RED），
// 因此未实现合同一律以 `skip: 'pending impl: ...'` 占位，断言体已按
// 最终合同写好（纯 Map/字符串比较，不引用未来符号）；W2 实现接线后
// 移除 skip、并把白盒复现函数替换为对真实 API 的调用，必须转 GREEN。
//
// 合同来源：
// - 计划 §7.4（JPush）：注册、刷新、注销、失效 token、前台、后台点击、
//   冷启动点击、登出后不导航。
// - 字段错位清单：imboy docs/reference/push-provider-jpush-research-2026-09-21.md §2
//   （后端 push/register 合同 = {device_id, device_type, platform, token}，
//    device_type ∈ {android, ios, web}，platform ∈ {fcm, apns, web_push, jpush}）
//
// 现状（基线 60bc4925）关键事实（详见 docs/push-jpush-flutter-research-2026-09-21.md）：
// - lib/store/api/push_api.dart register 实际发送 {token, platform, device_id}：
//   platform 塞的是 'android'/'ios'（device_type 的值），且完全缺 device_type 键
//   ——两条 DB CHECK 均违反，注册必然 500（错位 1/2）。
// - lib/service/push_notification_service.dart 的 registerToken/unregisterToken
//   在 lib/ 无任何调用方（错位 4）；quitLogin 清理链不含 push token 注销。
//
// 运行：flutter test test/unit_test/service/push_token_lifecycle_test.dart
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// 白盒复现：当前 push_api.dart PushApi.register 的 body 构造（现状快照）。
// W2 修复字段错位后，本函数必须与实现同步更新为合同形状，或删除。
// ---------------------------------------------------------------------------
Map<String, dynamic> currentRegisterBodySnapshot({
  required String token,
  required String platform,
  required String deviceId,
}) {
  // lib/store/api/push_api.dart:24 逐字复现
  return {'token': token, 'platform': platform, 'device_id': deviceId};
}

/// 目标合同：修复后的注册 body（EPGZ-07 W2-F1）。
/// 与后端 user_device_handler push_register + push_token CHECK 对齐。
Map<String, dynamic> contractRegisterBody({
  required String token,
  required String deviceType,
  required String provider,
  required String deviceId,
}) {
  return {
    'token': token,
    'device_type': deviceType,
    'platform': provider,
    'device_id': deviceId,
  };
}

const Set<String> kContractDeviceTypes = {'android', 'ios', 'web'};
const Set<String> kContractProviders = {'fcm', 'apns', 'web_push', 'jpush'};

String pendingImpl(String what) => 'pending impl: EPGZ-07 W2 $what';

void main() {
  // -------------------------------------------------------------------------
  // 1. 字段错位快照（现状文档化，可运行；W2 修复后翻转为本组合同断言）
  // -------------------------------------------------------------------------
  group('字段错位快照 — 当前 register body 违反后端合同（EPGZ-07 错位 1/2）', () {
    test('现状 body 缺 device_type 键（违反 chk_push_token_device_type）', () {
      // 现状：push_notification_service.dart:197 只算出一个 platform 值
      final body = currentRegisterBodySnapshot(
        token: 'fcm-token-x',
        platform: 'android',
        deviceId: 'did-1',
      );
      // 文档化断言：当前确实缺键（W2 修复后本断言应翻转为存在且 ∈ 合同值域）
      expect(
        body.containsKey('device_type'),
        isFalse,
        reason: '现状快照：W2 修复后请翻转本断言并改用真实 API',
      );
    });

    test('现状 platform 塞的是 device_type 的值（android/ios 不在 provider 值域）', () {
      final body = currentRegisterBodySnapshot(
        token: 'fcm-token-x',
        platform: 'android', // push_notification_service.dart:197 现状
        deviceId: 'did-1',
      );
      // 文档化断言：'android' 不是合法 provider（fcm/apns/web_push/jpush）
      expect(
        kContractProviders.contains(body['platform']),
        isFalse,
        reason: '现状快照：platform 应为 provider 值，当前误传 device_type 值',
      );
    });
  });

  // -------------------------------------------------------------------------
  // 2. 注册请求字段合同（W2-F1/F2 修复后启用）
  // -------------------------------------------------------------------------
  group('注册请求字段合同 — {device_id, device_type, platform, token}', () {
    test(
      'Android + JPush 组合：device_type=android、platform=jpush',
      skip: pendingImpl(
        '修复 push_api.dart register body（F1）+ push_notification_service provider 语义拆分（F2）',
      ),
      () {
        final body = contractRegisterBody(
          token: 'rid-jpush-001',
          deviceType: 'android',
          provider: 'jpush',
          deviceId: 'did-android-1',
        );
        expect(
          body.keys,
          containsAll(['device_id', 'device_type', 'platform', 'token']),
        );
        expect(body['device_type'], 'android');
        expect(body['platform'], 'jpush');
        expect(kContractDeviceTypes.contains(body['device_type']), isTrue);
        expect(kContractProviders.contains(body['platform']), isTrue);
        // W2 落地后：改为直接断言真实 PushApi.register 构造的 body（移除本地复现）
      },
    );

    test(
      'Android + FCM 组合仍兼容：platform=fcm 不受 JPush 接入影响',
      skip: pendingImpl('F1 修复后启用，验证 FCM 兼容保留'),
      () {
        final body = contractRegisterBody(
          token: 'fcm-token-x',
          deviceType: 'android',
          provider: 'fcm',
          deviceId: 'did-android-1',
        );
        expect(body['platform'], 'fcm');
        expect(body['device_type'], 'android');
      },
    );

    test(
      'iOS 组合不受影响：device_type=ios、platform=apns（一期 JPush 仅 Android）',
      skip: pendingImpl('F1 修复后启用'),
      () {
        final body = contractRegisterBody(
          token: 'apns-token-x',
          deviceType: 'ios',
          provider: 'apns',
          deviceId: 'did-ios-1',
        );
        expect(body['device_type'], 'ios');
        expect(body['platform'], 'apns');
      },
    );

    test(
      'provider 非法值（android/ios 误传）必须被客户端侧拒绝/纠正',
      skip: pendingImpl(
        'F2 修复后启用：_registerTokenToServer 拆分 deviceType 与 provider',
      ),
      () {
        // 修复后：即使底层 Platform.isIOS 分支逻辑回退，也不允许把
        // device_type 值当作 provider 发送
        const wrongProvider = 'android';
        expect(kContractProviders.contains(wrongProvider), isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 3. token 生命周期合同（J1/J2：注册、刷新、注销）
  // -------------------------------------------------------------------------
  group('token 生命周期', () {
    test(
      '登录成功后触发 registerToken（loginAfter 接线）',
      skip: pendingImpl(
        'loginAfter 调 PushNotificationService.instance.registerToken（F4）',
      ),
      () {
        // 现状：registerToken 在 lib/ 无调用方（错位 4）。
        // 合同：loginAfter 建立 uid/token 后注册 push token；
        // 未登录或无 token 时静默跳过（push_notification_service 现有守卫保留）。
        expect(true, isTrue);
      },
    );

    test(
      'token 刷新后重新注册（JPush registrationID 变化 / FCM onTokenRefresh）',
      skip: pendingImpl('JPush SDK token 刷新回调 → setToken/re-register 接线'),
      () {
        // 合同：刷新事件携带新 token，且仅在已登录时重注册；
        // 同设备旧 token 由后端 upsert 先 deactivate（见后端 J1 合同）。
        expect(true, isTrue);
      },
    );

    test('注销请求只带 device_id', skip: pendingImpl('W2 复核 unregister body 合同'), () {
      // 后端合同：POST /api/v1/push/unregister body 仅 {device_id}
      final body = <String, dynamic>{'device_id': 'did-android-1'};
      expect(json.encode(body), '{"device_id":"did-android-1"}');
    });
  });

  // -------------------------------------------------------------------------
  // 4. 登出清理合同（J2 + §7.4「登出后不导航」）
  // -------------------------------------------------------------------------
  group('登出清理', () {
    test(
      'quitLogin 先注销 push token 再清本地状态',
      skip: pendingImpl(
        'quitLogin 接入 PushNotificationService.instance.unregisterToken（F4）',
      ),
      () {
        // 现状：quitLogin（user_repo_local.dart:236-309）清理链含 storage/E2EE/
        // token/WS/DB，但不含 push token 注销——登出后后端仍会向该设备推送。
        expect(true, isTrue);
      },
    );

    test(
      '登出后通知点击不得导航到会话（登出后不导航）',
      skip: pendingImpl('W2 在 _navigateByResult 增加 isLoggedIn 守卫'),
      () {
        // 现状：_navigateByResult 仅重试 context 挂载，无登录态守卫。
        expect(true, isTrue);
      },
    );
  });

  // -------------------------------------------------------------------------
  // 5. 失效 token（后端侧下线为主，客户端侧不重复清理；合同一致性）
  // -------------------------------------------------------------------------
  group('失效 token', () {
    test(
      '客户端对失效 token 的本地处理：接受后端下线事实，不无限重注册',
      skip: pendingImpl('W2 确定重注册退避策略（与后端 deactivate_by_token 语义对齐）'),
      () {
        expect(true, isTrue);
      },
    );
  });
}
