/// DEF-SYN04-READSYNC-WEB-1：S2C 帧 17 位 TSID 数字必须精确转 string
/// （TSID 契约 / safeParseBigIntJson 语义）。
///
/// 根因链（runs/syn04-syn01resid-20261116/syn04-p2-r4b-triage.json）：
/// 1. 服务端 message_read_sync 帧顶层 `"to":124027430097913856` 为裸 JSON number
///    （rawwire3 实证）；2. S2C 解码路径此前用普通 jsonDecode（无 bigint 安全
///    解析）；3. web 上 dart jsonDecode 产 double，`toString()` 走 V8 最短往返
///    十进制 → '124027430097913860'；4. `MessageS2CService._requireReadOwner`
///    recipient != owner.uid → StateError('Read sync frame session changed')；
///    5. switchS2C 吞错（propagateErrors=false）→ markAsRead 永不执行 →
///    多端未读不收敛（live + 离线拉取两条腿同死）。
///
/// 修复（本测试锁定）：解码前经 rewriteChannelIds 对原始文本保真——
/// - 在线 WS：parseWebSocketMessage 对 type=='S2C' 帧走
///   ChannelResponseShape.s2cSocket（top-level from/to 保真）；
/// - 离线拉取：ChannelResponseShape.offline 的 s2c.list 行选择把
///   message_read_sync 纳入 from/to/msg_id/id 保真门。
///
/// 断言口径：解码产物 `to`/`from` 必须是 **String** 且逐位等于线上原始
/// 十进制（VM 端普通解码虽不失真，但 `is String` 在修复前必红——路由未改）；
/// 文本级断言直接锁存「引号保真」这一 web 精度安全的前提。
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/channel_id_response_decoder.dart';
import 'package:imboy/service/websocket_message_parser.dart';

void main() {
  // 线上实捕帧（syn04-p2-r4b-rawwire3.json）：to 为 17 位 TSID 裸数字。
  const liveReadSyncFrame =
      '{"action":"message_read_sync","e2ee":null,"from":0,'
      '"id":"s2c.6.gs.HHQu6p1R7s","msg_type":"",'
      '"payload":{"msg_id":"r4inja1449703550",'
      '"msg_ids":["dbpdn2wf5gl7p7z2trg1"],'
      '"peer":"124027431175849984","read_at":1794844021038},'
      '"server_ts":1794844021040,"to":124027430097913856,'
      '"type":"S2C","ver":2}';

  group('在线 WS S2C 解码路径（parseWebSocketMessage）', () {
    test(
      'message_read_sync 的 17 位 TSID to 精确转 string（safeParseBigIntJson 语义）',
      () {
        final decoded = parseWebSocketMessage(liveReadSyncFrame);

        // TSID 契约：64-bit id 一律 String 持有。
        expect(decoded['to'], isA<String>(), reason: 'to 必须是 string（契约）');
        expect(decoded['to'], '124027430097913856');
        // from 同为顶层 TSID 位点（读帧 from=0 语义不变，仅为 string 化）。
        expect(decoded['from'], '0');
        // 去重 key 消费点（buildS2CDedupKey → toString）得到保真值。
        expect('${decoded['from']}_${decoded['to']}', '0_124027430097913856');
      },
    );

    test('S2C 帧 payload 内容与非 id 字段保持标准 JSON 语义', () {
      final decoded = parseWebSocketMessage(liveReadSyncFrame);
      final payload = decoded['payload'] as Map<String, dynamic>;
      // peer 原本就是字符串；read_at/server_ts/ver 是计数/时间戳，不保真。
      expect(payload['peer'], '124027431175849984');
      expect(payload['read_at'], 1794844021038);
      expect(payload['msg_ids'], ['dbpdn2wf5gl7p7z2trg1']);
      expect(decoded['server_ts'], 1794844021040);
      expect(decoded['ver'], 2);
      expect(decoded['type'], 'S2C');
      expect(decoded['action'], 'message_read_sync');
    });

    test('重写层直接锁存「裸数字加引号」这一 web 精度安全前提', () {
      final rewritten = rewriteChannelIds(
        liveReadSyncFrame,
        ChannelResponseShape.s2cSocket,
      );
      expect(
        rewritten,
        contains('"to":"124027430097913856"'),
        reason:
            'to 必须在解码前于原始文本层加引号（web 解码器对裸 17 位'
            '数字先产 double，事后 toString 无法恢复原位）',
      );
      expect(rewritten, contains('"from":"0"'));
    });

    test('type 非 S2C 的帧不受该形状影响（不触碰无关解码点）', () {
      const c2cFrame =
          '{"type":"C2C","id":"m1","from":124027430097913856,'
          '"to":124027431175849984,"payload":{"x":1}}';
      final decoded = parseWebSocketMessage(c2cFrame);
      // C2C 走既有 groupSocket 形状（既有契约），此处仅断言路由不变：
      // from/to 仍按既有 groupSocket 语义处理（这里 top-level 不在选择内）。
      expect(decoded['type'], 'C2C');
      expect(decoded['payload'], {'x': 1});
    });
  });

  group('离线拉取 S2C 行（ChannelResponseShape.offline）', () {
    test('message_read_sync 行的 17 位 TSID from/to 精确转 string', () {
      const raw =
          '{"code":0,"payload":{"s2c":{"next_last_msg_at":1794844021040,'
          '"list":[$liveReadSyncFrame]},"c2c":{"list":[]}}}';
      final result = jsonDecode(
        rewriteChannelIds(raw, ChannelResponseShape.offline),
      ) as Map;
      final rows = ((result['payload'] as Map)['s2c'] as Map)['list'] as List;
      final row = Map<String, dynamic>.from(rows.first as Map);
      expect(row['action'], 'message_read_sync');
      expect(row['to'], '124027430097913856');
      expect(row['from'], '0');
      expect(row['id'], 's2c.6.gs.HHQu6p1R7s');
      // payload 内 peer 原本就是字符串，read_at 保持数字语义。
      expect((row['payload'] as Map)['read_at'], 1794844021038);
    });
  });
}
