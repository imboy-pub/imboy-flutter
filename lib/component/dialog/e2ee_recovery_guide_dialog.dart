import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 「新设备登录后待引导」持久标记键 / Pending-guide flag key after a new-device login.
///
/// 登录流程检测到本地新生成了 E2EE 密钥对时写入 `true`（见 `passport_notifier`），
/// 由登录后首屏 `BottomNavigationPage` 消费一次后清除，避免重复弹窗。
const String kE2eeNewDeviceGuidePendingKey = 'e2ee_new_device_guide_pending';

/// 「E2EE 恢复待办」常驻标记键 / Persistent "recovery needed" flag key.
///
/// 与一次性的 [kE2eeNewDeviceGuidePendingKey] 不同：本标记在换设备 / 重装
/// 新生成密钥时置 `true`，在会话列表常驻横幅中提示，直到用户**完成密钥恢复**
/// （社交恢复 / 设备转移成功）或主动关闭横幅后才清除。
const String kE2eeRecoveryNeededKey = 'e2ee_recovery_needed';

/// E2EE 密钥恢复引导场景 / E2EE key-recovery guidance scenes.
///
/// - [newDevice]：换设备 / 重装后登录，本地生成了全新密钥对；
/// - [decryptFailed]：用户点击了无法解密的「[加密消息]」气泡。
enum E2EERecoveryScene { newDevice, decryptFailed }

/// 弹出统一的 E2EE 密钥恢复引导对话框 / Show the unified key-recovery guide.
///
/// 两个场景复用同一入口（DRY），统一引导用户前往 `/e2ee_key_recovery` 恢复中心，
/// 接通既有的「设备转移 / 社交恢复 / 本地备份导入」能力，消除"撞到 [加密消息]
/// 却无引导"的死胡同。
///
/// Reuses one entry point for both scenes and routes the user to the existing
/// recovery hub (`/e2ee_key_recovery`), wiring up device-transfer / social
/// recovery / local-backup import.
Future<void> showE2EERecoveryGuide(
  BuildContext context, {
  required E2EERecoveryScene scene,
}) {
  final (String title, String content) = switch (scene) {
    E2EERecoveryScene.newDevice => (
      t.chat.e2eeRecoveryNewDeviceTitle,
      t.chat.e2eeRecoveryNewDeviceBody,
    ),
    E2EERecoveryScene.decryptFailed => (
      t.chat.e2eeRecoveryDecryptFailedTitle,
      t.chat.e2eeRecoveryDecryptFailedBody,
    ),
  };

  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(t.chat.e2eeRecoveryLater),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            ctx.push('/e2ee_key_recovery');
          },
          child: Text(t.chat.e2eeRecoveryGoRecover),
        ),
      ],
    ),
  );
}

/// 会话列表顶部 E2EE 恢复横幅 / Persistent recovery banner atop the chat list.
///
/// 在 [kE2eeRecoveryNeededKey] 为真时常驻显示，填补"用户点了弹窗的『稍后』
/// 后便再无提醒"的空窗：点击主体前往恢复中心，点 × 关闭则视为用户知悉。
class E2EERecoveryBanner extends StatelessWidget {
  const E2EERecoveryBanner({super.key, required this.onDismiss});

  /// 用户点击关闭（×）的回调——调用方负责清除 [kE2eeRecoveryNeededKey] 并刷新。
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: scheme.onSecondaryContainer);
    return Material(
      color: scheme.secondaryContainer,
      child: InkWell(
        onTap: () => context.push('/e2ee_key_recovery'),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.regular,
            vertical: AppSpacing.medium,
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_clock_outlined,
                size: 20,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(t.chat.e2eeRecoveryBannerText, style: textStyle),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onDismiss,
                behavior: HitTestBehavior.opaque,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
