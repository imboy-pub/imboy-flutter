/// 钉死好友申请链路的 fail-open 契约：落库失败必须被捕获，且不得静默。
///
/// 根因：`NewFriendRepo().save(...)` / `.update(...)` 曾以「不 await 的 Future」
/// 形式调用（new_friend_provider.dart:89、apply_friend_provider.dart:126、
/// contact_provider.dart:229）。Dart 里被丢弃的 Future 抛异常不会中断调用方，
/// 而是变成**未处理的异步错误**逃到 zone 里，UI 侧毫无反馈 —— 于是
/// 「退出再进申请就丢了、但用户全程没看到任何错误」。
///
/// 本文件钉两条：
///   1. 真实 repo 在底层 DB 不可用时**确实会抛** —— 证明调用方的 try/catch
///      不是死代码（失败注入方式沿用 batch_insert_offline_rethrow_test.dart：
///      不初始化 SqliteService 直接调用）。
///   2. 修复后的调用形态（await + try/catch + 用户可见反馈）：zone 里
///      **零**未处理异步错误，且**恰好一次**用户可见提示；
///      而修复前的形态（丢弃 Future）：错误逃逸到 zone，提示为零。
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/store/repository/new_friend_repo_sqlite.dart';

/// 一条形态完整的好友申请（字段对齐 NewFriendNotifier.receivedAddFriend 的
/// saveData），只是底层 DB 不可用，因而必然写入失败。
Map<String, dynamic> _applyRow() => <String, dynamic>{
  'uid': '1000000001',
  NewFriendRepo.from: '1000000002',
  NewFriendRepo.to: '1000000001',
  NewFriendRepo.nickname: '测试申请人',
  NewFriendRepo.avatar: '',
  NewFriendRepo.msg: '我是测试',
  NewFriendRepo.payload: '{}',
  NewFriendRepo.status: NewFriendStatus.waitingForValidation.index,
  NewFriendRepo.createdAt: 1750000000000,
};

void main() {
  group('好友申请落库失败契约', () {
    test('DB 不可用时 NewFriendRepo.save 必须抛出（调用方的 catch 不是死代码）', () async {
      await expectLater(
        NewFriendRepo().save(_applyRow()),
        throwsA(anything),
        reason: '落库失败必须向上传播，否则调用方无从判断成败',
      );
    });

    test('⚠️ 残留：DB 不可用时 NewFriendRepo.update 静默返回 0（不抛）', () async {
      // 实测发现的第二层 fail-open，位于更下面的 SqliteService.update
      // （lib/service/sqlite.dart:625 `if (db == null) return 0;`）：
      // 「DB 不可用」与「没有匹配到行」返回值完全相同，调用方无从区分。
      // 本用例把现状钉住 —— 一旦下层改成抛出，这里会变红，提醒把
      // new_friend_provider 里那段 try/catch 的语义一并复核。
      expect(
        await NewFriendRepo().update({
          'from': '1000000002',
          'to': '1000000001',
          'status': NewFriendStatus.added.index,
        }),
        0,
        reason: '当前实现下 update 不抛；调用方的 try/catch 仍覆盖约束冲突/超时等会抛的路径',
      );
    });

    test('修复后形态：await + try/catch → 零未处理异步错误 + 一次用户可见提示', () async {
      final zoneErrors = <Object>[];
      final userFeedback = <String>[];
      final done = Completer<void>();

      runZonedGuarded(() async {
        // 与 new_friend_provider.receivedAddFriend 修复后同构
        try {
          await NewFriendRepo().save(_applyRow());
        } catch (e) {
          userFeedback.add('保存失败，请重试'); // AppLoading.showError(...)
        }
        done.complete();
      }, (e, s) => zoneErrors.add(e));

      await done.future;
      await pumpEventQueue();

      expect(zoneErrors, isEmpty, reason: '异常必须被 catch 住，不得逃逸成未处理异步错误');
      expect(userFeedback, hasLength(1), reason: '不得静默：捕获后必须给用户可见反馈');
    });

    test('修复前形态（不 await）：错误逃逸到 zone 且用户零反馈 —— 回归即失败', () async {
      final zoneErrors = <Object>[];
      final userFeedback = <String>[];

      runZonedGuarded(() {
        // ignore: unawaited_futures
        NewFriendRepo().save(_applyRow()); // 旧写法：Future 被丢弃
      }, (e, s) => zoneErrors.add(e));

      await pumpEventQueue();

      expect(
        zoneErrors,
        isNotEmpty,
        reason: '这正是 BUG 机制：丢弃的 Future 抛异常 → 未处理异步错误，调用方毫不知情',
      );
      expect(userFeedback, isEmpty, reason: '旧写法下用户看不到任何东西');
    });
  });
}
