import 'package:flutter/material.dart';
import 'package:imboy/service/storage_secure.dart';

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
    // 延迟加载备份历史，避免布局期间触发 setState
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
        title: const Text('备份管理'),
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
              '暂无备份记录',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              '导出备份后将在此显示历史记录',
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
    final deviceId = backup['device_id'] ?? '未知设备';
    final createdAt = backup['created_at'] ?? '未知时间';
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
        title: Text('设备 $deviceId'),
        subtitle: Text('创建于 $createdAt'),
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
      // TODO: 从服务器获取备份历史
      // 这里使用模拟数据
      final deviceId = await StorageSecureService.to.getDeviceId() ?? '未知';
      setState(() {
        _backupHistory = [
          {
            'id': 1,
            'device_id': deviceId,
            'backup_version': 1,
            'created_at': DateTime.now().toIso8601String(),
            'file_size': 2048,
            'user_notes': '主手机备份',
          },
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _backupHistory = [];
      });
    }
  }

  void _showBackupDetailDialog(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('备份详情'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('设备 ID', backup['device_id']),
              _buildDetailRow('备份版本', '#${backup['backup_version']}'),
              _buildDetailRow('创建时间', backup['created_at']),
              _buildDetailRow('文件大小', '${backup['file_size']} bytes'),
              _buildDetailRow('备注', backup['user_notes'] ?? '无'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> backup) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除备份记录'),
        content: Text('确定要删除此备份记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteBackup(backup['id']);
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
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
    // TODO: 调用 API 删除备份记录
    setState(() {
      _backupHistory.removeWhere((b) => b['id'] == backupId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('备份记录已删除'), backgroundColor: Colors.green),
    );
  }
}
