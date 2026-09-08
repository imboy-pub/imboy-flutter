import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('消息链路日志不得记录原始帧、明文 payload 或完整会话对象', () {
    const forbiddenByFile = <String, List<String>>{
      'lib/service/websocket.dart': [
        'debug_log_websocket_full',
        r'原始帧: $message',
        r'): $message ;',
        r': $e',
        r'$e\n$s',
      ],
      'lib/store/repository/conversation_repo_sqlite.dart': [
        r'ConversationRepo_updateByPeerId $id, ${data.toString()}',
        r'ConversationRepo_save ${obj.toJson().toString()}',
      ],
      'lib/store/repository/message_repo_sqlite.dart': [
        r'${msgData.toString()}',
        r'${conv.toJson()}',
        r'subtitle=$subtitle',
        r'searchLeading_tag kwd $kwd',
      ],
      'lib/modules/messaging/infrastructure/message_model_mapper.dart': [
        r'payload=$payload',
        r'error=$e',
        "'_e2ee_error'",
      ],
      'lib/service/message.dart': [
        r"peer: ${peerInfo['title']}",
        r'error=$e',
        r'堆栈: $stack',
        r'接收标记: $receivingMsgKey',
      ],
      'lib/service/e2ee_service.dart': [r'${e.runtimeType}: $e'],
      'lib/service/message_s2c.dart': [
        r'${oldMsg.toJson()}',
        r'忽略: $payload',
        r'nickname: $nickname',
        r'完整 payload',
        r'payload=$payload',
      ],
      'lib/page/conversation/conversation_provider.dart': [
        r'computedTitle $computedTitle',
        r'$e; $s',
        r'$e, $s',
      ],
      'lib/service/message_offline.dart': [
        r'拉取离线消息异常: $e',
        r'处理 $type 离线消息失败: $e',
        r'发送离线消息确认异常: $e $s',
      ],
      // Finding 014 重开轮：E2EE 三个 service 的日志/toast 边界
      'lib/service/olm_session_service.dart': [
        r"regenerating', e, s)",
        r"', e, s)",
        r': $e',
      ],
      'lib/service/group_session_service.dart': [
        r': $e',
        r"', e)",
        r'olm_wrap_failed: $e',
      ],
      'lib/page/chat/chat/services/chat_network_service.dart': [
        r'error=$e',
        r'加密失败: $e',
        r'错误: $e',
        r'stackTrace: $stack',
        r'e, stackTrace,',
        r'（$snippet）',
      ],
    };

    for (final entry in forbiddenByFile.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final fragment in entry.value) {
        expect(
          source,
          isNot(contains(fragment)),
          reason: '${entry.key} 重新引入了敏感日志: $fragment',
        );
      }
    }
  });

  test('E2EE 服务异常日志保留稳定标识（异常 runtimeType）用于诊断', () {
    // Finding 014 允许的诊断形态：只记 e.runtimeType + 固定上下文标签，
    // 不得回退为完整异常对象/stackTrace/库错误原文。
    const filesWithRuntimeTypeGuard = <String>[
      'lib/service/olm_session_service.dart',
      'lib/service/group_session_service.dart',
      'lib/page/chat/chat/services/chat_network_service.dart',
    ];
    for (final path in filesWithRuntimeTypeGuard) {
      final source = File(path).readAsStringSync();
      expect(
        source,
        contains('runtimeType'),
        reason: '$path 丢失了异常类型标识（errType=runtimeType 形态）',
      );
    }
  });
}
