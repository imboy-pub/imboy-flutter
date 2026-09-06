import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/component/http/http_client.dart';

/// 举报 API
class ReportApi extends HttpClient {
  /// 测试注入点：非 null 时 `ReportApi()` 返回该实例（生产恒 null，
  /// 与 service 层 instanceForTest 同一惯例；举报入口无单例，故走工厂）。
  @visibleForTesting
  static ReportApi? debugInstanceForTest;

  factory ReportApi() => debugInstanceForTest ?? ReportApi.base();

  /// 常规实例构造（供 factory 与测试子类 super 调用）。
  ReportApi.base();

  /// 提交投诉举报（对象举报：user/group/channel/moment）
  /// [targetType] 类型: 'group'|'user'|'channel'|'moment'
  /// [targetId] 目标ID（群ID/用户ID等）
  /// [reason] 原因: 'spam'|'harassment'|'inappropriate'|'other'
  /// [description] 补充描述（可选）
  /// 返回 (ok, 服务端消息)：失败时 msg 是后端可读原因（如「您已举报过该对象」），
  /// 供调用方透出——此前只返回 bool，真实原因被「投诉失败，请稍后再试」掩盖。
  Future<(bool, String)> create({
    required String targetType,
    required String targetId,
    required String reason,
    String description = '',
  }) async {
    final resp = await post(
      API.reportCreate,
      data: {
        'target_type': targetType,
        'target_id': targetId,
        'reason': reason,
        'description': description,
      },
    );
    return (resp.ok, resp.msg);
  }

  /// 失败提示选择：优先透出后端可读消息，网络层/解析层噪音回退通用文案。
  static String friendlyError(String serverMsg, String fallback) {
    const noise = {'', 'unknown error', 'error', 'success'};
    return noise.contains(serverMsg.toLowerCase()) ? fallback : serverMsg;
  }

  /// R-01 消息一等举报：举报真实 UGC 消息对象（C2C/C2G/频道消息），
  /// 不再把消息 ID 写进 description 伪装成 user 举报。
  ///
  /// [chatType] 消息表面: 'c2c'|'c2g'|'channel'
  /// [targetId] 服务端消息行 ID（bigint）
  /// [scopeId] c2c=对话对端 uid；c2g=群 ID；channel=频道 ID
  /// [excerpt] 举报人明确同意提交的最小明文摘录；传空串表示不提交内容
  ///（E2EE 消息必须经用户明确同意后才传入非空 excerpt）
  /// [consent] E2EE 消息提交明文证据的明确同意标记
  /// [clientMsgId] 客户端消息 ID
  /// 返回 (ok, 服务端消息)，语义同 [create]。
  Future<(bool, String)> createMessage({
    required String chatType,
    required String targetId,
    required String scopeId,
    required String reason,
    String excerpt = '',
    bool consent = false,
    String clientMsgId = '',
    String msgType = '',
    int sentAt = 0,
  }) async {
    final evidence = <String, dynamic>{
      if (excerpt.isNotEmpty) 'content_excerpt': excerpt,
      // 摘录哈希无论是否提交明文都随工单携带（最小完整性锚点）
      if (excerpt.isNotEmpty) 'content_hash': _sha256Hex(excerpt),
      if (clientMsgId.isNotEmpty) 'client_msg_id': clientMsgId,
      if (msgType.isNotEmpty) 'msg_type': msgType,
      if (sentAt > 0) 'sent_at': sentAt,
      if (consent) 'e2ee_consent': true,
    };
    final resp = await post(
      API.reportCreate,
      data: {
        'target_type': 'message',
        'target_id': targetId,
        'chat_type': chatType,
        'scope_id': scopeId,
        'reason': reason,
        'evidence': evidence,
      },
    );
    return (resp.ok, resp.msg);
  }

  static String _sha256Hex(String input) {
    return crypto.sha256.convert(utf8.encode(input)).toString();
  }
}
