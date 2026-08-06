import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/olm_claim_request_id.dart';
import 'package:imboy/store/api/olm_api.dart';

/// E2EE-062：客户端幂等键（残留 ①）。
///
/// == 缺口 ==
///
/// 服务端三刀已把幂等租约铺到 claim 与 batch_claim 两条路径上
/// （imboy `evidence/E2EE-062-otk-claim-idempotent-lease.md` /
///  `E2EE-062-batch-claim-idempotency.md`），但客户端从不发送 `request_id`——
/// **生产流量一条也走不到幂等路径**。一次网络超时后 MessageRetry 的重投
/// （3/5/10/20s 退避）会重新进入 `_establishOutboundSession` 并再 claim 一次，
/// 每次都真实消费一条 one-time prekey。服务端做的全部工作在生产上等于零。
///
/// == 本文件守护 ==
///
/// 1. 同一次建会话尝试的重投必须拿到**同一个** id（幂等真正生效）；
/// 2. 【正向可用性】成功建会话后必须换新 id —— 一个「恒定 id」的实现在幂等
///    指标上恒得满分，却会把该对端此后所有会话钉死在同一条已消费的 OTK 上，
///    破坏 one-time prekey 的一次性，必须被这条否掉；
/// 3. 不同对端设备的 id 必须互不相同；
/// 4. id 必须落在服务端 `olm_handler:normalize_request_id/1` 的白名单内
///    （`^[A-Za-z0-9_.-]+$`、长度 ≤ 64）。不合规会被服务端**静默降级为空**，
///    幂等失效且没有任何信号——这是最容易无声失效的一环；
/// 5. `request_id` 必须真的进入 claim 请求体（生产开关本身）。
void main() {
  setUp(OlmClaimRequestId.resetForTest);

  group('OlmClaimRequestId 生命周期', () {
    test('对照组：清空后首次 issue 必须给出一个非空 id', () {
      final id = OlmClaimRequestId.issue('u-100', 'dev-A');
      expect(id, isNotEmpty);
    });

    test('同一次尝试的重投拿到同一个 id（幂等生效）', () {
      final first = OlmClaimRequestId.issue('u-100', 'dev-A');
      final retry1 = OlmClaimRequestId.issue('u-100', 'dev-A');
      final retry2 = OlmClaimRequestId.issue('u-100', 'dev-A');
      expect(retry1, first);
      expect(retry2, first);
    });

    test('正向可用性：成功建会话后必须换新 id（不得恒定去重）', () {
      final first = OlmClaimRequestId.issue('u-100', 'dev-A');
      OlmClaimRequestId.complete('u-100', 'dev-A');
      final second = OlmClaimRequestId.issue('u-100', 'dev-A');
      expect(
        second,
        isNot(first),
        reason:
            '恒定 id 会让该对端此后所有会话复用同一条已消费的 OTK，'
            '破坏 one-time prekey 的一次性',
      );
    });

    test('不同对端设备的 id 互不相同', () {
      final a = OlmClaimRequestId.issue('u-100', 'dev-A');
      final b = OlmClaimRequestId.issue('u-100', 'dev-B');
      final c = OlmClaimRequestId.issue('u-200', 'dev-A');
      expect(<String>{a, b, c}.length, 3);
    });

    test('id 必须落在服务端白名单内，否则会被静默降级为空', () {
      for (var i = 0; i < 50; i++) {
        final id = OlmClaimRequestId.issue('u-$i', 'dev-$i');
        expect(
          OlmClaimRequestId.isServerAcceptable(id),
          isTrue,
          reason:
              'id="$id" 不合规 → 服务端 normalize_request_id/1 降级为空，'
              '幂等无声失效',
        );
      }
    });

    test('白名单谓词本身：越界字符与超长必须被判不合规', () {
      expect(OlmClaimRequestId.isServerAcceptable('abc-123_x.y'), isTrue);
      expect(OlmClaimRequestId.isServerAcceptable(''), isFalse);
      expect(OlmClaimRequestId.isServerAcceptable('has space'), isFalse);
      expect(OlmClaimRequestId.isServerAcceptable('has/slash'), isFalse);
      expect(OlmClaimRequestId.isServerAcceptable('a' * 64), isTrue);
      expect(OlmClaimRequestId.isServerAcceptable('a' * 65), isFalse);
    });
  });

  group('claim 请求体', () {
    test('request_id 非空时必须进入请求体', () {
      final body = OlmApi.buildClaimBody(
        targetUid: 'u-100',
        deviceId: 'dev-A',
        requestId: 'req-abc-001',
      );
      expect(body['target_uid'], 'u-100');
      expect(body['device_id'], 'dev-A');
      expect(
        body['request_id'],
        'req-abc-001',
        reason: 'request_id 不进请求体 = 服务端三刀的幂等租约在生产上等于零',
      );
    });

    test('request_id 为空时不得写入该键（旧语义零破坏）', () {
      final body = OlmApi.buildClaimBody(
        targetUid: 'u-100',
        deviceId: 'dev-A',
        requestId: '',
      );
      expect(body.containsKey('request_id'), isFalse);
      expect(body['target_uid'], 'u-100');
      expect(body['device_id'], 'dev-A');
    });
  });
}
