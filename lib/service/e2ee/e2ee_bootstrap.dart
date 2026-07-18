/// E2EE 协议注册引导（ADR 02 §2.2）。
///
/// 这是唯一 import 具体协议实现的地方——业务层（E2EEService）只跟
/// [E2eeProtocolRegistry] 抽象对话。[ensureRegistered] 幂等，可在启动序列
/// （AppInitializer）或首次 encrypt/decrypt 前调用，保证 resolve 前已注册。
///
/// MLS 不注册（ADR 02 §8 占位；`all()` 因此不含 mls）。
library;

import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/megolm_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';
import 'package:imboy/service/e2ee/rsa_legacy_protocol.dart';

class E2eeBootstrap {
  const E2eeBootstrap._();

  static bool _registered = false;

  /// 幂等注册 olm / megolm / rsa-oaep 三套件。重复调用无副作用。
  static void ensureRegistered() {
    if (_registered) return;
    E2eeProtocolRegistry.register(OlmProtocol());
    E2eeProtocolRegistry.register(MegolmProtocol());
    E2eeProtocolRegistry.register(RsaLegacyProtocol()); // 仅 decrypt
    _registered = true;
  }

  /// 仅测试用：重置引导标志 + 清空注册表。
  static void resetForTest() {
    _registered = false;
    E2eeProtocolRegistry.resetForTest();
  }
}
