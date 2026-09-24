/// Organization 域「错误 → 页面 UI 状态」统一映射（ENT-FND-02）。
///
/// 契约：后继页面（ENT-APP-01..06）**不自行解析错误字符串**——
/// catch 到的异常原样交给 [orgErrorToUiState] / [OrgAsyncAdapter]，
/// 由这里集中分型为共享 [AsyncStateView] 的四态输入：
/// - `OrganizationApiException.isForbidden`（403）→ 权限终态（无重试）；
/// - 其余 API 失败 / 任意异常 → 错误态（wire message 优先，展示即事实）。
///
/// 既有 [OrgStateView] 保持不动（其 permissionDenied 语义与本 helper
/// 一致，旧页面零改动）；新页面统一走本 helper + 共享组件。
library;

import 'package:flutter/widgets.dart';

import 'package:imboy/component/ui/async_state_view.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';

/// 一次失败在页面上的呈现分型结果。
class OrgAsyncUiState {
  const OrgAsyncUiState({this.permissionDenied = false, this.errorText});

  /// true = 403 权限终态（渲染权限态，不引导重试）。
  final bool permissionDenied;

  /// 非 null = 系统性失败（渲染错误态 + 重试入口）。
  final String? errorText;

  /// 无失败（content / empty 由页面布尔另行表达）。
  static const OrgAsyncUiState idle = OrgAsyncUiState();
}

/// 错误 → UI 状态的唯一映射入口。
///
/// Organization 与 Human Directory 两条 API 面统一抛
/// [OrganizationApiException]（错误信封 code 一比一透传 HTTP 状态），
/// 因此这里不需要 instanceof 分支展开到第二个异常类型。
OrgAsyncUiState orgErrorToUiState(Object error) {
  if (error is OrganizationApiException) {
    // 403 = 非成员/角色不足/archived fail-closed：终态，不重试。
    if (error.isForbidden) {
      return const OrgAsyncUiState(permissionDenied: true);
    }
    // 401/404/409/503/98x 等：透传 wire message（展示即事实，
    // 不臆造文案；401 由请求层统一登出，页面层少见）。
    return OrgAsyncUiState(errorText: error.message);
  }
  // 非 org 契约异常（网络栈/解析等）：toString 兜底，仍归错误态。
  return OrgAsyncUiState(errorText: error.toString());
}

/// 薄 adapter：页面把 loading/原始异常/empty 直接交给它，
/// 内部经 [orgErrorToUiState] 分型后委托共享 [AsyncStateView] 渲染。
///
/// 页面侧典型用法：
/// ```dart
/// OrgAsyncAdapter(
///   loading: _loading,
///   error: _error,        // Object? 原样，不解析
///   empty: items.isEmpty,
///   onRetry: _reload,
///   child: ListView(...),
/// )
/// ```
class OrgAsyncAdapter extends StatelessWidget {
  const OrgAsyncAdapter({
    super.key,
    required this.loading,
    required this.empty,
    required this.child,
    this.error,
    this.onRetry,
    this.emptyText,
    this.permissionText,
  });

  final bool loading;

  /// 原始异常对象（catch 直传）。非 null 时经 [orgErrorToUiState] 分型。
  final Object? error;

  final bool empty;
  final Widget child;
  final VoidCallback? onRetry;
  final String? emptyText;

  /// 权限态文案覆盖。null = `t.common.noPermission`（AsyncStateView 默认）；
  /// org 读面常用 `t.organization.departments.viewForbidden`（仅限本组织在职成员）。
  final String? permissionText;

  @override
  Widget build(BuildContext context) {
    final ui = error == null ? OrgAsyncUiState.idle : orgErrorToUiState(error!);
    // AsyncStateView 以 error != null 判定错误态、errorText 覆盖文案；
    // 两者用同一映射结果喂入，页面拿到的 wire message 原样呈现。
    return AsyncStateView(
      isLoading: loading,
      permissionDenied: ui.permissionDenied,
      error: ui.errorText,
      errorText: ui.errorText,
      isEmpty: empty,
      onRetry: onRetry,
      emptyText: emptyText,
      permissionText: permissionText,
      child: child,
    );
  }
}
