/// 钉住 `GroupMemberMuteService.unmute` 契约 —— slice-9a RED。
///
/// 解禁语义独立于禁言：
///   - 不依赖 `duration` 参数（mute/4 要求 >0）
///   - 服务端 side-effect 为 `mute_until = 0`（或 NULL），触发 S2C 通知
///   - 客户端 Service 层仅负责调用 API + 结构化返回
///
/// 非职责（slice-9a 不做）：
///   - Repo 写入：由 S2C `group_member_mute` 通知统一落库（`muteUntil = null`）
///   - UI toast / 权限校验：上层 UI 处理
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_member_mute_service.dart';
import 'package:imboy/store/api/group_member_api.dart';

void main() {
  group('GroupMemberMuteService.unmute — sealed UnmuteResult', () {
    test('API ok=true → UnmuteSuccess', () async {
      final api = _FakeOkApi();
      final service = GroupMemberMuteService(api: api);

      final result = await service.unmute(gid: '10086', userId: 'u1');

      expect(result, isA<UnmuteSuccess>());
      expect(api.calls, [
        ('/unmute', '10086', 'u1'),
      ]);
    });

    test('API ok=false → UnmuteApiFailure', () async {
      final api = _FakeFailApi();
      final service = GroupMemberMuteService(api: api);

      final result = await service.unmute(gid: '10086', userId: 'u1');

      expect(result, isA<UnmuteApiFailure>());
    });

    test('gid 为空 → UnmuteValidationError，不调 API', () async {
      final api = _FakeFailApi();
      final service = GroupMemberMuteService(api: api);

      final result = await service.unmute(gid: '', userId: 'u1');

      expect(result, isA<UnmuteValidationError>());
      expect(api.calls, isEmpty);
    });

    test('userId 为空 → UnmuteValidationError，不调 API', () async {
      final api = _FakeFailApi();
      final service = GroupMemberMuteService(api: api);

      final result = await service.unmute(gid: '10086', userId: '');

      expect(result, isA<UnmuteValidationError>());
      expect(api.calls, isEmpty);
    });

    test('sealed —— switch 必须穷尽', () {
      String describe(UnmuteResult r) => switch (r) {
            UnmuteSuccess() => 'ok',
            UnmuteValidationError(:final message) => 'invalid:$message',
            UnmuteApiFailure(:final message) => 'fail:${message ?? ""}',
          };

      expect(describe(const UnmuteSuccess()), 'ok');
      expect(describe(const UnmuteValidationError('bad')), 'invalid:bad');
      expect(describe(const UnmuteApiFailure('x')), 'fail:x');
    });
  });
}

/// 伪造 API：记录所有调用 + 默认 ok。
class _FakeOkApi extends GroupMemberApi {
  final List<(String, String, String)> calls = [];

  @override
  Future<bool> unmute({required String gid, required String userId}) async {
    calls.add(('/unmute', gid, userId));
    return true;
  }
}

/// 伪造 API：ok=false。
class _FakeFailApi extends GroupMemberApi {
  final List<(String, String, String)> calls = [];

  @override
  Future<bool> unmute({required String gid, required String userId}) async {
    calls.add(('/unmute', gid, userId));
    return false;
  }
}
