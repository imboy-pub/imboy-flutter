/// QR 登录确认页"展示组件"（受控模式：state in, callbacks out）。
///
/// 此 Widget 故意不依赖 Riverpod / HTTP / 路由，便于 widget test 直接覆盖
/// 10 个状态变体的渲染契约。Provider 容器版本见
/// `qr_login_confirm_page.dart`，负责拼装 state 与回调。
///
/// 设计参考 `imboyapp/DESIGN.md`：
///   - 品牌蓝 #2474E5（`AppColors.primary`）作主按钮
///   - iOS 红 `#FF3B30`（`AppColors.iosRed`）作取消/破坏按钮
///   - 主按钮高度 ≥ 44pt（iOS HIG）
///   - 页面水平 padding 16pt
library;

import 'package:flutter/material.dart';
import 'package:imboy/theme/default/font_types.dart';

import 'package:imboy/page/scanner/qr_login_confirm_rules.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// QR 登录确认页展示组件。
///
/// 状态映射：
///   - Idle / Scanning / Confirming → 加载圆圈
///   - AwaitingConfirm → 设备信息卡片 + "确认登录" + "取消"
///   - Success → ✓ 图标 + "登录成功"
///   - Expired / AlreadyUsed / CancelledByOther / Failed → 错误图标 + "关闭"
///   - CancelledByMe → 提示文案（无按钮，由父层 800ms 后自动 pop）
class QrLoginConfirmContent extends StatelessWidget {
  const QrLoginConfirmContent({
    super.key,
    required this.state,
    required this.onConfirm,
    required this.onCancel,
    required this.onClose,
  });

  final QrLoginConfirmState state;

  /// 用户在 AwaitingConfirm 状态下点击"确认登录"。
  final VoidCallback onConfirm;

  /// 用户在 AwaitingConfirm 状态下点击"取消"。
  final VoidCallback onCancel;

  /// 用户在终态（错误 / 取消）下点击"关闭"，由父层退栈。
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.regular),
          child: Center(child: _buildBody(context)),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return switch (state) {
      QrLoginConfirmIdle() ||
      QrLoginConfirmScanning() => _loading(context, t.passport.qrConnecting),
      QrLoginConfirmAwaitingConfirm(:final deviceInfo) => _awaiting(
        context,
        deviceInfo,
      ),
      QrLoginConfirmConfirming() => _loading(
        context,
        t.passport.qrLoginConfirming,
      ),
      QrLoginConfirmSuccess() => _success(context),
      QrLoginConfirmExpired() => _terminal(
        context,
        icon: Icons.timer_off_outlined,
        message: t.passport.qrCodeExpired,
      ),
      QrLoginConfirmAlreadyUsed() => _terminal(
        context,
        icon: Icons.error_outline,
        message: t.passport.qrCodeUsed,
      ),
      QrLoginConfirmCancelledByMe() => _info(
        context,
        t.passport.qrLoginCancelledByMe,
      ),
      QrLoginConfirmCancelledByOther() => _terminal(
        context,
        icon: Icons.cancel_outlined,
        message: t.passport.qrLoginCancelled,
      ),
      QrLoginConfirmFailed(:final errorMessage) => _terminal(
        context,
        icon: Icons.error_outline,
        message: errorMessage,
      ),
    };
  }

  // -------------------------------------------------------------------------
  // 状态视图
  // -------------------------------------------------------------------------

  Widget _loading(BuildContext context, String hint) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.primary),
        AppSpacing.verticalXLarge,
        Text(hint, style: context.textStyle(FontSizeType.medium)),
      ],
    );
  }

  Widget _info(BuildContext context, String text) {
    return Text(
      text,
      style: context.textStyle(FontSizeType.medium),
      textAlign: TextAlign.center,
    );
  }

  Widget _awaiting(BuildContext context, QrLoginDeviceInfo? deviceInfo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.computer_outlined, size: 80, color: AppColors.primary),
        AppSpacing.verticalXLarge,
        Text(
          t.passport.qrWebLoginTitle,
          style: context.textStyle(
            FontSizeType.title,
            fontWeight: FontWeight.w600,
          ),
        ),
        AppSpacing.verticalSmall,
        Text(
          t.passport.qrWebLoginDesc,
          style: context.textStyle(
            FontSizeType.normal,
            color: AppColors.lightTextSecondary,
          ),
        ),
        if (deviceInfo != null) ...[
          AppSpacing.verticalXLarge,
          _DeviceInfoCard(deviceInfo: deviceInfo),
        ],
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              t.passport.qrLoginAction,
              style: context.textStyle(
                FontSizeType.medium,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        AppSpacing.verticalMedium,
        SizedBox(
          width: double.infinity,
          height: 48,
          child: TextButton(
            onPressed: onCancel,
            child: Text(
              t.common.buttonCancel,
              style: context.textStyle(
                FontSizeType.medium,
                color: AppColors.iosRed,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _success(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.check_circle_outline,
          size: 80,
          color: AppColors.primary,
        ),
        AppSpacing.verticalXLarge,
        Text(
          t.passport.qrLoginSuccess,
          style: context.textStyle(
            FontSizeType.large,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _terminal(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 80, color: AppColors.lightTextSecondary),
        AppSpacing.verticalXLarge,
        Text(
          message,
          style: context.textStyle(FontSizeType.medium),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 40),
        SizedBox(
          width: 200,
          height: 48,
          child: OutlinedButton(
            onPressed: onClose,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              t.common.buttonClose,
              style: context.textStyle(FontSizeType.medium),
            ),
          ),
        ),
      ],
    );
  }
}

/// 设备信息卡片（仅在 AwaitingConfirm + deviceInfo != null 时显示）。
class _DeviceInfoCard extends StatelessWidget {
  const _DeviceInfoCard({required this.deviceInfo});

  final QrLoginDeviceInfo deviceInfo;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[];
    if (deviceInfo.deviceName != null) {
      lines.add('设备：${deviceInfo.deviceName}');
    }
    if (deviceInfo.platform != null) {
      lines.add('平台：${deviceInfo.platform}');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.regular),
      decoration: BoxDecoration(
        color: AppColors.lightPageBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: context.textStyle(FontSizeType.normal),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}
