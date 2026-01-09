#!/usr/bin/env dart
///
/// 错误码自动生成脚本
///
/// 功能：从后端 error_code.hrl 生成前端 Dart 错误码常量文件
///
/// 使用方法:
///   dart script/generate_error_code.dart
///

import 'dart:io';
import 'dart:convert';

void main(List<String> args) async {
  print('🔄 开始生成错误码文件...\n');

  // 获取项目根目录
  final projectDir = Directory.current.path;
  final backendFile = File('$projectDir/../imboy/include/error_code.hrl');
  final frontendFile = File('$projectDir/lib/config/error_code.dart');

  // 检查后端文件是否存在
  if (!backendFile.existsSync()) {
    print('❌ 后端错误码文件不存在: ${backendFile.path}');
    print('   请确保 imboy 项目在正确位置\n');
    exit(1);
  }

  // 读取后端文件
  String content;
  try {
    content = await backendFile.readAsString();
    print('✅ 已读取后端错误码文件: ${backendFile.path}');
  } catch (e) {
    print('❌ 读取后端文件失败: $e\n');
    exit(1);
  }

  // 解析错误码定义
  final errorCodes = <String, ErrorCodeDef>{};
  final messages = <int, String>{};

  // 正则表达式匹配 -define(ERR_XXX, NNN) 或 -define(ERR_XXX, NNN). % Comment
  final defineRegex = RegExp(
    r'-define\((ERR_\w+),\s*(\d+)\)(?:\.)?\s*(?:%\s*(.*))?',
  );

  // 匹配错误消息映射
  final messageRegex = RegExp(
    r'(\d+)\s*=>\s*<<"([^"]*)"(?:/utf8)?',
  );

  // 解析 define 定义
  for (final match in defineRegex.allMatches(content)) {
    final name = match.group(1)!;
    final code = int.parse(match.group(2)!);
    errorCodes[name] = ErrorCodeDef(name: name, code: code);
  }

  // 解析消息映射
  for (final match in messageRegex.allMatches(content)) {
    final code = int.parse(match.group(1)!);
    final msg = match.group(2)!;
    messages[code] = msg;
  }

  print('📊 解析结果: ${errorCodes.length} 个错误码定义');
  print('📝 解析结果: ${messages.length} 个错误消息\n');

  // 检查是否有新的错误码
  final existingFile = frontendFile;
  String existingContent = '';
  if (existingFile.existsSync()) {
    existingContent = await existingFile.readAsString();
    // 统计现有的错误码数量
    final existingCount = 'static const int'.allMatches(existingContent).length;
    print('📦 现有文件: $existingCount 个常量\n');
  }

  // 生成 Dart 代码
  final buffer = StringBuffer();

  // 文件头
  buffer.writeln('// ignore_for_file: constant_identifier_names');
  buffer.writeln('/// ⚠️ 此文件由脚本自动生成，请勿手动修改');
  buffer.writeln('///');
  buffer.writeln('/// 生成命令: dart script/generate_error_code.dart');
  buffer.writeln('/// 源文件: ../imboy/include/error_code.hrl');
  buffer.writeln('/// 生成时间: ${DateTime.now().toIso8601String()}');
  buffer.writeln('///');
  buffer.writeln('/// 错误码设计原则:');
  buffer.writeln('/// - 0: 成功（API 响应成功标记）');
  buffer.writeln('/// - 4xx: 客户端错误（参数、认证、资源等）');
  buffer.writeln('/// - 5xx: 服务端错误（服务器问题）');
  buffer.writeln('/// - 9xx: 业务特定错误（IM 业务专用）');
  buffer.writeln();
  buffer.writeln('class ErrorCode {');
  buffer.writeln('  // =====================================================================');
  buffer.writeln('  // 成功 (0)');
  buffer.writeln('  // =====================================================================');
  buffer.writeln();

  // 按类别分组
  final categories = {
    'OK': [0],
    '4xx 客户端错误': errorCodes.values
        .where((e) => e.code >= 400 && e.code < 500)
        .map((e) => e.code)
        .toSet()
        .toList()
      ..sort(),
    '5xx 服务端错误': errorCodes.values
        .where((e) => e.code >= 500 && e.code < 600)
        .map((e) => e.code)
        .toSet()
        .toList()
      ..sort(),
    '9xx 业务特定错误': errorCodes.values
        .where((e) => e.code >= 900 && e.code < 1000)
        .map((e) => e.code)
        .toSet()
        .toList()
      ..sort(),
  };

  // 生成常量定义
  buffer.writeln('  /// 成功');
  buffer.writeln('  static const int OK = 0;');
  buffer.writeln();

  // 4xx 客户端错误
  buffer.writeln('  // =====================================================================');
  buffer.writeln('  // 4xx 客户端错误（参考 HTTP 4xx）');
  buffer.writeln('  // =====================================================================');
  buffer.writeln();

  final codes4xx = errorCodes.values
      .where((e) => e.code >= 400 && e.code < 500)
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  _generateConstants(buffer, codes4xx, errorCodes);

  // 5xx 服务端错误
  buffer.writeln('  // =====================================================================');
  buffer.writeln('  // 5xx 服务端错误（参考 HTTP 5xx）');
  buffer.writeln('  // =====================================================================');
  buffer.writeln();

  final codes5xx = errorCodes.values
      .where((e) => e.code >= 500 && e.code < 600)
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  _generateConstants(buffer, codes5xx, errorCodes);

  // 9xx 业务特定错误
  buffer.writeln('  // =====================================================================');
  buffer.writeln('  // 9xx 业务特定错误（IM 业务专用）');
  buffer.writeln('  // =====================================================================');
  buffer.writeln();

  final codes9xx = errorCodes.values
      .where((e) => e.code >= 900 && e.code < 1000)
      .toList()
    ..sort((a, b) => a.code.compareTo(b.code));

  _generateConstants(buffer, codes9xx, errorCodes);

  // 错误消息映射
  buffer.writeln('  // =====================================================================');
  buffer.writeln('  // 错误消息映射');
  buffer.writeln('  // =====================================================================');
  buffer.writeln();
  buffer.writeln('  static const Map<int, String> _messageMap = {');

  final sortedCodes = messages.keys.toList()..sort();
  for (final code in sortedCodes) {
    final msg = messages[code]!;
    buffer.writeln("    $code: '${_escapeDartString(msg)}',");
  }

  buffer.writeln('  };');
  buffer.writeln();

  // 辅助方法
  buffer.writeln('  /// 获取错误码对应的默认消息');
  buffer.writeln('  static String getMessage(int code) {');
  buffer.writeln("    return _messageMap[code] ?? '未知错误';");
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// 判断是否为成功响应');
  buffer.writeln('  static bool isSuccess(int code) {');
  buffer.writeln('    return code == OK;');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// 判断是否为客户端错误 (4xx)');
  buffer.writeln('  static bool isClientError(int code) {');
  buffer.writeln('    return code >= 400 && code < 500;');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// 判断是否为服务端错误 (5xx)');
  buffer.writeln('  static bool isServerError(int code) {');
  buffer.writeln('    return code >= 500 && code < 600;');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// 判断是否为业务错误 (9xx)');
  buffer.writeln('  static bool isBusinessError(int code) {');
  buffer.writeln('    return code >= 900 && code < 1000;');
  buffer.writeln('  }');
  buffer.writeln();
  buffer.writeln('  /// 判断是否需要重新登录');
  buffer.writeln('  static bool shouldReLogin(int code) {');
  buffer.writeln('    return code == UNAUTHORIZED ||');
  buffer.writeln('        code == TOKEN_INVALID ||');
  buffer.writeln('        code == TOKEN_EXPIRED ||');
  buffer.writeln('        code == TOKEN_MISSING ||');
  buffer.writeln('        code == LOGIN_ELSEWHERE;');
  buffer.writeln('  }');
  buffer.writeln('}');
  buffer.writeln();

  // 写入文件
  final newContent = buffer.toString();

  // 检查是否有变化
  if (newContent.trim() == existingContent.trim()) {
    print('✅ 错误码文件已是最新，无需更新\n');
    exit(0);
  }

  try {
    await frontendFile.writeAsString(newContent);
    print('✅ 已生成错误码文件: ${frontendFile.path}');
    print('📄 文件大小: ${(newContent.length / 1024).toStringAsFixed(2)} KB');
    print('\n📊 统计信息:');
    print('   - 总错误码数: ${errorCodes.length}');
    print('   - 错误消息数: ${messages.length}');
    print('   - 4xx 错误: ${codes4xx.length}');
    print('   - 5xx 错误: ${codes5xx.length}');
    print('   - 9xx 错误: ${codes9xx.length}\n');
  } catch (e) {
    print('❌ 写入文件失败: $e\n');
    exit(1);
  }

  print('✅ 生成完成!\n');
}

/// 生成常量定义
void _generateConstants(
  StringBuffer buffer,
  List<ErrorCodeDef> codes,
  Map<String, ErrorCodeDef> allCodes,
) {
  // 按错误码分组
  final grouped = <int, List<String>>{};
  for (final code in codes) {
    if (!grouped.containsKey(code.code)) {
      grouped[code.code] = [];
    }
    grouped[code.code]!.add(code.name);
  }

  // 为每个错误码生成定义
  for (final entry in grouped.entries) {
    final code = entry.key;
    final names = entry.value;

    // 只为第一个名称添加注释
    final first = allCodes[names.first]!;
    final comment = _getCommentForCode(first.name, code);
    buffer.writeln('  /// $comment');

    // 所有别名共享同一个值
    for (final name in names) {
      final dartName = _toDartConstantName(name);
      buffer.writeln('  static const int $dartName = $code;');
    }
    buffer.writeln();
  }
}

/// 根据错误码名称获取注释
String _getCommentForCode(String name, int code) {
  final commentMap = {
    'ERR_BAD_REQUEST': '请求参数错误',
    'ERR_UNAUTHORIZED': '未认证',
    'ERR_TOKEN_MISSING': 'Token 缺失',
    'ERR_TOKEN_INVALID': 'Token 无效',
    'ERR_TOKEN_EXPIRED': 'Token 已过期',
    'ERR_PAYMENT_REQUIRED': '需要付费',
    'ERR_FORBIDDEN': '已认证但无权限',
    'ERR_ACCESS_DENIED': '拒绝访问',
    'ERR_NOT_FOUND': '资源不存在',
    'ERR_USER_NOT_FOUND': '用户不存在',
    'ERR_FRIEND_NOT_FOUND': '好友不存在',
    'ERR_GROUP_NOT_FOUND': '群组不存在',
    'ERR_MESSAGE_NOT_FOUND': '消息不存在',
    'ERR_TOO_MANY_REQUESTS': '请求过于频繁',
    'ERR_INTERNAL_SERVER_ERROR': '服务器内部错误',
    'ERR_SERVICE_UNAVAILABLE': '服务不可用',
    'ERR_PASSWORD_WRONG': '密码错误',
    'ERR_ACCOUNT_DISABLED': '账号已禁用',
    'ERR_ACCOUNT_NOT_EXIST': '账号不存在',
    'ERR_ACCOUNT_ALREADY_EXISTS': '账号已存在',
    'ERR_LOGIN_ELSEWHERE': '在其他设备登录',
    'ERR_NOT_FRIENDS': '不是好友',
    'ERR_NOT_GROUP_MEMBER': '非群组成员',
    'ERR_MSG_SEND_FAILED': '消息发送失败',
  };

  return commentMap[name] ?? '错误码 $code';
}

/// 将 Erlang 宏名转换为 Dart 常量名
/// 例如: ERR_INVALID_TOKEN -> INVALID_TOKEN
String _toDartConstantName(String erlangName) {
  return erlangName.replaceAll('ERR_', '');
}

/// 转义 Dart 字符串中的特殊字符
String _escapeDartString(String str) {
  return str
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n')
      .replaceAll('\r', r'\r')
      .replaceAll('\t', r'\t');
}

/// 错误码定义数据类
class ErrorCodeDef {
  final String name;
  final int code;

  ErrorCodeDef({required this.name, required this.code});
}
