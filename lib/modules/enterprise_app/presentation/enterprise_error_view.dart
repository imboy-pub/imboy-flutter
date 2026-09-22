/// 企业应用错误与空态的稳定 UI（FULL-05 / plan-full §3.3）。
///
/// 每一类拒绝（401/403/404/409/422/429/503 + 客户端侧通道未绑定/网络/未知）
/// 都有**各自的标题与解释**，且都给出下一步动作——不得塌成同一个「出错了」，
/// 更不得静默吞掉（见 `enterprise_app_error.dart` 的 [EnterpriseErrorUiState]）。
///
/// 文案取自 `enterpriseApp` 命名空间；`switch` 是穷尽式的（枚举新增即编译报错），
/// 保证不会出现「新错误码没有 UI 文案」。
///
/// 颜色/间距/字号一律走 token。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_app/domain/enterprise_app_error.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// 错误分类 → 本地化标题（穷尽 switch）。
String enterpriseErrorTitle(EnterpriseErrorKind kind) {
  switch (kind) {
    case EnterpriseErrorKind.invalidCredential:
    case EnterpriseErrorKind.credentialExpired:
      return t.enterpriseApp.error401Title;
    case EnterpriseErrorKind.applicationDisabled:
    case EnterpriseErrorKind.organizationDisabled:
      return t.enterpriseApp.error403Title;
    case EnterpriseErrorKind.insufficientScope:
      return t.enterpriseApp.error403ScopeTitle;
    case EnterpriseErrorKind.organizationBoundaryViolation:
      return t.enterpriseApp.error403BoundaryTitle;
    case EnterpriseErrorKind.resourceNotFound:
      return t.enterpriseApp.error404Title;
    case EnterpriseErrorKind.identityNotMapped:
      return t.enterpriseApp.error422IdentityTitle;
    case EnterpriseErrorKind.idempotencyConflict:
      return t.enterpriseApp.error409Title;
    case EnterpriseErrorKind.rateLimited:
      return t.enterpriseApp.error429Title;
    case EnterpriseErrorKind.securityGateClosed:
      return t.enterpriseApp.error503Title;
    case EnterpriseErrorKind.invalidRequest:
      return t.enterpriseApp.error400Title;
    case EnterpriseErrorKind.internalError:
      return t.enterpriseApp.error500Title;
    case EnterpriseErrorKind.channelUnbound:
      return t.enterpriseApp.errorUnboundTitle;
    case EnterpriseErrorKind.network:
      return t.enterpriseApp.errorNetworkTitle;
    case EnterpriseErrorKind.unknown:
      return t.enterpriseApp.errorUnknownTitle;
  }
}

/// 错误分类 → 本地化解释（穷尽 switch）。
String enterpriseErrorHint(EnterpriseErrorKind kind) {
  switch (kind) {
    case EnterpriseErrorKind.invalidCredential:
    case EnterpriseErrorKind.credentialExpired:
      return t.enterpriseApp.error401Hint;
    case EnterpriseErrorKind.applicationDisabled:
    case EnterpriseErrorKind.organizationDisabled:
      return t.enterpriseApp.error403Hint;
    case EnterpriseErrorKind.insufficientScope:
      return t.enterpriseApp.error403ScopeHint;
    case EnterpriseErrorKind.organizationBoundaryViolation:
      return t.enterpriseApp.error403BoundaryHint;
    case EnterpriseErrorKind.resourceNotFound:
      return t.enterpriseApp.error404Hint;
    case EnterpriseErrorKind.identityNotMapped:
      return t.enterpriseApp.error422IdentityHint;
    case EnterpriseErrorKind.idempotencyConflict:
      return t.enterpriseApp.error409Hint;
    case EnterpriseErrorKind.rateLimited:
      return t.enterpriseApp.error429Hint;
    case EnterpriseErrorKind.securityGateClosed:
      return t.enterpriseApp.error503Hint;
    case EnterpriseErrorKind.invalidRequest:
      return t.enterpriseApp.error400Hint;
    case EnterpriseErrorKind.internalError:
      return t.enterpriseApp.error500Hint;
    case EnterpriseErrorKind.channelUnbound:
      return t.enterpriseApp.errorUnboundHint;
    case EnterpriseErrorKind.network:
      return t.enterpriseApp.errorNetworkHint;
    case EnterpriseErrorKind.unknown:
      return t.enterpriseApp.errorUnknownHint;
  }
}

/// 错误状态视图（列表/详情内嵌或用整页承载）。
class EnterpriseErrorView extends StatelessWidget {
  const EnterpriseErrorView({
    super.key,
    required this.state,
    this.onRetry,
    this.onSignIn,
    this.compact = false,
  });

  final EnterpriseErrorUiState state;

  /// 可重试时的重试回调（[EnterpriseErrorUiState.isRetryable] 为 false 时不展示）。
  final VoidCallback? onRetry;

  /// 需重新登录时的回调（401 两码）。
  final VoidCallback? onSignIn;

  /// 紧凑形态（列表内嵌，不占满屏）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    // 必须可见：任何错误都不允许渲染成「什么都没有」。
    assert(!state.isSilent, 'error state must be visible');
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          _iconFor(state.kind),
          size: compact ? AppSpacing.xLarge : AppSpacing.xxLarge,
          color: _colorFor(state.kind),
        ),
        AppSpacing.verticalSmall,
        Text(
          enterpriseErrorTitle(state.kind),
          textAlign: TextAlign.center,
          style: context.textStyle(
            compact ? FontSizeType.normal : FontSizeType.medium,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.verticalTiny,
        Text(
          enterpriseErrorHint(state.kind),
          textAlign: TextAlign.center,
          style: context.textStyle(
            FontSizeType.footnote,
            color: AppColors.slateText,
          ),
        ),
        if (onSignIn != null && state.needsReauth) ...[
          AppSpacing.verticalSmall,
          OutlinedButton(
            onPressed: onSignIn,
            child: Text(t.enterpriseApp.actionSignIn),
          ),
        ],
        if (onRetry != null && state.isRetryable) ...[
          AppSpacing.verticalSmall,
          TextButton(
            onPressed: onRetry,
            child: Text(t.enterpriseApp.actionRetry),
          ),
        ],
      ],
    );
    return Padding(
      padding: EdgeInsets.all(compact ? AppSpacing.medium : AppSpacing.xLarge),
      child: body,
    );
  }

  IconData _iconFor(EnterpriseErrorKind kind) {
    switch (kind) {
      case EnterpriseErrorKind.rateLimited:
        return CupertinoIcons.time;
      case EnterpriseErrorKind.network:
        return CupertinoIcons.wifi_slash;
      case EnterpriseErrorKind.channelUnbound:
        return CupertinoIcons.link;
      case EnterpriseErrorKind.resourceNotFound:
        return CupertinoIcons.search;
      case EnterpriseErrorKind.securityGateClosed:
      case EnterpriseErrorKind.internalError:
        return CupertinoIcons.exclamationmark_octagon;
      default:
        return CupertinoIcons.exclamationmark_circle;
    }
  }

  Color _colorFor(EnterpriseErrorKind kind) {
    switch (kind) {
      case EnterpriseErrorKind.rateLimited:
      case EnterpriseErrorKind.idempotencyConflict:
      case EnterpriseErrorKind.invalidRequest:
        return AppColors.warning;
      default:
        return AppColors.slateText;
    }
  }
}

/// 空态视图（与错误态分开：空是正常结果，不是失败）。
class EnterpriseEmptyView extends StatelessWidget {
  const EnterpriseEmptyView({super.key, required this.message, this.note});

  final String message;

  /// 可选附注（例如「受限目录：不提供全量导出」）。
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xLarge),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.tray,
            size: AppSpacing.xLarge,
            color: AppColors.slateText,
          ),
          AppSpacing.verticalSmall,
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.normal,
              color: AppColors.slateText,
            ),
          ),
          if (note != null) ...[
            AppSpacing.verticalTiny,
            Text(
              note!,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.tiny,
                color: AppColors.slateText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
