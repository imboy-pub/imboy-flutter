import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('消息链路日志不得记录原始帧、明文 payload 或完整会话对象', () {
    const forbiddenByFile = <String, List<String>>{
      'lib/service/payment_launcher.dart': [
        r'error: $e',
        r"launch failed', e, s)",
      ],
      'lib/component/extension/device_ext.dart': [
        r'DeviceExt/detail Web: $deviceId',
        r'DeviceExt/detail ${data.id}, ${data.toString()}',
      ],
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
        r'E2EE 解密成功，id=$id',
        r'E2EE 解密失败，id=$id',
        r'v3 解密成功，id=$id',
        r'v3 解密失败，id=$id',
        r"reason=${v3Result['_e2ee_reason']}",
        "'_e2ee_error'",
      ],
      'lib/service/message.dart': [
        r"peer: ${peerInfo['title']}",
        r'error=$e',
        r"AppLogger.error('消息后台处理失败 msgId=$msgId', e, s)",
        "'error_message': error.toString()",
        r'堆栈: $stack',
        r'接收标记: $receivingMsgKey',
      ],
      'lib/service/e2ee/e2ee_bootstrap.dart': [r'failed: $e'],
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
        'error: e,',
        r"error: '$e'",
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

    // Extracted files retain all privacy restrictions of their original library.
    const extractedSourcesByFile = <String, List<String>>{
      'lib/service/message.dart': ['lib/service/message_e2ee.dart'],
      'lib/service/e2ee_service.dart': [
        'lib/service/e2ee/decrypt_failure_metrics.dart',
      ],
      'lib/service/olm_session_service.dart': [
        'lib/service/e2ee/olm_exceptions.dart',
      ],
    };
    for (final entry in forbiddenByFile.entries) {
      for (final path in [entry.key, ...?extractedSourcesByFile[entry.key]]) {
        final source = File(path).readAsStringSync();
        for (final fragment in entry.value) {
          expect(
            source,
            isNot(contains(fragment)),
            reason: '$path 重新引入了敏感日志: $fragment',
          );
        }
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

  test('E2EE 写集源文件日志不得插值密钥材料或明文（S-01:LOCAL:01）', () {
    // S-01 写集的 4 个协议/密钥生命周期源文件：任何日志调用不得插值
    // 密钥材料（pickle / exported key / wrapped key / 私钥）或消息明文。
    // 当前基线：仅两条 iPrint（runtimeType + 固定串），本测试锁定该底线。
    const e2eeKeyMaterialSources = <String>[
      'lib/service/e2ee/olm_protocol.dart',
      'lib/service/e2ee/megolm_protocol.dart',
      'lib/service/e2ee/megolm_backup_section.dart',
      'lib/service/olm_session_cleanup.dart',
    ];
    final logCallPattern = RegExp(
      r'iPrint\s*\(|AppLogger\s*\.\s*[A-Za-z]+\s*\(|debugPrint\s*\(|\bprint\s*\(',
    );
    final keyOrPlaintextInterpolation = RegExp(
      r'\$\{?\s*[A-Za-z_][A-Za-z0-9_\.]*'
      r'(?:pickle|Pickle|exportedKey|exported_key|plaintext|Plaintext|'
      r'secret|Secret|privateKey|private_key|sessionKey|aesKey|'
      r'wrapKey|wrappedKey)\b',
    );
    for (final path in e2eeKeyMaterialSources) {
      final source = File(path).readAsStringSync();
      final calls = logCallPattern.allMatches(source).toList();
      for (final call in calls) {
        final windowEnd = call.start + 400 < source.length
            ? call.start + 400
            : source.length;
        final window = source.substring(call.start, windowEnd);
        expect(
          keyOrPlaintextInterpolation.hasMatch(window),
          isFalse,
          reason:
              '$path 的日志调用插值了密钥材料/明文（S-01:LOCAL:01）: '
              '${window.split('\n').first}',
        );
      }
    }
  });

  test('RTC 信令 TLS 不冒称媒体 E2EE（S-01:LOCAL:02）', () {
    // RTC 媒体经 LiveKit SFU 中转（LK-APP-01），信令走 WSS(TLS)。
    // TLS 只保护信令传输通道，不等于媒体端到端加密。通话面不得：
    // 1) 宣称媒体端到端加密；2) 给信令/通话记录打 e2ee 套件标记冒充
    //    E2EE 消息。RTC 相关源码当前无任何 E2EE 表述，本测试锁定该性质。
    const requiredRtcAnchors = <String>[
      'lib/service/message_webrtc.dart',
      'lib/component/webrtc/func.dart',
      'lib/page/chat/p2p_call_screen/p2p_call_screen_provider.dart',
    ];
    for (final anchor in requiredRtcAnchors) {
      expect(
        File(anchor).existsSync(),
        isTrue,
        reason: 'RTC 核心文件缺失: $anchor（模块迁移时请同步更新本守护清单）',
      );
    }
    final rtcDartFiles = <String>{...requiredRtcAnchors};
    for (final dir in [
      'lib/page/chat/p2p_call_screen',
      'lib/page/chat/rtc_room',
    ]) {
      final directory = Directory(dir);
      if (!directory.existsSync()) continue;
      rtcDartFiles.addAll(
        directory
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where((p) => p.endsWith('.dart') && !p.endsWith('.g.dart')),
      );
    }
    final e2eeClaimPattern = RegExp(
      '端到端加密|E2EE\\s*加密|e2ee_suite|end-to-end\\s+encrypt|media\\s+e2ee',
      caseSensitive: false,
    );
    for (final path in rtcDartFiles) {
      final source = File(path).readAsStringSync();
      expect(
        e2eeClaimPattern.hasMatch(source),
        isFalse,
        reason: '$path 把 TLS 信令/SFU 媒体冒称为媒体 E2EE（S-01:LOCAL:02）',
      );
    }

    // 本地通话记录 payload 只承载通话状态字段，不得携带 e2ee 加密元数据
    // 冒充加密消息（对端与服务器看到的是明文状态结构）。
    final webrtc = File('lib/service/message_webrtc.dart').readAsStringSync();
    const payloadOpening = 'payload: <String, dynamic>{';
    final literalAnchor = webrtc.indexOf(payloadOpening);
    expect(literalAnchor, greaterThan(0), reason: 'addLocalMsg payload 锚点漂移');
    final keys = _rtcTopLevelMapKeys(
      webrtc,
      literalAnchor + 'payload: <String, dynamic>'.length,
    );
    expect(keys, {
      'peer_id',
      'msg_type',
      'media',
      'start_at',
      'end_at',
      'state',
    });
  });
}

/// 从 [source] 中位置 [openBraceIndex]（指向 `{`）起做花括号配对，
/// 收集顶层（depth==1）的 `'key':` 形式键名。
Set<String> _rtcTopLevelMapKeys(String source, int openBraceIndex) {
  var depth = 0;
  var i = openBraceIndex;
  var inString = false;
  var stringQuote = '';
  var stringStart = -1;
  final keys = <String>{};
  while (i < source.length) {
    final c = source[i];
    if (inString) {
      if (c == r'\') {
        i += 2;
        continue;
      }
      if (c == stringQuote) {
        inString = false;
        if (depth == 1) {
          final content = source.substring(stringStart + 1, i);
          final tailEnd = i + 6 < source.length ? i + 6 : source.length;
          final tail = source.substring(i + 1, tailEnd);
          if (RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(content) &&
              RegExp(r'^\s*:').hasMatch(tail)) {
            keys.add(content);
          }
        }
      }
      i++;
      continue;
    }
    if (c == "'" || c == '"') {
      inString = true;
      stringQuote = c;
      stringStart = i;
      i++;
      continue;
    }
    if (c == '{') depth++;
    if (c == '}') {
      depth--;
      if (depth == 0) break;
    }
    i++;
  }
  return keys;
}
