/// P2P 通话悬浮窗状态机测试 / Floating-window state transitions
///
/// 覆盖 notifier 纯状态逻辑（不依赖 WebRTC 渲染器/平台通道）：
///   - enterFloating：设定小窗初始位 + 置 minimized
///   - updateFloatPosition：拖拽更新坐标，不影响 minimized
///   - toggleMinimized：复原/最小化翻转
///   - copyWith：floatX/floatY 字段契约
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/p2p_call_screen/p2p_call_screen_provider.dart';

void main() {
  group('floatX/floatY copyWith 契约', () {
    test('默认 0，且可被覆盖', () {
      const s = P2pCallScreenState();
      expect(s.floatX, 0.0);
      expect(s.floatY, 0.0);
      expect(s.minimized, isFalse);

      final s2 = s.copyWith(floatX: 12.5, floatY: 34.0);
      expect(s2.floatX, 12.5);
      expect(s2.floatY, 34.0);
      // 未传的字段保持原值
      expect(s2.minimized, isFalse);
    });
  });

  group('notifier 悬浮窗状态机', () {
    late ProviderContainer container;
    P2pCallScreenNotifier notifier() =>
        container.read(p2pCallScreenProvider.notifier);
    P2pCallScreenState read() => container.read(p2pCallScreenProvider);

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('enterFloating 设定坐标并最小化', () {
      notifier().enterFloating(300, 70);
      final s = read();
      expect(s.minimized, isTrue);
      expect(s.floatX, 300);
      expect(s.floatY, 70);
    });

    test('updateFloatPosition 仅更新坐标，不动 minimized', () {
      notifier().enterFloating(300, 70);
      notifier().updateFloatPosition(120, 200);
      final s = read();
      expect(s.floatX, 120);
      expect(s.floatY, 200);
      expect(s.minimized, isTrue);
    });

    test('toggleMinimized 复原全屏', () {
      notifier().enterFloating(300, 70);
      expect(read().minimized, isTrue);
      notifier().toggleMinimized();
      expect(read().minimized, isFalse);
    });

    test('setReconnecting 切换网络重连横幅状态', () {
      expect(read().reconnecting, isFalse);
      notifier().setReconnecting(true);
      expect(read().reconnecting, isTrue);
      notifier().setReconnecting(false);
      expect(read().reconnecting, isFalse);
    });
  });

  group('snapFloatingLeft 松手吸附边缘', () {
    // 屏幕宽 400，窗宽 108，边距 10 → 右缘 left = 400-108-10 = 282
    test('窗口中心在左半区 → 吸附左缘(margin)', () {
      expect(
        snapFloatingLeft(currentLeft: 30, windowWidth: 108, screenWidth: 400),
        10,
      );
    });

    test('窗口中心在右半区 → 吸附右缘', () {
      expect(
        snapFloatingLeft(currentLeft: 250, windowWidth: 108, screenWidth: 400),
        282,
      );
    });

    test('恰好中线（center==screenW/2）→ 归右缘', () {
      // center=200 时 200<200 为 false → 右缘
      expect(
        snapFloatingLeft(currentLeft: 146, windowWidth: 108, screenWidth: 400),
        282,
      );
    });
  });

  group('formatCallDuration 通话时长格式', () {
    test('<1h 显示 mm:ss', () {
      expect(formatCallDuration(0), '00:00');
      expect(formatCallDuration(9), '00:09');
      expect(formatCallDuration(65), '01:05');
      expect(formatCallDuration(3599), '59:59');
    });

    test('≥1h 显示 hh:mm:ss', () {
      expect(formatCallDuration(3600), '01:00:00');
      expect(formatCallDuration(3661), '01:01:01');
      expect(formatCallDuration(36000), '10:00:00');
    });
  });
}
