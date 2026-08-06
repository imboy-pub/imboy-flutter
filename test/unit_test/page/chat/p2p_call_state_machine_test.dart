import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_constants.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_state_machine.dart';

/// P2P 通话状态机（BUG#15）。
///
/// 通话链路需要两台真机才能端到端验证，所以流转规则被抽成纯逻辑，
/// 用这里的四条路径把「阶段 → 文案键 → 本地通话记录状态码」钉住。
void main() {
  CallStatus run(Iterable<CallSignal> signals) {
    var status = const CallStatus();
    for (final s in signals) {
      status = status.apply(s);
    }
    return status;
  }

  group('初始态', () {
    test('呼出时处于 dialing，提示等待对方接受，不展示通话时长', () {
      const status = CallStatus();
      expect(status.phase, CallPhase.dialing);
      expect(status.tipKey, CallTipKey.waitingPeerAccept);
      expect(status.showsDuration, isFalse);
      expect(status.isTerminal, isFalse);
      // 未结束不写库
      expect(status.recordStateCode, CallStateCode.calling);
    });
  });

  group('路径一：正常接通', () {
    test('dialing → ringing → connected，接通后不再显示任何提示语', () {
      final ringing = run([CallSignal.ringing]);
      expect(ringing.phase, CallPhase.ringing);
      expect(ringing.tipKey, CallTipKey.ringing);

      final connected = ringing.apply(CallSignal.connected);
      expect(connected.phase, CallPhase.connected);
      // 回归钉子：原实现 stateTips 从不清空，接通后一直停在“响铃中”，
      // 音频通话全程看不到通话时长。
      expect(connected.tipKey, CallTipKey.none);
      expect(connected.showsDuration, isTrue);
    });

    test('SDP answer 与 ICE connected 各报一次接通，结果幂等', () {
      final once = run([CallSignal.connected]);
      final twice = once.apply(CallSignal.connected);
      expect(twice, once);
    });

    test('接通后迟到的 ringing 不会把阶段拉回响铃', () {
      final status = run([CallSignal.connected, CallSignal.ringing]);
      expect(status.phase, CallPhase.connected);
    });

    test('接通后本机挂断记 connected，据此渲染通话时长', () {
      final status = run([
        CallSignal.ringing,
        CallSignal.connected,
        CallSignal.localHangUp,
      ]);
      expect(status.isTerminal, isTrue);
      expect(status.wasConnected, isTrue);
      expect(status.recordStateCode, CallStateCode.connected);
      expect(status.tipKey, CallTipKey.callEnded);
    });

    test('接通后对端挂断同样记 connected，而不是 peerHungUp', () {
      final status = run([CallSignal.connected, CallSignal.peerBye]);
      expect(status.recordStateCode, CallStateCode.connected);
      expect(status.tipKey, CallTipKey.peerHungUp);
    });
  });

  group('路径二：对端拒接 / 忙', () {
    test('未接通收到 busy → 结束，提示忙碌，记 busy', () {
      final status = run([CallSignal.ringing, CallSignal.peerBusy]);
      expect(status.phase, CallPhase.ended);
      expect(status.endReason, CallEndReason.peerBusy);
      expect(status.tipKey, CallTipKey.busy);
      expect(status.recordStateCode, CallStateCode.busy);
      expect(status.wasConnected, isFalse);
    });

    test('已接通后迟到的 busy 不得中断通话', () {
      final status = run([CallSignal.connected, CallSignal.peerBusy]);
      expect(status.phase, CallPhase.connected);
    });
  });

  group('路径三：无应答超时', () {
    test('响铃中超时 → 结束，提示对方无响应，记 rejected', () {
      final status = run([CallSignal.ringing, CallSignal.answerTimeout]);
      expect(status.phase, CallPhase.ended);
      expect(status.endReason, CallEndReason.noAnswer);
      expect(status.tipKey, CallTipKey.peerNoResponse);
      expect(status.recordStateCode, CallStateCode.rejected);
    });

    test('对端从未响铃（离线）也能超时结束', () {
      final status = run([CallSignal.answerTimeout]);
      expect(status.endReason, CallEndReason.noAnswer);
    });

    test('接通后定时器漏关也不得误杀通话', () {
      final status = run([CallSignal.connected, CallSignal.answerTimeout]);
      expect(status.phase, CallPhase.connected);
      expect(status.isTerminal, isFalse);
    });
  });

  group('路径四：异常中断', () {
    test('ICE 重启耗尽 → 结束，提示网络错误，记 failed 而非对端挂断', () {
      final status = run([CallSignal.ringing, CallSignal.failed]);
      expect(status.phase, CallPhase.ended);
      expect(status.endReason, CallEndReason.failed);
      expect(status.tipKey, CallTipKey.networkError);
      expect(status.recordStateCode, CallStateCode.failed);
      expect(status.recordStateCode, isNot(CallStateCode.peerHungUp));
    });

    test('接通后链路故障仍记 connected（已产生有效通话时长）', () {
      final status = run([CallSignal.connected, CallSignal.failed]);
      expect(status.recordStateCode, CallStateCode.connected);
      expect(status.tipKey, CallTipKey.networkError);
    });
  });

  group('终态吸收', () {
    test('结束后迟到的 bye / busy / 超时不得改写结束原因', () {
      final ended = run([CallSignal.answerTimeout]);
      for (final late in CallSignal.values) {
        expect(ended.apply(late), ended, reason: '结束后收到 $late 不应改变状态');
      }
    });
  });
}
