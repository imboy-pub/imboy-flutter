import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/storage_secure.dart';

/// E2EE 备份导入页面
///
/// 功能：
/// - 选择备份文件
/// - 验证文件格式
/// - 输入密码解密
/// - 恢复私钥到安全存储
class E2EEBackupImportPage extends StatefulWidget {
  final String? initialFilePath;

  const E2EEBackupImportPage({super.key, this.initialFilePath});

  @override
  // ignore: library_private_types_in_public_api
  _E2EEBackupImportPageState createState() => _E2EEBackupImportPageState();
}

class _E2EEBackupImportPageState extends State<E2EEBackupImportPage> {
  final _passwordController = TextEditingController();
  bool _isImporting = false;
  File? _selectedFile;
  Map<String, dynamic>? _backupInfo;

  @override
  void initState() {
    super.initState();
    // 延迟验证文件，避免布局期间触发 setState
    if (widget.initialFilePath != null) {
      _selectedFile = File(widget.initialFilePath!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _verifyFile();
        }
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('导入 E2EE 备份'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildWarningCard(),
          const SizedBox(height: 24),
          _buildFileSelector(),
          if (_backupInfo != null) ...[
            const SizedBox(height: 16),
            _buildBackupInfoCard(),
          ],
          const SizedBox(height: 24),
          _buildPasswordSection(),
          const SizedBox(height: 24),
          _buildImportButton(),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange),
                const SizedBox(width: 8),
                Text(
                  '导入说明',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '• 导入后，当前的 E2EE 密钥将被替换',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
            const SizedBox(height: 4),
            Text(
              '• 请确保备份文件来自可信任的来源',
              style: TextStyle(fontSize: 13, color: Colors.orange.shade900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('选择备份文件', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectFile,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                      color: _selectedFile != null ? Colors.green : Colors.grey,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? (_selectedFile!.path.split('/').last)
                          : '点击选择备份文件 (.enc)',
                      style: TextStyle(
                        color: _selectedFile != null
                            ? Colors.green
                            : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupInfoCard() {
    if (_backupInfo == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '备份信息',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.green, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('版本号', _backupInfo!['version'].toString()),
            _buildInfoRow('算法', _backupInfo!['algorithm'].toString()),
            _buildInfoRow('文件大小', '${_backupInfo!['file_size']} bytes'),
            const SizedBox(height: 8),
            const Text(
              '✓ 文件格式有效',
              style: TextStyle(fontSize: 12, color: Colors.green),
            ),
          ],
        ),
      ),
    );
  }

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
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildPasswordSection() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: InputDecoration(
        labelText: '备份密码 *',
        hintText: '请输入备份时设置的密码',
        prefixIcon: const Icon(Icons.lock),
        border: const OutlineInputBorder(),
        suffixIcon: _isImporting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
      ),
      enabled: _backupInfo != null,
    );
  }

  Widget _buildImportButton() {
    final isEnabled =
        _passwordController.text.isNotEmpty &&
        _backupInfo != null &&
        !_isImporting;

    return ElevatedButton(
      onPressed: isEnabled ? _handleImport : null,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        backgroundColor: isEnabled ? null : Colors.grey,
      ),
      child: _isImporting
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Text('导入密钥'),
    );
  }

  Future<void> _selectFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['enc'],
        allowMultiple: false,
      );

      if (result != null &&
          result.files.isNotEmpty &&
          result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _backupInfo = null;
        });
        await _verifyFile();
      }
    } on Exception {
      _showError('选择文件失败，请重试');
    }
  }

  Future<void> _verifyFile() async {
    if (_selectedFile == null) return;

    try {
      final info = await E2EELocalBackupService.verifyBackupFile(
        _selectedFile!.path,
      );
      setState(() => _backupInfo = info);
    } on Exception {
      setState(() {
        _backupInfo = null;
      });
      _showError('文件验证失败，请检查文件格式');
    }
  }

  Future<void> _handleImport() async {
    final password = _passwordController.text;

    try {
      setState(() => _isImporting = true);

      // 导入备份
      final result = await E2EELocalBackupService.importBackup(
        filePath: _selectedFile!.path,
        password: password,
      );

      // 存储密钥到安全存储
      await StorageSecureService.to.savePrivateKey(result['private_key']);
      await StorageSecureService.to.savePublicKey(result['public_key']);
      await StorageSecureService.to.setDeviceId(result['device_id']);
      await StorageSecureService.to.setKeyId(result['key_id']);

      setState(() => _isImporting = false);

      // 显示成功对话框
      _showSuccessDialog(result);
    } on Exception {
      setState(() => _isImporting = false);
      _showError('导入失败，请检查密码是否正确');
    }
  }

  void _showSuccessDialog(Map<String, dynamic> result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('导入成功'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('E2EE 密钥已成功恢复！'),
            const SizedBox(height: 12),
            Text('设备 ID: ${_maskId(result['device_id']?.toString() ?? '')}'),
            Text('密钥 ID: ${_maskId(result['key_id']?.toString() ?? '')}'),
            Text('创建时间: ${result['created_at']}'),
            const SizedBox(height: 12),
            Text(
              '注意：旧消息可能无法访问，这是 E2EE 的正常行为',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // 关闭对话框
              Navigator.of(context).pop(); // 返回上一页
            },
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  /// 脱敏 ID 显示（只显示前4位和后4位）
  String _maskId(String id) {
    if (id.length <= 8) return id;
    return '${id.substring(0, 4)}...${id.substring(id.length - 4)}';
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
