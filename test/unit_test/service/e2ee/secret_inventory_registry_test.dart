import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_secret_inventory.dart';

/// C05 secret/data inventory 对账：**源码中每个 secure storage 访问键**
/// 必须落在清单前缀（会被 logout/换号清理）或声明豁免（declaredExemptions）
/// 之一。新增写入键未登记时本测试失败——清单与 purge 覆盖的一致性由
/// 机器保证，不靠人工记忆。
///
/// 扫描口径：`StorageSecureService.to.<write|read|delete>(` 调用括号起
/// 400 字符内出现的第一个 `key: <表达式>`。`lib/service/storage_secure.dart`
/// 本身是通用封装层（key 为形参透传），排除在扫描外。
void main() {
  // 归类表：表达式（trim 后，去掉行尾 ')'）→ 期望类别。
  // 值为 {'prefix': '...'} 表示必须匹配该 purge 前缀；
  // {'exempt': '...'} 表示必须等于该豁免键；
  // {'passthrough': ...} 表示透传形态（备份恢复/局部变量），单独说明。
  final classification = <String, Map<String, String>>{
    // ── 字符串字面量 / 插值构造 ──
    "'\$_flagKeyPrefix\$gid'": const {'prefix': 'group_e2ee_mode_'},
    "'\$_inboundKeyPrefix\$storageScope:\$sessionId'": const {
      'prefix': 'megolm_inbound_',
    },
    "'\$kMegolmHistoryGrantPrefix\$storageScope:\$sessionId'": const {
      'prefix': 'megolm_history_grant_',
    },
    "'\$kMegolmHistoryGrantPrefix\$suffix'": const {
      'prefix': 'megolm_history_grant_',
    },
    "'\$kMegolmRestoredGrantPrefix\$suffix'": const {
      'prefix': 'megolm_restored_history_grant_',
    },
    // ── safety number 信任态（C05 verified 标记 + C07/AC-15 设备集合）──
    // 页面直写已收口到 SafetyNumberService（AC-15），表达式全部在 service 内。
    '_verifiedKeyPrefix + peerUid': const {'prefix': 'safety_number_verified_'},
    '_approvedDevsetKeyPrefix + peerUid': const {
      'prefix': 'safety_number_devset_',
    },
    // 局部变量：_checkDeviceSetDrift 内 baselineKey = _devsetBaselineKeyPrefix
    // + peerUid（safety_number_devset_ 前缀覆盖 devset_baseline_ 子族）
    'baselineKey': const {'prefix': 'safety_number_devset_'},
    'kE2eeBackupPassphraseSecureKey': const {'prefix': 'e2ee_'},
    // ── 常量（定义处值见各 service）──
    '_accountPickleStorageKey': const {'prefix': 'olm_'},
    '_lastFallbackRotationKey': const {'prefix': 'olm_'},
    '_pickleKeyStorageKey': const {'prefix': 'olm_'},
    '_storageKey(uid': const {'prefix': 'db_cipher_key_'},
    '_storageKey(ref': const {'prefix': 'utk_'},
    // E2EE 收藏 CK 版本链（CollectKeychain，PLAN 2026-10-24 §6）
    '_kCollectKeychainStorageKey': const {'prefix': 'collect_ck_'},
    '_tokenKey': const {'exempt': 'secure_token'},
    '_refreshTokenKey': const {'exempt': 'secure_refresh_token'},
    'oaLoginAttemptKey': const {'exempt': 'oa_inbound_login_attempt'},
    '_pinStorageKey': const {'exempt': 'compliance_key_pin_v1'},
    'Keys.publicKey': const {'exempt': 'public_key'},
    'Keys.privateKey': const {'exempt': 'private_key'},
    'Keys.uploadKey': const {'exempt': 'upload_key'},
    // ── 透传形态 ──
    // e2ee_local_backup_service 恢复：键来自备份内容本身（其键空间即清单前缀）
    'entry.key': const {'passthrough': 'backup_restore'},
  };

  test('源码中全部 secure storage 键都被清单或豁免覆盖', () {
    final found = <String>{};
    final libDir = Directory('lib');
    final files = libDir
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.endsWith('storage_secure.dart'));

    final callRe = RegExp(r'StorageSecureService\.to\.(?:write|read|delete)\(');
    final keyRe = RegExp(r'key:\s*([^,\n)]{1,80})');

    for (final file in files) {
      final source = file.readAsStringSync();
      for (final call in callRe.allMatches(source)) {
        final window = source.substring(
          call.end,
          call.end + 400 < source.length ? call.end + 400 : source.length,
        );
        final keyMatch = keyRe.firstMatch(window);
        if (keyMatch == null) continue;
        var expr = keyMatch.group(1)!.trim();
        // 裸 `key` 形参：仅允许三个已知安全位置——
        // olm_session_service（_sessionKey 局部变量，olm_ 前缀）、
        // e2ee_secret_inventory（purgeAll 透传 matchesSecretKey 过滤后的键）、
        // db_encryption_key_service（_storageKey(uid) 局部变量，db_cipher_key_ 前缀）
        if (expr == 'key') {
          expect(
            file.path,
            anyOf(
              contains('olm_session_service.dart'),
              contains('e2ee_secret_inventory.dart'),
              contains('db_encryption_key_service.dart'),
              // talk_record AI BYOK 适配层：key 由 _key() 派生
              // （talk_record_ai_v1_ 前缀），形参透传同上三个已知位置
              contains('talk_record_ai_credentials.dart'),
            ),
            reason: '${file.path} 出现裸 key: 形参，需在归类表中登记',
          );
          found.add('_bare_key@${file.path.split('/').last}');
          continue;
        }
        found.add(expr);
      }
    }

    // 每个实际出现的表达式必须已归类
    for (final expr in found) {
      if (expr.startsWith('_bare_key@')) {
        final file = expr.substring('_bare_key@'.length);
        if (file == 'olm_session_service.dart') {
          expect(
            E2eeSecretInventory.matchesSecretKey('olm_session_u1:d1'),
            isTrue,
            reason: '裸 key 形参应落在 olm_ 前缀',
          );
        } else if (file == 'db_encryption_key_service.dart') {
          expect(
            E2eeSecretInventory.matchesSecretKey('db_cipher_key_u1'),
            isTrue,
            reason: '裸 key 形参应落在 db_cipher_key_ 前缀',
          );
        } else if (file == 'talk_record_ai_credentials.dart') {
          expect(
            E2eeSecretInventory.matchesSecretKey(
              'talk_record_ai_v1_digest_minimax',
            ),
            isTrue,
            reason: '裸 key 形参应落在 talk_record_ai_v1_ 前缀',
          );
        } else {
          // e2ee_secret_inventory.dart：透传键先经 matchesSecretKey 过滤
          expect(file, 'e2ee_secret_inventory.dart');
        }
        continue;
      }
      expect(
        classification.containsKey(expr),
        isTrue,
        reason:
            '发现未登记的 secure storage 键表达式: $expr（请登记到 '
            'E2eeSecretInventory 清单或豁免表，并更新本测试归类表）',
      );
    }

    // 归类表不允许死条目（表达式从源码消失后应同步删除）
    for (final expr in classification.keys) {
      expect(
        found.contains(expr),
        isTrue,
        reason: '归类表条目在源码中已不存在（注册表漂移）: $expr',
      );
    }
  });

  test('归类表每个前缀/豁免与 inventory 定义一致', () {
    for (final entry in classification.values) {
      final prefix = entry['prefix'];
      if (prefix != null) {
        expect(
          E2eeSecretInventory.secretKeyPrefixes.contains(prefix),
          isTrue,
          reason: '归类表前缀不在 secretKeyPrefixes: $prefix',
        );
      }
      final exempt = entry['exempt'];
      if (exempt != null) {
        expect(
          E2eeSecretInventory.declaredExemptions.containsKey(exempt),
          isTrue,
          reason: '归类表豁免键不在 declaredExemptions: $exempt',
        );
      }
    }
  });

  test('豁免表键的清理责任方真实存在（防"豁免即遗忘"）', () {
    // secure_token / secure_refresh_token：SecureTokenStorageService.clear
    // 在 quitLogin 中调用（user_repo_local.dart）
    final quitLogin = File('lib/store/repository/user_repo_local.dart')
        .readAsStringSync();
    expect(quitLogin, contains('SecureTokenStorageService.clear'));
    // upload_key：loginAfter → initConfig 每次登录覆盖写
    expect(
      File('lib/config/init.dart')
          .readAsStringSync()
          .contains('Keys.uploadKey'),
      isTrue,
      reason: 'upload_key 豁免依赖「每次登录重新下发覆盖」，该写入点已不存在',
    );
  });
}
