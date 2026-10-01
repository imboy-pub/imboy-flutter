/// OA Tab 容器页面（EPGZ-06 W3 / plan §7.2）
///
/// W3 集成形态：状态机由**真实回调驱动**——
/// - `POST /api/v1/oa/sso/code`（Human JWT 既有认证基建）换取 60s 一次性
///   code，构造 `redirect_uri?code=…&state=<nonce>` 后挂载真 WebView
///   （[OaWebViewContainer]）；
/// - 60s 倒计时 UI（code 有效期恒 60s，A5 合同）；归零 → sessionExpired
///   终态（不重试同 code，重新签发完全独立）；
/// - issue 侧错误码经 [targetStatusForIssueFailure] 映射到 W1 状态机；
/// - WebView 导航/加载事件经 [OaWebViewEventHandlers] 驱动状态机。
///
/// 安全边界（plan §7.2）：WebView 不注入 IMBoy JWT / Application secret、
/// 不开 JS bridge（见 oa_webview_container.dart 库文档）；一次性 code 只
/// 在内存流转，不持久化、不打日志。
///
/// W1 兼容：`machine`/`onRetry`/`onRestartSso` 注入形态保持——未配置
/// OA（fallback config）时不发起 SSO，ready 态仍渲染占位槽，骨架测试
/// 不变。
///
/// 颜色/间距/字号全部走 token；文案走 i18n enterpriseOa 命名空间。
library;

import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import 'package:imboy/component/helper/func.dart' show iPrint;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/enterprise_oa/data/oa_sso_api.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_sso_issue.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_tab_state.dart';
import 'package:imboy/modules/enterprise_oa/domain/oa_webview_policy.dart';
import 'package:imboy/modules/enterprise_oa/enterprise_oa_runtime_config.dart';
import 'package:imboy/modules/enterprise_oa/presentation/oa_webview_container.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_sizes.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/store/model/workspace_model.dart' show EntityId;

/// SSO 签发出口（生产 [ApiOaSsoIssueLauncher]；测试注入 fake）。
abstract interface class OaSsoIssueLauncher {
  Future<OaSsoIssueResult> launch({
    required String applicationKey,
    required String redirectUri,
    required String nonce,
  });
}

/// 生产签发出口：OaSsoApi 直连。
class ApiOaSsoIssueLauncher implements OaSsoIssueLauncher {
  ApiOaSsoIssueLauncher({this.organizationId});

  final EntityId? organizationId;

  final OaSsoApi _api = OaSsoApi();

  @override
  Future<OaSsoIssueResult> launch({
    required String applicationKey,
    required String redirectUri,
    required String nonce,
  }) {
    return _api.issueCode(
      applicationKey: applicationKey,
      redirectUri: redirectUri,
      nonce: nonce,
      organizationId: organizationId,
    );
  }
}

/// WebView 槽位接线属性（默认真容器；测试 fake 同形接线回调）。
@immutable
class OaWebViewSlotProps {
  const OaWebViewSlotProps({
    required this.initialUrl,
    required this.machine,
    required this.allowedOrigin,
    required this.onFirstPageLoaded,
    required this.onStateChanged,
  });

  /// 首次加载 URL（`redirect_uri?code=…&state=…`）。
  final String initialUrl;

  final OaTabStateMachine machine;

  /// 唯一允许的 exact HTTPS origin（BrandConfig.oaOrigin）。
  final String allowedOrigin;

  /// 首次页面加载完成（loading → ready 之后停 60s 倒计时）。
  final VoidCallback onFirstPageLoaded;

  /// 任意状态机迁移通知（协调器 setState）。
  final VoidCallback onStateChanged;
}

/// WebView 槽位构建器（缺省真 [OaWebViewContainer]；测试注入 fake）。
typedef OaWebViewSlotBuilder = Widget Function(OaWebViewSlotProps props);

/// OA Tab 容器页（SSO 协调器）。
class OaTabPage extends StatefulWidget {
  const OaTabPage({
    super.key,
    this.machine,
    this.onRetry,
    this.onRestartSso,
    this.config,
    this.ssoLauncher,
    this.webViewBuilder,
    this.nonceGenerator,
    this.autoStart = true,
    this.accountKey,
    this.organizationId,
  });

  /// 外部注入的状态机；缺省自建（loading 起步）。
  final OaTabStateMachine? machine;

  /// 「重试」动作回调（error / originMismatch 态可见）。
  final void Function()? onRetry;

  /// 「重新单点登录」动作回调（expired / logged-out / oa401 态可见）。
  final void Function()? onRestartSso;

  /// 运行时配置；缺省解析 dart-define（未配置 OA → fallback，不发起 SSO）。
  final EnterpriseOaRuntimeConfig? config;

  /// SSO 签发出口；缺省 [ApiOaSsoIssueLauncher]（测试注入 fake）。
  final OaSsoIssueLauncher? ssoLauncher;

  /// WebView 槽位构建器；缺省真 [OaWebViewContainer]，测试注入 fake
  /// 以脱离平台通道。
  final OaWebViewSlotBuilder? webViewBuilder;

  /// nonce 生成器注入（测试固定值；生产 CSPRNG）。
  final String Function()? nonceGenerator;

  /// 是否在 initState 自动发起 SSO（缺省 true；测试可关闭手工驱动）。
  final bool autoStart;

  /// 宿主登录/企业上下文；null 保留无宿主的既有测试与独立页面形态。
  final String? accountKey;
  final EntityId? organizationId;

  @override
  State<OaTabPage> createState() => _OaTabPageState();
}

class _OaTabPageState extends State<OaTabPage>
    with AutomaticKeepAliveClientMixin<OaTabPage> {
  @override
  bool get wantKeepAlive => true;
  late final OaTabStateMachine _machine;
  late EnterpriseOaRuntimeConfig _config;

  /// 当前 launch URL（issue 成功后非空；null = 未取得/已失效）。
  String? _activeUrl;

  /// WebView 挂载代数（SSO 重启/重挂载时递增，强制重建 controller）。
  int _webviewGeneration = 0;

  /// 倒计时剩余秒数；null = 倒计时未运行。
  int? _countdownRemaining;

  /// 倒计时是否已归零过（归零后同 code 不可再用，重试须重新签发）。
  bool _countdownExpired = false;

  Timer? _countdownTimer;
  bool _ssoInFlight = false;
  int _issueGeneration = 0;
  bool _contextInvalidated = false;

  @override
  void initState() {
    super.initState();
    _machine = widget.machine ?? OaTabStateMachine();
    _config = widget.config ?? resolveEnterpriseOaRuntimeConfig();
    if (widget.accountKey == '' || widget.organizationId == '') {
      _invalidateContext();
    }
    if (widget.autoStart && _machine.status == OaTabStatus.loading) {
      // initState 内不 await：SSE/HTTP 均为异步，结果经 setState 回流。
      Future.microtask(_startSso);
    }
  }

  @override
  void dispose() {
    _issueGeneration++;
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(OaTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final config = widget.config ?? resolveEnterpriseOaRuntimeConfig();
    if (oldWidget.accountKey != widget.accountKey ||
        oldWidget.organizationId != widget.organizationId ||
        _config.applicationKey != config.applicationKey ||
        _config.redirectUri != config.redirectUri ||
        _config.brand.oaOrigin != config.brand.oaOrigin) {
      _config = config;
      _invalidateContext();
    }
  }

  void _invalidateContext() {
    // ponytail: 身份变化后锁住本页；企业 OA 配置经服务端绑定后再接恢复流程。
    _contextInvalidated = true;
    _issueGeneration++;
    _ssoInFlight = false;
    _activeUrl = null;
    _countdownRemaining = null;
    _countdownExpired = true;
    _stopCountdown();
    _machine.invalidateSession();
  }

  bool get _ssoCapable => _config.ssoConfigComplete;

  // -------------------------------------------------------------------
  // SSO 链路
  // -------------------------------------------------------------------

  Future<void> _startSso() async {
    if (_ssoInFlight || !mounted || _contextInvalidated) return;
    if (!_ssoCapable) {
      // 配置残缺（部署错误/测试直构）：保持骨架形态不动状态机——
      // 正常入口已由 runtimeEntryEnabled 隐藏本页，这里仅记日志。
      iPrint('[OaTab] SSO config incomplete, entry should be hidden');
      return;
    }
    _ssoInFlight = true;
    final generation = ++_issueGeneration;
    _stopCountdown();
    setState(() {
      _countdownRemaining = null;
      _countdownExpired = false;
      _activeUrl = null;
    });

    final String nonce = widget.nonceGenerator?.call() ?? generateOaSsoNonce();
    final OaSsoIssueResult result =
        await (widget.ssoLauncher ??
                ApiOaSsoIssueLauncher(organizationId: widget.organizationId))
            .launch(
              applicationKey: _config.applicationKey,
              redirectUri: _config.redirectUri,
              nonce: nonce,
            )
            .onError(
              (Object error, StackTrace stack) =>
                  const OaSsoIssueFailed(OaSsoIssueFailureKind.network),
            );
    if (!mounted || generation != _issueGeneration) return;
    _ssoInFlight = false;

    switch (result) {
      case OaSsoCodeIssued(
        :final code,
        :final redirectUri,
        :final expiresInSeconds,
      ):
        final String url = buildOaSsoLaunchUrl(
          redirectUri: redirectUri,
          code: code,
          state: nonce,
        );
        // 纵深防御：回显 redirect 与配置 origin exact 校验（runtime config
        // 已在入口判定过，这里挡服务端回显漂移）。
        if (evaluateOrigin(_config.brand.oaOrigin, url) !=
            OaOriginVerdict.allow) {
          iPrint('[OaTab] echoed redirect left allowed origin');
          _machine.markOriginMismatch(
            attemptedUrl: redirectUri,
            allowedOrigin: _config.brand.oaOrigin,
          );
          setState(() {});
          return;
        }
        setState(() {
          _activeUrl = url;
          _webviewGeneration++;
          _countdownRemaining = expiresInSeconds;
        });
        _startCountdown(expiresInSeconds);
      case OaSsoIssueFailed(:final kind):
        iPrint('[OaTab] sso issue failed: ${kind.wireName}');
        _applyIssueFailure(kind);
    }
  }

  void _applyIssueFailure(OaSsoIssueFailureKind kind) {
    final OaTabStatus target = targetStatusForIssueFailure(kind);
    switch (target) {
      case OaTabStatus.sessionExpired:
        _machine.markSessionExpired();
      case OaTabStatus.error:
        _machine.markError();
      default:
        break;
    }
    setState(() {});
  }

  // -------------------------------------------------------------------
  // 60s 倒计时（code 一次性有效期）
  // -------------------------------------------------------------------

  void _startCountdown(int seconds) {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final int remaining = _countdownRemaining ?? 0;
      if (remaining <= 1) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
        _countdownExpired = true;
        // 归零 → 过期终态（仅 loading/ready 合法；error/mismatch 等状态
        // 保留自身恢复入口，code 已死由 _countdownExpired 记录）。
        _machine.markSessionExpired();
        setState(() => _countdownRemaining = 0);
        return;
      }
      setState(() => _countdownRemaining = remaining - 1);
    });
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  // -------------------------------------------------------------------
  // 动作
  // -------------------------------------------------------------------

  void _handleRetry() {
    if (_contextInvalidated) return;
    if (_machine.retry()) {
      widget.onRetry?.call();
      // code 仍有效期内：重挂同 URL；否则（含从未取得 code）重新签发。
      if (_activeUrl != null && !_countdownExpired) {
        setState(() => _webviewGeneration++);
      } else {
        Future.microtask(_startSso);
      }
    }
    setState(() {});
  }

  void _handleRestartSso() {
    if (_contextInvalidated) return;
    if (_machine.restartSso()) {
      widget.onRestartSso?.call();
      Future.microtask(_startSso);
    }
    setState(() {});
  }

  /// WebView 事件回流（状态机被 OaWebViewEventHandlers 迁移后）。
  void _handleWebViewStateChanged() {
    if (!mounted || _contextInvalidated) return;
    // 进入终态（非 loading/ready）时停倒计时——code 有效期对恢复动作
    // 的意义由 _countdownExpired（归零标志）保留。
    switch (_machine.status) {
      case OaTabStatus.error:
      case OaTabStatus.sessionExpired:
      case OaTabStatus.loggedOut:
      case OaTabStatus.originMismatch:
      case OaTabStatus.oaUnauthorized:
        _stopCountdown();
      case OaTabStatus.loading:
      case OaTabStatus.ready:
        break;
    }
    setState(() {});
  }

  void _handleFirstPageLoaded() {
    if (_contextInvalidated) return;
    _stopCountdown();
    if (!mounted) return;
    setState(() => _countdownRemaining = null);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text(t.enterpriseOa.title), centerTitle: true),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          // Loading and ready share one controller: the launch code is single-use.
          key: ValueKey<OaTabStatus>(
            _machine.status == OaTabStatus.ready
                ? OaTabStatus.loading
                : _machine.status,
          ),
          child: _buildStatusView(context),
        ),
      ),
    );
  }

  Widget _buildStatusView(BuildContext context) {
    switch (_machine.status) {
      case OaTabStatus.loading:
        // code 已取得：WebView 在 loading 期即挂载（ready 由其
        // onPageFinished 驱动——先挂载才可能就绪），叠加载入遮罩 +
        // 倒计时；未取得 code 时仅展示签发中视图。
        if (_activeUrl != null) {
          return _buildActiveWebView();
        }
        return _OaLoadingView(
          issuingSso: _ssoInFlight || (_activeUrl == null && _ssoCapable),
          countdownRemaining: null,
        );
      case OaTabStatus.ready:
        return _activeUrl == null ? _buildWebViewSlot() : _buildActiveWebView();
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
          hint: _contextInvalidated
              ? t.common.noPermission
              : t.enterpriseOa.statusLoggedOutHint,
          actionLabel: t.enterpriseOa.actionRestartSso,
          onAction: _contextInvalidated ? null : _handleRestartSso,
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

  Widget _buildActiveWebView() => Stack(
    children: [
      Positioned.fill(child: _buildWebViewSlot()),
      if (_machine.status == OaTabStatus.loading)
        Positioned.fill(
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: _OaLoadingView(
              issuingSso: false,
              countdownRemaining: _countdownRemaining,
            ),
          ),
        ),
    ],
  );

  /// WebView 槽：有 activeUrl → 真 WebView（loading/ready 两态共用，
  /// ready 由 onPageFinished 驱动）；否则保留 W1 占位（未配置 OA 的
  /// 直构形态，如骨架测试）。
  Widget _buildWebViewSlot() {
    final String? url = _activeUrl;
    if (url == null) {
      return _OaWebViewSlot(machine: _machine);
    }
    final generation = _issueGeneration;
    final OaWebViewSlotProps props = OaWebViewSlotProps(
      initialUrl: url,
      machine: _machine,
      allowedOrigin: _config.brand.oaOrigin,
      onFirstPageLoaded: () {
        if (generation == _issueGeneration) _handleFirstPageLoaded();
      },
      onStateChanged: () {
        if (generation == _issueGeneration) _handleWebViewStateChanged();
      },
    );
    final Widget slot = widget.webViewBuilder != null
        ? widget.webViewBuilder!(props)
        : OaWebViewContainer(
            initialUrl: props.initialUrl,
            machine: props.machine,
            allowedOrigin: props.allowedOrigin,
            onFirstPageLoaded: props.onFirstPageLoaded,
            onStateChanged: props.onStateChanged,
          );
    return KeyedSubtree(key: ValueKey<int>(_webviewGeneration), child: slot);
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

/// loading 态：居中进度指示 + 签发/倒计时说明。
class _OaLoadingView extends StatelessWidget {
  const _OaLoadingView({required this.issuingSso, this.countdownRemaining});

  /// 是否处于「签发中」（issue 请求在途）。
  final bool issuingSso;

  /// 倒计时剩余秒数（code 已取得、WebView 首帧加载中）；null 不渲染。
  final int? countdownRemaining;

  @override
  Widget build(BuildContext context) {
    final int? remaining = countdownRemaining;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          SizedBox(height: AppSpacing.regular),
          Text(
            issuingSso
                ? t.enterpriseOa.ssoIssuing
                : t.enterpriseOa.statusLoading,
            style: context.textStyle(
              FontSizeType.footnote,
              color: AppColors.slateText,
            ),
          ),
          if (remaining != null) ...[
            SizedBox(height: AppSpacing.tiny),
            Text(
              t.enterpriseOa.ssoCountdown(seconds: '$remaining'),
              style: context.textStyle(
                FontSizeType.tiny,
                color: AppColors.slateMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// WebView 挂载槽（未配置 OA / 未取得 code 时的占位，W1 形态保留）。
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
  final VoidCallback? onAction;

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
