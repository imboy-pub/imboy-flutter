import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_bridge_auth_code.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_sso_issue.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';

/// 桥 getAuthCode 服务（data/oa_bridge_auth_code.dart）纯逻辑单测：
/// 应用裁决矩阵、成功信封、失败映射、异常归一。
void main() {
  EnterpriseOaRuntimeConfig config(
    String key,
    String redirect, {
    bool enabled = true,
  }) {
    return EnterpriseOaRuntimeConfig.fromMap({
      'IMBOY_WL_OA_ORIGIN': 'https://oa.example.com',
      'IMBOY_WL_OA_LABEL': 'OA',
      'IMBOY_WL_OA_ENTRY_ENABLED': enabled,
      'IMBOY_WL_OA_APPLICATION_KEY': key,
      'IMBOY_WL_OA_REDIRECT_URI': redirect,
    });
  }

  const issued = OaSsoCodeIssued(
    code: 'oa_sso_testcode',
    redirectUri: 'https://oa.example.com/callback',
    expiresInSeconds: 60,
  );

  OaSsoIssueResult? captured;
  String? capturedKey;
  String? capturedRedirect;
  String? capturedNonce;

  OaBridgeAuthCodeService service(OaSsoIssueResult result) {
    return OaBridgeAuthCodeService(
      issue:
          ({
            required applicationKey,
            required redirectUri,
            required nonce,
          }) async {
            captured = result;
            capturedKey = applicationKey;
            capturedRedirect = redirectUri;
            capturedNonce = nonce;
            return result;
          },
      nonceGenerator: () => 'fixednonce_fixednonce_ab',
    );
  }

  setUp(() {
    captured = null;
    capturedKey = null;
    capturedRedirect = null;
    capturedNonce = null;
  });

  group('selectOaApplication', () {
    test('空 entries 回 app_not_configured', () {
      final selection = selectOaApplication(const [], null);
      expect(selection.config, isNull);
      expect(selection.errorCode, 'app_not_configured');
    });

    test('未指定 key 且恰一个可用应用时命中', () {
      final one = config('app_key_1', 'https://oa.example.com/cb');
      final selection = selectOaApplication([one], null);
      expect(selection.config?.applicationKey, 'app_key_1');
      expect(selection.errorCode, isNull);
    });

    test('未指定 key 且多个候选回 ambiguous_application 且不签发', () {
      final selection = selectOaApplication([
        config('app_key_1', 'https://oa.example.com/cb'),
        config('app_key_2', 'https://oa.example.com/cb2'),
      ], null);
      expect(selection.config, isNull);
      expect(selection.errorCode, 'ambiguous_application');
    });

    test('指定 key 精确命中；未命中统一 app_not_configured（无枚举 oracle）', () {
      final a = config('app_key_1', 'https://oa.example.com/cb');
      final b = config('app_key_2', 'https://oa.example.com/cb2');
      expect(
        selectOaApplication([a, b], 'app_key_2').config?.applicationKey,
        'app_key_2',
      );
      expect(
        selectOaApplication([a, b], 'app_key_9').errorCode,
        'app_not_configured',
      );
    });

    test('runtimeEntryEnabled=false 的应用不参与裁决', () {
      final disabled = config(
        'app_key_1',
        'https://evil.example.com/cb',
        enabled: false,
      );
      final selection = selectOaApplication([disabled], null);
      expect(selection.config, isNull);
      expect(selection.errorCode, 'app_not_configured');
    });
  });

  group('OaBridgeAuthCodeService.getAuthCode', () {
    test('成功：回执信封字段齐备且 state 为注入 nonce', () async {
      final outcome = await service(issued).getAuthCode(
        entries: [config('app_key_1', 'https://oa.example.com/callback')],
      );
      expect(outcome.ok, isTrue);
      expect(outcome.code, 'oa_sso_testcode');
      expect(outcome.state, 'fixednonce_fixednonce_ab');
      expect(outcome.expiresInSeconds, 60);
      expect(outcome.redirectUri, 'https://oa.example.com/callback');
      expect(outcome.applicationKey, 'app_key_1');
      expect(capturedKey, 'app_key_1');
      expect(capturedRedirect, 'https://oa.example.com/callback');
      expect(capturedNonce, 'fixednonce_fixednonce_ab');
    });

    test('签发失败：OaSsoIssueFailureKind 透传为稳定错误码', () async {
      for (final kind in OaSsoIssueFailureKind.values) {
        final outcome = await service(OaSsoIssueFailed(kind)).getAuthCode(
          entries: [config('app_key_1', 'https://oa.example.com/callback')],
        );
        expect(outcome.ok, isFalse, reason: kind.wireName);
        expect(outcome.errorCode, kind.wireName, reason: kind.wireName);
        expect(outcome.code, isNull, reason: kind.wireName);
      }
    });

    test('签发出口抛异常归一为 network（不向 H5 泄漏异常形态）', () async {
      final throwing = OaBridgeAuthCodeService(
        issue:
            ({
              required applicationKey,
              required redirectUri,
              required nonce,
            }) async {
              throw StateError('boom');
            },
        nonceGenerator: () => 'fixednonce_fixednonce_ab',
      );
      final outcome = await throwing.getAuthCode(
        entries: [config('app_key_1', 'https://oa.example.com/callback')],
      );
      expect(outcome.ok, isFalse);
      expect(outcome.errorCode, 'network');
    });

    test('无可用应用时不调用签发出口', () async {
      var called = false;
      final never = OaBridgeAuthCodeService(
        issue:
            ({
              required applicationKey,
              required redirectUri,
              required nonce,
            }) async {
              called = true;
              return issued;
            },
      );
      final outcome = await never.getAuthCode(entries: const []);
      expect(outcome.errorCode, 'app_not_configured');
      expect(called, isFalse);
    });

    test('未指定 key 多候选时回 ambiguous_application', () async {
      final outcome = await service(issued).getAuthCode(
        entries: [
          config('app_key_1', 'https://oa.example.com/cb'),
          config('app_key_2', 'https://oa.example.com/cb2'),
        ],
      );
      expect(outcome.errorCode, 'ambiguous_application');
      expect(captured, isNull);
    });
  });
}
