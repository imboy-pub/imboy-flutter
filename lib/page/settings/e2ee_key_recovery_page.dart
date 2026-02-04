import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/settings/e2ee_backup_export_page.dart';
import 'package:imboy/page/settings/e2ee_backup_import_page.dart';
import 'package:imboy/page/settings/e2ee_backup_manage_page.dart';
import 'package:imboy/page/settings/e2ee_transfer_page.dart';
import 'package:imboy/page/settings/e2ee_social_page.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GlassAppBar(
        title: '端到端加密密钥管理',
        titleWidget: const Text('端到端加密密钥管理'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
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
                      '密钥恢复方法',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),

                  // 方法 A: 设备间传输（已实现）
                  _buildRecoveryMethodCard(
                    context,
                    title: '设备间传输',
                    description: '通过二维码直接传输密钥到新设备',
                    securityLevel: 3,
                    icon: Icons.devices,
                    iconColor: Colors.blue,
                    status: '可用',
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const E2EETransferPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // 方法 B: 社交恢复（已实现）
                  _buildRecoveryMethodCard(
                    context,
                    title: '社交恢复',
                    description: '通过信任的联系人协助恢复密钥',
                    securityLevel: 2,
                    icon: Icons.people,
                    iconColor: Colors.purple,
                    status: '可用',
                    onTap: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (_) => const E2EESocialPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // 方法 C: 本地备份（已实现）
                  _buildRecoveryMethodCard(
                    context,
                    title: '本地备份',
                    description: '导出加密备份文件到本地或云端',
                    securityLevel: 4,
                    icon: Icons.backup,
                    iconColor: Colors.green,
                    status: '可用',
                    onTap: () => _showLocalBackupOptions(context),
                  ),

                  const SizedBox(height: 20),

                  // 危险操作区域
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      '危险操作',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),

                  // 生成新密钥
                  _buildDangerActionCard(
                    context,
                    title: '生成新密钥',
                    description: '生成新的 E2EE 密钥对（旧消息将无法解密）',
                    icon: Icons.refresh,
                    iconColor: Colors.orange,
                    onTap: () => _showGenerateNewKeyDialog(context),
                  ),

                  const SizedBox(height: 12),

                  // 删除密钥
                  _buildDangerActionCard(
                    context,
                    title: '删除密钥',
                    description: '删除本地存储的密钥（无法恢复）',
                    icon: Icons.delete_forever,
                    iconColor: Colors.red,
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
          colors: [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '当前密钥信息',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '端到端加密已启用',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade700,
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
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '已激活',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('设备 ID', _keyInfo['device_id'] ?? '未知'),
            _buildInfoRow('密钥 ID', _keyInfo['key_id'] ?? '未知'),
            _buildInfoRow('创建时间', _keyInfo['created_at'] ?? '未知'),
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
          colors: [Colors.orange.shade50, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              '未检测到 E2EE 密钥',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '您需要先生成密钥对或从备份中恢复',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showGenerateNewKeyDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('生成新密钥'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
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
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
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
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '关于端到端加密',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '• 您的消息在发送前已加密，服务器无法查看内容',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text(
              '• 更换设备或删除密钥后，旧消息可能无法解密',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 4),
            const Text('• 请定期备份密钥以防数据丢失', style: TextStyle(fontSize: 13)),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMedium,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: AppRadius.borderRadiusMedium,
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.03),
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
                            style: const TextStyle(
                              fontSize: 16,
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
                              color: status == '可用'
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                color: status == '可用'
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
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
                                ? Colors.amber
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.navigate_next,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderRadiusMedium,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.navigate_next,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示本地备份选项
  void _showLocalBackupOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('导出备份'),
              subtitle: const Text('生成加密备份文件'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const E2EEBackupExportPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('导入备份'),
              subtitle: const Text('从备份文件恢复密钥'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const E2EEBackupImportPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('备份管理'),
              subtitle: const Text('查看备份历史记录'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  CupertinoPageRoute(
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('生成新密钥'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要生成新的 E2EE 密钥对吗？'),
            SizedBox(height: 12),
            Text(
              '警告：',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            Text('• 旧消息将无法解密'),
            Text('• 需要重新生成备份文件'),
            Text('• 此操作不可撤销'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generateNewKey();
            },
            child: const Text('确认生成', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  /// 显示删除密钥对话框
  void _showDeleteKeyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除密钥'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('确定要删除当前密钥吗？'),
            SizedBox(height: 12),
            Text(
              '警告：',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            Text('• 删除后无法恢复'),
            Text('• 所有 E2EE 消息将无法解密'),
            Text('• 需要从备份恢复或生成新密钥'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteKeys();
            },
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// 加载密钥信息
  Future<void> _loadKeyInfo() async {
    setState(() => _isLoading = true);

    try {
      final storage = StorageSecure();
      final hasKeys = await storage.hasE2EEKeys();

      if (hasKeys) {
        final deviceId = await storage.getDeviceId();
        final keyId = await storage.getKeyId();
        final createdAt = await storage.getKeyCreatedAt();

        setState(() {
          _keyInfo = {
            'device_id': deviceId ?? '未知',
            'key_id': keyId ?? '未知',
            'created_at': createdAt ?? '未知',
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _keyInfo = {};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _keyInfo = {};
        _isLoading = false;
      });
    }
  }

  /// 生成新密钥
  Future<void> _generateNewKey() async {
    // 显示加载对话框
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 16),
            Text('正在生成密钥，请稍候...'),
          ],
        ),
      ),
    );

    try {
      // 1. 生成新的密钥对
      final keyInfo = await E2EEKeyService.generateKeyPair();

      // 关闭加载对话框
      Navigator.of(context).pop();

      // 2. 刷新页面显示
      await _loadKeyInfo();

      // 3. 显示成功对话框
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('密钥生成成功'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('新的 E2EE 密钥对已生成！'),
                const SizedBox(height: 12),
                Text('设备 ID: ${keyInfo['device_id']}'),
                Text('密钥 ID: ${keyInfo['key_id']}'),
                Text('创建时间: ${keyInfo['created_at']}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            '重要提示',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('• 旧消息可能无法解密'),
                      Text('• 建议立即导出备份'),
                      Text('• 此操作不可撤销'),
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
                    CupertinoPageRoute(
                      builder: (_) => const E2EEBackupExportPage(),
                    ),
                  );
                },
                child: const Text('去备份'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // 关闭加载对话框
      Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('密钥生成失败: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// 删除密钥
  Future<void> _deleteKeys() async {
    try {
      final storage = StorageSecure();
      await storage.deleteAllE2EEKeys();

      setState(() => _keyInfo = {});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('密钥已删除'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('删除失败: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
