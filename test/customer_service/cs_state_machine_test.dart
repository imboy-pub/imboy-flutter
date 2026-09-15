/// APP-A04 — 客服链路状态单测
///
/// 覆盖（amendment §3 / plan §5.2）：
/// - 坐席会话状态机：queue→claim→active→transfer/close/rating 全分支；
/// - suspend 拒绝分支：被 suspend 后一切前进事件被拒绝且状态不变；
/// - offboarding case 状态机：draft→frozen→transferring→verifying→
///   completed / failed。
///
/// 状态机为纯 Dart（零 Flutter 依赖），时间/ID 显式注入。
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/modules/customer_service/public.dart';

void main() {
  group('APP-A04 坐席会话状态机（CsSessionMachine）', () {
    test('主干：queue→claim(active)→close→rating', () {
      final cs = CsSessionMachine(sessionId: 's1');

      expect(cs.status, CsSessionStatus.queued);
      expect(cs.claim(), isTrue);
      expect(cs.status, CsSessionStatus.active);

      expect(cs.close(), isTrue);
      expect(cs.status, CsSessionStatus.closed);

      expect(cs.rate(score: 5), isTrue);
      expect(cs.status, CsSessionStatus.rated);
    });

    test('transfer：active→transferring，accept 后回 active', () {
      final cs = CsSessionMachine(sessionId: 's2')..claim();

      expect(cs.transfer(toIdentityId: '7266418340025468931'), isTrue);
      expect(cs.status, CsSessionStatus.transferring);

      expect(cs.transferAccepted(), isTrue);
      expect(cs.status, CsSessionStatus.active);
    });

    test('transfer 后可直接 close（转接中断开）', () {
      final cs = CsSessionMachine(sessionId: 's3')
        ..claim()
        ..transfer(toIdentityId: 'x');

      expect(cs.close(), isTrue);
      expect(cs.status, CsSessionStatus.closed);
    });

    test('非法转移：非 active 不可 transfer/close/rate；closed 不可重开', () {
      final cs = CsSessionMachine(sessionId: 's4');

      // queued 状态直接 close/transfer 拒绝
      expect(cs.close(), isFalse);
      expect(cs.transfer(toIdentityId: 'x'), isFalse);
      expect(cs.status, CsSessionStatus.queued);

      // claim 后 rate 拒绝（必须先 close）
      cs.claim();
      expect(cs.rate(score: 5), isFalse);
      expect(cs.status, CsSessionStatus.active);

      // rated 是终态：不可 close/claim
      cs.close();
      cs.rate(score: 4);
      expect(cs.close(), isFalse);
      expect(cs.claim(), isFalse);
      expect(cs.status, CsSessionStatus.rated);
    });

    test('suspend 拒绝分支：suspended 下 claim/transfer/close/rate 全拒绝', () {
      final cs = CsSessionMachine(sessionId: 's5', suspended: true);

      // queued 时 suspend：claim 拒绝
      expect(cs.claim(), isFalse);
      expect(cs.status, CsSessionStatus.queued);

      // 恢复后 claim 到 active，再 suspend：前进事件全拒绝
      cs.suspended = false;
      expect(cs.claim(), isTrue);
      cs.suspended = true;
      expect(cs.transfer(toIdentityId: 'x'), isFalse);
      expect(cs.close(), isFalse);
      expect(cs.rate(score: 5), isFalse);
      expect(cs.status, CsSessionStatus.active);
    });
  });

  group('APP-A04 offboarding 状态机（CsOffboardingMachine）', () {
    test('主干：draft→frozen→transferring→verifying→completed', () {
      final ob = CsOffboardingMachine();

      expect(ob.status, CsOffboardingStatus.draft);
      expect(ob.freeze(), isTrue);
      expect(ob.status, CsOffboardingStatus.frozen);
      expect(ob.startTransfer(), isTrue);
      expect(ob.status, CsOffboardingStatus.transferring);
      expect(ob.submitVerification(), isTrue);
      expect(ob.status, CsOffboardingStatus.verifying);
      expect(ob.complete(), isTrue);
      expect(ob.status, CsOffboardingStatus.completed);
    });

    test('失败分支：transferring/verifying 可 fail；failed 为终态', () {
      final ob = CsOffboardingMachine()
        ..freeze()
        ..startTransfer();
      expect(ob.fail(), isTrue);
      expect(ob.status, CsOffboardingStatus.failed);
      // 终态：不可再前进
      expect(ob.startTransfer(), isFalse);
      expect(ob.complete(), isFalse);
      expect(ob.status, CsOffboardingStatus.failed);

      final ob2 = CsOffboardingMachine()
        ..freeze()
        ..startTransfer()
        ..submitVerification();
      expect(ob2.fail(), isTrue);
      expect(ob2.status, CsOffboardingStatus.failed);
    });

    test('非法跳转：draft 不可直接 transferring/verifying/completed', () {
      final ob = CsOffboardingMachine();

      expect(ob.startTransfer(), isFalse);
      expect(ob.submitVerification(), isFalse);
      expect(ob.complete(), isFalse);
      expect(ob.status, CsOffboardingStatus.draft);

      // frozen 不可直接 verifying
      final ob2 = CsOffboardingMachine()..freeze();
      expect(ob2.submitVerification(), isFalse);
      expect(ob2.status, CsOffboardingStatus.frozen);
    });
  });
}
