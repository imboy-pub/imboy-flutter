/// Web 端登录页面 - WhatsApp Web 风格
///
/// 功能：
/// - QR 码扫码登录（主推）
/// - 账号密码登录（备选）
/// - 多标签页同步状态显示
/// - 桌面通知权限请求
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:imboy/component/ui/debounce_button.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/config/routes.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
import 'package:imboy/page/passport/qr_login_response_rules.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/service/secure_token_storage_service.dart';

part 'web_login_page.g.dart';

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

/// QR 码登录状态管理
@riverpod
class QRLogin extends _$QRLogin {
  Timer? _pollTimer;
  Timer? _expireTimer;
  String? _webDeviceId;

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
        '/v1/passport/qr_login/create',
        data: {
          'device_id': _webDeviceId,
          'device_name': 'Web Browser',
          'platform': 'web',
        },
      );

      // slice-5b：委托纯函数解析（27 测覆盖契约：qr_token / session_token /
      // expires_in / 字段缺失 / 非法类型等）。
      switch (parseQrCreateResponse(
          ok: response.ok, payload: response.payload)) {
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
          _startPolling();
          _startExpireTimer();
        case QrCreateFailure():
          state = QRLoginState(
            status: QRLoginStatus.failed,
            errorMessage: t.webQRGenerateFailed,
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
          '/v1/passport/qr_login/status',
          queryParameters: {
            'session_token': state.sessionToken,
          },
        );

        // slice-5b：委托纯函数解析（27 测覆盖契约：6 status 字符串 /
        // confirmed+token 防御 / payload 非 Map 等）。
        final event = parseQrStatusResponse(
          ok: response.ok,
          code: response.code,
          payload: response.payload,
        );
        switch (event) {
          case QrStatusStopPolling():
            timer.cancel();
            return;
          case QrStatusWaiting():
            return; // 继续轮询
          case QrStatusScanned():
            state = state.copyWith(status: QRLoginStatus.scanned);
          case QrStatusConfirmed(:final token):
            state = state.copyWith(status: QRLoginStatus.confirming);
            await _completeLogin(token);
          case QrStatusExpired():
            state = state.copyWith(status: QRLoginStatus.expired);
            timer.cancel();
          case QrStatusCancelled():
            state = state.copyWith(status: QRLoginStatus.waiting);
            await generateQRCode();
          case QrStatusUnknown(:final rawStatus):
            // 协议违反：confirmed 但 token 为空（后端契约保证不会发生，但客户端
            // 防御性处理，保留原 Notifier 行为：状态机退回 failed）。
            if (rawStatus == 'confirmed') {
              state = state.copyWith(
                status: QRLoginStatus.failed,
                errorMessage: t.webQRTokenInvalid,
              );
              timer.cancel();
            } else if (kDebugMode) {
              debugPrint('qr_login unknown status: $rawStatus');
            }
        }
      } catch (e) {
        debugPrint('轮询扫码状态失败: $e');
      }
    });
  }

  /// 开始过期倒计时
  void _startExpireTimer() {
    _expireTimer?.cancel();
    _expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.remainingSeconds <= 0) {
        state = state.copyWith(status: QRLoginStatus.expired);
        timer.cancel();
        return;
      }
      state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
    });
  }

  /// 完成登录
  Future<void> _completeLogin(String? token) async {
    if (token == null || token.isEmpty) {
      state = state.copyWith(
        status: QRLoginStatus.failed,
        errorMessage: t.webQRTokenInvalid,
      );
      return;
    }

    try {
      // 保存 token
      await SecureTokenStorageService.saveToken(token);

      state = state.copyWith(status: QRLoginStatus.success);

      // 停止轮询
      _pollTimer?.cancel();
      _expireTimer?.cancel();
    } catch (e) {
      state = state.copyWith(
        status: QRLoginStatus.failed,
        errorMessage: '登录失败: $e',
      );
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

  /// 清理资源
  void dispose() {
    _pollTimer?.cancel();
    _expireTimer?.cancel();
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
    // Web 平台自动生成 QR 码
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(qRLoginProvider.notifier).generateQRCode();
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
          Expanded(
            flex: 3,
            child: _buildLeftSection(context),
          ),
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
              const SizedBox(width: 16),
              const Text(
                'ImBoy Web',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          // 功能说明
          _buildFeatureItem(
            Icons.devices,
            t.webFeatureMultiDevice,
            t.webFeatureMultiDeviceDesc,
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.lock_outline,
            t.webFeatureE2EE,
            t.webFeatureE2EEDesc,
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.notifications_outlined,
            t.webFeatureNotification,
            t.webFeatureNotificationDesc,
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.attach_file,
            t.webFeatureFileTransfer,
            t.webFeatureFileTransferDesc,
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
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 14,
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
            const SizedBox(height: 24),
            // 切换到密码登录
            TextButton(
              onPressed: () {
                // 停止二维码轮询
                ref.read(qRLoginProvider.notifier)._stopPolling();
                setState(() => _showPasswordLogin = true);
              },
              child: Text(
                t.webSwitchToPassword,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                ),
              ),
            ),
          ] else ...[
            // 账号密码登录
            _buildPasswordLoginSection(passportState, passportNotifier),
            const SizedBox(height: 24),
            // 切换回 QR 码登录
            TextButton(
              onPressed: () {
                setState(() => _showPasswordLogin = false);
                ref.read(qRLoginProvider.notifier).generateQRCode();
              },
              child: Text(
                t.webSwitchToQR,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
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
          t.webQRLoginTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          t.webQRLoginHint,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.darkTextSecondary,
          ),
        ),
        const SizedBox(height: 32),
        // QR 码容器
        Container(
          width: 256,
          height: 256,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: _buildQRContent(qrState),
        ),
        const SizedBox(height: 16),
        // 状态文字
        _buildQRStatusText(qrState),
        const SizedBox(height: 16),
        // 刷新按钮（过期时显示）
        if (qrState.status == QRLoginStatus.expired ||
            qrState.status == QRLoginStatus.failed)
          ElevatedButton.icon(
            onPressed: () => ref.read(qRLoginProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: Text(t.webQRRefresh),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        // 倒计时
        if (qrState.status == QRLoginStatus.waiting ||
            qrState.status == QRLoginStatus.scanned)
          Text(
            t.webQRExpiresIn(seconds: qrState.remainingSeconds),
            style: const TextStyle(
              fontSize: 12,
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
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
        }
        // 私有 scheme 包装，便于手机端 scanner 通过 detectQrLoginIntent 识别
        // 为 web 登录 QR（与 user/group/channel HTTP URL 名片命名空间隔离）。
        return QrImageView(
          data: 'imboy://qr_login/${qrState.qrData!}',
          version: QrVersions.auto,
          size: 224,
          backgroundColor: Colors.white,
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
                const SizedBox(height: 16),
                Text(
                  t.webQRScanned,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  t.webQRConfirmOnPhone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
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
              const CircularProgressIndicator(
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                t.webQRLoggingIn,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );

      case QRLoginStatus.expired:
        return Container(
          color: AppColors.lightTextSecondary,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  t.webQRExpired,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
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
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                Text(
                  qrState.errorMessage ?? t.webQRLoginFailed,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red,
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
              const SizedBox(height: 16),
              Text(
                t.webQRLoginSuccess,
                style: const TextStyle(
                  fontSize: 18,
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
        text = t.webQRStatusWaiting;
        icon = Icons.qr_code_scanner;
      case QRLoginStatus.scanned:
        text = t.webQRStatusScanned;
        icon = Icons.smartphone;
      case QRLoginStatus.confirming:
        text = t.webQRStatusVerifying;
        icon = Icons.hourglass_empty;
      case QRLoginStatus.expired:
        text = t.webQRStatusExpired;
        icon = Icons.refresh;
      case QRLoginStatus.failed:
        text = qrState.errorMessage ?? t.webQRStatusFailed;
        icon = Icons.error_outline;
      case QRLoginStatus.success:
        text = t.webQRStatusSuccess;
        icon = Icons.check_circle;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.darkTextSecondary),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
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
          t.webPasswordLoginTitle,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 32),
        // 账号输入
        TextField(
          controller: _accountController,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t.webAccountHint,
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
        const SizedBox(height: 16),
        // 密码输入
        TextField(
          controller: _passwordController,
          obscureText: passportState.loginPwdObscure,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: t.webPasswordHint,
            hintStyle: const TextStyle(color: AppColors.darkTextDisabled),
            prefixIcon: const Icon(Icons.lock, color: AppColors.darkTextDisabled),
            suffixIcon: IconButton(
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
        const SizedBox(height: 24),
        // 登录按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: DebounceButton(
            text: t.login,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            onPressed: () async {
              final account = _accountController.text;
              final pwd = _passwordController.text;

              if (account.isEmpty || pwd.isEmpty) {
                passportNotifier.setError(t.webLoginEmptyError);
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
        const SizedBox(height: 16),
        // 忘记密码
        TextButton(
          onPressed: () => context.push(AppRoutes.forgotPassword),
          child: Text(
            t.forgotPassword,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
