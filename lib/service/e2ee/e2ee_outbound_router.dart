/// E2EE 发送侧路由（ADR 02 §4 / ADR 05 §4.2）。
///
/// 业务层只传入已选定的 [ProtocolSuite]；本路由通过
/// [E2eeProtocolRegistry] 找到协议插件并补齐双写期的通用信封。
library;

import 'package:imboy/service/e2ee/e2ee_protocol.dart';

class E2eeOutboundRouter {
  const E2eeOutboundRouter._();

  static Future<E2eeCiphertext> encrypt({
    required ProtocolSuite suite,
    required String plaintext,
    required List<RecipientDevice> recipients,
    required E2eeContext context,
    int? createdAtMs,
  }) async {
    final protocol = E2eeProtocolRegistry.resolve({
      'protocol': suite.protocol,
      'version': suite.version,
    });
    if (protocol.suite != suite) {
      throw StateError(
        'E2EE suite mismatch: selected=$suite, registered=${protocol.suite}',
      );
    }
    final encrypted = await protocol.encrypt(
      plaintext: plaintext,
      recipients: recipients,
      context: context,
    );
    final metadata = <String, dynamic>{
      ...encrypted.metadata,
      'e2ee': true,
      'e2ee_ver': suite.protocol == ProtocolSuite.rsa.protocol ? 1 : 2,
      'e2ee_suite': suite.legacyWire,
      'meta_version': 2,
      'protocol': suite.protocol,
      'version': suite.version,
      'cipher': suite.cipher,
      'created_at': createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
    };
    return E2eeCiphertext(encrypted.ciphertext, metadata);
  }
}
