import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/retry_plaintext_guard.dart';

/// E2EE-062 第八刀：**耗尽 / 限流绝不触发明文降级**（残留 ①）。
///
/// == 缺口（本轮实证发现）==
///
/// 发送路径在加密失败时是 fail-closed 的：
/// `ChatNetworkService.sendWsMsg` catch → toast → `return false`，不发送
/// （`chat_network_service.dart` 的 `catch (e, stackTrace)` 分支）。
/// **但那条消息行早已落库**，payload 是明文、`e2ee` 为空，状态被置为 `error`。
///
/// `MessageRetry._scanAndRetryFailedMessages` 的重试状态集是
/// `{sending, pendingRetry, error}`（`message_retry.dart`），会把这条行捡起来；
/// `_retryFailedMessagesLocked` 直接从库里读 `payload` / `e2ee` 拼报文发 WS，
/// **完全不经过 `encryptPayload`，也不经过 PolicyGate**。
///
/// 于是链路是：
///   OTK 池被抽干 / 触发 429
///     → `_establishOutboundSession` 抛错
///     → `encryptPayload` 抛错
///     → `sendWsMsg` 置 error 并拒发（发送侧 fail-closed 成立）
///     → MessageRetry 扫到 error 行
///     → **按库中原样重发 = 明文出网**
///
/// 发送侧的 fail-closed 被重发路径整条旁路掉。
/// 这正是「耗尽/限流绝不触发 RSA/Megolm/明文」的反面。
///
/// == 本文件守护 ==
///
/// 1. 该加密却没有 `e2ee` 元数据的行 → **必须拦下**；
/// 2. 【正向可用性】已加密的行 → **必须照常重发**。
///    一个「一律拦下」的实现会让所有重发失效、消息永久卡住，
///    在「不泄漏明文」这个指标上却恒得满分，必须被这条否掉；
/// 3. 【正向可用性】本就不需要加密的行（C2S / 策略未要求）→ **必须照常重发**；
/// 4. `e2ee` 为空 map 与 null 同等对待（空 map 不构成"已加密"）。
void main() {
  group('shouldBlockPlaintextRetry', () {
    test('该加密却无 e2ee 元数据 → 拦下（耗尽/限流的明文降级出口）', () {
      expect(
        shouldBlockPlaintextRetry(encryptionRequired: true, e2ee: null),
        isTrue,
        reason: '这条行是明文；按库中原样重发等于绕开发送侧的 fail-closed',
      );
    });

    test('e2ee 为空 map 同样视为明文 → 拦下', () {
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: true,
          e2ee: <String, dynamic>{},
        ),
        isTrue,
      );
    });

    test('正向可用性：已加密的行必须照常重发', () {
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: true,
          e2ee: <String, dynamic>{
            'meta_version': 3,
            'protocol': 'olm',
            'fan_out': 'per_device',
          },
        ),
        isFalse,
        reason:
            '一律拦下会让所有重发失效、消息永久卡住，'
            '却在"不泄漏明文"指标上恒得满分',
      );
    });

    test('正向可用性：本就不需要加密的行必须照常重发', () {
      expect(
        shouldBlockPlaintextRetry(encryptionRequired: false, e2ee: null),
        isFalse,
      );
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: false,
          e2ee: <String, dynamic>{},
        ),
        isFalse,
      );
    });

    test('对照组：不需加密且已加密的行 —— 两个维度互不干扰', () {
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: false,
          e2ee: <String, dynamic>{'meta_version': 3},
        ),
        isFalse,
      );
    });
  });

  /// E2EE-061：带 **content key** 的行（payload 含 `attachment_descriptor`）。
  ///
  /// 封装判定发生在**上传那一刻**，而这条行可能在几小时后才被重发。
  /// 中间策略若翻成明文，`encryptionRequired` 就是 false，旧判据会放行——
  /// 于是能解开整个附件的钥匙明文出网，**比明文附件本身更糟**。
  group('shouldBlockPlaintextRetry：content key 维度（E2EE-061）', () {
    test('⚠️ 即便策略说「不需加密」，带 content key 的明文行也必须拦下', () {
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: false,
          e2ee: null,
          carriesContentKey: true,
        ),
        isTrue,
        reason: '策略翻成明文不构成「可以把附件密钥明文发出去」的理由',
      );
    });

    test('正向可用性：带 content key 但已加密的行照常重发', () {
      expect(
        shouldBlockPlaintextRetry(
          encryptionRequired: true,
          e2ee: <String, dynamic>{'meta_version': 3, 'protocol': 'olm'},
          carriesContentKey: true,
        ),
        isFalse,
        reason: '恒拦下会让加密附件永远重发不出去，却在泄漏指标上满分',
      );
    });

    test('默认 false：旧调用形状行为不变', () {
      expect(
        shouldBlockPlaintextRetry(encryptionRequired: false, e2ee: null),
        isFalse,
      );
    });
  });
}
