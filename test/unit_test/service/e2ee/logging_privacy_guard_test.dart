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
}
