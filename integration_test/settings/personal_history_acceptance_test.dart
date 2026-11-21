// integration_test/settings/personal_history_acceptance_test.dart
//
// 个人消息历史域设备端验收（MH-04 计划件；执行窗口=FL-15 客服完整旅程或
// MH-06 汇总前的真机窗口，小米 45861a）。本文件是可执行验收载体而非占位：
// 在真机上驱动 PersonalHistoryKeyService 的封包/恢复/轮换/撤销链路并核验
// 平台 KDF（native）分支真实参与。
//
// 红线：仅本地环境；无真实通知/外发；口令为合成 fixture；断言失败即红。
// 服务端面（upload/changes/disable）由 MH-02 后端套件与 FL 侧 API 验收覆盖，
// 本文件聚焦密钥域设备侧行为。夹具构造与单测
// （test/unit_test/service/personal_history_key_test.dart）同款。

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/auth_session_scope.dart';
import 'package:imboy/service/personal_history_key_service.dart';

class _DeviceSession extends ChangeNotifier implements AuthSessionReader {
  _DeviceSession();

  final String uid = '900071992547409930';
  var _transitioning = false;

  @override
  AuthSessionScope get current =>
      (uid: uid, generation: 21, transitioning: _transitioning);

  @override
  bool get transitionFailed => false;

  @override
  bool isCurrent(AuthSessionScope captured) =>
      !_transitioning && current == captured;

  void logout() {
    _transitioning = true;
    notifyListeners();
  }
}

PersonalHistoryKeyService _service({_DeviceSession? session}) {
  final client = PersonalHistoryKeyService(
    domain: 'local.device.acceptance',
    generation: 9,
    sessionReader: session ?? _DeviceSession(),
    authorization: ValueNotifier<bool>(true),
  );
  addTearDown(client.close);
  return client;
}

void main() {
  const password = 'device-acceptance-fixture';

  test('AT-PH01 设备端封包/恢复往返（平台 KDF 真实参与）', () async {
    final sealing = _service()..rotate(1);
    final wire = await sealing.sealPackage(1, password);
    expect(
      wire.keys,
      containsAll(<String>[
        'key_version',
        'kdf_meta',
        'wrapped_key',
        'integrity_hash',
      ]),
    );
    final restoring = _service();
    await restoring.restorePackage(Map<String, Object?>.from(wire), password);
    expect(wire['wrapped_key'], isA<String>());
  });

  test('AT-PH02 错误口令可分辨失败，不污染既有密钥', () async {
    final sealing = _service()..rotate(1);
    final wire = await sealing.sealPackage(1, password);
    final stranger = _service();
    expect(
      () => stranger.restorePackage(
        Map<String, Object?>.from(wire),
        'wrong-device-fixture',
      ),
      throwsA(isA<PersonalHistoryKeyException>()),
    );
  });

  test('AT-PH03 会话退出阻断迟到工作（安全退出清理）', () async {
    final session = _DeviceSession();
    final client = _service(session: session)..rotate(1);
    await client.sealPackage(1, password);
    session.logout();
    expect(
      () => client.sealPackage(2, password),
      throwsA(isA<PersonalHistoryKeyException>()),
    );
  });

  test('AT-PH04 封包线格式无口令/裸密钥', () async {
    final wire = await (_service()..rotate(1)).sealPackage(1, password);
    final blob = wire['wrapped_key']! as String;
    expect(blob.contains(password), isFalse);
    expect(blob.length, greaterThan(40));
    expect((wire['kdf_meta']! as Map)['alg'], isNotNull);
  });
}
