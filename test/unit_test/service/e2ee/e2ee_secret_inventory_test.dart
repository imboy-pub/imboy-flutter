import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/e2ee_secret_inventory.dart';

/// E2EE-015：logout 秘密清理 orchestrator。
///
/// 每类秘密先写 canary，purge 后逐项确认不存在（playbook 验收第 1 条）；
/// 任一清理失败/残留必须抛 [E2eeSecretPurgeException]（fail-closed，
/// 阻止切入另一账号）。
void main() {
  /// 每类秘密一个 canary：RSA 身份/历史/分片、Olm account/pickle key/session、
  /// Megolm inbound、群旗标、safety number 信任态、SQLCipher key、MLS 预留、
  /// backup/recovery 元数据。
  Map<String, String> seedCanaries() => {
    'e2ee_private_key': 'rsa-priv',
    'e2ee_public_key': 'rsa-pub',
    'e2ee_private_key_history_kid1': 'rsa-old',
    'e2ee_device_id': 'did-1',
    'e2ee_key_id': 'kid-1',
    'e2ee_key_created_at': '2026',
    'e2ee_shard_s1': 'shard',
    'e2ee_shard_id_list': '["s1"]',
    'e2ee_shard_metadata_list': '[]',
    'e2ee_backup_passphrase': 'pw-canary',
    'olm_account_pickle': 'acct',
    'olm_pickle_key': 'pk',
    'olm_session_u2:d9': 'sess',
    'megolm_inbound_u1:gid7:sess1': 'inbound',
    'megolm_history_grant_gid7:sess1': 'grant',
    'megolm_restored_history_grant_gid7:sess1': 'restored-grant',
    'group_e2ee_mode_gid7': '1',
    'safety_number_verified_9001': '1',
    'safety_number_devset_9001': '["d1","d2"]',
    'safety_number_devset_baseline_9001': '["d1"]',
    'db_cipher_key_uid5': 'sqlcipher',
    'mls_reserved_future': 'mls',
  };

  test('purgeAll 删除全部秘密类别且不动非秘密键', () async {
    final store = seedCanaries();
    store['secure_token'] = 'jwt'; // 非 E2EE 键，由 token 服务负责
    store['unrelated_key'] = 'keep';
    // 声明豁免：设备级信任锚 / 凭据键不随账号清理（矩阵中的有意保留项）
    store['compliance_key_pin_v1'] = '{"key_id":"k","fingerprint":"fp"}';
    store['upload_key'] = 'upload-cred';
    var memoryCleared = false;
    var artifactPurged = false;

    final inventory = E2eeSecretInventory(
      readAll: () async => Map.of(store),
      deleteKey: (key) async => store.remove(key),
      clearMemoryCaches: [() => memoryCleared = true],
      purgeArtifacts: [() async => artifactPurged = true],
    );

    await inventory.purgeAll();

    // 逐类 canary 复核为不存在
    for (final key in seedCanaries().keys) {
      expect(store.containsKey(key), isFalse, reason: 'residual: $key');
    }
    expect(store['secure_token'], 'jwt');
    expect(store['unrelated_key'], 'keep');
    // 豁免键不被 purge 误伤（它们的清理责任在各自 owner）
    expect(store['compliance_key_pin_v1'], isNotNull);
    expect(store['upload_key'], isNotNull);
    expect(memoryCleared, isTrue);
    expect(artifactPurged, isTrue);
  });

  test('单个键删除失败：其余键仍被清理，最终抛异常并点名失败键', () async {
    final store = seedCanaries();
    final inventory = E2eeSecretInventory(
      readAll: () async => Map.of(store),
      deleteKey: (key) async {
        if (key == 'olm_account_pickle') throw Exception('keychain busy');
        store.remove(key);
      },
    );

    await expectLater(
      inventory.purgeAll(),
      throwsA(
        isA<E2eeSecretPurgeException>().having(
          (e) => e.failures.join(','),
          'failures',
          contains('olm_account_pickle'),
        ),
      ),
    );
    // 其余键不因单点失败而放弃
    expect(store.keys.toList(), ['olm_account_pickle']);
  });

  test('删除静默无效（键残留）：复核阶段 fail-closed 抛异常', () async {
    final store = seedCanaries();
    final inventory = E2eeSecretInventory(
      readAll: () async => Map.of(store),
      deleteKey: (key) async {}, // 静默 no-op，模拟平台层假成功
    );

    await expectLater(
      inventory.purgeAll(),
      throwsA(isA<E2eeSecretPurgeException>()),
    );
  });

  test('内存缓存清理回调抛错：仍执行存储清理，最终抛异常', () async {
    final store = seedCanaries();
    final inventory = E2eeSecretInventory(
      readAll: () async => Map.of(store),
      deleteKey: (key) async => store.remove(key),
      clearMemoryCaches: [() => throw StateError('cache boom')],
    );

    await expectLater(
      inventory.purgeAll(),
      throwsA(isA<E2eeSecretPurgeException>()),
    );
    expect(store, isEmpty, reason: '内存清理失败不应放弃存储清理');
  });

  test('readAll 本身失败：fail-closed 抛异常', () async {
    final inventory = E2eeSecretInventory(
      readAll: () async => throw Exception('keychain unavailable'),
      deleteKey: (key) async {},
    );
    await expectLater(
      inventory.purgeAll(),
      throwsA(isA<E2eeSecretPurgeException>()),
    );
  });

  test('matchesSecretKey 覆盖全部前缀类别', () {
    const secrets = [
      'e2ee_private_key',
      'olm_pickle_key',
      'megolm_inbound_x',
      'megolm_history_grant_g1:s1',
      'megolm_restored_history_grant_g1:s1',
      'group_e2ee_mode_g1',
      'safety_number_verified_9001',
      'safety_number_devset_9001',
      'safety_number_devset_baseline_9001',
      'db_cipher_key_u1',
      'mls_group_state',
    ];
    for (final key in secrets) {
      expect(E2eeSecretInventory.matchesSecretKey(key), isTrue, reason: key);
    }
    expect(E2eeSecretInventory.matchesSecretKey('secure_token'), isFalse);
    expect(E2eeSecretInventory.matchesSecretKey('unrelated'), isFalse);
  });

  // ─── C05 inventory 报告一致性 ──────────────────────────────────────────────

  test('报告矩阵与前缀清单双向一致（清单即 purge 覆盖）', () {
    final prefixes = E2eeSecretInventory.secretKeyPrefixes;
    final matrixPrefixes = E2eeSecretInventory.categories
        .map((c) => c.keyPrefix)
        .toList();
    // 每个矩阵条目的前缀必须真实存在于 purge 前缀清单
    for (final p in matrixPrefixes) {
      expect(prefixes.contains(p), isTrue, reason: '矩阵前缀不在 purge 清单: $p');
    }
    // purge 前缀清单的每一项都必须有矩阵条目（无孤儿前缀）
    for (final p in prefixes) {
      expect(matrixPrefixes.contains(p), isTrue, reason: 'purge 前缀无矩阵条目: $p');
    }
    // 无重复条目
    expect(matrixPrefixes.toSet().length, matrixPrefixes.length);
  });

  test('矩阵声明 backup=false / logout=清理 / 换号=清理 的基线不变式', () {
    for (final c in E2eeSecretInventory.categories) {
      expect(c.inOsBackup, isFalse, reason: '${c.id} 声称会进 OS 备份，需人工复核');
      expect(c.clearedOnLogout, isTrue, reason: '${c.id} 未纳入 logout 清理');
      expect(c.clearedOnAccountSwitch, isTrue, reason: '${c.id} 未纳入换号清理');
    }
  });

  test('report() 输出包含每个类别与豁免项', () {
    final report = E2eeSecretInventory.report();
    for (final c in E2eeSecretInventory.categories) {
      expect(report, contains('[${c.id}]'));
      expect(report, contains(c.keyPrefix));
    }
    for (final exempt in E2eeSecretInventory.declaredExemptions.keys) {
      expect(report, contains(exempt));
    }
    // 备份/清理结论进入报告
    expect(report, contains('osBackup=no'));
    expect(report, contains('logout=purge'));
  });

  test('豁免键确实不在 purge 范围（豁免与清理互斥）', () {
    for (final exempt in E2eeSecretInventory.declaredExemptions.keys) {
      expect(
        E2eeSecretInventory.matchesSecretKey(exempt),
        isFalse,
        reason: '$exempt 在豁免表但也被 purge 前缀命中（矛盾）',
      );
    }
  });
}
