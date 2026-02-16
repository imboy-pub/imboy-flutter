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
import 'package:imboy/config/routes.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/page/passport/passport_notifier.dart';
import 'package:imboy/page/passport/passport_state.dart';
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

      if (response.ok && response.payload != null) {
        final data = response.payload;
        state = QRLoginState(
          status: QRLoginStatus.waiting,
          qrData: data['qr_token'] as String?,
          sessionToken: data['session_token'] as String?,
          remainingSeconds: 60,
        );

        // 开始轮询检查扫码状态
        _startPolling();
        _startExpireTimer();
      } else {
        state = QRLoginState(
          status: QRLoginStatus.failed,
          errorMessage: '生成二维码失败',
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

        // 如果返回错误（HTTP 错误或业务 code 不为 0），停止轮询
        if (!response.ok || response.code != 0) {
          timer.cancel();
          return;
        }

        if (response.payload != null) {
          final data = response.payload;
          final statusStr = data['status'] as String?;

          switch (statusStr) {
            case 'scanned':
              state = state.copyWith(status: QRLoginStatus.scanned);
              break;
            case 'confirmed':
              state = state.copyWith(status: QRLoginStatus.confirming);
              // 获取 token 并完成登录
              await _completeLogin(data['token'] as String?);
              break;
            case 'expired':
              state = state.copyWith(status: QRLoginStatus.expired);
              timer.cancel();
              break;
            case 'cancelled':
              state = state.copyWith(status: QRLoginStatus.waiting);
              await generateQRCode();
              break;
            case 'waiting':
              // 继续等待，不需要特殊处理
              break;
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
        errorMessage: '登录令牌无效',
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
        context.go('/bottom_navigation');
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
            '多设备同步',
            '在手机和电脑之间无缝切换，消息实时同步',
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.lock_outline,
            '端到端加密',
            '所有消息都经过端到端加密，确保隐私安全',
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.notifications_outlined,
            '桌面通知',
            '即使不在页面也能收到新消息提醒',
          ),
          const SizedBox(height: 32),
          _buildFeatureItem(
            Icons.attach_file,
            '文件传输',
            '拖拽即可发送文件，支持各种格式',
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
              child: const Text(
                '使用账号密码登录',
                style: TextStyle(
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
              child: const Text(
                '使用 QR 码登录',
                style: TextStyle(
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
        const Text(
          '扫码登录',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '使用 ImBoy 手机版扫描二维码',
          style: TextStyle(
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
            label: const Text('刷新二维码'),
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
            '${qrState.remainingSeconds} 秒后过期',
            style: TextStyle(
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
        return QrImageView(
          data: qrState.qrData!,
          version: QrVersions.auto,
          size: 224,
          backgroundColor: Colors.white,
          errorCorrectionLevel: QrErrorCorrectLevel.H,
        );

      case QRLoginStatus.scanned:
        return Container(
          color: AppColors.primary.withAlpha(26), // 0.1 * 255 ≈ 26
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smartphone,
                  size: 64,
                  color: AppColors.primary,
                ),
                SizedBox(height: 16),
                Text(
                  '已扫描',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  '请在手机上确认登录',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );

      case QRLoginStatus.confirming:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppColors.primary,
              ),
              SizedBox(height: 16),
              Text(
                '登录中...',
                style: TextStyle(
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
                  '二维码已过期',
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
                  qrState.errorMessage ?? '登录失败',
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
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                size: 64,
                color: AppColors.primary,
              ),
              SizedBox(height: 16),
              Text(
                '登录成功',
                style: TextStyle(
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
        text = '打开 ImBoy 手机版 > 设置 > 扫一扫';
        icon = Icons.qr_code_scanner;
      case QRLoginStatus.scanned:
        text = '请在手机上点击"确认登录"';
        icon = Icons.smartphone;
      case QRLoginStatus.confirming:
        text = '正在验证...';
        icon = Icons.hourglass_empty;
      case QRLoginStatus.expired:
        text = '请点击刷新重新扫码';
        icon = Icons.refresh;
      case QRLoginStatus.failed:
        text = qrState.errorMessage ?? '登录失败，请重试';
        icon = Icons.error_outline;
      case QRLoginStatus.success:
        text = '正在跳转...';
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
        const Text(
          '账号登录',
          style: TextStyle(
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
          decoration: const InputDecoration(
            hintText: '请输入账号/手机号/邮箱',
            hintStyle: TextStyle(color: AppColors.darkTextDisabled),
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
            hintText: '请输入密码',
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
            text: '登录',
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
                passportNotifier.setError('请输入账号和密码');
                return;
              }

              final error = await passportNotifier.loginUser(
                'account',
                account,
                pwd,
              );

              if (error == null) {
                if (mounted) {
                  context.go('/bottom_navigation');
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
          child: const Text(
            '忘记密码？',
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
