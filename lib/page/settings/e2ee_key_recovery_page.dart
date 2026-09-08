import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/cupertino_modal_surface.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_export_page.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/service/e2ee_health_check_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/ui/app_loading.dart';

/// E2EE 密钥恢复入口页面
///
/// 功能：
/// - 显示当前密钥信息
/// - 整合三种恢复方法（设备间传输、社交恢复、本地备份）
/// - 提供密钥生成/更新功能
/// - E2EE 行为警告
class E2EEKeyRecoveryPage extends StatefulWidget {
  const E2EEKeyRecoveryPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _E2EEKeyRecoveryPageState createState() => _E2EEKeyRecoveryPageState();
}

class _E2EEKeyRecoveryPageState extends State<E2EEKeyRecoveryPage> {
  bool _isLoading = true;
  Map<String, dynamic> _keyInfo = {};

  /// 密钥信息读取失败标记：错误态与空态必须分离——
  /// 读取错误若伪装成「未检测到密钥」空态，旁边的「生成新密钥」CTA
  /// 会诱导用户重置密钥，导致旧消息永久无法解密。
  bool _loadError = false;

  /// 重试解密失败的消息（自愈）进行中
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    // 延迟到第一帧完成后再加载密钥信息，避免在布局期间触发 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadKeyInfo();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IosPageTemplate(
      title: t.main.e2eeKeyRecoveryTitle,
      actions: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _loadKeyInfo,
          child: Icon(
            CupertinoIcons.refresh,
            size: 22,
            semanticLabel: t.common.buttonRefresh,
          ),
        ),
      ],
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.only(top: 120),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : _loadError
          // 错误态：只提示重试，不渲染空态 CTA 与任何密钥生成/删除入口
          ? _buildLoadErrorCard(context)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSpacing.verticalRegular,
                // 当前密钥信息卡片
                if (_keyInfo.isNotEmpty) _buildKeyInfoCard(context),
                if (_keyInfo.isEmpty) _buildNoKeyCard(context),

                AppSpacing.verticalLarge,

                // E2EE 说明卡片
                _buildE2EEInfoCard(context),

                AppSpacing.verticalLarge,

                // 恢复方法分组
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    t.main.e2eeRecoveryMethods,
                    style: context.textStyle(
                      FontSizeType.normal,
                      fontWeight: FontWeight.w500,
                      color: AppColors.iosGray,
                    ),
                  ),
                ),

                // 密钥找回统一走口令/恢复密钥加密的云备份（4S 等价机制）。
                // 换机历史恢复 = 新设备导入云备份；已弃用自研设备转移/社交恢复。
                _buildRecoveryMethodCard(
                  context,
                  title: t.common.e2eeLocalBackup,
                  description: t.common.e2eeLocalBackupDesc,
                  securityLevel: 4,
                  icon: CupertinoIcons.cloud_upload,
                  iconColor: AppColors.iosGreen,
                  status: t.chat.e2eeStatusAvailable,
                  onTap: () => _showLocalBackupOptions(context),
                ),

                AppSpacing.verticalMedium,

                // 自愈入口：密钥恢复后补解密此前失败的历史消息
                _buildRetryFailedCard(context),

                AppSpacing.verticalLarge,

                // 危险操作区域
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    t.main.e2eeDangerousOps,
                    style: context.textStyle(
                      FontSizeType.normal,
                      fontWeight: FontWeight.w500,
                      color: AppColors.iosGray,
                    ),
                  ),
                ),

                // 生成新密钥
                _buildDangerActionCard(
                  context,
                  title: t.chat.e2eeGenerateNewKey,
                  description: t.chat.e2eeGenerateNewKeyDesc,
                  icon: CupertinoIcons.arrow_2_circlepath,
                  iconColor: AppColors.iosOrange,
                  onTap: () => _showGenerateNewKeyDialog(context),
                ),

                AppSpacing.verticalMedium,

                // 删除密钥
                _buildDangerActionCard(
                  context,
                  title: t.common.e2eeDeleteKey,
                  description: t.common.e2eeDeleteKeyDesc,
                  icon: CupertinoIcons.delete_solid,
                  iconColor: AppColors.getIosRed(Theme.of(context).brightness),
                  onTap: () => _showDeleteKeyDialogStage1(context),
                ),
              ],
            ),
    );
  }

  /// 构建密钥信息卡片
  Widget _buildKeyInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.iosBlue.withValues(alpha: 0.1),
            AppColors.iosBlue.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: AppColors.iosBlue.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  CupertinoIcons.lock_fill,
                  color: AppColors.iosBlue,
                  size: 24,
                ),
                AppSpacing.horizontalMedium,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.common.e2eeCurrentKeyInfo,
                        style: context.textStyle(
                          FontSizeType.large,
                          fontWeight: FontWeight.bold,
                          color: AppColors.iosBlue,
                        ),
                      ),
                      AppSpacing.verticalTiny,
                      Text(
                        t.common.e2eeE2EEEnabled,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.iosBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(color: AppColors.iosGreen),
                  child: Text(
                    t.chat.e2eeActivated,
                    style: context.textStyle(
                      FontSizeType.small,
                      color: AppColors.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.verticalRegular,
            _buildInfoRow(
              t.account.e2eeDeviceIdLabel,
              _keyInfo['device_id'] as String? ?? t.common.unknown,
            ),
            _buildInfoRow(
              t.main.e2eeKeyIdLabel,
              _keyInfo['key_id'] as String? ?? t.common.unknown,
            ),
            _buildInfoRow(
              t.chat.e2eeCreatedAtLabel,
              _keyInfo['created_at'] as String? ?? t.common.unknown,
            ),
          ],
        ),
      ),
    );
  }

  /// 构建无密钥卡片
  Widget _buildNoKeyCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.iosOrange.withValues(alpha: 0.1),
            AppColors.iosOrange.withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: AppColors.iosOrange.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: AppSpacing.allLarge,
        child: Column(
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: AppColors.iosOrange,
              size: 48,
            ),
            AppSpacing.verticalRegular,
            Text(
              t.common.e2eeNoKeyDetected,
              style: context.textStyle(
                FontSizeType.large,
                fontWeight: FontWeight.bold,
                color: AppColors.iosOrange,
              ),
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeNoKeyDesc,
              style: context.textStyle(FontSizeType.normal),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalRegular,
            CupertinoButton.filled(
              onPressed: () => _showGenerateNewKeyDialog(context),
              color: AppColors.iosOrange,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.add,
                    color: AppColors.onPrimary,
                    size: 18,
                  ),
                  AppSpacing.horizontalTiny,
                  Text(t.chat.e2eeGenerateNewKey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 重试解密失败的消息（自愈能力接线）
  ///
  /// 密钥恢复/导入完成后，本地可能残留此前解密失败的历史消息；
  /// 全量扫描并重试解密（[E2EEHealthCheckService.retryFailedMessages]
  /// 不传会话则扫描全部会话），完成后提示恢复条数。
  Future<void> _retryFailedMessages() async {
    if (_isRetrying) return;
    setState(() => _isRetrying = true);
    try {
      final count = await E2EEHealthCheckService.to.retryFailedMessages();
      if (!mounted) return;
      // count == 0：没有需要重试的失败消息，用中性提示避免误导用户以为失败
      AppLoading.showToast(
        count == 0
            ? t.common.e2eeRetryFailedNone
            : t.common.e2eeRetryFailedDone(count: count),
      );
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  /// 构建重试解密失败消息入口卡片
  Widget _buildRetryFailedCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: AppColors.transparent,
      child: GestureDetector(
        onTap: _isRetrying ? null : _retryFailedMessages,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: AppSpacing.allRegular,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceGroupedTertiary
                : AppColors.lightSurface,
            borderRadius: AppRadius.borderRadiusMedium,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: _isRetrying
                    ? const CupertinoActivityIndicator()
                    : const Icon(
                        CupertinoIcons.arrow_clockwise,
                        color: AppColors.iosBlue,
                        size: 24,
                      ),
              ),
              AppSpacing.horizontalRegular,
              Expanded(
                child: Text(
                  t.common.e2eeRetryFailedMessages,
                  style: context.textStyle(
                    FontSizeType.medium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (!_isRetrying)
                const Icon(
                  CupertinoIcons.chevron_forward,
                  color: AppColors.iosGray,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建加载失败卡片（错误态，与空态分离）
  ///
  /// 复用 [t.common.loadError] / [t.common.buttonRetry] 既有通用键；
  /// 呈现方式对齐 safety_number_page / compliance_key_page 的
  /// 「错误文案 + 重试」模式，但绝不提供「生成新密钥」入口。
  Widget _buildLoadErrorCard(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Padding(
        padding: AppSpacing.allLarge,
        child: Column(
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: AppColors.getIosOrange(brightness),
              size: 48,
            ),
            AppSpacing.verticalRegular,
            Text(
              t.common.loadError,
              style: context.textStyle(
                FontSizeType.large,
                fontWeight: FontWeight.bold,
                color: AppColors.getIosOrange(brightness),
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.verticalRegular,
            CupertinoButton.filled(
              onPressed: _loadKeyInfo,
              child: Text(t.common.buttonRetry),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: context.textStyle(
                FontSizeType.footnote,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: context.textStyle(
                FontSizeType.footnote,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 E2EE 说明卡片
  Widget _buildE2EEInfoCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceGroupedTertiary
            : AppColors.lightSurface,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: AppColors.iosBlue.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: AppSpacing.allRegular,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.info, color: AppColors.iosBlue, size: 20),
                AppSpacing.horizontalSmall,
                Text(
                  t.common.e2eeAboutTitle,
                  style: context.textStyle(
                    FontSizeType.subheadline,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            AppSpacing.verticalMedium,
            Text(
              t.common.e2eeInfoPoint1,
              style: context.textStyle(FontSizeType.footnote),
            ),
            AppSpacing.verticalTiny,
            Text(
              t.common.e2eeInfoPoint2,
              style: context.textStyle(FontSizeType.footnote),
            ),
            AppSpacing.verticalTiny,
            Text(
              t.common.e2eeInfoPoint3,
              style: context.textStyle(FontSizeType.footnote),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建恢复方法卡片
  Widget _buildRecoveryMethodCard(
    BuildContext context, {
    required String title,
    required String description,
    required int securityLevel,
    required IconData icon,
    required Color iconColor,
    required String status,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: AppColors.transparent,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceGroupedTertiary
                : AppColors.lightSurface,
            borderRadius: AppRadius.borderRadiusMedium,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? AppColors.lightTextPrimary.withValues(alpha: 0.2)
                    : AppColors.lightTextPrimary.withValues(alpha: 0.03),
                blurRadius: 0.5,
                offset: const Offset(0, 0.5),
              ),
            ],
          ),
          child: Padding(
            padding: AppSpacing.allRegular,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                AppSpacing.horizontalRegular,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: context.textStyle(
                              FontSizeType.medium,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          AppSpacing.horizontalSmall,
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: status == t.chat.e2eeStatusAvailable
                                  ? AppColors.iosGreen.withValues(alpha: 0.2)
                                  : AppColors.iosGray5,
                              borderRadius: AppRadius.borderRadiusSmall,
                            ),
                            child: Text(
                              status,
                              style: context.textStyle(
                                FontSizeType.caption2,
                                color: status == t.chat.e2eeStatusAvailable
                                    ? AppColors.iosGreen
                                    : AppColors.iosGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalTiny,
                      Text(
                        description,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.iosGray,
                        ),
                      ),
                      AppSpacing.verticalSmall,
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < securityLevel
                                ? CupertinoIcons.star_fill
                                : CupertinoIcons.star,
                            size: 14,
                            color: index < securityLevel
                                ? AppColors.iosYellow
                                : AppColors.iosGray2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_forward, color: AppColors.iosGray),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建危险操作卡片
  Widget _buildDangerActionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: AppColors.transparent,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkSurfaceGroupedTertiary
                : AppColors.lightSurface,
            borderRadius: AppRadius.borderRadiusMedium,
            border: Border.all(color: iconColor.withValues(alpha: 0.3)),
          ),
          child: Padding(
            padding: AppSpacing.allRegular,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                AppSpacing.horizontalRegular,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: context.textStyle(
                          FontSizeType.medium,
                          fontWeight: FontWeight.w500,
                          color: iconColor,
                        ),
                      ),
                      AppSpacing.verticalTiny,
                      Text(
                        description,
                        style: context.textStyle(
                          FontSizeType.footnote,
                          color: AppColors.iosGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.chevron_forward, color: AppColors.iosGray),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示本地备份选项
  void _showLocalBackupOptions(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoModalSurface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.arrow_up_doc_fill),
              title: Text(t.common.e2eeExportBackup),
              subtitle: Text(t.common.e2eeExportBackupDesc),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => const E2EEBackupExportPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(CupertinoIcons.arrow_down_doc_fill),
              title: Text(t.common.e2eeImportBackup),
              subtitle: Text(t.common.e2eeImportBackupDesc),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => const E2EEBackupImportPage(),
                  ),
                );
              },
            ),
            AppSpacing.verticalSmall,
          ],
        ),
      ),
    );
  }

  /// 显示生成新密钥对话框
  void _showGenerateNewKeyDialog(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.chat.e2eeGenerateNewKey),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(t.common.e2eeGenerateKeyConfirm),
            AppSpacing.verticalMedium,
            Text(
              t.common.warning,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.getIosRed(Theme.of(context).brightness),
              ),
            ),
            Text(t.common.e2eeWarnOldMessagesLost),
            Text(t.common.e2eeWarnNeedNewBackup),
            Text(t.main.e2eeWarnIrreversible),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _generateNewKey();
            },
            child: Text(t.common.e2eeConfirmGenerate),
          ),
        ],
      ),
    );
  }

  /// 显示删除密钥对话框（第一阶段：说明后果）
  void _showDeleteKeyDialogStage1(BuildContext context) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(t.common.e2eeDeleteKey),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(t.common.e2eeDeleteKeyConfirm),
            AppSpacing.verticalMedium,
            Text(
              t.common.warning,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.getIosRed(Theme.of(context).brightness),
              ),
            ),
            Text(t.common.e2eeWarnCannotRestore),
            Text(t.common.e2eeWarnAllMsgsLost),
            Text(t.main.e2eeWarnNeedRestoreOrNew),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              // 高摩擦二次确认：删除密钥不可逆，历史消息将永久无法解密
              _showDeleteKeyDialogStage2(context);
            },
            child: Text(t.common.buttonContinue),
          ),
        ],
      ),
    );
  }

  /// 显示删除密钥对话框（第二阶段：最终高摩擦确认）
  void _showDeleteKeyDialogStage2(BuildContext context) {
    final iosRed = AppColors.getIosRed(Theme.of(context).brightness);
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              color: iosRed,
              size: 20,
            ),
            AppSpacing.horizontalTiny,
            Expanded(
              child: Text(
                t.common.warning,
                style: TextStyle(color: iosRed, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeWarnAllMsgsLost,
              style: TextStyle(color: iosRed, fontWeight: FontWeight.w600),
            ),
            Text(
              t.common.e2eeWarnCannotRestore,
              style: TextStyle(color: iosRed, fontWeight: FontWeight.w600),
            ),
            AppSpacing.verticalSmall,
            Text(t.main.e2eeWarnNeedRestoreOrNew),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _deleteKeys();
            },
            child: Text(t.common.e2eeConfirmDelete),
          ),
        ],
      ),
    );
  }

  /// 加载密钥信息
  Future<void> _loadKeyInfo() async {
    setState(() => _isLoading = true);

    try {
      final storage = StorageSecureService.to;
      final hasKeys = await storage.hasE2EEKeys();

      if (hasKeys) {
        final deviceId = await storage.getDeviceId();
        final keyId = await storage.getKeyId();
        final createdAt = await storage.getKeyCreatedAt();

        setState(() {
          _keyInfo = {
            'device_id': deviceId ?? t.common.unknown,
            'key_id': keyId ?? t.common.unknown,
            'created_at': createdAt ?? t.common.unknown,
          };
          _loadError = false;
          _isLoading = false;
        });
      } else {
        setState(() {
          _keyInfo = {};
          _loadError = false;
          _isLoading = false;
        });
      }
    } on Exception catch (e) {
      iPrint('[E2EEKeyRecovery] 读取密钥信息失败, errType=${e.runtimeType}');
      // 读取错误 ≠ 确认无密钥：进入错误态，禁止任何密钥生成/删除入口
      setState(() {
        _keyInfo = {};
        _loadError = true;
        _isLoading = false;
      });
    }
  }

  /// 生成新密钥
  Future<void> _generateNewKey() async {
    // 显示加载对话框
    showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CupertinoActivityIndicator(),
            ),
            AppSpacing.horizontalRegular,
            Text(t.chat.e2eeGeneratingKey),
          ],
        ),
      ),
    );

    try {
      // 1. 生成新密钥对**并上报新公钥到服务端**。
      //    ⚠️ 只 generateKeyPair() 不上报，服务端就查不到本设备公钥，
      //    对端加密时 no_recipient_keys，消息根本发不出去（BUG-05 同款漏报）。
      //    上报失败按整体失败处理：走下方 catch 的失败 SnackBar，提示重试。
      final reported = await E2EEKeyService.regenerateAndReportDeviceKey();
      if (!reported) {
        throw Exception('新公钥上报服务端失败');
      }
      final keyInfo = await E2EEKeyService.getKeyInfo() ?? <String, dynamic>{};

      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();

      // 2. 刷新页面显示
      await _loadKeyInfo();

      // 3. 显示成功对话框
      if (mounted) {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text(t.common.e2eeKeyGeneratedSuccess),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSpacing.verticalSmall,
                Text(t.chat.e2eeNewKeyGenerated),
                AppSpacing.verticalMedium,
                Text(
                  t.common.e2eeDeviceIdInfo(
                    id: _maskId(keyInfo['device_id']?.toString() ?? ''),
                  ),
                ),
                Text(
                  t.common.e2eeKeyIdInfo(
                    id: _maskId(keyInfo['key_id']?.toString() ?? ''),
                  ),
                ),
                Text(
                  t.common.e2eeCreatedAtInfo(
                    time: keyInfo['created_at'].toString(),
                  ),
                ),
                AppSpacing.verticalMedium,
                Container(
                  padding: AppSpacing.allMedium,
                  decoration: BoxDecoration(
                    color: AppColors.iosOrange.withValues(alpha: 0.1),
                    borderRadius: AppRadius.borderRadiusSmall,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            CupertinoIcons.exclamationmark_triangle_fill,
                            color: AppColors.iosOrange,
                            size: 18,
                          ),
                          AppSpacing.horizontalSmall,
                          Text(
                            t.common.e2eeImportantNote,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.iosOrange,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalTiny,
                      Text(t.common.e2eeWarnOldMayNotDecrypt),
                      Text(t.common.e2eeSuggestBackupNow),
                      Text(t.main.e2eeWarnIrreversible),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              CupertinoDialogAction(
                onPressed: () {
                  Navigator.of(context).pop();
                  // 导入到备份导出页面
                  Navigator.push(
                    context,
                    CupertinoPageRoute<dynamic>(
                      builder: (_) => const E2EEBackupExportPage(),
                    ),
                  );
                },
                child: Text(t.common.e2eeGoBackup),
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.main.gotIt),
              ),
            ],
          ),
        );
      }
    } on Exception catch (e) {
      iPrint('[E2EEKeyRecovery] 生成密钥失败: $e');
      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        AppLoading.showToast(t.common.e2eeKeyGenerateFailed);
      }
    }
  }

  /// 脱敏 ID 显示（只显示前4位和后4位）
  String _maskId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  /// 删除密钥
  Future<void> _deleteKeys() async {
    try {
      final storage = StorageSecureService.to;
      await storage.deleteAllE2EEKeys();

      if (!mounted) return;
      setState(() => _keyInfo = {});

      AppLoading.showToast(t.common.e2eeKeyDeleted);
    } on Exception catch (e) {
      iPrint('[E2EEKeyRecovery] 删除密钥失败: $e');
      if (!mounted) return;
      AppLoading.showToast(t.common.e2eeDeleteFailed);
    }
  }
}
