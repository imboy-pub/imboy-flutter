import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/service/e2ee_crypto_service.dart';
import 'package:imboy/service/e2ee_key_service.dart';
import 'package:imboy/service/e2ee_local_backup_service.dart';
import 'package:imboy/service/storage_secure.dart';

/// E2EE 功能开发者测试页面
///
/// 用于快速验证 E2EE 功能的开发调试页面
/// 包含：
/// - 密钥生成测试
/// - 加密服务测试
/// - 备份导出测试
/// - 备份导入测试
/// - 存储服务测试
class E2EEDevTestPage extends StatefulWidget {
  const E2EEDevTestPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _E2EEDevTestPageState createState() => _E2EEDevTestPageState();
}

class _E2EEDevTestPageState extends State<E2EEDevTestPage> {
  final _testResults = <TestResult>[];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: 'E2EE 开发测试',
        titleWidget: const Text('E2EE 开发测试'),
      ),
      body: Column(
        children: [
          // 测试控制区
          _buildTestControls(),
          const Divider(height: 1),
          // 测试结果区
          Expanded(child: _buildTestResults()),
        ],
      ),
    );
  }

  Widget _buildTestControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isRunning ? null : () => _runAllTests(),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('运行所有测试'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.iosBlue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isRunning ? null : () => _clearResults(),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('清空结果'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '测试进度: ${_testResults.where((r) => r.status == TestStatus.pass).length} / ${_testResults.length}',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: FontSizeType.small.size,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestResults() {
    if (_testResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.science_outlined, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              '点击"运行所有测试"开始验证',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _testResults.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final result = _testResults[index];
        return _buildTestResultCard(result);
      },
    );
  }

  Widget _buildTestResultCard(TestResult result) {
    Color statusColor;
    IconData statusIcon;
    switch (result.status) {
      case TestStatus.pass:
        statusColor = AppColors.iosGreen;
        statusIcon = Icons.check_circle;
        break;
      case TestStatus.fail:
        statusColor = AppColors.iosRed;
        statusIcon = Icons.error;
        break;
      case TestStatus.running:
        statusColor = AppColors.iosBlue;
        statusIcon = Icons.hourglass_empty;
        break;
      case TestStatus.pending:
        statusColor = AppColors.iosGray;
        statusIcon = Icons.pending;
        break;
    }

    return Card(
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(result.name),
        subtitle: Text(result.message),
        trailing: result.duration != null
            ? Text(
                '${result.duration}ms',
                style: TextStyle(
                  fontSize: FontSizeType.small.size,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
    });

    // 按顺序执行测试
    await _testCryptoService();
    await _testKeyGeneration();
    await _testPasswordStrength();
    await _testBackupExportImport();
    await _testStorageService();

    setState(() {
      _isRunning = false;
    });

    _showSummary();
  }

  void _clearResults() {
    setState(() {
      _testResults.clear();
    });
  }

  void _addResult(
    String name,
    TestStatus status,
    String message, {
    int? duration,
  }) {
    if (mounted) {
      setState(() {
        _testResults.add(
          TestResult(
            name: name,
            status: status,
            message: message,
            duration: duration,
          ),
        );
      });
    }
  }

  Future<void> _testCryptoService() async {
    _addResult('加密服务测试', TestStatus.running, '正在测试...');

    try {
      final stopwatch = Stopwatch()..start();

      // 测试 1: 密钥派生
      final salt = E2EECryptoService.generateSalt();
      final derivedKey = await E2EECryptoService.deriveKey(
        'TestPassword123!',
        salt,
      );

      if (derivedKey.length != 32) {
        _addResult(
          '加密服务测试',
          TestStatus.fail,
          '密钥派生失败：长度不正确 (${derivedKey.length})',
        );
        return;
      }

      // 测试 2: 加密/解密
      final iv = E2EECryptoService.generateIV();
      final plaintext = utf8.encode('Hello, E2EE World!');
      final encrypted = await E2EECryptoService.encryptAesGcm(
        plaintext,
        derivedKey,
        iv,
      );
      final decrypted = await E2EECryptoService.decryptAesGcm(
        encrypted['ciphertext']!,
        encrypted['authTag']!,
        derivedKey,
        iv,
      );

      if (utf8.decode(decrypted) != 'Hello, E2EE World!') {
        _addResult('加密服务测试', TestStatus.fail, '加密/解密失败：数据不匹配');
        return;
      }

      // 测试 3: 校验和
      final checksum = E2EECryptoService.calculateChecksum(plaintext);
      if (checksum.length != 64) {
        _addResult('加密服务测试', TestStatus.fail, '校验和长度不正确');
        return;
      }

      stopwatch.stop();
      _addResult(
        '加密服务测试',
        TestStatus.pass,
        '所有测试通过',
        duration: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      _addResult('加密服务测试', TestStatus.fail, '异常: $e');
    }
  }

  Future<void> _testKeyGeneration() async {
    _addResult('密钥生成测试', TestStatus.running, '正在测试...');

    try {
      final stopwatch = Stopwatch()..start();

      // 清理旧密钥
      await StorageSecureService.to.deleteAllE2EEKeys();

      // 生成新密钥
      final keyInfo = await E2EEKeyService.generateKeyPair();

      // 验证密钥信息
      if (keyInfo['device_id'] == null ||
          keyInfo['device_id'].toString().isEmpty) {
        _addResult('密钥生成测试', TestStatus.fail, '设备 ID 为空');
        return;
      }

      if (keyInfo['key_id'] == null || keyInfo['key_id'].toString().isEmpty) {
        _addResult('密钥生成测试', TestStatus.fail, '密钥 ID 为空');
        return;
      }

      // 验证密钥已保存
      final hasKey = await E2EEKeyService.hasKey();
      if (!hasKey) {
        _addResult('密钥生成测试', TestStatus.fail, '密钥未保存到存储');
        return;
      }

      // 验证 PEM 格式
      final privateKey = await StorageSecureService.to.getPrivateKey();
      final publicKey = await StorageSecureService.to.getPublicKey();

      if (privateKey == null ||
          !privateKey.startsWith('-----BEGIN PRIVATE KEY-----')) {
        // gitleaks:allow
        _addResult('密钥生成测试', TestStatus.fail, '私钥 PEM 格式错误');
        return;
      }

      if (publicKey == null ||
          !publicKey.startsWith('-----BEGIN PUBLIC KEY-----')) {
        _addResult('密钥生成测试', TestStatus.fail, '公钥 PEM 格式错误');
        return;
      }

      stopwatch.stop();
      _addResult(
        '密钥生成测试',
        TestStatus.pass,
        '密钥生成成功 (设备 ID: ${keyInfo['device_id']})',
        duration: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      _addResult('密钥生成测试', TestStatus.fail, '异常: $e');
    }
  }

  Future<void> _testPasswordStrength() async {
    _addResult('密码强度测试', TestStatus.running, '正在测试...');

    try {
      final stopwatch = Stopwatch()..start();

      // 测试弱密码
      final weak1 = E2EELocalBackupService.calculatePasswordStrength('123');
      if (weak1 >= 0.3) {
        _addResult('密码强度测试', TestStatus.fail, '弱密码 "123" 强度过高');
        return;
      }

      // 测试中等密码
      final medium = E2EELocalBackupService.calculatePasswordStrength(
        'Test123!',
      );
      if (medium < 0.3 || medium > 0.7) {
        _addResult('密码强度测试', TestStatus.fail, '中等密码强度计算错误');
        return;
      }

      // 测试强密码
      final strong = E2EELocalBackupService.calculatePasswordStrength(
        'Str0ng!Pass123#',
      );
      if (strong <= 0.7) {
        _addResult('密码强度测试', TestStatus.fail, '强密码强度过低');
        return;
      }

      stopwatch.stop();
      _addResult(
        '密码强度测试',
        TestStatus.pass,
        '弱: ${(weak1 * 100).toInt()}%, 中: ${(medium * 100).toInt()}%, 强: ${(strong * 100).toInt()}%',
        duration: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      _addResult('密码强度测试', TestStatus.fail, '异常: $e');
    }
  }

  Future<void> _testBackupExportImport() async {
    _addResult('备份导出/导入测试', TestStatus.running, '正在测试...');

    try {
      final stopwatch = Stopwatch()..start();

      // 确保有密钥
      if (!(await E2EEKeyService.hasKey())) {
        await E2EEKeyService.generateKeyPair();
      }

      final privateKey = await StorageSecureService.to.getPrivateKey();
      final publicKey = await StorageSecureService.to.getPublicKey();
      final deviceId = await StorageSecureService.to.getDeviceId();
      final keyId = await StorageSecureService.to.getKeyId();

      if (privateKey == null ||
          publicKey == null ||
          deviceId == null ||
          keyId == null) {
        _addResult('备份导出/导入测试', TestStatus.fail, '密钥信息不完整');
        return;
      }

      // 导出备份
      final backupPath = await E2EELocalBackupService.exportBackup(
        password: 'TestBackup123!@#',
        privateKey: privateKey,
        publicKey: publicKey,
        deviceId: deviceId,
        keyId: keyId,
        userNotes: '开发者测试备份',
      );

      if (backupPath.isEmpty || !File(backupPath).existsSync()) {
        _addResult('备份导出/导入测试', TestStatus.fail, '备份文件未创建');
        return;
      }

      // 删除密钥
      await StorageSecureService.to.deleteAllE2EEKeys();

      // 导入备份
      final restored = await E2EELocalBackupService.importBackup(
        filePath: backupPath,
        password: 'TestBackup123!@#',
      );

      if (restored['device_id'] != deviceId) {
        _addResult('备份导出/导入测试', TestStatus.fail, '设备 ID 不匹配');
        return;
      }

      if (restored['key_id'] != keyId) {
        _addResult('备份导出/导入测试', TestStatus.fail, '密钥 ID 不匹配');
        return;
      }

      // 恢复密钥到存储
      await StorageSecureService.to.savePrivateKey(
        restored['private_key'] as String,
      );
      await StorageSecureService.to.savePublicKey(
        restored['public_key'] as String,
      );

      stopwatch.stop();
      _addResult(
        '备份导出/导入测试',
        TestStatus.pass,
        '备份文件: ${backupPath.split('/').last}',
        duration: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      _addResult('备份导出/导入测试', TestStatus.fail, '异常: $e');
    }
  }

  Future<void> _testStorageService() async {
    _addResult('存储服务测试', TestStatus.running, '正在测试...');

    try {
      final stopwatch = Stopwatch()..start();

      final storage = StorageSecureService.to;

      // 测试写入
      await storage.savePrivateKey('test_private_key');
      await storage.savePublicKey('test_public_key');
      await storage.setDeviceId('test_device_id');
      await storage.setKeyId('test_key_id');

      // 测试读取
      final privateKey = await storage.getPrivateKey();
      final publicKey = await storage.getPublicKey();
      final deviceId = await storage.getDeviceId();
      final keyId = await storage.getKeyId();

      if (privateKey != 'test_private_key' ||
          publicKey != 'test_public_key' ||
          deviceId != 'test_device_id' ||
          keyId != 'test_key_id') {
        _addResult('存储服务测试', TestStatus.fail, '存储/读取值不匹配');
        return;
      }

      // 测试删除
      await storage.deleteAllE2EEKeys();
      final hasKeys = await storage.hasE2EEKeys();

      if (hasKeys) {
        _addResult('存储服务测试', TestStatus.fail, '删除后密钥仍然存在');
        return;
      }

      stopwatch.stop();
      _addResult(
        '存储服务测试',
        TestStatus.pass,
        '读写删除功能正常',
        duration: stopwatch.elapsedMilliseconds,
      );
    } catch (e) {
      _addResult('存储服务测试', TestStatus.fail, '异常: $e');
    }
  }

  void _showSummary() {
    final passed = _testResults
        .where((r) => r.status == TestStatus.pass)
        .length;
    final failed = _testResults
        .where((r) => r.status == TestStatus.fail)
        .length;
    final total = _testResults.length;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('测试完成 ($total/$total 通过)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (passed > 0)
              Text(
                '✅ 通过: $passed',
                style: const TextStyle(color: AppColors.iosGreen),
              ),
            if (failed > 0)
              Text(
                '❌ 失败: $failed',
                style: const TextStyle(color: AppColors.iosRed),
              ),
            const SizedBox(height: 16),
            Text(
              failed == 0 ? '所有测试通过！' : '有失败的测试，请检查',
              style: TextStyle(
                color: failed == 0 ? AppColors.iosGreen : AppColors.iosOrange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}

enum TestStatus { pending, running, pass, fail }

class TestResult {
  final String name;
  final TestStatus status;
  final String message;
  final int? duration;

  TestResult({
    required this.name,
    required this.status,
    required this.message,
    this.duration,
  });
}
