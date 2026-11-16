import 'dart:async';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/service/storage.dart';

import 'decrypt_failure_reason.dart';

/// 解密失败发生率度量 —— 「[加密消息] 占位发生率压到一辈子遇不到」的验证仪表。
///
/// 两个互补口径（存量口径见 `E2EEHealthCheckService.failureInventory()`）：
/// - **累计发生**（本类，只增不减）：占位产生即按 reason 分桶计数并持久化，
///   反映「这台设备的用户到底遇到过几次」；
/// - **存量盘点**（健康检查服务）：DB 内现存占位行扫描，被自愈恢复
///   （路径4 retryFailedMessages）消化后会下降。
///
/// 计数点只有两类：
/// - message.dart 落库漏斗：占位行即将持久化（唯一持久化事件点）；
/// - mapper toTypeMessage 读时解密失败：密文行每次渲染都会重试，传 dedupKey
///   做本次启动内去重，避免逐帧渲染造成的计数膨胀。
///
/// 幂等重投（duplicate_message / already_processed）不落占位故不计数；
/// 服务端 ACK 前重投的极端序列可能对同一行重复计数，对趋势判断无影响。
class E2EEDecryptFailureMetrics {
  E2EEDecryptFailureMetrics._();

  static const _storeKey = 'e2ee_decrypt_fail_metrics';

  /// 本次启动内去重（读时解密失败按「reason×行」计一次）
  static final Set<String> _seenDedupKeys = {};

  /// 归一化失败原因：只允许有限分类，避免持久化不可信内容
  static String normalizeReason(Object? reason) {
    return normalizeDecryptFailureReason(reason);
  }

  /// 记一次占位产生（fire-and-forget：度量绝不阻塞消息主链路）。
  ///
  /// [dedupKey] 提供时同一 key 本次启动只计一次（读时解密场景传 `'r:<msgId>'`）。
  static void count(Object? reason, {String? dedupKey}) {
    unawaited(_bump(reason, dedupKey: dedupKey));
  }

  /// [count] 的可等待版：测试确定性用，生产调用方请用 [count]。
  static Future<void> countAwait(Object? reason, {String? dedupKey}) =>
      _bump(reason, dedupKey: dedupKey);

  static Future<void> _bump(Object? reason, {String? dedupKey}) async {
    try {
      final key = normalizeReason(reason);
      if (dedupKey != null && !_seenDedupKeys.add('$key|$dedupKey')) {
        return;
      }
      final m = _normalizedSnapshot();
      m[key] = (m[key] ?? 0) + 1;
      await StorageService.setMap(_storeKey, m);
      iPrint('📊 [E2EE_METRICS] decrypt failure: $key total=${m[key]}');
    } catch (_) {
      // 度量失败静默：不影响消息主链路
    }
  }

  /// 累计计数快照（reason → 次数）
  static Future<Map<String, int>> snapshot() async => _normalizedSnapshot();

  static Map<String, int> _normalizedSnapshot() {
    try {
      final m = StorageService.getMap(_storeKey);
      final result = <String, int>{};
      for (final entry in m.entries) {
        final key = normalizeReason(entry.key);
        final value = entry.value;
        final count = value is int ? value : int.tryParse('$value') ?? 0;
        result[key] = (result[key] ?? 0) + count;
      }
      return result;
    } catch (_) {
      return <String, int>{};
    }
  }

  /// 清零（仅测试用）
  static Future<void> resetForTest() async {
    _seenDedupKeys.clear();
    await StorageService.setMap(_storeKey, <String, dynamic>{});
  }
}
