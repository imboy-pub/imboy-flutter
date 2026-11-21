// B.1 守护测试：OlmProtocol 参数校验 + 接口契约（纯测，不触发 vodozemac）。
// 真实 X3DH + Double Ratchet round-trip 需原生库，留真机集成测试。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_protocol.dart';
import 'package:imboy/service/e2ee/olm_protocol.dart';

RecipientDevice _dev(String id) =>
    RecipientDevice(deviceId: id, keyId: 'k-$id', publicKey: 'pub-$id');

void main() {
  group('OlmProtocol —— 接口契约', () {
    test('suite 为 ProtocolSuite.olm', () {
      expect(OlmProtocol().suite, ProtocolSuite.olm);
    });

    test('注册到 Registry 后可按 olm 元数据 resolve', () {
      E2eeProtocolRegistry.resetForTest();
      final olm = OlmProtocol();
      E2eeProtocolRegistry.register(olm);
      expect(
        E2eeProtocolRegistry.resolve({'protocol': 'olm', 'version': 1}),
        same(olm),
      );
      expect(E2eeProtocolRegistry.resolve({'e2ee_suite': 'OLM.V1'}), same(olm));
      E2eeProtocolRegistry.resetForTest();
    });
  });

  group('OlmProtocol.encrypt —— per-device 校验（不触发 vodozemac）', () {
    const ctx = E2eeContext(peerUid: 'peerU', scope: 'c2c');

    test('recipients 非单元素抛 ArgumentError（Olm 是 per-device 会话）', () {
      final p = OlmProtocol();
      expect(
        () => p.encrypt(plaintext: 'hi', recipients: const [], context: ctx),
        throwsArgumentError,
      );
      expect(
        () => p.encrypt(
          plaintext: 'hi',
          recipients: [_dev('d1'), _dev('d2')],
          context: ctx,
        ),
        throwsArgumentError,
      );
    });

    test('缺 context.peerUid 抛 ArgumentError', () {
      final p = OlmProtocol();
      expect(
        () => p.encrypt(
          plaintext: 'hi',
          recipients: [_dev('d1')],
          context: const E2eeContext(scope: 'c2c'),
        ),
        throwsArgumentError,
      );
    });

    test('未 initialize（无 self uid）抛 StateError，在触发 vodozemac 前拦截', () {
      final p = OlmProtocol();
      expect(
        () =>
            p.encrypt(plaintext: 'hi', recipients: [_dev('d1')], context: ctx),
        throwsStateError,
      );
    });
  });

  group('OlmProtocol.decrypt —— 缺字段兜底（不触发 vodozemac）', () {
    test('缺 peer_uid/peer_device_id 抛 E2eeDecryptException(no_device_key)', () {
      final p = OlmProtocol();
      expect(
        () => p.decrypt(ciphertext: 'ct', metadata: const {}),
        throwsA(
          isA<E2eeDecryptException>().having(
            (e) => e.reason,
            'reason',
            'no_device_key',
          ),
        ),
      );
      expect(
        () => p.decrypt(ciphertext: 'ct', metadata: const {'peer_uid': 'a'}),
        throwsA(isA<E2eeDecryptException>()),
      );
    });
  });

  group('OlmProtocol.encrypt metadata 白名单（源码合同，S-01:LOCAL:01）', () {
    // encrypt 写入消息顶层 e2ee 字段的 metadata 随帧出网（服务端与被动
    // 观察者可见）。新增字段 = 扩大可见元数据面；塞入明文/密钥字段则
    // 直接破坏 E2EE 承诺。锁死 metadata map 字面量的键集合。
    test('e2ee metadata 字段锁定为路由三元组 + peer 视角，无明文/密钥字段', () {
      final source = File('lib/service/e2ee/olm_protocol.dart')
          .readAsStringSync();
      const opening = 'E2eeCiphertext(res.ciphertext, {';
      final anchor = source.indexOf(opening);
      expect(anchor, greaterThan(0), reason: 'encrypt metadata 锚点漂移，请同步本守护');
      final keys = _topLevelMapKeys(
        source,
        anchor + 'E2eeCiphertext(res.ciphertext, '.length,
      );
      expect(keys, {
        'protocol',
        'version',
        'e2ee_suite',
        'peer_uid',
        'peer_device_id',
        'message_type',
        'session_id',
      });
    });
  });
}

/// 从 [source] 中位置 [openBraceIndex]（指向 `{`）起做花括号配对，
/// 收集顶层（depth==1）的 `'key':` 形式键名。
Set<String> _topLevelMapKeys(String source, int openBraceIndex) {
  var depth = 0;
  var i = openBraceIndex;
  var inString = false;
  var stringQuote = '';
  var stringStart = -1;
  final keys = <String>{};
  while (i < source.length) {
    final c = source[i];
    if (inString) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == stringQuote) {
        inString = false;
        if (depth == 1) {
          final content = source.substring(stringStart + 1, i);
          final tailEnd = i + 6 < source.length ? i + 6 : source.length;
          final tail = source.substring(i + 1, tailEnd);
          if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(content) &&
              RegExp(r'^\s*:').hasMatch(tail)) {
            keys.add(content);
          }
        }
      }
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      stringQuote = c;
      stringStart = i;
      i++;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) break;
    }
    i++;
  }
  return keys;
}
