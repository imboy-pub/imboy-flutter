import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/service/e2ee_health_check_service.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/service/storage.dart';

/// 发生率度量（「[加密消息] 占位发生率压到一辈子遇不到」的验证仪表）：
/// - E2EEDecryptFailureMetrics：累计发生口径（分桶 / 去重 / 归一化）
/// - E2EEHealthCheckService.failedPayloadReason：存量盘点的分桶核心（纯函数）
/// - E2EEFailureInventory：不可解 / 可恢复分类
class _PrivateReason {
  @override
  String toString() => throw StateError('must not stringify private reason');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await StorageService.init();
    await E2EEDecryptFailureMetrics.resetForTest();
  });

  group('E2EEDecryptFailureMetrics.normalizeReason', () {
    test('null 与空串归 unknown', () {
      expect(E2EEDecryptFailureMetrics.normalizeReason(null), 'unknown');
      expect(E2EEDecryptFailureMetrics.normalizeReason(''), 'unknown');
    });

    test('已知 reason 保留分类', () {
      expect(
        E2EEDecryptFailureMetrics.normalizeReason('invalid_e2ee'),
        'invalid_e2ee',
      );
      expect(
        E2EEDecryptFailureMetrics.normalizeReason('no_device_envelope'),
        'no_device_envelope',
      );
    });
  });

  test('任意对象不被转换为日志内容', () {
    expect(
      E2EEDecryptFailureMetrics.normalizeReason(_PrivateReason()),
      'unknown',
    );
  });

  test('真实指标日志不输出原因、历史键或去重标识中的秘密', () async {
    const canary = 'synthetic-private-user-key';
    await StorageService.setMap('e2ee_decrypt_fail_metrics', {canary: 2});
    final logs = <String>[];
    final previousDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) logs.add(message);
    };
    try {
      await E2EEDecryptFailureMetrics.countAwait(canary, dedupKey: canary);
      await E2EEDecryptFailureMetrics.countAwait('bounds_$canary');
      await E2EEDecryptFailureMetrics.countAwait('envelope_$canary');
      await E2EEDecryptFailureMetrics.countAwait(_PrivateReason());
      await E2EEDecryptFailureMetrics.countAwait('decrypt_error');
    } finally {
      debugPrint = previousDebugPrint;
    }
    final metricLogs = logs.where((line) => line.contains('[E2EE_METRICS]'));
    expect(metricLogs.length, 5);
    expect(logs.join('\n'), isNot(contains(canary)));
    expect(
      metricLogs,
      contains('📊 [E2EE_METRICS] decrypt failure: unknown total=3'),
    );
    expect(
      metricLogs,
      contains('📊 [E2EE_METRICS] decrypt failure: bounds_invalid total=1'),
    );
    expect(
      metricLogs,
      contains('📊 [E2EE_METRICS] decrypt failure: envelope_invalid total=1'),
    );
    expect(await E2EEDecryptFailureMetrics.snapshot(), {
      'unknown': 4,
      'bounds_invalid': 1,
      'envelope_invalid': 1,
      'decrypt_error': 1,
    });
  });

  test('不可信原因只持久化固定分类', () async {
    for (final reason in ['secret-user-key-1', 'secret-user-key-2']) {
      await E2EEDecryptFailureMetrics.countAwait(reason);
    }
    expect(await E2EEDecryptFailureMetrics.snapshot(), {'unknown': 2});
    expect(StorageService.getMap('e2ee_decrypt_fail_metrics'), {'unknown': 2});
  });

  test('带动态值的边界错误归有限分类', () {
    expect(
      E2EEDecryptFailureMetrics.normalizeReason('bounds_secret-key'),
      'bounds_invalid',
    );
    expect(
      E2EEDecryptFailureMetrics.normalizeReason('envelope_secret-key'),
      'envelope_invalid',
    );
    expect(E2EEDecryptFailureMetrics.normalizeReason(42), 'unknown');
  });

  test('历史不可信分类合并且下一次写入清除旧键', () async {
    await StorageService.setMap('e2ee_decrypt_fail_metrics', {
      'secret-user-key-1': 2,
      'secret-user-key-2': 3,
      'decrypt_error': 1,
    });
    expect(await E2EEDecryptFailureMetrics.snapshot(), {
      'unknown': 5,
      'decrypt_error': 1,
    });
    await E2EEDecryptFailureMetrics.countAwait('decrypt_error');
    expect(StorageService.getMap('e2ee_decrypt_fail_metrics'), {
      'unknown': 5,
      'decrypt_error': 2,
    });
  });

  group('E2EEDecryptFailureMetrics 累计计数', () {
    test('按 reason 分桶累计且持久化', () async {
      await E2EEDecryptFailureMetrics.countAwait('decrypt_error');
      await E2EEDecryptFailureMetrics.countAwait('decrypt_error');
      await E2EEDecryptFailureMetrics.countAwait('no_device_envelope');

      final snap = await E2EEDecryptFailureMetrics.snapshot();
      expect(snap['decrypt_error'], 2);
      expect(snap['no_device_envelope'], 1);
    });

    test('null / 空 reason 计入 unknown 桶', () async {
      await E2EEDecryptFailureMetrics.countAwait(null);
      await E2EEDecryptFailureMetrics.countAwait('');

      final snap = await E2EEDecryptFailureMetrics.snapshot();
      expect(snap['unknown'], 2);
      expect(snap.containsKey(''), isFalse);
    });

    test('dedupKey 同 key 本次启动只计一次，不同 key 各计一次', () async {
      await E2EEDecryptFailureMetrics.countAwait(
        'decrypt_failed',
        dedupKey: 'r:m1',
      );
      await E2EEDecryptFailureMetrics.countAwait(
        'decrypt_failed',
        dedupKey: 'r:m1',
      );
      await E2EEDecryptFailureMetrics.countAwait(
        'decrypt_failed',
        dedupKey: 'r:m2',
      );
      // 无 dedupKey 的落库事件口径：始终计数
      await E2EEDecryptFailureMetrics.countAwait('decrypt_failed');

      final snap = await E2EEDecryptFailureMetrics.snapshot();
      expect(snap['decrypt_failed'], 3);
    });

    test('resetForTest 清零计数与去重表', () async {
      await E2EEDecryptFailureMetrics.countAwait('decrypt_error');
      await E2EEDecryptFailureMetrics.resetForTest();
      await E2EEDecryptFailureMetrics.countAwait(
        'decrypt_error',
        dedupKey: 'r:m1',
      );
      await E2EEDecryptFailureMetrics.countAwait(
        'decrypt_error',
        dedupKey: 'r:m1',
      );

      final snap = await E2EEDecryptFailureMetrics.snapshot();
      expect(snap['decrypt_error'], 1);
    });
  });

  group('E2EEHealthCheckService.failedPayloadReason', () {
    test('JSON 串占位行提取 reason', () {
      expect(
        E2EEHealthCheckService.failedPayloadReason(
          '{"_e2ee_failed":true,"_e2ee_reason":"no_device_envelope"}',
        ),
        'no_device_envelope',
      );
    });

    test('Map 占位行提取 reason', () {
      expect(
        E2EEHealthCheckService.failedPayloadReason({
          '_e2ee_failed': true,
          '_e2ee_reason': 'crypto_store_unavailable',
        }),
        'crypto_store_unavailable',
      );
    });

    test('占位但缺 reason 归 unknown', () {
      expect(
        E2EEHealthCheckService.failedPayloadReason({'_e2ee_failed': true}),
        'unknown',
      );
    });

    test('非占位行（明文/无标记）返回 null', () {
      expect(
        E2EEHealthCheckService.failedPayloadReason('{"text":"hello"}'),
        isNull,
      );
      expect(
        E2EEHealthCheckService.failedPayloadReason({'text': 'hello'}),
        isNull,
      );
      expect(E2EEHealthCheckService.failedPayloadReason(null), isNull);
    });

    test('坏 JSON 返回 null', () {
      expect(E2EEHealthCheckService.failedPayloadReason('not-a-json{'), isNull);
    });
  });

  group('E2EEFailureInventory 不可解 / 可恢复分类', () {
    test('按 reason 性质拆分存量', () {
      final inv = E2EEFailureInventory(
        total: 3,
        byReason: const {
          'no_device_envelope': 2,
          'crypto_store_unavailable': 1,
        },
        occurrences: const {'no_device_envelope': 5},
        checkedAt: DateTime.utc(2026, 9, 11),
      );

      expect(inv.unrecoverableCount, 2);
      expect(inv.recoverableCount, 1);

      final m = inv.toMap();
      expect(m['total'], 3);
      expect(m['unrecoverable'], 2);
      expect(m['recoverable'], 1);
      expect(m['by_reason'], {
        'no_device_envelope': 2,
        'crypto_store_unavailable': 1,
      });
      expect((m['checked_at'] as String), contains('2026-09-11'));
    });

    test('空盘点零值', () {
      final inv = E2EEFailureInventory(
        total: 0,
        byReason: const {},
        occurrences: const {},
        checkedAt: DateTime.utc(2026, 9, 11),
      );
      expect(inv.unrecoverableCount, 0);
      expect(inv.recoverableCount, 0);
    });
  });
}
