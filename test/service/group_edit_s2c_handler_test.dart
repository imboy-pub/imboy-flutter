/// 钉住 `handleGroupEditS2C` dispatcher 的副作用分派契约 —— slice-3 RED-11。
///
/// 设计目的：将「解析 payload → 决定是否更新 Repo / 是否广播事件」的
/// 编排逻辑从 `message_s2c.dart` 抽出，用函数注入替代真实 `GroupRepo`
/// 与 `AppEventBus`，便于在无 sqflite / 无 Flutter binding 的测试环境
/// 里穷尽分支。
///
/// 契约：
///   1. 合法 payload → 依次调用 `applyUpdate(gid, updates)` 与
///      `fireEvent(gid, updates)`
///   2. `updates` 为空（仅含 gid）→ 跳过 `applyUpdate`（避免无谓写库），
///      仍需 `fireEvent`（UI/监听方可能仍关心「群被编辑」信号）
///   3. 非法 payload（`GroupEditParseError`）→ 两个回调都不调用
///   4. `applyUpdate` 抛异常不应影响 `fireEvent` 被调用（吞异常 + log），
///      保证广播端不被本地写失败拖垮
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/group_edit_s2c.dart';

void main() {
  group('handleGroupEditS2C — 分派契约', () {
    late List<(int, Map<String, dynamic>)> applyCalls;
    late List<(int, Map<String, dynamic>)> fireCalls;
    late List<String> logs;

    setUp(() {
      applyCalls = [];
      fireCalls = [];
      logs = [];
    });

    Future<void> run(
      Map<String, dynamic> payload, {
      Future<void> Function(int, Map<String, dynamic>)? applyUpdate,
      void Function(int, Map<String, dynamic>)? fireEvent,
    }) {
      return handleGroupEditS2C(
        payload: payload,
        applyUpdate: applyUpdate ??
            (gid, updates) async => applyCalls.add((gid, updates)),
        fireEvent:
            fireEvent ?? (gid, updates) => fireCalls.add((gid, updates)),
        log: logs.add,
      );
    }

    test('合法 payload → 先 applyUpdate 再 fireEvent', () async {
      await run({'gid': 1, 'title': 't', 'avatar': 'a.png'});

      expect(applyCalls, hasLength(1));
      expect(applyCalls.first.$1, 1);
      expect(applyCalls.first.$2, {'title': 't', 'avatar': 'a.png'});

      expect(fireCalls, hasLength(1));
      expect(fireCalls.first.$1, 1);
      expect(fireCalls.first.$2, {'title': 't', 'avatar': 'a.png'});
    });

    test('仅含 gid 的 payload → 跳过 applyUpdate，仍 fireEvent', () async {
      await run({'gid': 7});

      expect(applyCalls, isEmpty,
          reason: '空 updates 不应触发 GroupRepo.update（避免无谓写库）');
      expect(fireCalls, hasLength(1));
      expect(fireCalls.first.$1, 7);
      expect(fireCalls.first.$2, isEmpty);
    });

    test('非法 payload（gid<=0）→ 两个回调都不调用', () async {
      await run({'gid': 0, 'title': 'x'});

      expect(applyCalls, isEmpty);
      expect(fireCalls, isEmpty);
      expect(
        logs.any((l) => l.contains('invalid_gid')),
        isTrue,
        reason: '应记录解析失败原因',
      );
    });

    test('非法 payload（缺 gid）→ 两个回调都不调用', () async {
      await run({'title': 'oops'});
      expect(applyCalls, isEmpty);
      expect(fireCalls, isEmpty);
    });

    test('applyUpdate 抛异常时 → fireEvent 仍被调用（吞异常 + log）', () async {
      await run(
        {'gid': 2, 'title': 'x'},
        applyUpdate: (gid, updates) async {
          throw StateError('db locked');
        },
      );

      expect(applyCalls, isEmpty, reason: '被注入的失败回调不会追加调用记录');
      expect(fireCalls, hasLength(1), reason: '广播不应被本地写失败拖垮');
      expect(
        logs.any((l) => l.contains('apply_failed')),
        isTrue,
        reason: '应记录 apply 阶段的失败原因',
      );
    });
  });
}
