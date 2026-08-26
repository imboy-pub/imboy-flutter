// P3-1：备份载荷 Megolm 段的纯函数守护 + 打包/解包往返实证。
//
// == 关闭的缺口 ==
//
// standard/gap-matrix.md B4：备份仅含 RSA 私钥 → 换设备后**群聊历史全灭**。
// 本文件证明 Megolm inbound session 进出备份载荷保真。
//
// == 守护 ==
//
// 1. 【正向可用性】pack→unpack 往返后 Megolm 段逐条一致——只写不读（或反之）必红；
// 2. 【范围纪律】Olm session pickle（`olm_*`）**不得**进备份——跨设备还原双棘轮
//    会 key reuse / ratchet 分叉。收集器只认 megolm 前缀，且往返后全包不含该值；
// 3. 【向后兼容】v1 旧备份无该字段 → 解析为空 map 而非抛错（缺可选段不得让
//    整包恢复失败，否则老用户的 RSA 私钥也恢复不了）；
// 4. 【上限】超 kMaxMegolmSessions 截断，不撑爆载荷；
// 5. 【脏数据韧性】非字符串值 / 空键单条跳过，不整包丢弃。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/megolm_backup_section.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';

const String _pw = 'TestPass123';
// 合成 fixture，非真实密钥（packBackupBytes 只做不透明字符串搬运）
const String _priv =
    '-----BEGIN PRIVATE KEY-----\nFAKE\n-----END PRIVATE KEY-----'; // gitleaks:allow
const String _pub =
    '-----BEGIN PUBLIC KEY-----\nFAKE\n-----END PUBLIC KEY-----'; // gitleaks:allow

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('collectMegolmSection（收集范围纪律）', () {
    test('只收 megolm_inbound_ 前缀；Olm pickle / 群旗标一律不进备份', () {
      final section = collectMegolmSection({
        'megolm_inbound_c2c:sess-A': 'key-A',
        'megolm_inbound_1900000000000:sess-B': 'key-B',
        // 以下都不得进备份
        'olm_account_pickle': 'olm-acc', // 双棘轮发送态：还原会 key reuse
        'olm_session_1001:did-x': 'olm-sess',
        'group_e2ee_mode_1900000000000': '1', // 服务端权威，可重拉
        'e2ee_private_key': 'rsa-priv', // 另有专门字段
      });

      expect(section.keys.toSet(), {'c2c:sess-A', '1900000000000:sess-B'});
      expect(section['c2c:sess-A'], 'key-A');
      expect(section.keys.any((k) => k.startsWith('olm')), isFalse);
    });

    test('空值条目跳过', () {
      expect(
        collectMegolmSection({
          'megolm_inbound_c2c:s1': '',
          'megolm_inbound_c2c:s2': 'v',
        }),
        {'c2c:s2': 'v'},
      );
    });

    test('超上限截断而非撑爆载荷', () {
      final all = <String, String>{};
      for (var i = 0; i < kMaxMegolmSessions + 50; i++) {
        all['${kMegolmInboundPrefix}g:s$i'] = 'k$i';
      }
      expect(collectMegolmSection(all).length, kMaxMegolmSessions);
    });
  });

  group('parseMegolmSection（向后兼容 + 脏数据韧性）', () {
    test('缺字段（v1 旧备份载荷）→ 空 map，不抛错', () {
      expect(parseMegolmSection(null), isEmpty);
      expect(parseMegolmSection('not-a-map'), isEmpty);
      expect(parseMegolmSection(123), isEmpty);
    });

    test('非字符串值 / 空键单条跳过，其余保留', () {
      expect(
        parseMegolmSection({'g:s1': 'ok', 'g:s2': 42, '': 'ek', 'g:s3': ''}),
        {'g:s1': 'ok'},
      );
    });
  });

  group('megolmRestoreEntries（回填补前缀）', () {
    test('键补回 megolm_inbound_ 前缀', () {
      expect(megolmRestoreEntries({'c2c:s1': 'v1'}), {
        'megolm_inbound_c2c:s1': 'v1',
      });
    });

    test('空键/空值不产生垃圾写入项', () {
      expect(megolmRestoreEntries({'': 'v', 'k': ''}), isEmpty);
    });
  });

  group('pack/unpack 往返（正向可用性）', () {
    test('Megolm 段逐条保真，且 Olm pickle 不出现在包内任何位置', () async {
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _pw,
        privateKey: _priv,
        publicKey: _pub,
        deviceId: 'dev-EXAMPLE',
        keyId: 'key-EXAMPLE',
        secureEntriesForTest: const {
          'megolm_inbound_c2c:sess-A': 'exported-key-A',
          'megolm_inbound_1900000000000:sess-B': 'exported-key-B',
          'olm_account_pickle': 'must-not-appear',
        },
      );

      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: _pw,
      );

      // 既有字段不回归
      expect(restored['private_key'], _priv);
      expect(restored['key_id'], 'key-EXAMPLE');

      final section = restored[kMegolmSectionKey] as Map<String, String>;
      expect(section, {
        'c2c:sess-A': 'exported-key-A',
        '1900000000000:sess-B': 'exported-key-B',
      });
      expect(jsonEncode(restored).contains('must-not-appear'), isFalse);
    }, timeout: const Timeout(Duration(minutes: 2)));

    test('无群会话时段为空但字段存在（与 v1 旧包可区分）', () async {
      final bytes = await E2EELocalBackupService.packBackupBytes(
        password: _pw,
        privateKey: _priv,
        publicKey: _pub,
        deviceId: 'dev-EXAMPLE',
        keyId: 'key-EXAMPLE',
        secureEntriesForTest: const {'e2ee_private_key': 'rsa'},
      );
      final restored = await E2EELocalBackupService.unpackBackupBytes(
        bytes: bytes,
        password: _pw,
      );
      expect(restored[kMegolmSectionKey], isEmpty);
      expect(restored['private_key'], _priv);
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
