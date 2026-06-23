import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/e2ee_plus_api.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// E2EE 备份管理页面
///
/// 功能：
/// - 显示备份历史记录
/// - 查看备份详情
/// - 删除备份记录
class E2EEBackupManagePage extends StatefulWidget {
  const E2EEBackupManagePage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _E2EEBackupManagePageState createState() => _E2EEBackupManagePageState();
}

class _E2EEBackupManagePageState extends State<E2EEBackupManagePage> {
  bool _isLoading = true;
  List<dynamic> _backupHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBackupHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.common.e2eeBackupManage),
        actions: [
          IconButton(
            onPressed: _loadBackupHistory,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBackupList(),
    );
  }

  Widget _buildBackupList() {
    if (_backupHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.backup_outlined, size: 64, color: AppColors.iosGray4),
            AppSpacing.verticalRegular,
            Text(
              t.common.e2eeBackupNoRecords,
              style: TextStyle(
                fontSize: FontSizeType.medium.size,
                color: AppColors.textSecondary,
              ),
            ),
            AppSpacing.verticalSmall,
            Text(
              t.common.e2eeBackupNoRecordsHint,
              style: TextStyle(
                fontSize: FontSizeType.footnote.size,
                color: AppColors.iosGray2,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _backupHistory.length,
      padding: const EdgeInsets.all(AppSpacing.small),
      itemBuilder: (context, index) {
        final backup = _backupHistory[index];
        return _buildBackupCard(backup as Map<String, dynamic>);
      },
    );
  }

  Widget _buildBackupCard(Map<String, dynamic> backup) {
    final deviceId = backup['device_id'] ?? t.common.unknown;
    final createdAt = backup['created_at'] ?? t.common.unknown;
    final backupVersion = backup['backup_version'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.small),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primaryLight,
          child: Text(
            'v$backupVersion',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(t.common.e2eeBackupDeviceLabel(id: deviceId.toString())),
        subtitle: Text(
          t.common.e2eeBackupCreatedAtLabel(time: createdAt.toString()),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _showDeleteDialog(backup),
        ),
        onTap: () => _showBackupDetailDialog(backup),
      ),
    );
  }

  Future<void> _loadBackupHistory() async {
    setState(() => _isLoading = true);
    try {
      final backups = await E2EEPlusApi().listBackups();
      if (mounted) {
        setState(() {
          _backupHistory = backups;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _backupHistory = [];
        });
      }
    }
  }

  void _showBackupDetailDialog(Map<String, dynamic> backup) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.e2eeBackupDetailTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(
                t.common.e2eeBackupDeviceIdLabel,
                backup['device_id'],
              ),
              _buildDetailRow(
                t.common.e2eeBackupVersionNum,
                '#${backup['backup_version']}',
              ),
              _buildDetailRow(
                t.common.e2eeBackupCreatedAtRow,
                backup['created_at'],
              ),
              _buildDetailRow(
                t.common.e2eeBackupFileSizeRow,
                '${backup['file_size']} bytes',
              ),
              _buildDetailRow(
                t.common.e2eeBackupNoteRow,
                backup['user_notes'] ?? t.common.unknown,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.buttonClose),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> backup) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.common.e2eeBackupDeleteTitle),
        content: Text(t.common.e2eeBackupDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteBackup(backup['id'] as int);
            },
            child: Text(
              t.common.buttonDelete,
              style: const TextStyle(color: AppColors.iosRed),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.iosGray,
                fontSize: FontSizeType.small.size,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.toString(),
              style: TextStyle(fontSize: FontSizeType.footnote.size),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(int backupId) async {
    final success = await E2EEPlusApi().deleteBackup(backupId);
    if (!mounted) return;
    if (success) {
      setState(() {
        _backupHistory.removeWhere((b) => b['id'] == backupId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.common.e2eeBackupDeleteSuccess),
          backgroundColor: AppColors.iosGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.common.e2eeDeleteFailed),
          backgroundColor: AppColors.iosRed,
        ),
      );
    }
  }
}
