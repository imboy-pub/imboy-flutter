#!/usr/bin/env dart

import 'dart:io';

/// 错误码生成器（C-20）
///
/// 用法：
///   dart scripts/generate_error_code.dart              # 生成/更新
///   dart scripts/generate_error_code.dart --check      # 只校验，不写文件（CI 用）
///   dart scripts/generate_error_code.dart --source=/path/to/error_code.hrl
///
/// 源文件查找顺序：`--source=` > 环境变量 `IMBOY_ERROR_CODE_HRL` >
/// 默认的跨仓相对路径 `../imboy/include/error_code.hrl`。
/// 独立 clone imboyapp（没有并排的 imboy 仓）时只有前两条可用 —— 这正是本脚本
/// 此前必然失败、进而从未被接进 CI 的原因。
void main(List<String> args) async {
  final checkOnly = args.contains('--check');
  stdout.writeln(checkOnly ? '校验错误码文件是否最新...\n' : '开始生成错误码文件...\n');

  final projectDir = Directory.current.path;
  final backendFile = File(_resolveSourcePath(args, projectDir));
  final frontendFile = File('$projectDir/lib/config/error_code.dart');

  // 检查后端文件是否存在
  if (!backendFile.existsSync()) {
    stdout.writeln('后端错误码文件不存在: ${backendFile.path}');
    stdout.writeln('独立 clone 时请显式指定源文件：');
    stdout.writeln('  dart scripts/generate_error_code.dart --source=<路径>');
    stdout.writeln('  或设置环境变量 IMBOY_ERROR_CODE_HRL=<路径>\n');
    exit(1);
  }

  // 读取后端文件
  String content;
  try {
    content = await backendFile.readAsString();
    stdout.writeln('已读取后端错误码文件: ${backendFile.path}');
  } catch (e) {
    stdout.writeln('读取后端文件失败: $e\n');
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
  final messageRegex = RegExp(r'(\d+)\s*=>\s*<<"([^"]*)"(?:/utf8)?');

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

  stdout.writeln('解析结果: ${errorCodes.length} 个错误码定义');
  stdout.writeln('解析结果: ${messages.length} 个错误消息\n');

  // 检查是否有新的错误码
  final existingFile = frontendFile;
  String existingContent = '';
  if (existingFile.existsSync()) {
    existingContent = await existingFile.readAsString();
    // 统计现有的错误码数量
    final existingCount = 'static const int'.allMatches(existingContent).length;
    stdout.writeln('现有文件: $existingCount 个常量\n');
  }

  // 生成 Dart 代码
  final buffer = StringBuffer();

  // 文件头
  //
  // ⚠️ 这里**不写生成时间戳**：带时间戳则每次运行产物都不同，
  // "跑生成器后 git diff 为空" 这条 CI 判据永远不可能满足（C-20）。
  // 用 `//` 而非 `///`：`ignore_for_file` 之后接文档注释会触发
  // dangling_library_doc_comments lint。
  buffer.writeln('// ignore_for_file: constant_identifier_names');
  buffer.writeln('// ⚠️ 此文件由脚本自动生成，请勿手动修改');
  buffer.writeln('//');
  buffer.writeln('// 生成命令: dart scripts/generate_error_code.dart');
  buffer.writeln('// 校验命令: dart scripts/generate_error_code.dart --check');
  buffer.writeln('// 源文件: imboy/include/error_code.hrl');
  buffer.writeln('//');
  buffer.writeln('// 错误码设计原则:');
  buffer.writeln('// - 0: 成功（API 响应成功标记）');
  buffer.writeln('// - 4xx: 客户端错误（参数、认证、资源等）');
  buffer.writeln('// - 5xx: 服务端错误（服务器问题）');
  buffer.writeln('// - 9xx: 业务特定错误（IM 业务专用）');
  buffer.writeln('// - 其余: 各子系统扩展码（E2EE / 支付 / 插件 …）');
  buffer.writeln();
  buffer.writeln('class ErrorCode {');

  // 分段输出。
  //
  // ⚠️ 最后一段是 **"其余全部"** 而不是又一个固定区间：原实现只生成
  // 4xx/5xx/9xx 三段，148 个定义里有 58 个（E2EE 5000+、支付、插件…）
  // 落在区间外被**静默丢弃** —— 前端 75 个常量对后端 148 个，差 73 个。
  // 兜底段 + 下面的数量断言让"新增一个区间就静默漏掉"从此不可能发生。
  //
  // "成功 (0)" 也走分段而不是硬编码 `static const int OK = 0;` ——
  // hrl 里本就有 `ERR_OK`，硬编码会与生成的 `OK` 撞成 duplicate_definition。
  final segments = <({String title, bool Function(int) match})>[
    (title: '成功 (0) 与通用错误 (1)', match: (c) => c < 400),
    (title: '4xx 客户端错误（参考 HTTP 4xx）', match: (c) => c >= 400 && c < 500),
    (title: '5xx 服务端错误（参考 HTTP 5xx）', match: (c) => c >= 500 && c < 600),
    (title: '9xx 业务特定错误（IM 业务专用）', match: (c) => c >= 900 && c < 1000),
    (title: '其余：各子系统扩展错误码', match: (_) => true),
  ];

  final remaining = errorCodes.values.toList()
    ..sort((a, b) => a.code.compareTo(b.code));
  var emittedNames = 0;

  for (final segment in segments) {
    final picked = remaining.where((e) => segment.match(e.code)).toList();
    if (picked.isEmpty) continue;
    remaining.removeWhere((e) => segment.match(e.code));

    buffer.writeln(
      '  // =====================================================================',
    );
    buffer.writeln('  // ${segment.title}');
    buffer.writeln(
      '  // =====================================================================',
    );
    buffer.writeln();

    _generateConstants(buffer, picked, errorCodes);
    emittedNames += picked.length;
  }

  // 完整性断言：每一个解析到的 define 都必须落进某一段。
  // 生成器"少生成一些"是最难发现的失败模式 —— 产物看起来完全正常，
  // 只有引用到缺失常量时才编译报错，而那可能是几个月后（本次即 7 个月）。
  if (emittedNames != errorCodes.length || remaining.isNotEmpty) {
    stdout.writeln(
      '生成不完整：解析到 ${errorCodes.length} 个定义，只输出 $emittedNames 个'
      '（漏掉 ${remaining.map((e) => '${e.name}=${e.code}').join(', ')}）\n',
    );
    exit(1);
  }

  // 错误消息映射
  buffer.writeln(
    '  // =====================================================================',
  );
  buffer.writeln('  // 错误消息映射');
  buffer.writeln(
    '  // =====================================================================',
  );
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
    stdout.writeln('错误码文件已是最新，无需更新\n');
    exit(0);
  }

  // --check：CI 门禁模式，只报告不写盘。
  // 判据"跑生成器后 git diff 为空"在 CI 里等价于本模式 exit 0。
  if (checkOnly) {
    stdout.writeln('❌ lib/config/error_code.dart 与后端 error_code.hrl 不同步。');
    stdout.writeln('   后端定义 ${errorCodes.length} 个，当前文件需要重新生成。');
    stdout.writeln('   本地执行：dart scripts/generate_error_code.dart 并提交产物\n');
    exit(1);
  }

  try {
    await frontendFile.writeAsString(newContent);
    stdout.writeln('已生成错误码文件: ${frontendFile.path}');
    stdout.writeln('文件大小: ${(newContent.length / 1024).toStringAsFixed(2)} KB');
    stdout.writeln('\n统计信息:');
    stdout.writeln('  - 总错误码数: ${errorCodes.length}');
    stdout.writeln('  - 错误消息数: ${messages.length}');
    stdout.writeln('  - 已生成常量: $emittedNames\n');
  } catch (e) {
    stdout.writeln('写入文件失败: $e\n');
    exit(1);
  }

  stdout.writeln('生成完成!\n');
}

/// 解析源文件路径：`--source=` > `IMBOY_ERROR_CODE_HRL` > 跨仓相对路径
String _resolveSourcePath(List<String> args, String projectDir) {
  final flag = args.where((a) => a.startsWith('--source=')).firstOrNull;
  if (flag != null) return flag.substring('--source='.length);

  final env = Platform.environment['IMBOY_ERROR_CODE_HRL'];
  if (env != null && env.isNotEmpty) return env;

  return '$projectDir/../imboy/include/error_code.hrl';
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
