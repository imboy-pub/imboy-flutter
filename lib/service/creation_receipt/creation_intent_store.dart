/// W04.d（channel-group-ux-v2.2 §6.4 C1）：创建意图本机持久化。
///
/// 新客户端在提交创建请求**之前**保存
/// `(服务器来源, 账号, 操作, scopeId, request_id, 规范载荷, client_intent_created_at)`；
/// 同键自动/人工重试不变；响应丢失/进程被杀/应用重启后仍能以同一
/// request_id 原载荷重放或 recover_only 只查（§6.4 恢复状态表）。
///
/// 存储按「服务器来源+账号+操作+scopeId」隔离（scopeId=工作区 id 或
/// 'personal'），换账号/换来源/换工作区互不可见。内容损坏时安全返回
/// null，不把坏数据回显到界面（沿用 org_group_rename_pending_store 先例）。
library;

import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:imboy/config/env.dart';

class CreationIntent {
  /// 客户端生成的意图键；同键自动/人工重试不变。
  final String requestId;

  /// 意图创建时刻（本地 wall-clock 毫秒）；24h 派发窗口的判定基准。
  final int createdAtMs;

  /// 规范化后的识别载荷（重放时原样携带；服务端再按同一规范形式算摘要）。
  final Map<String, dynamic> payload;

  const CreationIntent({
    required this.requestId,
    required this.createdAtMs,
    required this.payload,
  });

  Map<String, dynamic> toMap() => {
    'request_id': requestId,
    'created_at_ms': createdAtMs,
    'payload': payload,
  };

  static CreationIntent? fromMap(Map<String, dynamic> raw) {
    final requestId = raw['request_id'];
    final createdAtMs = raw['created_at_ms'];
    final payload = raw['payload'];
    if (requestId is! String ||
        requestId.isEmpty ||
        createdAtMs is! int ||
        payload is! Map) {
      return null;
    }
    return CreationIntent(
      requestId: requestId,
      createdAtMs: createdAtMs,
      payload: Map<String, dynamic>.from(payload),
    );
  }
}

/// 客户端生成意图键：时间戳+CSPRNG，仅要求客户端内唯一与不可预测性足够。
String generateCreationRequestId() {
  final rnd = Random.secure();
  final suffix = List.generate(
    8,
    (_) => rnd.nextInt(16).toRadixString(16),
  ).join();
  return 'cri_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$suffix';
}

String creationIntentStorageKey(
  String account,
  String operation,
  String scopeId,
) =>
    'creation_intent:'
    '${Env().apiBaseUrl.length}:'
    '${Env().apiBaseUrl}:$account:$operation:$scopeId';

Future<void> saveCreationIntent({
  required String account,
  required String operation,
  required String scopeId,
  required CreationIntent intent,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    creationIntentStorageKey(account, operation, scopeId),
    jsonEncode(intent.toMap()),
  );
}

/// 读取意图；键不存在、内容损坏或字段缺失时返回 null（安全缺省）。
Future<CreationIntent?> loadCreationIntent({
  required String account,
  required String operation,
  required String scopeId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(
    creationIntentStorageKey(account, operation, scopeId),
  );
  if (raw == null) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return null;
    return CreationIntent.fromMap(decoded);
  } on Object {
    return null;
  }
}

/// 清除意图。仅在两类事实下调用：受理成功（accepted/replayed 已确认），
/// 或服务端给出可证明终止的事实（create_recovery_expired /
/// create_resource_unavailable）。超时、断连、create_not_accepted、
/// 冲突等未知/非终态一律保留意图（§6.4：不提供换键恢复）。
Future<void> clearCreationIntent({
  required String account,
  required String operation,
  required String scopeId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(creationIntentStorageKey(account, operation, scopeId));
}
