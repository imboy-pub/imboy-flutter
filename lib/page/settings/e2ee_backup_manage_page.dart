import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/e2ee_plus_api.dart';

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
        title: Text(t.e2eeBackupManage),
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
            Icon(Icons.backup_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              t.e2eeBackupNoRecords,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              t.e2eeBackupNoRecordsHint,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _backupHistory.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final backup = _backupHistory[index];
        return _buildBackupCard(backup);
      },
    );
  }

  Widget _buildBackupCard(Map<String, dynamic> backup) {
    final deviceId = backup['device_id'] ?? t.unknown;
    final createdAt = backup['created_at'] ?? t.unknown;
    final backupVersion = backup['backup_version'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Text(
            'v$backupVersion',
            style: TextStyle(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(t.e2eeBackupDeviceLabel(id: deviceId.toString())),
        subtitle: Text(t.e2eeBackupCreatedAtLabel(time: createdAt.toString())),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.e2eeBackupDetailTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(t.e2eeBackupDeviceIdLabel, backup['device_id']),
              _buildDetailRow(
                t.e2eeBackupVersionNum,
                '#${backup['backup_version']}',
              ),
              _buildDetailRow(t.e2eeBackupCreatedAtRow, backup['created_at']),
              _buildDetailRow(
                t.e2eeBackupFileSizeRow,
                '${backup['file_size']} bytes',
              ),
              _buildDetailRow(
                t.e2eeBackupNoteRow,
                backup['user_notes'] ?? t.unknown,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.buttonClose),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.e2eeBackupDeleteTitle),
        content: Text(t.e2eeBackupDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.buttonCancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteBackup(backup['id']);
            },
            child: Text(
              t.buttonDelete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value.toString(), style: const TextStyle(fontSize: 13)),
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
          content: Text(t.e2eeBackupDeleteSuccess),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.e2eeDeleteFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
