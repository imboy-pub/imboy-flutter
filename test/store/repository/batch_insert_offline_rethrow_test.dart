/// 钉死 `batchInsertOfflineMessages` 的失败契约（A-24）。
///
/// 背景：该方法整体包在 `on Object catch (e) { iPrint(...); return null; }` 里。
/// 返回 null 与"这批本来就没有需要 ACK 的消息"在调用方看来完全一样
/// （`message_offline.dart`: `if (msgIds != null && msgIds.isNotEmpty)`），
/// 于是整批写入失败被读成"没什么要确认的"：不 ACK、不报错、拉取继续、
/// 游标照常推进。持久性失败（A-21 的 `msg_c2c.sender_did` 缺列就是实例）
/// 因此变成每次拉取都失败、每次只留一行 print 的静默循环。
///
/// 本测试只钉一条、也是本次改动的全部契约：
/// **写入失败时必须抛出，不得静默降级成 null。**
///
/// 失败注入方式：不初始化 SqliteService 直接调用 —— 底层 DB 不可用，
/// 是最贴近"整批写入失败"的真实形态，且无需伪造 schema。
/// 改动前该用例为 RED（返回 null），改动后为 GREEN（抛出）。
///
/// ⚠️ 判据「断网发 10 条，恢复后 100% 补投」属真机验收，不在本文件覆盖范围：
/// 那条要求设备断开数据网络但保持调试连接，**必须有线连接**。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

void main() {
  group('A-24 batchInsertOfflineMessages 失败传播', () {
    test('写入失败时抛出，不得吞成 null', () async {
      final repo = MessageRepo(tableName: MessageRepo.getTableName('C2C'));

      await expectLater(
        repo.batchInsertOfflineMessages([
          {
            'msg_id': 'a24_probe_1',
            'type': 'C2C',
            'msg_type': 'text',
            'from': '1',
            'to': '2',
            'payload': {'text': 'probe'},
            'created_at': 1750000000000,
          },
        ]),
        throwsA(anything),
        reason:
            '整批写入失败必须向上传播 —— 返回 null 会被调用方读成'
            '"没有需要 ACK 的消息"，与真正的空批次不可区分',
      );
    });

    test('空批次仍返回 null（不是失败，不得抛）', () async {
      final repo = MessageRepo(tableName: MessageRepo.getTableName('C2C'));

      // 守住"严格化没有波及正常路径"：空输入是合法的 no-op，
      // 它的 null 与失败的 null 从此语义分离 —— 前者留下，后者变成异常。
      expect(await repo.batchInsertOfflineMessages(const []), isNull);
    });
  });
}
