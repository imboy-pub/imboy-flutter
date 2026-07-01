/// Web 端登录页面 - WhatsApp Web 风格
///
/// 功能：
/// - QR 码扫码登录（主推）
/// - 账号密码登录（备选）
/// - 多标签页同步状态显示
/// - 桌面通知权限请求
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/ui/debounce_button.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';
import 'package:imboy/page/passport/qr_login_polling_rules.dart';
import 'package:imboy/page/passport/qr_sse_session.dart';
import 'package:imboy/page/passport/sse_client.dart';
import 'package:imboy/page/passport/web_e2e_bypass.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/secure_token_storage_service.dart';
import 'package:imboy/config/const.dart' show Keys;
import 'package:imboy/service/storage.dart' show StorageService;

part 'web_login_page.g.dart';

// Step 2 (#8) — E2E 测试旁路 dart-define 守卫
// 生产构建默认空字符串 → parseE2eBypassConfig 返回 BypassDisabled，零运行时开销
const String _kWebE2eTokenEnv = String.fromEnvironment(
  'WEB_E2E_TOKEN',
  defaultValue: '',
);
const String _kWebE2eUidEnv = String.fromEnvironment(
  'WEB_E2E_UID',
  defaultValue: '',
);

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

/// QR 码登录状态管理
@riverpod
class QRLogin extends _$QRLogin {
  Timer? _pollTimer;
  Timer? _expireTimer;
  String? _webDeviceId;

  /// PR-4δ：SSE 会话（Web 平台主路径，失败 fallback 到 _startPolling）
  QrSseSession? _sseSession;

  /// PR-4δ：SSE 客户端工厂，测试可通过 setter 替换为 FakeSseClient
  /// 默认走 platform-conditional createSseClient（Web 真实 EventSource，
  /// 非 Web 走 IO stub 抛 UnsupportedError）。
  SseClientBuilder _sseClientBuilder = createSseClient;
  // ignore: avoid_setters_without_getters
  set sseClientBuilderForTesting(SseClientBuilder builder) =>
      _sseClientBuilder = builder;

  @override
  QRLoginState build() {
    return const QRLoginState();
  }

  /// 生成新的 QR 码
  Future<void> generateQRCode() async {
    try {
      // 获取或创建 Web 设备 ID
      _webDeviceId ??= 'web_${DateTime.now().millisecondsSinceEpoch}';

      // 调用后端 API 生成登录 QR 码
      final response = await HttpClient.client.post(
        '/api/v1/passport/qr_login/create',
        data: {
          'device_id': _webDeviceId,
          'device_name': 'Web Browser',
          'platform': 'web',
        },
      );

      // slice-5b：委托纯函数解析（27 测覆盖契约：qr_token / session_token /
      // expires_in / 字段缺失 / 非法类型等）。
      switch (parseQrCreateResponse(
        ok: response.ok,
        payload: response.payload,
      )) {
        case QrCreateSuccess(
          :final qrToken,
          :final sessionToken,
          :final expiresInSeconds,
        ):
          state = QRLoginState(
            status: QRLoginStatus.waiting,
            qrData: qrToken,
            sessionToken: sessionToken,
            remainingSeconds: expiresInSeconds,
          );
          // PR-4δ: Web 平台优先 SSE 推送（实时），失败由 watcher 自动 fallback
          // 到 _startPolling；非 Web 平台直接走轮询（无 EventSource 原生支持）。
          if (kIsWeb) {
            startSseSession(sessionToken);
          } else {
            _startPolling();
          }
          _startExpireTimer();
        case QrCreateFailure():
          state = QRLoginState(
            status: QRLoginStatus.failed,
            errorMessage: t.common.webQRGenerateFailed,
          );
      }
    } catch (e) {
      state = QRLoginState(
        status: QRLoginStatus.failed,
        errorMessage: '网络错误: $e',
      );
    }
  }

  /// 开始轮询扫码状态
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (state.sessionToken == null) {
        timer.cancel();
        return;
      }

      try {
        final response = await HttpClient.client.get(
          '/api/v1/passport/qr_login/status',
          queryParameters: {'session_token': state.sessionToken},
        );

        // slice-5b：解析层（27 测覆盖契约：6 status 字符串 / confirmed+token 防御 /
        // payload 非 Map 等）。
        final event = parseQrStatusResponse(
          ok: response.ok,
          code: response.code,
          payload: response.payload,
        );
        // slice-5c：决策层（24 测覆盖：sessionToken 守卫 + 7 状态分支 + 协议违反）。
        switch (derivePollingDecision(
          sessionToken: state.sessionToken,
          event: event,
        )) {
          case StopSilently():
            timer.cancel();
            return;
          case KeepPolling():
            // 未知 status 时若需诊断可在此 debugPrint，但生产路径保持静默。
            return;
          case TransitionToScanned():
            state = state.copyWith(status: QRLoginStatus.scanned);
          case RequestCompleteLogin(:final token):
            state = state.copyWith(status: QRLoginStatus.confirming);
            await _completeLogin(token);
          case TransitionToExpired():
            state = state.copyWith(status: QRLoginStatus.expired);
            timer.cancel();
          case TransitionToCancelledThenRefresh():
            state = state.copyWith(status: QRLoginStatus.waiting);
            await generateQRCode();
          case ProtocolViolation():
            // confirmed 但 token 为空（后端契约保证不会发生，但客户端防御）。
            state = state.copyWith(
              status: QRLoginStatus.failed,
              errorMessage: t.common.webQRTokenInvalid,
            );
            timer.cancel();
        }
      } catch (e) {
        debugPrint('[web_login_page] cancel error: $e');
      }
    });
  }

  /// 开始过期倒计时
  void _startExpireTimer() {
    _expireTimer?.cancel();
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      switch (deriveExpireTickDecision(
        remainingSeconds: state.remainingSeconds,
      )) {
        case MarkExpired():
          state = state.copyWith(status: QRLoginStatus.expired);
          timer.cancel();
        case DecrementRemaining(:final newRemainingSeconds):
          state = state.copyWith(remainingSeconds: newRemainingSeconds);
      }
    });
  }

  /// 完成登录
  Future<void> _completeLogin(String? token) async {
    switch (deriveCompleteLoginDecision(token: token)) {
      case RejectInvalidToken():
        state = state.copyWith(
          status: QRLoginStatus.failed,
          errorMessage: t.common.webQRTokenInvalid,
        );
        return;
      case ProceedWithToken(:final token):
        try {
          await SecureTokenStorageService.saveToken(token);
          state = state.copyWith(status: QRLoginStatus.success);
          _pollTimer?.cancel();
          _expireTimer?.cancel();
        } catch (e) {
          state = state.copyWith(
            status: QRLoginStatus.failed,
            errorMessage: '登录失败: $e',
          );
        }
    }
  }

  /// 刷新 QR 码
  Future<void> refresh() async {
    _pollTimer?.cancel();
    _expireTimer?.cancel();
    await generateQRCode();
  }

  /// 停止轮询
  void _stopPolling() {
    _pollTimer?.cancel();
    _expireTimer?.cancel();
  }

  /// PR-4δ: 启动 SSE 会话（Web 平台主路径）。
  ///
  /// 标记 `@visibleForTesting` 而非 private —— 让单测可绕过 generateQRCode
  /// 的 HTTP 调用直接验证状态机接线。生产路径只通过 generateQRCode 内部触发。
  ///
  /// onEvent 复用 `derivePollingDecision`：与轮询路径同套状态机，避免双轨漂移。
  /// onFallback 调 `_startPolling()`：SSE 不可用时无缝降级。
  @visibleForTesting
  void startSseSession(String sessionToken, {int gracePeriodSeconds = 3}) {
    _sseSession?.stop(); // 防重入：旧会话先清理
    final session = QrSseSession(
      client: _sseClientBuilder(),
      onEvent: (event) {
        switch (derivePollingDecision(
          sessionToken: state.sessionToken,
          event: event,
        )) {
          case StopSilently():
          case KeepPolling():
            // SSE 路径下 StopSilently 表示协议异常，等 watcher 触发 fallback
            return;
          case TransitionToScanned():
            state = state.copyWith(status: QRLoginStatus.scanned);
          case RequestCompleteLogin(:final token):
            state = state.copyWith(status: QRLoginStatus.confirming);
            _completeLogin(token);
          case TransitionToExpired():
            state = state.copyWith(status: QRLoginStatus.expired);
            _stopSseSession();
          case TransitionToCancelledThenRefresh():
            state = state.copyWith(status: QRLoginStatus.waiting);
            _stopSseSession();
            generateQRCode();
          case ProtocolViolation():
            state = state.copyWith(
              status: QRLoginStatus.failed,
              errorMessage: t.common.webQRTokenInvalid,
            );
            _stopSseSession();
        }
      },
      onFallback: () {
        // SSE 不可用 → 启动 2 秒轮询兜底（与现有 _startPolling 完全一致）
        _startPolling();
      },
    );
    _sseSession = session;
    final url =
        '/api/v1/passport/qr_login/subscribe?session_token=$sessionToken';
    unawaited(session.start(url, gracePeriodSeconds: gracePeriodSeconds));
  }

  void _stopSseSession() {
    final s = _sseSession;
    _sseSession = null;
    if (s != null) {
      unawaited(s.stop());
    }
  }

  /// 清理资源
  void dispose() {
    _pollTimer?.cancel();
    _expireTimer?.cancel();
    _stopSseSession();
  }
}

/// Web 登录页面
class WebLoginPage extends ConsumerStatefulWidget {
  const WebLoginPage({super.key});

  @override
  ConsumerState<WebLoginPage> createState() => _WebLoginPageState();
}

class _WebLoginPageState extends ConsumerState<WebLoginPage> {
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showPasswordLogin = false;

  @override
  void initState() {
    super.initState();
    // Web 平台自动生成 QR 码（或 E2E 测试旁路：直接注入登录态跳 /web_shell）
    if (kIsWeb) {
      final bypass = parseE2eBypassConfig(
        token: _kWebE2eTokenEnv,
        uid: _kWebE2eUidEnv,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        switch (bypass) {
          case BypassDisabled():
            ref.read(qRLoginProvider.notifier).generateQRCode();
          case BypassEnabled(:final token, :final uid):
            // 注入登录态：写 currentUid + secure token，不走 QR/SSE 链路
            await StorageService.to.setString(Keys.currentUid, uid);
            await SecureTokenStorageService.saveToken(token);
            if (mounted) context.go('/web_shell');
        }
      });
    }
  }

  @override
  void dispose() {
    _accountController.dispose();
    _passwordController.dispose();
    ref.read(qRLoginProvider.notifier).dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrState = ref.watch(qRLoginProvider);
    final passportState = ref.watch(passportProvider);
    final passportNotifier = ref.read(passportProvider.notifier);

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
      body: Row(
        children: [
          // 左侧说明区域
          Expanded(flex: 3, child: _buildLeftSection(context)),
          // 右侧登录区域
          Expanded(
            flex: 2,
            child: _buildRightSection(
              context,
              qrState,
              passportState,
              passportNotifier,
            ),
          ),
        ],
      ),
    );
  }

  /// 左侧说明区域
  Widget _buildLeftSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(60),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo
            Row(
              children: [
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 48,
                  color: AppColors.primary,
                ),
                AppSpacing.horizontalRegular,
                Text(
                  'ImBoy Web',
                  style: context.textStyle(
                    FontSizeType.extraLargeTitle,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkTextPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 60),
            // 功能说明
            _buildFeatureItem(
              Icons.devices,
              t.chat.webFeatureMultiDevice,
              t.chat.webFeatureMultiDeviceDesc,
            ),
            AppSpacing.verticalXXLarge,
            _buildFeatureItem(
              Icons.lock_outline,
              t.chat.webFeatureE2EE,
              t.chat.webFeatureE2EEDesc,
            ),
            AppSpacing.verticalXXLarge,
            _buildFeatureItem(
              Icons.notifications_outlined,
              t.common.webFeatureNotification,
              t.common.webFeatureNotificationDesc,
            ),
            AppSpacing.verticalXXLarge,
            _buildFeatureItem(
              Icons.attach_file,
              t.chat.webFeatureFileTransfer,
              t.chat.webFeatureFileTransferDesc,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(51), // 0.2 * 255 ≈ 51
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primary),
        ),
        AppSpacing.horizontalLarge,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.textStyle(
                  FontSizeType.large,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkTextPrimary,
                ),
              ),
              AppSpacing.verticalTiny,
              Text(
                desc,
                style: context.textStyle(
                  FontSizeType.normal,
                  color: AppColors.darkTextSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 右侧登录区域
  Widget _buildRightSection(
    BuildContext context,
    QRLoginState qrState,
    PassportState passportState,
    PassportNotifier passportNotifier,
  ) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: const BoxDecoration(
        color: AppColors.darkSurfaceContainer,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_showPasswordLogin) ...[
              // QR 码登录
              _buildQRLoginSection(qrState),
              AppSpacing.verticalXLarge,
              // 切换到密码登录
              TextButton(
                onPressed: () {
                  // 停止二维码轮询
                  ref.read(qRLoginProvider.notifier)._stopPolling();
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
              TextButton(
                onPressed: () {
                  setState(() => _showPasswordLogin = false);
                  ref.read(qRLoginProvider.notifier).generateQRCode();
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
        ),
      ),
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
          child: _buildQRContent(qrState),
        ),
        AppSpacing.verticalRegular,
        // 状态文字
        _buildQRStatusText(qrState),
        AppSpacing.verticalRegular,
        // 刷新按钮（过期时显示）
        if (qrState.status == QRLoginStatus.expired ||
            qrState.status == QRLoginStatus.failed)
          ElevatedButton.icon(
            onPressed: () => ref.read(qRLoginProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: Text(t.main.webQRRefresh),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
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
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
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
                  Icons.smartphone,
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
              const CircularProgressIndicator(color: AppColors.primary),
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
                  Icons.qr_code_scanner,
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
                  Icons.error_outline,
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
                Icons.check_circle,
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
        icon = Icons.qr_code_scanner;
      case QRLoginStatus.scanned:
        text = t.chat.webQRStatusScanned;
        icon = Icons.smartphone;
      case QRLoginStatus.confirming:
        text = t.chat.webQRStatusVerifying;
        icon = Icons.hourglass_empty;
      case QRLoginStatus.expired:
        text = t.chat.webQRStatusExpired;
        icon = Icons.refresh;
      case QRLoginStatus.failed:
        text = qrState.errorMessage ?? t.common.webQRStatusFailed;
        icon = Icons.error_outline;
      case QRLoginStatus.success:
        text = t.common.webQRStatusSuccess;
        icon = Icons.check_circle;
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
          controller: _accountController,
          style: TextStyle(color: AppColors.darkTextPrimary),
          decoration: InputDecoration(
            hintText: t.account.webAccountHint,
            hintStyle: const TextStyle(color: AppColors.darkTextDisabled),
            prefixIcon: Icon(Icons.person, color: AppColors.darkTextDisabled),
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
          controller: _passwordController,
          obscureText: passportState.loginPwdObscure,
          style: TextStyle(color: AppColors.darkTextPrimary),
          decoration: InputDecoration(
            hintText: t.account.webPasswordHint,
            hintStyle: const TextStyle(color: AppColors.darkTextDisabled),
            prefixIcon: const Icon(
              Icons.lock,
              color: AppColors.darkTextDisabled,
            ),
            suffixIcon: IconButton(
              tooltip: passportState.loginPwdObscure
                  ? t.common.showPassword
                  : t.common.hidePassword,
              icon: Icon(
                passportState.loginPwdObscure
                    ? Icons.visibility
                    : Icons.visibility_off,
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
          height: 48,
          child: DebounceButton(
            text: t.account.login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            textStyle: context.textStyle(
              FontSizeType.medium,
              color: AppColors.onPrimary,
              fontWeight: FontWeight.w600,
            ),
            onPressed: () async {
              final account = _accountController.text;
              final pwd = _passwordController.text;

              if (account.isEmpty || pwd.isEmpty) {
                passportNotifier.setError(t.common.webLoginEmptyError);
                return;
              }

              final error = await passportNotifier.loginUser(
                'account',
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
        AppSpacing.verticalRegular,
        // 忘记密码
        TextButton(
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
