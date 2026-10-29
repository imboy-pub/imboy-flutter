/// 钉住 `handleGroupTransferS2C` dispatcher 与 `switchS2C` 分发契约
/// —— Q05/AC10。
///
/// 设计与 `group_member_role_s2c` 一致：函数注入替代真实 Repo / EventBus，
/// 分派契约穷尽分支而不依赖 sqflite / Flutter binding；另通过
/// `MessageS2CService.switchS2C` 直接驱动在线帧与离线拉取帧
/// （两路径共用同一入口，见 message.dart / message_offline.dart 的
/// switchS2C 调用），验证 action 表分发与缺 gid 防御。
///
/// 无 SQLite 环境下 GroupRepo/GroupMemberRepo 的写方法是安全 no-op
/// （SqliteService 在 db==null 时返回 0），因此集成分支只以
/// AppEventBus 广播作为「已分发到处理函数」的可观察 oracle。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/service/events/common_events.dart';
import 'package:imboy/service/group_transfer_s2c.dart';
import 'package:imboy/service/message_s2c.dart';

void main() {
  group('handleGroupTransferS2C — 分派契约', () {
    late List<(String, String)> ownerCalls;
    late List<(String, String, int)> roleCalls;
    late List<GroupTransferPayload> fireCalls;
    late List<String> logs;

    setUp(() {
      ownerCalls = [];
      roleCalls = [];
      fireCalls = [];
      logs = [];
    });

    Future<void> run(
      Map<String, dynamic> payload, {
      Future<void> Function(String, String)? applyOwnerUpdate,
      Future<void> Function(String, String, int)? applyRoleUpdate,
    }) {
      return handleGroupTransferS2C(
        payload: payload,
        applyOwnerUpdate:
            applyOwnerUpdate ??
            (gid, toOwnerUid) async => ownerCalls.add((gid, toOwnerUid)),
        applyRoleUpdate:
            applyRoleUpdate ??
            (gid, userId, role) async => roleCalls.add((gid, userId, role)),
        fireEvent: fireCalls.add,
        log: logs.add,
      );
    }

    test('合法 payload → owner 写一次 + 新旧主角色各写一次 + fireEvent', () async {
      await run({'gid': 10, 'from_owner_uid': 100, 'to_owner_uid': 200});

      expect(ownerCalls, [('10', '200')]);
      // 旧主降普通成员(1)、新主升群主(4)——镜像服务端 do_transfer 终态
      expect(roleCalls, [
        ('10', '100', groupTransferRoleMember),
        ('10', '200', groupTransferRoleOwner),
      ]);
      expect(fireCalls, hasLength(1));
      expect(fireCalls.first.gid, '10');
    });

    test('缺 gid → 全部回调都不调用，仅 log（防御）', () async {
      await run({'from_owner_uid': 100, 'to_owner_uid': 200});

      expect(ownerCalls, isEmpty);
      expect(roleCalls, isEmpty);
      expect(fireCalls, isEmpty);
      expect(logs.any((l) => l.contains('invalid_gid')), isTrue);
    });

    test('from/to 未带（0）→ 只跳过对应写，fireEvent 仍执行', () async {
      await run({'gid': 10});

      expect(ownerCalls, isEmpty, reason: 'toOwnerUid=0 跳过 owner 写');
      expect(roleCalls, isEmpty);
      expect(fireCalls, hasLength(1), reason: '广播不被字段缺失拖垮');
    });

    test('applyOwnerUpdate 抛异常 → 吞下 + log，后续角色写与 fireEvent 不受影响', () async {
      await run(
        {'gid': 10, 'from_owner_uid': 100, 'to_owner_uid': 200},
        applyOwnerUpdate: (_, _) async {
          throw StateError('db locked');
        },
      );

      expect(roleCalls, hasLength(2));
      expect(fireCalls, hasLength(1));
      expect(logs.any((l) => l.contains('owner_update_failed')), isTrue);
    });

    test('applyRoleUpdate 抛异常 → 吞下 + log，fireEvent 仍执行', () async {
      await run(
        {'gid': 10, 'from_owner_uid': 100, 'to_owner_uid': 200},
        applyRoleUpdate: (_, _, _) async {
          throw StateError('db locked');
        },
      );

      expect(ownerCalls, [('10', '200')]);
      expect(fireCalls, hasLength(1));
      expect(logs.any((l) => l.contains('role_update_failed')), isTrue);
    });
  });

  group('switchS2C — group_transfer action 分发（在线/离线同入口）', () {
    // 在线帧（message.dart）与离线拉取帧（message_offline.dart）都调用
    // 同一个 MessageS2CService.switchS2C；id 留空走去重 key 复合回退
    // （action_from_to_serverTs），以不同 server_ts 区分两帧。
    Map<String, dynamic> frame({required String serverTs, Object? gid}) => {
      'id': '',
      'type': 'S2C',
      'action': 'group_transfer',
      'from': '1001',
      'to': '2002',
      'payload': {'gid': ?gid, 'from_owner_uid': 1001, 'to_owner_uid': 2002},
      'server_ts': serverTs,
    };

    test('在线帧分发到处理函数并广播 owner 变更事件', () async {
      final editEvents = <GroupEditEvent>[];
      final roleEvents = <GroupMemberRoleEvent>[];
      final subEdit = AppEventBus.on<GroupEditEvent>().listen(editEvents.add);
      final subRole = AppEventBus.on<GroupMemberRoleEvent>().listen(
        roleEvents.add,
      );

      await MessageS2CService.switchS2C(frame(serverTs: '1001', gid: 77));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await subEdit.cancel();
      await subRole.cancel();

      expect(editEvents, hasLength(1));
      expect(editEvents.first.gid, '77');
      expect(editEvents.first.updates['owner_uid'], '2002');

      expect(roleEvents, hasLength(2));
      expect(roleEvents.map((e) => (e.userId, e.role)).toList(), [
        ('1001', groupTransferRoleMember),
        ('2002', groupTransferRoleOwner),
      ]);
    });

    test('离线拉取帧经同一入口同样分发（Q05：save 通知离线可补）', () async {
      final editEvents = <GroupEditEvent>[];
      final sub = AppEventBus.on<GroupEditEvent>().listen(editEvents.add);

      // 模拟 message_offline.dart 拉取后逐帧调用 switchS2C 的路径：
      // 不同 server_ts（不同帧）不会命中 S2C 去重层
      await MessageS2CService.switchS2C(frame(serverTs: '2002', gid: 88));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();

      expect(editEvents, hasLength(1));
      expect(editEvents.first.gid, '88');
      expect(editEvents.first.updates['owner_uid'], '2002');
    });

    test('payload 缺 gid → 不抛异常、不分发任何事件（防御）', () async {
      final editEvents = <GroupEditEvent>[];
      final roleEvents = <GroupMemberRoleEvent>[];
      final subEdit = AppEventBus.on<GroupEditEvent>().listen(editEvents.add);
      final subRole = AppEventBus.on<GroupMemberRoleEvent>().listen(
        roleEvents.add,
      );

      // switchS2C 自身有 on Object catch，异常会被吞掉并打日志——
      // 这里要求更强的契约：缺 gid 属于预期内防御分支，处理函数早退，
      // 不依赖外层吞异常，也不 fire 任何事件。
      await MessageS2CService.switchS2C(frame(serverTs: '3003'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await subEdit.cancel();
      await subRole.cancel();

      expect(editEvents, isEmpty);
      expect(roleEvents, isEmpty);
    });
  });
}
