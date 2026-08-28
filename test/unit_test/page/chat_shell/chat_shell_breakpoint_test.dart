/// T2 (WP1) — Chat Shell 断点纯函数测试
///
/// 镜像 `web_shell_breakpoint_test.dart`：
/// - mobile / desktop 两档分段（阈值 900，同源于 AppBreakpoints.wide）
/// - 边界值（899.99 / 900）
/// - 典型设备宽度（320 / 768 / 1024 / 1920）
/// - 安全默认（负数宽度归入 mobile）
/// - enum 顺序契约
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat_shell/chat_shell_breakpoint.dart';

void main() {
  group('resolveChatShellLayout — mobile 分支 (< 900)', () {
    test('width 0 (零宽) → mobile', () {
      expect(resolveChatShellLayout(0), ChatShellLayout.mobile);
    });

    test('width 320 (小手机) → mobile', () {
      expect(resolveChatShellLayout(320), ChatShellLayout.mobile);
    });

    test('width 768 (平板竖屏) → mobile', () {
      expect(resolveChatShellLayout(768), ChatShellLayout.mobile);
    });

    test('width 899.99 (刚低于阈值) → mobile', () {
      expect(resolveChatShellLayout(899.99), ChatShellLayout.mobile);
    });

    test('width -100 (非法负数, 安全默认) → mobile', () {
      expect(resolveChatShellLayout(-100), ChatShellLayout.mobile);
    });
  });

  group('resolveChatShellLayout — desktop 分支 (>= 900)', () {
    test('width 900 (左闭边界) → desktop', () {
      expect(resolveChatShellLayout(900), ChatShellLayout.desktop);
    });

    test('width 1024 (典型平板/小桌面) → desktop', () {
      expect(resolveChatShellLayout(1024), ChatShellLayout.desktop);
    });

    test('width 1440 (典型笔记本) → desktop', () {
      expect(resolveChatShellLayout(1440), ChatShellLayout.desktop);
    });

    test('width 1920 (Full HD) → desktop', () {
      expect(resolveChatShellLayout(1920), ChatShellLayout.desktop);
    });
  });

  group('ChatShellLayout enum 契约', () {
    test('恰好 2 个值且按宽度递增顺序', () {
      expect(ChatShellLayout.values, [
        ChatShellLayout.mobile,
        ChatShellLayout.desktop,
      ]);
    });

    test('每个值都有稳定的 index（断点契约的依赖项）', () {
      expect(ChatShellLayout.mobile.index, 0);
      expect(ChatShellLayout.desktop.index, 1);
    });
  });

  group('与 web_shell 断点同源（无灰区）', () {
    test('mobile/desktop 分界与 AppBreakpoints.wide 一致（900）', () {
      // 镜像 web_shell_breakpoint 的 mobile 分界：< 900 mobile，>= 900 非 mobile。
      // 两壳共用 AppBreakpoints.wide，本测试固化该契约防止未来漂移出灰区。
      const threshold = 900.0;
      expect(resolveChatShellLayout(threshold - 0.01), ChatShellLayout.mobile);
      expect(resolveChatShellLayout(threshold), ChatShellLayout.desktop);
    });
  });
}
