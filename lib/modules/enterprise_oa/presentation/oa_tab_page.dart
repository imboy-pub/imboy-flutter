/// OA Tab 容器页面骨架（EPGZ-06 W1 / plan §7.2）
///
/// W1 交付范围：状态机驱动的**渲染骨架**——七个稳定 UI 状态
/// （loading / ready / error / expired / logged-out / domain-mismatch /
/// oa-401）各自的占位视图与动作入口；**不接真 WebView、不接共享
/// router/导航**（W3 集成波次由 A0 持 lease 协调时接线）。
///
/// W3 接线点（本骨架预留，勿在 W1 提前接线）：
/// - ready 态的 [_OaWebViewSlot] 替换为真实 WebView 容器（挂
///   ExactOriginNavigationHandler 到 NavigationDelegate）；
/// - onRetry / onRestartSso 回调替换为真实 SSO code 获取
///   （POST /api/v1/oa/sso/code）+ redirect 跳转链路；
/// - 状态机事件由 WebView 回调与 API 结果驱动，而非本骨架的演示入口。
///
/// 颜色/间距/字号全部走 token；文案走 i18n enterpriseOa 命名空间。
library;

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// OA Tab 容器骨架页。
///
/// [machine] 可注入（测试用）；[onRetry]/[onRestartSso] 为 W3 预留的
/// 动作回调（骨架阶段可为空，仅驱动状态机演示迁移）。
class OaTabPage extends StatefulWidget {
  const OaTabPage({super.key, this.machine, this.onRetry, this.onRestartSso});

  /// 外部注入的状态机；缺省自建（loading 起步）。
  final OaTabStateMachine? machine;

  /// 「重试」动作回调（error / originMismatch 态可见）。
  final void Function()? onRetry;

  /// 「重新单点登录」动作回调（expired / logged-out / oa401 态可见）。
  final void Function()? onRestartSso;

  @override
  State<OaTabPage> createState() => _OaTabPageState();
}

class _OaTabPageState extends State<OaTabPage> {
  late final OaTabStateMachine _machine;

  @override
  void initState() {
    super.initState();
    _machine = widget.machine ?? OaTabStateMachine();
  }

  void _handleRetry() {
    if (_machine.retry()) widget.onRetry?.call();
    setState(() {});
  }

  void _handleRestartSso() {
    if (_machine.restartSso()) widget.onRestartSso?.call();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(t.enterpriseOa.title), centerTitle: true),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey<OaTabStatus>(_machine.status),
          child: _buildStatusView(context),
        ),
      ),
    );
  }

  Widget _buildStatusView(BuildContext context) {
    switch (_machine.status) {
      case OaTabStatus.loading:
        return const _OaLoadingView();
      case OaTabStatus.ready:
        return _OaWebViewSlot(machine: _machine);
      case OaTabStatus.error:
        return _OaStatusMessageView(
          iconData: CupertinoIcons.wifi_exclamationmark,
          title: t.enterpriseOa.statusErrorTitle,
          hint: t.enterpriseOa.statusErrorHint,
          actionLabel: t.enterpriseOa.actionRetry,
          onAction: _handleRetry,
        );
      case OaTabStatus.sessionExpired:
        return _OaStatusMessageView(
          iconData: CupertinoIcons.timer,
          title: t.enterpriseOa.statusExpiredTitle,
          hint: t.enterpriseOa.statusExpiredHint,
          actionLabel: t.enterpriseOa.actionRestartSso,
          onAction: _handleRestartSso,
        );
      case OaTabStatus.loggedOut:
        return _OaStatusMessageView(
          iconData: CupertinoIcons.square_arrow_right,
          title: t.enterpriseOa.statusLoggedOutTitle,
          hint: t.enterpriseOa.statusLoggedOutHint,
          actionLabel: t.enterpriseOa.actionRestartSso,
          onAction: _handleRestartSso,
        );
      case OaTabStatus.originMismatch:
        return _OaStatusMessageView(
          iconData: CupertinoIcons.exclamationmark_shield,
          title: t.enterpriseOa.statusMismatchTitle,
          hint: t.enterpriseOa.statusMismatchHint,
          detail: _mismatchBlockedHost(),
          actionLabel: t.enterpriseOa.actionRetry,
          onAction: _handleRetry,
        );
      case OaTabStatus.oaUnauthorized:
        return _OaStatusMessageView(
          iconData: CupertinoIcons.lock,
          title: t.enterpriseOa.statusOa401Title,
          hint: t.enterpriseOa.statusOa401Hint,
          actionLabel: t.enterpriseOa.actionRestartSso,
          onAction: _handleRestartSso,
        );
    }
  }

  /// 被拦截跳转的 host 附注行（仅 host 形态，不含 query/fragment 等
  /// 敏感参数，降低日志/截屏泄漏面）；无事实时返回 null 不渲染。
  String? _mismatchBlockedHost() {
    final OaOriginMismatchFact? fact = _machine.mismatchFact;
    if (fact == null) return null;
    final String? attemptedHost = Uri.tryParse(fact.attemptedUrl)?.host
        .toLowerCase();
    if (attemptedHost == null || attemptedHost.isEmpty) return null;
    return t.enterpriseOa.statusMismatchBlockedHost(host: attemptedHost);
  }
}

/// loading 态：居中进度指示 + 说明文案。
class _OaLoadingView extends StatelessWidget {
  const _OaLoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: AppSpacing.regular),
          Text(
            t.enterpriseOa.statusLoading,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.slateText,
            ),
          ),
        ],
      ),
    );
  }
}

/// WebView 挂载槽（W3 替换为真实容器）。
///
/// 骨架阶段展示占位说明，验证 ready 态渲染路径与挂载点位置。
class _OaWebViewSlot extends StatelessWidget {
  const _OaWebViewSlot({required this.machine});

  final OaTabStateMachine machine;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.briefcase,
              size: AppSizes.iconSizeXLarge,
              color: AppColors.slateMuted,
            ),
            SizedBox(height: AppSpacing.medium),
            Text(
              t.enterpriseOa.webviewSlotHint,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.slateText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 通用错误/失效态视图：图标 + 标题 + 说明 + 可选附注行 + 单个动作按钮。
class _OaStatusMessageView extends StatelessWidget {
  const _OaStatusMessageView({
    required this.iconData,
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onAction,
    this.detail,
  });

  final IconData iconData;
  final String title;
  final String hint;

  /// 附注行（如被拦截 host）；null 时不渲染。
  final String? detail;

  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.large),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              iconData,
              size: AppSizes.iconSizeXLarge,
              color: AppColors.slateMuted,
            ),
            SizedBox(height: AppSpacing.medium),
            Text(
              title,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.body,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: AppSpacing.small),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.slateText,
              ),
            ),
            if (detail != null) ...[
              SizedBox(height: AppSpacing.tiny),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: context.textStyle(
                  FontSizeType.tiny,
                  color: AppColors.slateMuted,
                ),
              ),
            ],
            SizedBox(height: AppSpacing.regular),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
