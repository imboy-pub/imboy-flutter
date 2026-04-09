/// 备份服务
///
/// 负责数据备份和恢复
library;

import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/encrypter.dart';

/// 备份配置
class BackupConfig {
  final bool includeMessages;
  final bool includeContacts;
  final bool includeGroups;
  final bool includeConversations;
  final BackupFormat format;
  final String? password;

  BackupConfig({
    this.includeMessages = true,
    this.includeContacts = true,
    this.includeGroups = true,
    this.includeConversations = true,
    this.format = BackupFormat.database,
    this.password,
  });

  /// 创建构建器
  static BackupConfigBuilder builder() => BackupConfigBuilder();
}

/// 备份配置构建器
class BackupConfigBuilder {
  bool _includeMessages = true;
  bool _includeContacts = true;
  bool _includeGroups = true;
  bool _includeConversations = true;
  BackupFormat _format = BackupFormat.database;
  String? _password;

  BackupConfigBuilder includeMessages({bool value = true}) {
    _includeMessages = value;
    return this;
  }

  BackupConfigBuilder includeContacts({bool value = true}) {
    _includeContacts = value;
    return this;
  }

  BackupConfigBuilder includeGroups({bool value = true}) {
    _includeGroups = value;
    return this;
  }

  BackupConfigBuilder includeConversations({bool value = true}) {
    _includeConversations = value;
    return this;
  }

  BackupConfigBuilder format(BackupFormat format) {
    _format = format;
    return this;
  }

  BackupConfigBuilder password(String password) {
    _password = password;
    return this;
  }

  BackupConfig build() {
    return BackupConfig(
      includeMessages: _includeMessages,
      includeContacts: _includeContacts,
      includeGroups: _includeGroups,
      includeConversations: _includeConversations,
      format: _format,
      password: _password,
    );
  }
}

/// 备份格式
enum BackupFormat { database, json }

/// 备份结果
class BackupResult {
  final bool success;
  final String? backupPath;
  final int? fileSize;
  final String? error;

  BackupResult({
    required this.success,
    this.backupPath,
    this.fileSize,
    this.error,
  });

  String? get formattedFileSize {
    if (fileSize == null) return null;
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) {
      return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize! < 1024 * 1024 * 1024) {
      return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize! / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 备份服务
class BackupService {
  static final Logger _logger = Logger();

  // 单例
  static final BackupService to = BackupService._privateConstructor();

  BackupService._privateConstructor();

  Directory? _backupDir;

  /// 导出备份
  Future<BackupResult> export(BackupConfig config) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return BackupResult(success: false, error: 'Database not available');
    }

    final stopwatch = Stopwatch()..start();

    try {
      final backupDir = await _getBackupDirectory();
      await backupDir.create(recursive: true);

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(
        DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond()),
      );
      final extension = config.format == BackupFormat.database
          ? '.db'
          : '.json';
      final backupPath = path.join(
        backupDir.path,
        'backup_$timestamp$extension',
      );

      switch (config.format) {
        case BackupFormat.database:
          await _exportDatabase(db, backupPath, config);
          break;
        case BackupFormat.json:
          await _exportJson(db, backupPath, config);
          break;
      }

      stopwatch.stop();

      final file = File(backupPath);
      final size = await file.length();

      _logger.i(
        'Backup completed: $backupPath (${stopwatch.elapsedMilliseconds}ms)',
      );

      return BackupResult(
        success: true,
        backupPath: backupPath,
        fileSize: size,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      _logger.e('Backup failed', error: e, stackTrace: stackTrace);

      return BackupResult(success: false, error: e.toString());
    }
  }

  /// 从备份恢复
  Future<bool> restore(String backupPath, {String? password}) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      _logger.e('Database not available');
      return false;
    }

    try {
      _logger.i('Restoring from: $backupPath');

      // 创建当前数据库备份
      final dbPath = db.path;
      final tempBackup = '$dbPath.temp';

      await File(dbPath).copy(tempBackup);

      try {
        await db.close();

        // 替换数据库文件
        if (backupPath.endsWith('.db')) {
          await File(backupPath).copy(dbPath);
        } else if (backupPath.endsWith('.json')) {
          await _restoreFromJson(dbPath, backupPath);
        }

        // 重新打开数据库
        await SqliteService.to.db;

        _logger.i('Restore completed');
        return true;
      } catch (e) {
        // 恢复失败，回滚
        _logger.w('Restore failed, rolling back');
        await File(tempBackup).copy(dbPath);
        await SqliteService.to.db;
        rethrow;
      } finally {
        // 删除临时备份
        final file = File(tempBackup);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Restore failed', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 导出为数据库文件
  /// ⚠️ 安全警告：如果未设置密码，数据库文件将以明文存储
  Future<void> _exportDatabase(
    Database db,
    String outputPath,
    BackupConfig config,
  ) async {
    final dbPath = db.path;

    if (config.password == null || config.password!.isEmpty) {
      _logger.w('⚠️ 备份未设置密码，数据将以明文存储');
      await File(dbPath).copy(outputPath);
    } else {
      // 使用 AES 加密数据库文件
      await _encryptFile(dbPath, outputPath, config.password!);
    }
  }

  /// 导出为 JSON
  /// ⚠️ 安全警告：如果未设置密码，JSON 文件将以明文存储
  Future<void> _exportJson(
    Database db,
    String outputPath,
    BackupConfig config,
  ) async {
    final data = await _collectData(db, config);

    final encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(data);

    if (config.password == null || config.password!.isEmpty) {
      _logger.w('⚠️ 备份未设置密码，数据将以明文存储');
      await File(outputPath).writeAsString(json);
    } else {
      // 使用 AES 加密 JSON 内容
      await _encryptDataToJson(json, outputPath, config.password!);
    }
  }

  /// 从 JSON 恢复
  /// 自动检测是否加密并解密
  Future<void> _restoreFromJson(String dbPath, String jsonPath) async {
    // 尝试读取并解密
    final data = await _readAndDecryptJson(jsonPath);

    final db = await openDatabase(dbPath);

    await db.transaction((txn) async {
      if (data['messages'] != null) {
        final messages = data['messages'] as List;
        for (final msg in messages) {
          await txn.insert(
            'message',
            msg as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (data['contacts'] != null) {
        final contacts = data['contacts'] as List;
        for (final contact in contacts) {
          await txn.insert(
            'contact',
            contact as Map<String, dynamic>,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    await db.close();
  }

  /// 加密文件到新位置（用于数据库备份）
  Future<void> _encryptFile(
    String inputPath,
    String outputPath,
    String password,
  ) async {
    try {
      // 读取源文件
      final inputFile = File(inputPath);
      final bytes = await inputFile.readAsBytes();

      // 生成加密密钥和 IV
      final key = EncrypterService.sha256Hash(password).substring(0, 32);
      final iv = EncrypterService.sha256Hash(
        password + DateTimeHelper.millisecond().toString(),
      ).substring(0, 16);

      // 分块加密（避免内存问题）
      final chunkSize = 1024 * 1024; // 1MB chunks
      final encryptedChunks = <List<int>>[];

      for (int i = 0; i < bytes.length; i += chunkSize) {
        final end = (i + chunkSize < bytes.length)
            ? i + chunkSize
            : bytes.length;
        final chunk = bytes.sublist(i, end);
        final base64Chunk = base64.encode(chunk);

        // 使用 AES 加密
        final encrypted = EncrypterService.aesEncrypt(base64Chunk, key, iv);
        encryptedChunks.add(utf8.encode(encrypted));
      }

      // 写入加密文件（格式：IV + 加密数据）
      final outputFile = File(outputPath);
      final sink = outputFile.openWrite();

      // 写入魔术数字和 IV
      sink.write('IMBOY_ENC:');
      sink.write(iv);
      sink.write(':');

      // 写入加密数据
      for (final chunk in encryptedChunks) {
        sink.add(chunk);
        sink.write('\n');
      }

      await sink.flush();
      await sink.close();

      _logger.i('✅ 数据库文件已加密');
    } catch (e, stackTrace) {
      _logger.e('文件加密失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 加密 JSON 数据到文件
  Future<void> _encryptDataToJson(
    String json,
    String outputPath,
    String password,
  ) async {
    try {
      // 生成加密密钥和 IV
      final key = EncrypterService.sha256Hash(password).substring(0, 32);
      final iv = EncrypterService.sha256Hash(
        password + DateTimeHelper.millisecond().toString(),
      ).substring(0, 16);

      // AES 加密
      final encrypted = EncrypterService.aesEncrypt(json, key, iv);

      // 创建加密数据结构
      final encryptedData = {
        'format': 'encrypted',
        'version': '1.0',
        'iv': iv,
        'data': encrypted,
      };

      final encoder = JsonEncoder.withIndent('  ');
      await File(outputPath).writeAsString(encoder.convert(encryptedData));

      _logger.i('✅ JSON 备份已加密');
    } catch (e, stackTrace) {
      _logger.e('JSON 加密失败', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 读取并解密 JSON（自动检测加密）
  Future<Map<String, dynamic>> _readAndDecryptJson(String jsonPath) async {
    final json = await File(jsonPath).readAsString();
    final data = jsonDecode(json) as Map<String, dynamic>;

    // 检测是否为加密格式
    if (data['format'] == 'encrypted' && data['data'] != null) {
      _logger.i('🔓 检测到加密备份，需要密码解密');

      // 注意：这里需要用户提供密码，实际应用中应该从 UI 获取
      // 目前抛出异常，提示需要密码
      throw Exception('加密备份需要密码解密，请提供备份密码');
    }

    return data;
  }

  /// 收集数据
  Future<Map<String, dynamic>> _collectData(
    Database db,
    BackupConfig config,
  ) async {
    final data = <String, dynamic>{};

    // 获取当前数据库版本
    final versionResult = await db.rawQuery('PRAGMA user_version');
    final currentVersion = Sqflite.firstIntValue(versionResult) ?? 9;
    data['version'] = currentVersion;
    data['exportedAt'] = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    ).toIso8601String();

    if (config.includeMessages) {
      data['messages'] = await db.query('message');
    }

    if (config.includeContacts) {
      data['contacts'] = await db.query('contact');
    }

    if (config.includeGroups) {
      data['groups'] = await db.query('group');
      data['groupMembers'] = await db.query('group_member');
    }

    if (config.includeConversations) {
      data['conversations'] = await db.query('conversation');
    }

    return data;
  }

  /// 获取备份目录
  Future<Directory> _getBackupDirectory() async {
    if (_backupDir != null) return _backupDir!;

    final docDir = await getApplicationDocumentsDirectory();
    _backupDir = Directory(path.join(docDir.path, 'backups'));
    return _backupDir!;
  }

  /// 获取备份列表
  Future<List<Map<String, dynamic>>> listBackups() async {
    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) return [];

    final backups = <Map<String, dynamic>>[];

    await for (final entity in backupDir.list()) {
      if (entity is File) {
        final stat = await entity.stat();
        backups.add({
          'path': entity.path,
          'name': path.basename(entity.path),
          'size': stat.size,
          'modified': stat.modified,
        });
      }
    }

    backups.sort((a, b) => b['modified'].compareTo(a['modified']));
    return backups;
  }

  /// 删除备份
  Future<void> deleteBackup(String backupPath) async {
    await File(backupPath).delete();
  }

  /// 清理旧备份
  Future<int> cleanupOldBackups({int keepDays = 7}) async {
    final backups = await listBackups();
    int cleaned = 0;
    final cutoff = DateTime.fromMillisecondsSinceEpoch(
      DateTimeHelper.millisecond(),
    ).subtract(Duration(days: keepDays));

    for (final backup in backups) {
      if (backup['modified'].isBefore(cutoff)) {
        try {
          await deleteBackup(backup['path']);
          cleaned++;
        } catch (e) {
          _logger.w('Failed to delete backup: ${backup['path']}');
        }
      }
    }

    return cleaned;
  }
}
