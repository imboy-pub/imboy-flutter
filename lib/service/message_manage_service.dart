/// 消息管理服务
///
/// 负责消息的批量操作、搜索、统计、导出和自动清理
library;

import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';
import 'package:imboy/component/helper/func.dart';

/// 消息删除结果
class MessageDeleteResult {
  final int deletedCount;
  final String? error;

  MessageDeleteResult({
    required this.deletedCount,
    this.error,
  });

  bool get success => error == null;
}

/// 消息搜索结果
class MessageSearchResult {
  final List<Map<String, dynamic>> messages;
  final int totalCount;
  final int? nextPage;

  MessageSearchResult({
    required this.messages,
    required this.totalCount,
    this.nextPage,
  });
}

/// 消息统计信息
class MessageStatistics {
  final int totalMessages;
  final int totalConversations;
  final Map<String, int> messagesByType;
  final Map<String, int> messagesByConversation;
  final int storageBytes;
  final String? formattedStorage;

  MessageStatistics({
    required this.totalMessages,
    required this.totalConversations,
    required this.messagesByType,
    required this.messagesByConversation,
    required this.storageBytes,
    this.formattedStorage,
  });

  String get formattedStorageSize {
    return formattedStorage ?? formatBytes(storageBytes);
  }
}

/// 消息导出结果
class MessageExportResult {
  final bool success;
  final String? exportPath;
  final int? messageCount;
  final String? error;

  MessageExportResult({
    required this.success,
    this.exportPath,
    this.messageCount,
    this.error,
  });
}

/// 消息清理规则
class MessageCleanupRule {
  final String id;
  final String name;
  final CleanupRuleType type;
  final int retentionDays;
  final int? maxMessageCount;
  final List<String>? conversationIds;
  final List<String>? messageTypes;
  final bool enabled;

  MessageCleanupRule({
    required this.id,
    required this.name,
    required this.type,
    required this.retentionDays,
    this.maxMessageCount,
    this.conversationIds,
    this.messageTypes,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.name,
    'retention_days': retentionDays,
    'max_message_count': maxMessageCount,
    'conversation_ids': conversationIds,
    'message_types': messageTypes,
    'enabled': enabled,
  };

  factory MessageCleanupRule.fromJson(Map<String, dynamic> json) => MessageCleanupRule(
    id: json['id'] as String,
    name: json['name'] as String,
    type: CleanupRuleType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => CleanupRuleType.byTime,
    ),
    retentionDays: json['retention_days'] as int,
    maxMessageCount: json['max_message_count'] as int?,
    conversationIds: (json['conversation_ids'] as List<dynamic>?)?.cast<String>(),
    messageTypes: (json['message_types'] as List<dynamic>?)?.cast<String>(),
    enabled: json['enabled'] as bool? ?? true,
  );
}

/// 清理规则类型
enum CleanupRuleType {
  byTime,      // 按时间清理
  byCount,     // 按数量清理
  byCustom,    // 自定义清理
}

/// 消息导出格式
enum MessageExportFormat {
  json,
  txt,
  html,
}

/// 消息管理服务
class MessageManageService {
  static final Logger _logger = Logger();

  // 单例
  static final MessageManageService to = MessageManageService._privateConstructor();

  MessageManageService._privateConstructor();

  /// 批量删除指定会话的消息
  Future<MessageDeleteResult> deleteByConversation(
    String conversationUk3, {
    String? messageType,
  }) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageDeleteResult(
        deletedCount: 0,
        error: 'Database not available',
      );
    }

    try {
      final tableName = _determineTable(messageType);
      String where = '${MessageRepo.conversationUk3} = ?';
      List<dynamic> whereArgs = [conversationUk3];

      if (messageType != null) {
        where = '$where AND ${MessageRepo.type} = ?';
        whereArgs.add(messageType);
      }

      final count = await db.delete(
        tableName,
        where: where,
        whereArgs: whereArgs,
      );

      _logger.i('Deleted $count messages from conversation $conversationUk3');
      return MessageDeleteResult(deletedCount: count);
    } catch (e, stackTrace) {
      _logger.e('Failed to delete messages by conversation', error: e, stackTrace: stackTrace);
      return MessageDeleteResult(
        deletedCount: 0,
        error: e.toString(),
      );
    }
  }

  /// 批量删除指定时间范围的消息
  Future<MessageDeleteResult> deleteByTimeRange({
    required DateTime startDate,
    required DateTime endDate,
    String? conversationUk3,
    String? messageType,
  }) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageDeleteResult(
        deletedCount: 0,
        error: 'Database not available',
      );
    }

    try {
      int totalDeleted = 0;
      final tables = messageType != null
          ? [_determineTable(messageType)]
          : [MessageRepo.c2cTable, MessageRepo.c2gTable, MessageRepo.c2sTable];

      for (final table in tables) {
        String where = '${MessageRepo.createdAt} >= ? AND ${MessageRepo.createdAt} <= ?';
        List<dynamic> whereArgs = [
          startDate.millisecondsSinceEpoch ~/ 1000,
          endDate.millisecondsSinceEpoch ~/ 1000,
        ];

        if (conversationUk3 != null) {
          where = '$where AND ${MessageRepo.conversationUk3} = ?';
          whereArgs.add(conversationUk3);
        }

        if (messageType != null) {
          where = '$where AND ${MessageRepo.type} = ?';
          whereArgs.add(messageType);
        }

        final count = await db.delete(
          table,
          where: where,
          whereArgs: whereArgs,
        );
        totalDeleted += count;
      }

      _logger.i('Deleted $totalDeleted messages from time range');
      return MessageDeleteResult(deletedCount: totalDeleted);
    } catch (e, stackTrace) {
      _logger.e('Failed to delete messages by time range', error: e, stackTrace: stackTrace);
      return MessageDeleteResult(
        deletedCount: 0,
        error: e.toString(),
      );
    }
  }

  /// 批量删除指定ID的消息
  Future<MessageDeleteResult> deleteByIds(
    List<String> messageIds, {
    String? messageType,
  }) async {
    if (messageIds.isEmpty) {
      return MessageDeleteResult(deletedCount: 0);
    }

    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageDeleteResult(
        deletedCount: 0,
        error: 'Database not available',
      );
    }

    try {
      int totalDeleted = 0;
      final tables = messageType != null
          ? [_determineTable(messageType)]
          : [MessageRepo.c2cTable, MessageRepo.c2gTable, MessageRepo.c2sTable];

      final placeholders = messageIds.map((_) => '?').join(',');

      for (final table in tables) {
        final count = await db.delete(
          table,
          where: '${MessageRepo.id} IN ($placeholders)',
          whereArgs: messageIds,
        );
        totalDeleted += count;
      }

      _logger.i('Deleted $totalDeleted messages by IDs');
      return MessageDeleteResult(deletedCount: totalDeleted);
    } catch (e, stackTrace) {
      _logger.e('Failed to delete messages by IDs', error: e, stackTrace: stackTrace);
      return MessageDeleteResult(
        deletedCount: 0,
        error: e.toString(),
      );
    }
  }

  /// 搜索消息
  Future<MessageSearchResult> searchMessages({
    required String keyword,
    String? conversationUk3,
    String? messageType,
    int page = 1,
    int pageSize = 20,
  }) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageSearchResult(
        messages: [],
        totalCount: 0,
      );
    }

    try {
      final tables = messageType != null
          ? [_determineTable(messageType)]
          : [MessageRepo.c2cTable, MessageRepo.c2gTable, MessageRepo.c2sTable];

      List<Map<String, dynamic>> allResults = [];
      int totalCount = 0;

      for (final table in tables) {
        String where = "json_extract(${MessageRepo.payload}, '\$.text') LIKE ?";
        List<dynamic> whereArgs = ['%$keyword%'];

        if (conversationUk3 != null) {
          where = '$where AND ${MessageRepo.conversationUk3} = ?';
          whereArgs.add(conversationUk3);
        }

        if (messageType != null) {
          where = '$where AND ${MessageRepo.type} = ?';
          whereArgs.add(messageType);
        }

        // 计算总数
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE $where',
          whereArgs,
        );
        totalCount += Sqflite.firstIntValue(countResult) ?? 0;

        // 分页查询
        final offset = (page - 1) * pageSize;
        final results = await db.query(
          table,
          where: where,
          whereArgs: whereArgs,
          orderBy: '${MessageRepo.createdAt} DESC',
          limit: pageSize,
          offset: offset,
        );

        allResults.addAll(results);
      }

      // 按时间排序
      allResults.sort((a, b) {
        final aTime = a[MessageRepo.createdAt] as int;
        final bTime = b[MessageRepo.createdAt] as int;
        return bTime.compareTo(aTime);
      });

      // 应用分页
      final start = (page - 1) * pageSize;
      final end = start + pageSize;
      final pageResults = allResults.skip(start).take(pageSize).toList();

      final nextPage = (end < allResults.length) ? page + 1 : null;

      return MessageSearchResult(
        messages: pageResults,
        totalCount: totalCount,
        nextPage: nextPage,
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to search messages', error: e, stackTrace: stackTrace);
      return MessageSearchResult(
        messages: [],
        totalCount: 0,
      );
    }
  }

  /// 获取消息统计信息
  Future<MessageStatistics> getStatistics({
    String? conversationUk3,
    String? messageType,
  }) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageStatistics(
        totalMessages: 0,
        totalConversations: 0,
        messagesByType: {},
        messagesByConversation: {},
        storageBytes: 0,
      );
    }

    try {
      final tables = messageType != null
          ? [_determineTable(messageType)]
          : [MessageRepo.c2cTable, MessageRepo.c2gTable, MessageRepo.c2sTable];

      int totalMessages = 0;
      final messagesByType = <String, int>{};
      final messagesByConversation = <String, int>{};
      final conversationIds = <String>{};
      int storageBytes = 0;

      for (final table in tables) {
        String where = '1=1';
        List<dynamic> whereArgs = [];

        if (conversationUk3 != null) {
          where = '${MessageRepo.conversationUk3} = ?';
          whereArgs.add(conversationUk3);
        }

        if (messageType != null) {
          where = '$where AND ${MessageRepo.type} = ?';
          whereArgs.add(messageType);
        }

        // 消息总数
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE $where',
          whereArgs,
        );
        final count = Sqflite.firstIntValue(countResult) ?? 0;
        totalMessages += count;

        // 按类型统计
        final typeResults = await db.rawQuery(
          'SELECT ${MessageRepo.type}, COUNT(*) as count FROM $table WHERE $where GROUP BY ${MessageRepo.type}',
          whereArgs,
        );
        for (final row in typeResults) {
          final type = row[MessageRepo.type] as String;
          final typeCount = row['count'] as int;
          messagesByType[type] = (messagesByType[type] ?? 0) + typeCount;
        }

        // 按会话统计
        final convResults = await db.rawQuery(
          'SELECT ${MessageRepo.conversationUk3}, COUNT(*) as count FROM $table WHERE $where GROUP BY ${MessageRepo.conversationUk3}',
          whereArgs,
        );
        for (final row in convResults) {
          final convId = row[MessageRepo.conversationUk3] as String;
          final convCount = row['count'] as int;
          messagesByConversation[convId] = (messagesByConversation[convId] ?? 0) + convCount;
          conversationIds.add(convId);
        }

        // 估算存储空间（数据库页大小 * 页数）
        final pageResult = await db.rawQuery('PRAGMA page_count');
        final pageSizeResult = await db.rawQuery('PRAGMA page_size');
        final pageCount = Sqflite.firstIntValue(pageResult) ?? 0;
        final pageSize = Sqflite.firstIntValue(pageSizeResult) ?? 4096;
        storageBytes += pageCount * pageSize;
      }

      return MessageStatistics(
        totalMessages: totalMessages,
        totalConversations: conversationIds.length,
        messagesByType: messagesByType,
        messagesByConversation: messagesByConversation,
        storageBytes: storageBytes,
        formattedStorage: formatBytes(storageBytes),
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to get statistics', error: e, stackTrace: stackTrace);
      return MessageStatistics(
        totalMessages: 0,
        totalConversations: 0,
        messagesByType: {},
        messagesByConversation: {},
        storageBytes: 0,
      );
    }
  }

  /// 导出消息
  Future<MessageExportResult> exportMessages({
    String? conversationUk3,
    String? messageType,
    DateTime? startDate,
    DateTime? endDate,
    MessageExportFormat format = MessageExportFormat.json,
  }) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageExportResult(
        success: false,
        error: 'Database not available',
      );
    }

    try {
      final tables = messageType != null
          ? [_determineTable(messageType)]
          : [MessageRepo.c2cTable, MessageRepo.c2gTable, MessageRepo.c2sTable];

      List<Map<String, dynamic>> allMessages = [];

      for (final table in tables) {
        String where = '1=1';
        List<dynamic> whereArgs = [];

        if (conversationUk3 != null) {
          where = '${MessageRepo.conversationUk3} = ?';
          whereArgs.add(conversationUk3);
        }

        if (messageType != null) {
          where = '$where AND ${MessageRepo.type} = ?';
          whereArgs.add(messageType);
        }

        if (startDate != null) {
          where = '$where AND ${MessageRepo.createdAt} >= ?';
          whereArgs.add(startDate.millisecondsSinceEpoch ~/ 1000);
        }

        if (endDate != null) {
          where = '$where AND ${MessageRepo.createdAt} <= ?';
          whereArgs.add(endDate.millisecondsSinceEpoch ~/ 1000);
        }

        final results = await db.query(
          table,
          where: where,
          whereArgs: whereArgs,
          orderBy: '${MessageRepo.createdAt} ASC',
        );
        allMessages.addAll(results);
      }

      // 按时间排序
      allMessages.sort((a, b) {
        final aTime = a[MessageRepo.createdAt] as int;
        final bTime = b[MessageRepo.createdAt] as int;
        return aTime.compareTo(bTime);
      });

      // 生成导出文件
      final exportDir = await _getExportDirectory();
      await exportDir.create(recursive: true);

      final now = DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond());
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(now);
      final extension = _getFileExtension(format);
      final filename = 'messages_$timestamp$extension';
      final filePath = path.join(exportDir.path, filename);

      String content;
      switch (format) {
        case MessageExportFormat.json:
          final encoder = JsonEncoder.withIndent('  ');
          content = encoder.convert({
            'exported_at': now.toIso8601String(),
            'total_count': allMessages.length,
            'messages': allMessages,
          });
          break;
        case MessageExportFormat.txt:
          content = _formatAsText(allMessages);
          break;
        case MessageExportFormat.html:
          content = _formatAsHtml(allMessages);
          break;
      }

      await File(filePath).writeAsString(content);

      _logger.i('Exported ${allMessages.length} messages to $filePath');

      return MessageExportResult(
        success: true,
        exportPath: filePath,
        messageCount: allMessages.length,
      );
    } catch (e, stackTrace) {
      _logger.e('Failed to export messages', error: e, stackTrace: stackTrace);
      return MessageExportResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// 执行清理规则
  Future<MessageDeleteResult> executeCleanupRule(MessageCleanupRule rule) async {
    if (!rule.enabled) {
      return MessageDeleteResult(
        deletedCount: 0,
        error: 'Rule is disabled',
      );
    }

    try {
      switch (rule.type) {
        case CleanupRuleType.byTime:
          final cutoffDate = DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond()).subtract(Duration(days: rule.retentionDays));
          return await deleteByTimeRange(
            startDate: DateTime.fromMillisecondsSinceEpoch(0), // 从最早开始
            endDate: cutoffDate,
            conversationUk3: rule.conversationIds?.firstOrNull,
            messageType: rule.messageTypes?.firstOrNull,
          );

        case CleanupRuleType.byCount:
          if (rule.maxMessageCount == null) {
            return MessageDeleteResult(
              deletedCount: 0,
              error: 'maxMessageCount is required for byCount rule',
            );
          }
          return await _deleteByCount(
            maxCount: rule.maxMessageCount!,
            conversationUk3: rule.conversationIds?.firstOrNull,
            messageType: rule.messageTypes?.firstOrNull,
          );

        case CleanupRuleType.byCustom:
          return await _deleteByCustomRule(rule);
      }
    } catch (e, stackTrace) {
      _logger.e('Failed to execute cleanup rule', error: e, stackTrace: stackTrace);
      return MessageDeleteResult(
        deletedCount: 0,
        error: e.toString(),
      );
    }
  }

  /// 保存清理规则
  Future<void> saveCleanupRules(List<MessageCleanupRule> rules) async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = rules.map((r) => r.toJson()).toList();
    await prefs.setString('message_cleanup_rules', jsonEncode(rulesJson));
  }

  /// 加载清理规则
  Future<List<MessageCleanupRule>> loadCleanupRules() async {
    final prefs = await SharedPreferences.getInstance();
    final rulesJson = prefs.getString('message_cleanup_rules');
    if (rulesJson == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(rulesJson);
      return decoded.map((json) => MessageCleanupRule.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      _logger.w('Failed to load cleanup rules: $e');
      return [];
    }
  }

  /// 获取导出目录
  Future<Directory> _getExportDirectory() async {
    final docDir = await getApplicationDocumentsDirectory();
    return Directory(path.join(docDir.path, 'message_exports'));
  }

  /// 确定表名
  String _determineTable(String? messageType) {
    if (messageType == null) return MessageRepo.c2cTable;
    return MessageRepo.getTableName(messageType);
  }

  /// 获取文件扩展名
  String _getFileExtension(MessageExportFormat format) {
    switch (format) {
      case MessageExportFormat.json:
        return '.json';
      case MessageExportFormat.txt:
        return '.txt';
      case MessageExportFormat.html:
        return '.html';
    }
  }

  /// 格式化为文本
  String _formatAsText(List<Map<String, dynamic>> messages) {
    final buffer = StringBuffer();
    buffer.writeln('=== Message Export ===');
    buffer.writeln('Exported at: ${DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond()).toIso8601String()}');
    buffer.writeln('Total messages: ${messages.length}');
    buffer.writeln();

    for (final msg in messages) {
      final payloadStr = msg[MessageRepo.payload] as String?;
      String text = '';
      if (payloadStr != null) {
        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          text = payload['text']?.toString() ?? '';
        } catch (_) {}
      }

      final createdAt = msg[MessageRepo.createdAt] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

      buffer.writeln('[${date.toLocal()}] ${msg[MessageRepo.from]} -> ${msg[MessageRepo.to]}');
      buffer.writeln('Type: ${msg[MessageRepo.type]}');
      buffer.writeln('Text: $text');
      buffer.writeln('---');
    }

    return buffer.toString();
  }

  /// 格式化为HTML
  String _formatAsHtml(List<Map<String, dynamic>> messages) {
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('  <meta charset="UTF-8">');
    buffer.writeln('  <title>Message Export</title>');
    buffer.writeln('  <style>');
    buffer.writeln('    body { font-family: Arial, sans-serif; margin: 20px; }');
    buffer.writeln('    .header { background: #f0f0f0; padding: 10px; margin-bottom: 20px; }');
    buffer.writeln('    .message { border: 1px solid #ddd; margin: 10px 0; padding: 10px; }');
    buffer.writeln('    .message-header { font-weight: bold; color: #333; }');
    buffer.writeln('    .message-body { margin-top: 10px; color: #555; }');
    buffer.writeln('    .timestamp { color: #999; font-size: 0.9em; }');
    buffer.writeln('  </style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('  <div class="header">');
    buffer.writeln('    <h1>Message Export</h1>');
    buffer.writeln('    <p>Exported at: ${DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond()).toIso8601String()}</p>');
    buffer.writeln('    <p>Total messages: ${messages.length}</p>');
    buffer.writeln('  </div>');

    for (final msg in messages) {
      final payloadStr = msg[MessageRepo.payload] as String?;
      String text = '';
      if (payloadStr != null) {
        try {
          final payload = jsonDecode(payloadStr) as Map<String, dynamic>;
          text = payload['text']?.toString() ?? '';
        } catch (_) {}
      }

      final createdAt = msg[MessageRepo.createdAt] as int;
      final date = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);

      buffer.writeln('  <div class="message">');
      buffer.writeln('    <div class="message-header">');
      buffer.writeln('      ${msg[MessageRepo.from]} &rarr; ${msg[MessageRepo.to]}');
      buffer.writeln('      <span class="timestamp">[${date.toLocal()}]</span>');
      buffer.writeln('    </div>');
      buffer.writeln('    <div class="message-body">');
      buffer.writeln('      Type: ${msg[MessageRepo.type]}<br>');
      buffer.writeln('      Text: $text');
      buffer.writeln('    </div>');
      buffer.writeln('  </div>');
    }

    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  /// 按数量删除消息
  Future<MessageDeleteResult> _deleteByCount({
    required int maxCount,
    String? conversationUk3,
    String? messageType,
  }) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageDeleteResult(
        deletedCount: 0,
        error: 'Database not available',
      );
    }

    try {
      final tables = messageType != null
          ? [_determineTable(messageType)]
          : [MessageRepo.c2cTable, MessageRepo.c2gTable, MessageRepo.c2sTable];

      int totalDeleted = 0;

      for (final table in tables) {
        String where = '1=1';
        List<dynamic> whereArgs = [];

        if (conversationUk3 != null) {
          where = '${MessageRepo.conversationUk3} = ?';
          whereArgs.add(conversationUk3);
        }

        if (messageType != null) {
          where = '$where AND ${MessageRepo.type} = ?';
          whereArgs.add(messageType);
        }

        // 获取总消息数
        final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table WHERE $where',
          whereArgs,
        );
        final totalCount = Sqflite.firstIntValue(countResult) ?? 0;

        if (totalCount <= maxCount) continue;

        final deleteCount = totalCount - maxCount;

        // 删除最早的消息
        final messagesToDelete = await db.query(
          table,
          columns: [MessageRepo.id],
          where: where,
          whereArgs: whereArgs,
          orderBy: '${MessageRepo.createdAt} ASC',
          limit: deleteCount,
        );

        for (final msg in messagesToDelete) {
          final msgId = msg[MessageRepo.id] as String;
          final count = await db.delete(
            table,
            where: '${MessageRepo.id} = ?',
            whereArgs: [msgId],
          );
          totalDeleted += count;
        }
      }

      return MessageDeleteResult(deletedCount: totalDeleted);
    } catch (e, stackTrace) {
      _logger.e('Failed to delete by count', error: e, stackTrace: stackTrace);
      return MessageDeleteResult(
        deletedCount: 0,
        error: e.toString(),
      );
    }
  }

  /// 按自定义规则删除
  Future<MessageDeleteResult> _deleteByCustomRule(MessageCleanupRule rule) async {
    final db = await SqliteService.to.db;
    if (db == null) {
      return MessageDeleteResult(
        deletedCount: 0,
        error: 'Database not available',
      );
    }

    try {
      int totalDeleted = 0;
      final tables = rule.messageTypes?.map((t) => _determineTable(t)).toSet().toList()
          ?? [MessageRepo.c2cTable, MessageRepo.c2gTable, MessageRepo.c2sTable];

      for (final table in tables) {
        String where = '1=1';
        List<dynamic> whereArgs = [];

        if (rule.conversationIds != null && rule.conversationIds!.isNotEmpty) {
          final placeholders = rule.conversationIds!.map((_) => '?').join(',');
          where = '${MessageRepo.conversationUk3} IN ($placeholders)';
          whereArgs.addAll(rule.conversationIds!);
        }

        if (rule.messageTypes != null && rule.messageTypes!.isNotEmpty) {
          final typePlaceholders = rule.messageTypes!.map((_) => '?').join(',');
          where = '$where AND ${MessageRepo.type} IN ($typePlaceholders)';
          whereArgs.addAll(rule.messageTypes!);
        }

        final count = await db.delete(
          table,
          where: where,
          whereArgs: whereArgs,
        );
        totalDeleted += count;
      }

      return MessageDeleteResult(deletedCount: totalDeleted);
    } catch (e, stackTrace) {
      _logger.e('Failed to delete by custom rule', error: e, stackTrace: stackTrace);
      return MessageDeleteResult(
        deletedCount: 0,
        error: e.toString(),
      );
    }
  }
}
