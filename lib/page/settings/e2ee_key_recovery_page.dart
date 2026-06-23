import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/settings/e2ee_backup_export_page.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/page/settings/e2ee_backup_manage_page.dart';
import 'package:imboy/page/settings/e2ee_transfer_page.dart';
import 'package:imboy/page/settings/e2ee_social_page.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/font_types.dart';

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
    return Scaffold(
      appBar: GlassAppBar(
        title: t.main.e2eeKeyRecoveryTitle,
        titleWidget: Text(t.main.e2eeKeyRecoveryTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.common.buttonBack,
        ),
        rightDMActions: [
          IconButton(onPressed: _loadKeyInfo, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 当前密钥信息卡片
                  if (_keyInfo.isNotEmpty) _buildKeyInfoCard(context),
                  if (_keyInfo.isEmpty) _buildNoKeyCard(context),

                  const SizedBox(height: 20),

                  // E2EE 说明卡片
                  _buildE2EEInfoCard(context),

                  const SizedBox(height: 20),

                  // 恢复方法分组
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      t.main.e2eeRecoveryMethods,
                      style: TextStyle(
                        fontSize: FontSizeType.normal.size,
                        fontWeight: FontWeight.w500,
                        color: AppColors.iosGray,
                      ),
                    ),
                  ),

                  // 方法 A: 设备间传输（已实现）
                  _buildRecoveryMethodCard(
                    context,
                    title: t.account.e2eeDeviceTransfer,
                    description: t.account.e2eeDeviceTransferDesc,
                    securityLevel: 3,
                    icon: Icons.devices,
                    iconColor: AppColors.iosBlue,
                    status: t.chat.e2eeStatusAvailable,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<dynamic>(
                          builder: (_) => const E2EETransferPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // 方法 B: 社交恢复（已实现）
                  _buildRecoveryMethodCard(
                    context,
                    title: t.main.e2eeSocialRecovery,
                    description: t.main.e2eeSocialRecoveryDesc,
                    securityLevel: 2,
                    icon: Icons.people,
                    iconColor: AppColors.iosPurple,
                    status: t.chat.e2eeStatusAvailable,
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute<dynamic>(
                          builder: (_) => const E2EESocialPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // 方法 C: 本地备份（已实现）
                  _buildRecoveryMethodCard(
                    context,
                    title: t.common.e2eeLocalBackup,
                    description: t.common.e2eeLocalBackupDesc,
                    securityLevel: 4,
                    icon: Icons.backup,
                    iconColor: AppColors.iosGreen,
                    status: t.chat.e2eeStatusAvailable,
                    onTap: () => _showLocalBackupOptions(context),
                  ),

                  const SizedBox(height: 20),

                  // 危险操作区域
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      t.main.e2eeDangerousOps,
                      style: TextStyle(
                        fontSize: FontSizeType.normal.size,
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
                    icon: Icons.refresh,
                    iconColor: AppColors.iosOrange,
                    onTap: () => _showGenerateNewKeyDialog(context),
                  ),

                  const SizedBox(height: 12),

                  // 删除密钥
                  _buildDangerActionCard(
                    context,
                    title: t.common.e2eeDeleteKey,
                    description: t.common.e2eeDeleteKeyDesc,
                    icon: Icons.delete_forever,
                    iconColor: AppColors.iosRed,
                    onTap: () => _showDeleteKeyDialog(context),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, color: AppColors.iosBlue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.common.e2eeCurrentKeyInfo,
                        style: TextStyle(
                          fontSize: FontSizeType.large.size,
                          fontWeight: FontWeight.bold,
                          color: AppColors.iosBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.common.e2eeE2EEEnabled,
                        style: TextStyle(
                          fontSize: FontSizeType.footnote.size,
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
                  decoration: BoxDecoration(
                    color: AppColors.iosGreen,
                    borderRadius: AppRadius.borderRadiusMedium,
                  ),
                  child: Text(
                    t.chat.e2eeActivated,
                    style: TextStyle(
                      color: AppColors.onPrimary,
                      fontSize: FontSizeType.small.size,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.iosOrange,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              t.common.e2eeNoKeyDetected,
              style: TextStyle(
                fontSize: FontSizeType.large.size,
                fontWeight: FontWeight.bold,
                color: AppColors.iosOrange,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t.common.e2eeNoKeyDesc,
              style: TextStyle(fontSize: FontSizeType.normal.size),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showGenerateNewKeyDialog(context),
              icon: const Icon(Icons.add),
              label: Text(t.chat.e2eeGenerateNewKey),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.iosOrange,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(160, 44),
              ),
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
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
                color: AppColors.iosGray,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.iosBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  t.common.e2eeAboutTitle,
                  style: TextStyle(
                    fontSize: FontSizeType.subheadline.size,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              t.common.e2eeInfoPoint1,
              style: TextStyle(fontSize: FontSizeType.footnote.size),
            ),
            const SizedBox(height: 4),
            Text(
              t.common.e2eeInfoPoint2,
              style: TextStyle(fontSize: FontSizeType.footnote.size),
            ),
            const SizedBox(height: 4),
            Text(
              t.common.e2eeInfoPoint3,
              style: TextStyle(fontSize: FontSizeType.footnote.size),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMedium,
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: FontSizeType.medium.size,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                              style: TextStyle(
                                fontSize: FontSizeType.caption2.size,
                                color: status == t.chat.e2eeStatusAvailable
                                    ? AppColors.iosGreen
                                    : AppColors.iosGray,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: FontSizeType.footnote.size,
                          color: AppColors.iosGray,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: List.generate(
                          5,
                          (index) => Icon(
                            index < securityLevel
                                ? Icons.star
                                : Icons.star_border,
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
                Icon(Icons.navigate_next, color: AppColors.iosGray),
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
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMedium,
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
            padding: const EdgeInsets.all(16),
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
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: FontSizeType.medium.size,
                          fontWeight: FontWeight.w500,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: FontSizeType.footnote.size,
                          color: AppColors.iosGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.navigate_next, color: AppColors.iosGray),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示本地备份选项
  void _showLocalBackupOptions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
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
              leading: const Icon(Icons.download),
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
            ListTile(
              leading: const Icon(Icons.folder),
              title: Text(t.common.e2eeBackupManage),
              subtitle: Text(t.common.e2eeBackupManageDesc),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute<dynamic>(
                    builder: (_) => const E2EEBackupManagePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 显示生成新密钥对话框
  void _showGenerateNewKeyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.chat.e2eeGenerateNewKey),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.common.e2eeGenerateKeyConfirm),
            const SizedBox(height: 12),
            Text(
              t.common.warning,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.iosRed,
              ),
            ),
            Text(t.common.e2eeWarnOldMessagesLost),
            Text(t.common.e2eeWarnNeedNewBackup),
            Text(t.main.e2eeWarnIrreversible),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generateNewKey();
            },
            child: Text(
              t.common.e2eeConfirmGenerate,
              style: const TextStyle(color: AppColors.iosOrange),
            ),
          ),
        ],
      ),
    );
  }

  /// 显示删除密钥对话框
  void _showDeleteKeyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.e2eeDeleteKey),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.common.e2eeDeleteKeyConfirm),
            const SizedBox(height: 12),
            Text(
              t.common.warning,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.iosRed,
              ),
            ),
            Text(t.common.e2eeWarnCannotRestore),
            Text(t.common.e2eeWarnAllMsgsLost),
            Text(t.main.e2eeWarnNeedRestoreOrNew),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteKeys();
            },
            child: Text(
              t.common.e2eeConfirmDelete,
              style: const TextStyle(color: AppColors.iosRed),
            ),
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
          _isLoading = false;
        });
      } else {
        setState(() {
          _keyInfo = {};
          _isLoading = false;
        });
      }
    } on Exception {
      setState(() {
        _keyInfo = {};
        _isLoading = false;
      });
    }
  }

  /// 生成新密钥
  Future<void> _generateNewKey() async {
    // 显示加载对话框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(t.chat.e2eeGeneratingKey),
          ],
        ),
      ),
    );

    try {
      // 1. 生成新的密钥对
      final keyInfo = await E2EEKeyService.generateKeyPair();

      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();

      // 2. 刷新页面显示
      await _loadKeyInfo();

      // 3. 显示成功对话框
      if (mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(t.common.e2eeKeyGeneratedSuccess),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.chat.e2eeNewKeyGenerated),
                const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
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
                            Icons.warning_amber_rounded,
                            color: AppColors.iosOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.common.e2eeImportantNote,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.iosOrange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(t.common.e2eeWarnOldMayNotDecrypt),
                      Text(t.common.e2eeSuggestBackupNow),
                      Text(t.main.e2eeWarnIrreversible),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
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
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(t.main.gotIt),
              ),
            ],
          ),
        );
      }
    } on Exception {
      // 关闭加载对话框
      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.common.e2eeKeyGenerateFailed),
            backgroundColor: AppColors.iosRed,
            duration: const Duration(seconds: 3),
          ),
        );
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

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.common.e2eeKeyDeleted),
          backgroundColor: AppColors.iosGreen,
        ),
      );
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.common.e2eeDeleteFailed),
          backgroundColor: AppColors.iosRed,
        ),
      );
    }
  }
}
