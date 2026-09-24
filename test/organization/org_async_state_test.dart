import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/organization/public.dart'
    show
        OrganizationApiException,
        OrgAsyncAdapter,
        OrgAsyncUiState,
        orgErrorToUiState;

/// ENT-FND-02 — organization 域错误 → UI 状态统一映射单测。
///
/// 契约：新页面不自行解析错误字符串，一切分型经 [orgErrorToUiState]；
/// 403 → 权限终态（无重试），其余 API 失败 → 错误态（wire message 透传），
/// 非 org 契约异常 → toString 兜底仍归错误态。
void main() {
  group('orgErrorToUiState', () {
    test('idle：无失败', () {
      expect(OrgAsyncUiState.idle.permissionDenied, isFalse);
      expect(OrgAsyncUiState.idle.errorText, isNull);
    });

    test('403 → 权限终态（errorText 为空，不引导重试）', () {
      final ui = orgErrorToUiState(
        const OrganizationApiException(403, 'insufficient_scope'),
      );
      expect(ui.permissionDenied, isTrue);
      expect(ui.errorText, isNull);
    });

    test('404/409/503 → 错误态，wire message 透传（展示即事实）', () {
      expect(
        orgErrorToUiState(const OrganizationApiException(404, '资源不存在'))
            .errorText,
        '资源不存在',
      );
      expect(
        orgErrorToUiState(const OrganizationApiException(409, '状态冲突'))
            .errorText,
        '状态冲突',
      );
      expect(
        orgErrorToUiState(
          const OrganizationApiException(503, 'security_gate_closed'),
        ).errorText,
        'security_gate_closed',
      );
    });

    test('非 org 契约异常 → toString 兜底归错误态', () {
      final ui = orgErrorToUiState(StateError('dio stack'));
      expect(ui.permissionDenied, isFalse);
      expect(ui.errorText, contains('dio stack'));
    });
  });

  group('OrgAsyncAdapter', () {
    Widget wrap(Widget child) => TranslationProvider(
      child: MaterialApp(home: Scaffold(body: child)),
    );

    testWidgets('原始 403 异常直传 → 渲染权限态且无重试入口', (tester) async {
      await tester.pumpWidget(
        wrap(
          OrgAsyncAdapter(
            loading: false,
            error: const OrganizationApiException(403, 'denied'),
            empty: false,
            onRetry: () {},
            child: const Text('CONTENT'),
          ),
        ),
      );
      expect(find.text(t.common.noPermission), findsOneWidget);
      expect(find.text(t.common.buttonRetry), findsNothing);
      expect(find.text('CONTENT'), findsNothing);
    });

    testWidgets('原始 500 异常直传 → 渲染错误态 + 重试可达', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        wrap(
          OrgAsyncAdapter(
            loading: false,
            error: const OrganizationApiException(500, '内部错误'),
            empty: false,
            onRetry: () => retried++,
            child: const Text('CONTENT'),
          ),
        ),
      );
      expect(find.text('内部错误'), findsOneWidget);
      await tester.tap(find.text(t.common.buttonRetry));
      expect(retried, 1);
    });

    testWidgets('permissionText 覆盖生效（org 读面专用文案）', (tester) async {
      await tester.pumpWidget(
        wrap(
          OrgAsyncAdapter(
            loading: false,
            error: const OrganizationApiException(403, 'denied'),
            empty: false,
            permissionText: t.organization.departments.viewForbidden,
            child: const SizedBox.shrink(),
          ),
        ),
      );
      expect(
        find.text(t.organization.departments.viewForbidden),
        findsOneWidget,
      );
      expect(find.text(t.common.noPermission), findsNothing);
    });

    testWidgets('empty 态渲染空态文案', (tester) async {
      await tester.pumpWidget(
        wrap(
          OrgAsyncAdapter(
            loading: false,
            empty: true,
            child: const Text('CONTENT'),
          ),
        ),
      );
      expect(find.text(t.common.noData), findsOneWidget);
      expect(find.text('CONTENT'), findsNothing);
    });

    testWidgets('loading 态渲染指示器', (tester) async {
      await tester.pumpWidget(
        wrap(
          OrgAsyncAdapter(
            loading: true,
            empty: false,
            child: const Text('CONTENT'),
          ),
        ),
      );
      expect(find.byType(CupertinoActivityIndicator), findsOneWidget);
      expect(find.text('CONTENT'), findsNothing);
    });

    testWidgets('无异常且非空 → 渲染 child', (tester) async {
      await tester.pumpWidget(
        wrap(
          OrgAsyncAdapter(
            loading: false,
            empty: false,
            child: const Text('CONTENT'),
          ),
        ),
      );
      expect(find.text('CONTENT'), findsOneWidget);
    });
  });
}
