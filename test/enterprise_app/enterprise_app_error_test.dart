/// FULL-05 — 企业接口错误与空态测试（能力项 5）。
///
/// 硬要求：401/403/404/409/422/429/503 **每一类都有各自稳定的 UI 状态**，
/// 不得塌成一个「出错了」，也不得静默吞掉（[EnterpriseErrorUiState.isSilent]）。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/enterprise_app/public.dart';

Map<String, dynamic> envelope(String code) => <String, dynamic>{
  'error': <String, dynamic>{'code': code, 'message': 'generic'},
};

void main() {
  group('13 个稳定码 → HTTP 状态逐条对齐后端 ?STATUS_MAP', () {
    const Map<String, int> expected = <String, int>{
      'invalid_credential': 401,
      'credential_expired': 401,
      'application_disabled': 403,
      'organization_disabled': 403,
      'insufficient_scope': 403,
      'organization_boundary_violation': 403,
      'resource_not_found': 404,
      'identity_not_mapped': 422,
      'idempotency_conflict': 409,
      'rate_limited': 429,
      'security_gate_closed': 503,
      'invalid_request': 400,
      'internal_error': 500,
    };
    expected.forEach((String code, int status) {
      test('$code → $status', () {
        expect(enterpriseHttpStatusForCode(code), status);
      });
    });

    test('表外码 → unknown（不冒充已知码）', () {
      expect(
        enterpriseErrorKindFromCode('something_new'),
        EnterpriseErrorKind.unknown,
      );
      expect(enterpriseErrorKindFromCode(null), EnterpriseErrorKind.unknown);
    });
  });

  group('brief 点名的 7 类拒绝各有独立 UI 状态', () {
    const Map<String, EnterpriseErrorKind> cases =
        <String, EnterpriseErrorKind>{
          'invalid_credential': EnterpriseErrorKind.invalidCredential,
          'insufficient_scope': EnterpriseErrorKind.insufficientScope,
          'resource_not_found': EnterpriseErrorKind.resourceNotFound,
          'idempotency_conflict': EnterpriseErrorKind.idempotencyConflict,
          'identity_not_mapped': EnterpriseErrorKind.identityNotMapped,
          'rate_limited': EnterpriseErrorKind.rateLimited,
          'security_gate_closed': EnterpriseErrorKind.securityGateClosed,
        };

    cases.forEach((String code, EnterpriseErrorKind kind) {
      test('$code：状态唯一且非静默，有独立文案键', () {
        final EnterpriseErrorUiState state = enterpriseErrorUiState(
          httpStatus: kind.httpStatus,
          body: envelope(code),
        );
        expect(state.kind, kind);
        expect(state.isSilent, isFalse);
        expect(state.messageKeyPrefix, isNotEmpty);
      });
    });

    test('7 类的 UI 状态互不相同（不塌成一个「出错了」）', () {
      final Set<String> kinds = cases.values
          .map(
            (EnterpriseErrorKind k) =>
                enterpriseErrorUiState(body: envelope(k.wireCode))
                    .kind
                    .wireCode,
          )
          .toSet();
      expect(kinds.length, cases.length);
    });

    test('403 三个子类各有独立文案前缀（不笼统成一个 403）', () {
      final Set<String> prefixes = <String>{
        enterpriseErrorUiState(body: envelope('application_disabled'))
            .messageKeyPrefix,
        enterpriseErrorUiState(body: envelope('insufficient_scope'))
            .messageKeyPrefix,
        enterpriseErrorUiState(
          body: envelope('organization_boundary_violation'),
        ).messageKeyPrefix,
      };
      expect(prefixes.length, 3);
    });
  });

  group('可重试性 / 重新登录判定', () {
    test('429 / 503 / 网络 / 500 可重试', () {
      for (final String code in <String>[
        'rate_limited',
        'security_gate_closed',
        'internal_error',
      ]) {
        expect(
          enterpriseErrorUiState(body: envelope(code)).isRetryable,
          isTrue,
          reason: code,
        );
      }
      expect(
        enterpriseErrorUiState(transportError: Exception('offline'))
            .isRetryable,
        isTrue,
      );
    });

    test('401 两码需要重新登录；403/404/422 不需要', () {
      expect(
        enterpriseErrorUiState(body: envelope('invalid_credential'))
            .needsReauth,
        isTrue,
      );
      expect(
        enterpriseErrorUiState(body: envelope('credential_expired'))
            .needsReauth,
        isTrue,
      );
      for (final String code in <String>[
        'insufficient_scope',
        'resource_not_found',
        'identity_not_mapped',
      ]) {
        expect(
          enterpriseErrorUiState(body: envelope(code)).needsReauth,
          isFalse,
          reason: code,
        );
      }
    });
  });

  group('信封解析与兜底', () {
    test('嵌套 error.code 优先', () {
      expect(enterpriseEnvelopeCode(envelope('rate_limited')), 'rate_limited');
    });

    test('扁平 code 兜底（老约定）', () {
      expect(
        enterpriseEnvelopeCode(<String, dynamic>{'code': 'resource_not_found'}),
        'resource_not_found',
      );
    });

    test('无码时按 HTTP 状态归类（仍不静默）', () {
      final EnterpriseErrorUiState state = enterpriseErrorUiState(
        httpStatus: 404,
        body: <String, dynamic>{},
      );
      expect(state.kind, EnterpriseErrorKind.resourceNotFound);
      expect(state.isSilent, isFalse);
    });

    test('传输层异常 → network（detail 只记异常类型，不含内容）', () {
      final EnterpriseErrorUiState state = enterpriseErrorUiState(
        transportError: StateError('socket closed with payload=SECRET'),
      );
      expect(state.kind, EnterpriseErrorKind.network);
      expect(state.detail.contains('SECRET'), isFalse);
    });

    test('detail 取自 error.detail，不含服务端 message', () {
      final EnterpriseErrorUiState state = enterpriseErrorUiState(
        httpStatus: 400,
        body: <String, dynamic>{
          'error': <String, dynamic>{
            'code': 'invalid_request',
            'message': 'invalid request',
            'detail': 'members_over_limit',
          },
        },
      );
      expect(state.detail, 'members_over_limit');
      expect(state.detail.contains('invalid request'), isFalse);
    });

    test('通道未绑定是独立分类（不是 unknown、不是 500 冒充）', () {
      const EnterpriseErrorUiState state = EnterpriseErrorUiState(
        kind: EnterpriseErrorKind.channelUnbound,
      );
      expect(state.httpStatus, 0);
      expect(state.messageKeyPrefix, 'errorUnbound');
      expect(state.isSilent, isFalse);
    });
  });
}
