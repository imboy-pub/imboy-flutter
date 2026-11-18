/// Web 端登录页面 - WhatsApp Web 风格
///
/// 功能：
/// - QR 码扫码登录（主推）
/// - 账号密码登录（备选）
/// - 多标签页同步状态显示
/// - 桌面通知权限请求
library;

import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/service/auth_session_scope.dart';

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show deviceId, currentEnv;
import 'package:imboy/component/http/http_request_policy.dart'
    show webHumanRequestUri;
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/widget/web_login_layout.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';
import 'package:imboy/page/passport/qr_login_polling_rules.dart';
import 'package:imboy/page/passport/qr_sse_session.dart';
import 'package:imboy/page/passport/sse_client.dart';
import 'package:imboy/page/passport/web_e2e_bypass.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/service/user_profile_service.dart';

part 'web_login_page.g.dart';
part 'web_login_qr.dart';

// 旁路凭据仅供隔离 debug 测试；交付 profile/release 不读取误带的 define。
// parser 另有实际构建模式硬门禁；正式产物仍需检查无旁路凭据。
const String _kWebE2eTokenEnv = kDebugMode
    ? String.fromEnvironment('WEB_E2E_TOKEN', defaultValue: '')
    : '';
const String _kWebE2eUidEnv = kDebugMode
    ? String.fromEnvironment('WEB_E2E_UID', defaultValue: '')
    : '';

/// QR 码登录状态
enum QRLoginStatus {
  /// 等待扫码
  waiting,

  /// 已扫码，等待确认
  scanned,

  /// 已确认，登录中
  confirming,

  /// 已过期
  expired,

  /// 登录成功
  success,

  /// 登录失败
  failed,
}

/// QR 码登录状态
class QRLoginState {
  final QRLoginStatus status;
  final String? qrData;
  final String? sessionToken;
  final String? errorMessage;
  final int remainingSeconds;

  const QRLoginState({
    this.status = QRLoginStatus.waiting,
    this.qrData,
    this.sessionToken,
    this.errorMessage,
    this.remainingSeconds = 60,
  });

  QRLoginState copyWith({
    QRLoginStatus? status,
    String? qrData,
    String? sessionToken,
    String? errorMessage,
    int? remainingSeconds,
  }) {
    return QRLoginState(
      status: status ?? this.status,
      qrData: qrData ?? this.qrData,
      sessionToken: sessionToken ?? this.sessionToken,
      errorMessage: errorMessage ?? this.errorMessage,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
    );
  }
}

/// QR SSE 客户端工厂签名（PR-4δ：让测试可注入 FakeSseClient）。
typedef SseClientBuilder = SseClient Function();

/// Web 登录页面
class WebLoginPage extends ConsumerStatefulWidget {
  const WebLoginPage({super.key, this.sessionReader});

  final AuthSessionReader? sessionReader;

  @override
  ConsumerState<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends ConsumerState<WebLoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPasswordLogin = false;
  late final AuthSessionReader _sessions =
      widget.sessionReader ?? authSessionReader;
  AuthSessionScope? _startedAnonymousScope;
  AuthSessionScope? _scheduledAnonymousScope;
  int _qrStartGeneration = 0;
  StreamSubscription<void>? _pageWriterFailureSub;
  bool _listeningAuth = false;

  @override
  void initState() {
    super.initState();
    // Web 自动生成普通 QR；仅隔离 debug 测试可使用既有会话旁路。
    if (kIsWeb) {
      final bypass = parseE2eBypassConfig(
        token: _kWebE2eTokenEnv,
        uid: _kWebE2eUidEnv,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        switch (bypass) {
          case BypassDisabled():
            _listenToAuth();
            _pageWriterFailureSub = webWriterFailures.listen((_) {
              _cancelQrStart();
              _stopListeningToAuth();
              _qrLogin?.cancelQRCode();
            });
            _startQrWhenAnonymous();
            // F6/AUT01：带有效会话 reload 落在 sign_in 时，auth 不会再次
            // notify——初始就要检查一次 landed，否则整页停在登录面
            // （aut01-stuck-observation.json：post_reload_hash 停 #/sign_in）。
            if (!_sessions.current.transitioning &&
                _sessions.current.uid.isNotEmpty) {
              _goWebShellAfterAuth();
            }
          case BypassEnabled(:final token, :final uid):
            // 合成登录仍通过与 QR 相同的会话和所有者提交边界。
            await UserRepoLocal.to.loginAfterQr(uid: uid, token: token);
            if (mounted) context.go('/web_shell');
        }
      });
    }
  }

  void _listenToAuth() {
    if (_listeningAuth) return;
    _sessions.addListener(_onAuthChanged);
    _listeningAuth = true;
  }

  void _stopListeningToAuth() {
    if (!_listeningAuth) return;
    _sessions.removeListener(_onAuthChanged);
    _listeningAuth = false;
  }

  void _cancelQrStart() {
    _qrStartGeneration++;
    _scheduledAnonymousScope = null;
  }

  void _onAuthChanged() {
    if (!mounted || _showPasswordLogin) return;
    // F6/AUT01（属主裁决 2026-11-16）：auth 真正落地（uid 非空且转换已完成）
    // 是登录页离开的权威信号，直接导航进壳，不再把导航链绑死在
    // qRLoginProvider 的 success 事件上——QR confirm→commit 窗口内，
    // 提交期 auth notify 会触发本回调的 transitioning/cancelQRCode 分支，
    // generation 失效后 success/hydration 链静默死亡，导航卡死
    // （DEF-AUT01-WEB-COMPLETE 4 轮 live 复现，aut-residuals-20261116）。
    // 这里不调用 cancelQRCode：confirming/hydration 在途时让 notifier
    // 自行收尾，避免把已提交的登录再次掐断。
    final landed = _sessions.current;
    if (landed.uid.isNotEmpty &&
        !landed.transitioning &&
        !_sessions.transitionFailed) {
      _cancelQrStart();
      _stopListeningToAuth();
      _goWebShellAfterAuth();
      return;
    }
    final qr = ref.read(qRLoginProvider.notifier);
    if (qr.canRetryProfile ||
        (ref.read(qRLoginProvider).status == QRLoginStatus.confirming &&
            !qr.hasPendingProfile)) {
      return;
    }
    if (_sessions.transitionFailed) {
      _startQrWhenAnonymous();
      return;
    }
    final scope = _sessions.current;
    if (scope.uid.isNotEmpty || scope.transitioning) {
      _cancelQrStart();
      _startedAnonymousScope = null;
      _qrLogin?.cancelQRCode();
      return;
    }
    _startQrWhenAnonymous();
  }

  /// auth 已落地后的统一出口；重复调用幂等（go 到同一路由）。
  void _goWebShellAfterAuth() {
    if (!mounted) return;
    context.go('/web_shell');
  }

  void _startQrWhenAnonymous({bool explicit = false}) {
    if (!mounted || _showPasswordLogin || !isWebWriterReady) return;
    if (_sessions.transitionFailed) {
      _cancelQrStart();
      _stopListeningToAuth();
      _qrLogin?.failAuthTransition();
      return;
    }
    if (explicit) _listenToAuth();
    final scope = _sessions.current;
    if (scope.uid.isNotEmpty || scope.transitioning) return;
    final qr = ref.read(qRLoginProvider.notifier);
    if (qr.canRetryProfile ||
        (ref.read(qRLoginProvider).status == QRLoginStatus.confirming &&
            !qr.hasPendingProfile)) {
      return;
    }
    if (_scheduledAnonymousScope == scope ||
        (!explicit && _startedAnonymousScope == scope)) {
      return;
    }
    final generation = ++_qrStartGeneration;
    _scheduledAnonymousScope = scope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _qrStartGeneration) return;
      _scheduledAnonymousScope = null;
      if (_showPasswordLogin ||
          !isWebWriterReady ||
          _sessions.current != scope) {
        return;
      }
      final qr = ref.read(qRLoginProvider.notifier);
      if (qr.canRetryProfile ||
          (ref.read(qRLoginProvider).status == QRLoginStatus.confirming &&
              !qr.hasPendingProfile)) {
        return;
      }
      _startedAnonymousScope = scope;
      unawaited(ref.read(qRLoginProvider.notifier).generateQRCode());
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  /// dispose 时 ref.read 已不安全（unmount 期 BuildContext 断言）：
  /// build 期缓存 notifier，退出时用字段清理轮询 timer/SSE。
  QRLogin? _qrLogin;
  PassportNotifier? _passportNotifier;

  @override
  void dispose() {
    _cancelQrStart();
    _stopListeningToAuth();
    _pageWriterFailureSub?.cancel();
    // F3（a11y03-residual-20261116，属主裁决）：离开登录页（含登录成功导航）
    // 时先清空账号/密码输入。引擎层 stale 语义节点/浏览器表单快照可能把
    // <input> 的最后值留在 AX 树里（收据：登录后 chat 面 AX 残留登录表单
    // 且含密码明文 StaticText）——dispose 前清值可让残留节点不再携带明文。
    _accountController.clear();
    _passwordController.clear();
    // 密码可见性是会话级偏好：归位为 obscured，下一次进入登录页默认不可读。
    _passportNotifier?.resetLoginPwdObscure();
    _accountController.dispose();
    _passwordController.dispose();
    _qrLogin?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrState = ref.watch(qRLoginProvider);
    _qrLogin = ref.read(qRLoginProvider.notifier);
    final passportState = ref.watch(passportProvider);
    final passportNotifier = ref.read(passportProvider.notifier);
    // F3：dispose 里 ref.read 不安全，build 期缓存（与 _qrLogin 同一模式）。
    _passportNotifier = passportNotifier;

    // 监听 QR 登录成功
    ref.listen<QRLoginState>(qRLoginProvider, (previous, next) {
      if (next.status == QRLoginStatus.success) {
        // Phase 1.1.i: WebLoginPage 仅在 kIsWeb 时被调用（参见 app_router.dart:113），
        // 登录成功统一跳到 Web Shell 三栏壳；窄屏由 WebShellBootstrap 内部回退到
        // BottomNavigationPage（响应式断点 1.1.a resolveShellLayout 处理）
        context.go('/web_shell');
      }
    });

    return Scaffold(
      backgroundColor: AppColors.darkBackground, // WhatsApp Web 深色背景
      body: WebLoginLayout(
        child: _buildRightSection(
          context,
          qrState,
          passportState,
          passportNotifier,
        ),
      ),
    );
  }

  /// 右侧登录区域
  Widget _buildRightSection(
    BuildContext context,
    QRLoginState qrState,
    PassportState passportState,
    PassportNotifier passportNotifier,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_showPasswordLogin) ...[
          // QR 码登录
          _buildQRLoginSection(qrState),
          AppSpacing.verticalXLarge,
          // 切换到密码登录
          CupertinoButton(
            onPressed: qrState.status == QRLoginStatus.confirming
                ? null
                : () {
                    _cancelQrStart();
                    ref.read(qRLoginProvider.notifier).cancelQRCode();
                    setState(() => _showPasswordLogin = true);
                  },
            child: Text(
              t.account.webSwitchToPassword,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.primary,
              ),
            ),
          ),
        ] else ...[
          // 账号密码登录
          _buildPasswordLoginSection(passportState, passportNotifier),
          AppSpacing.verticalXLarge,
          // 切换回 QR 码登录
          CupertinoButton(
            onPressed: () {
              setState(() => _showPasswordLogin = false);
              _startQrWhenAnonymous(explicit: true);
            },
            child: Text(
              t.main.webSwitchToQR,
              style: context.textStyle(
                FontSizeType.normal,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// QR 码登录区域
  Widget _buildQRLoginSection(QRLoginState qrState) {
    return Column(
      children: [
        Text(
          t.account.webQRLoginTitle,
          style: context.textStyle(
            FontSizeType.largeTitle,
            fontWeight: FontWeight.bold,
            color: AppColors.darkTextPrimary,
          ),
        ),
        AppSpacing.verticalSmall,
        Text(
          t.account.webQRLoginHint,
          style: context.textStyle(
            FontSizeType.normal,
            color: AppColors.darkTextSecondary,
          ),
        ),
        AppSpacing.verticalXXLarge,
        // QR 码容器
        Container(
          width: 256,
          height: 256,
          padding: const EdgeInsets.all(AppSpacing.regular),
          decoration: BoxDecoration(
            // QR 码白底：保持浅色以保证扫码识别（不随主题切换）
            color: AppColors.lightSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: qrState.status == QRLoginStatus.waiting
              ? _buildQRContent(qrState)
              : Center(
                  child: SingleChildScrollView(child: _buildQRContent(qrState)),
                ),
        ),
        AppSpacing.verticalRegular,
        // 状态文字
        _buildQRStatusText(qrState),
        AppSpacing.verticalRegular,
        // 刷新按钮（过期时显示）
        if (qrState.status == QRLoginStatus.expired ||
            qrState.status == QRLoginStatus.failed)
          CupertinoButton(
            onPressed: () {
              final qr = ref.read(qRLoginProvider.notifier);
              if (qr.canRetryProfile) {
                unawaited(qr.refresh());
              } else {
                _startQrWhenAnonymous(explicit: true);
              }
            },
            borderRadius: BorderRadius.circular(24),
            color: AppColors.primaryDark,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.arrow_clockwise),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(t.main.webQRRefresh, textAlign: TextAlign.center),
                ),
              ],
            ),
          ),
        // 倒计时
        if (qrState.status == QRLoginStatus.waiting ||
            qrState.status == QRLoginStatus.scanned)
          Text(
            t.common.webQRExpiresIn(seconds: qrState.remainingSeconds),
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.darkTextDisabled,
            ),
          ),
      ],
    );
  }

  Widget _buildQRContent(QRLoginState qrState) {
    switch (qrState.status) {
      case QRLoginStatus.waiting:
        if (qrState.qrData == null) {
          return const Center(child: CupertinoActivityIndicator());
        }
        // 私有 scheme 包装，便于手机端 scanner 通过 detectQrLoginIntent 识别
        // 为 web 登录 QR（与 user/group/channel HTTP URL 名片命名空间隔离）。
        return QrImageView(
          data: 'imboy://qr_login/${qrState.qrData!}',
          version: QrVersions.auto,
          size: 224,
          // QR 码白底：保持浅色以保证扫码识别（不随主题切换）
          backgroundColor: AppColors.lightSurface,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
        );

      case QRLoginStatus.scanned:
        return Container(
          color: AppColors.primary.withAlpha(26), // 0.1 * 255 ≈ 26
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.device_phone_portrait,
                  size: 64,
                  color: AppColors.primary,
                ),
                AppSpacing.verticalRegular,
                Text(
                  t.discovery.webQRScanned,
                  style: context.textStyle(
                    FontSizeType.large,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  t.common.webQRConfirmOnPhone,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.iosGray,
                  ),
                ),
              ],
            ),
          ),
        );

      case QRLoginStatus.confirming:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(),
              AppSpacing.verticalRegular,
              Text(
                t.main.webQRLoggingIn,
                style: context.textStyle(
                  FontSizeType.medium,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );

      case QRLoginStatus.expired:
        return Container(
          color: AppColors.lightSurfaceContainer,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.qrcode_viewfinder,
                  size: 64,
                  color: AppColors.lightTextDisabled,
                ),
                AppSpacing.verticalSmall,
                Text(
                  t.main.webQRExpired,
                  style: context.textStyle(
                    FontSizeType.medium,
                    color: AppColors.lightTextDisabled,
                  ),
                ),
              ],
            ),
          ),
        );

      case QRLoginStatus.failed:
        return Container(
          color: AppColors.lightErrorContainer,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  CupertinoIcons.exclamationmark_circle,
                  size: 64,
                  color: AppColors.iosRed,
                ),
                AppSpacing.verticalSmall,
                Text(
                  qrState.errorMessage ?? t.common.webQRLoginFailed,
                  style: context.textStyle(
                    FontSizeType.normal,
                    color: AppColors.iosRed,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );

      case QRLoginStatus.success:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.checkmark_circle,
                size: 64,
                color: AppColors.primary,
              ),
              AppSpacing.verticalRegular,
              Text(
                t.common.webQRLoginSuccess,
                style: context.textStyle(
                  FontSizeType.large,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildQRStatusText(QRLoginState qrState) {
    String text;
    IconData icon;

    switch (qrState.status) {
      case QRLoginStatus.waiting:
        text = t.chat.webQRStatusWaiting;
        icon = CupertinoIcons.qrcode_viewfinder;
      case QRLoginStatus.scanned:
        text = t.chat.webQRStatusScanned;
        icon = CupertinoIcons.device_phone_portrait;
      case QRLoginStatus.confirming:
        text = t.chat.webQRStatusVerifying;
        icon = CupertinoIcons.clock;
      case QRLoginStatus.expired:
        text = t.chat.webQRStatusExpired;
        icon = CupertinoIcons.arrow_clockwise;
      case QRLoginStatus.failed:
        text = qrState.errorMessage ?? t.common.webQRStatusFailed;
        icon = CupertinoIcons.exclamationmark_circle;
      case QRLoginStatus.success:
        text = t.common.webQRStatusSuccess;
        icon = CupertinoIcons.checkmark_circle;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.darkTextSecondary),
        AppSpacing.horizontalSmall,
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.darkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// 账号密码登录区域
  Widget _buildPasswordLoginSection(
    PassportState passportState,
    PassportNotifier passportNotifier,
  ) {
    return Column(
      children: [
        Text(
          t.account.webPasswordLoginTitle,
          style: context.textStyle(
            FontSizeType.largeTitle,
            fontWeight: FontWeight.bold,
            color: AppColors.darkTextPrimary,
          ),
        ),
        AppSpacing.verticalXXLarge,
        // 账号输入
        TextField(
          enableSuggestions: false,
          autocorrect: false,
          controller: _accountController,
          style: TextStyle(color: AppColors.darkTextPrimary),
          decoration: InputDecoration(
            hintText: t.account.webAccountHint,
            hintStyle: const TextStyle(color: AppColors.darkTextDisabled),
            prefixIcon: Icon(
              CupertinoIcons.person,
              color: AppColors.darkTextDisabled,
            ),
            filled: true,
            fillColor: AppColors.darkSurfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        AppSpacing.verticalRegular,
        // 密码输入
        TextField(
          enableSuggestions: false,
          autocorrect: false,
          controller: _passwordController,
          obscureText: passportState.loginPwdObscure,
          style: TextStyle(color: AppColors.darkTextPrimary),
          decoration: InputDecoration(
            hintText: t.account.webPasswordHint,
            hintStyle: const TextStyle(color: AppColors.darkTextDisabled),
            prefixIcon: const Icon(
              CupertinoIcons.lock,
              color: AppColors.darkTextDisabled,
            ),
            suffixIcon: IconButton(
              tooltip: passportState.loginPwdObscure
                  ? t.common.showPassword
                  : t.common.hidePassword,
              icon: Icon(
                passportState.loginPwdObscure
                    ? CupertinoIcons.eye
                    : CupertinoIcons.eye_slash,
                color: AppColors.darkTextDisabled,
              ),
              onPressed: () => passportNotifier.toggleLoginPwdObscure(),
            ),
            filled: true,
            fillColor: AppColors.darkSurfaceContainerHighest,
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        AppSpacing.verticalXLarge,
        // 登录按钮
        SizedBox(
          width: double.infinity,
          child: CupertinoButton.filled(
            minimumSize: const Size(0, 48),
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(24),
            child: Text(
              t.account.login,
              style: context.textStyle(
                FontSizeType.medium,
                color: AppColors.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () async {
              final account = _accountController.text;
              final pwd = _passwordController.text;

              if (account.isEmpty || pwd.isEmpty) {
                passportNotifier.setError(t.common.webLoginEmptyError);
                return;
              }

              final error = await passportNotifier.loginUser(
                account.contains('@') ? 'email' : 'account',
                account,
                pwd,
              );

              if (error == null) {
                if (mounted) {
                  // Phase 1.1.i: WebLoginPage 仅在 kIsWeb 时被调用（参见 app_router.dart:113），
                  // 登录成功统一跳到 Web Shell 三栏壳；窄屏由 WebShellBootstrap 内部回退到
                  // BottomNavigationPage（响应式断点 1.1.a resolveShellLayout 处理）
                  context.go('/web_shell');
                }
              } else {
                passportNotifier.snackBar(error);
              }
            },
          ),
        ),
        // 拦截提示：账号/密码为空等客户端校验错误经 [PassportNotifier.setError]
        // 写入 state.error，此前页面无渲染位，用户看不到任何反馈
        // （批次126 空值提交场景实证）。
        if (passportState.error.isNotEmpty) ...[
          AppSpacing.verticalRegular,
          Text(
            passportState.error,
            textAlign: TextAlign.center,
            style: context.textStyle(
              FontSizeType.small,
              color: AppColors.iosRed,
            ),
          ),
        ],
        AppSpacing.verticalRegular,
        // 忘记密码
        CupertinoButton(
          onPressed: () => context.push(AppRoutes.forgotPassword),
          child: Text(
            t.account.forgotPassword,
            style: context.textStyle(
              FontSizeType.normal,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
