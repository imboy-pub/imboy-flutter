/// 钉住 `GroupMemberMuteService` 的分支契约（sealed `MuteResult`）。
///
/// Service 职责：把 UI 侧的「禁言 X 秒」意图串起 API 调用 → 返回结构化
/// 结果，并在本地推导出 `muteUntilMs = now + durationSec * 1000` 作为
/// 乐观更新的依据。本地持久化（Repo.update mute_until）留给切片 2
/// 或 S2C 广播覆盖，service 当前只负责 API + 时间换算。
///
/// 契约：
///   1. durationSec <= 0 → MuteValidationError（不调 API）
///   2. API 返回 true → MuteSuccess(muteUntilMs = clock + duration*1000)
///   3. API 返回 false → MuteApiFailure
///   4. API 抛 ArgumentError（后端契约防线二次防守）→ MuteValidationError
library;

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/http/http_transformer.dart';
import 'package:imboy/service/group_member_mute_service.dart';
import 'package:imboy/store/api/group_member_api.dart';

class _StubApi extends GroupMemberApi {
  int muteCallCount = 0;
  String? lastGid;
  String? lastUserId;
  int? lastDuration;

  bool nextMuteOk = true;
  Object? nextMuteThrow;

  @override
  Future<bool> mute({
    required String gid,
    required String userId,
    required int duration,
  }) async {
    muteCallCount++;
    lastGid = gid;
    lastUserId = userId;
    lastDuration = duration;
    if (nextMuteThrow != null) {
      // ignore: only_throw_errors
      throw nextMuteThrow!;
    }
    return nextMuteOk;
  }

  // HttpClient 基类在 mute() 里只会被我们的 override 拦截，但仍需满足
  // 继承契约，其它方法默认不会被触发。
  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    HttpTransformer? httpTransformer,
  }) async {
    fail('Stub.post 不应被调用 —— mute() 已被直接 override');
  }
}

GroupMemberMuteService _build({
  required _StubApi api,
  int nowMs = 1_700_000_000_000,
}) {
  return GroupMemberMuteService(api: api, clock: () => nowMs);
}

void main() {
  group('GroupMemberMuteService.mute — sealed MuteResult 分支', () {
    test('durationSec = 0 → MuteValidationError，不调 API', () async {
      final api = _StubApi();
      final svc = _build(api: api);

      final result = await svc.mute(gid: 'g1', userId: 'u1', durationSec: 0);

      expect(result, isA<MuteValidationError>());
      expect(api.muteCallCount, 0);
    });

    test('durationSec < 0 → MuteValidationError，不调 API', () async {
      final api = _StubApi();
      final svc = _build(api: api);

      final result = await svc.mute(gid: 'g1', userId: 'u1', durationSec: -1);

      expect(result, isA<MuteValidationError>());
      expect(api.muteCallCount, 0);
    });

    test('API ok=true → MuteSuccess(muteUntilMs = clock + duration*1000)', () async {
      final api = _StubApi()..nextMuteOk = true;
      final svc = _build(api: api, nowMs: 1_700_000_000_000);

      final result = await svc.mute(
        gid: 'g-42',
        userId: 'u-7',
        durationSec: 600,
      );

      expect(result, isA<MuteSuccess>());
      final success = result as MuteSuccess;
      // 1_700_000_000_000 + 600 * 1000 = 1_700_000_600_000
      expect(success.muteUntilMs, 1_700_000_600_000);

      expect(api.muteCallCount, 1);
      expect(api.lastGid, 'g-42');
      expect(api.lastUserId, 'u-7');
      expect(api.lastDuration, 600);
    });

    test('API ok=false → MuteApiFailure', () async {
      final api = _StubApi()..nextMuteOk = false;
      final svc = _build(api: api);

      final result = await svc.mute(gid: 'g1', userId: 'u1', durationSec: 60);

      expect(result, isA<MuteApiFailure>());
      expect(api.muteCallCount, 1);
    });

    test('API 抛 ArgumentError（二次防线）→ MuteValidationError', () async {
      final api = _StubApi()
        ..nextMuteThrow = ArgumentError.value(0, 'duration', 'test');
      final svc = _build(api: api);

      final result = await svc.mute(gid: 'g1', userId: 'u1', durationSec: 60);

      expect(result, isA<MuteValidationError>());
    });

    test('MuteResult 是 sealed —— switch 必须穷尽', () {
      String describe(MuteResult r) {
        // 如果将来新增分支未在此枚举，编译器会报错 —— 这正是 sealed 的价值。
        return switch (r) {
          MuteSuccess(:final muteUntilMs) => 'success:$muteUntilMs',
          MuteValidationError(:final message) => 'validation:$message',
          MuteApiFailure(:final message) => 'api:${message ?? "null"}',
        };
      }

      expect(describe(const MuteSuccess(1)), 'success:1');
      expect(
        describe(const MuteValidationError('m')),
        'validation:m',
      );
      expect(describe(const MuteApiFailure('e')), 'api:e');
    });
  });
}
