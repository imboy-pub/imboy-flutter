/// Phase 1.1 Web Shell 断点纯函数测试
///
/// 覆盖：
/// - mobile / twoColumn / threeColumn 三档分段
/// - 边界值（899.99 / 900 / 1199.99 / 1200）
/// - 典型设备宽度（320 / 1024 / 1920 / 3840）
/// - 安全默认（负数宽度归入 mobile）
/// - enum 顺序契约
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_shell_breakpoint.dart';

void main() {
  group('resolveShellLayout — mobile 分支 (< 900)', () {
    test('width 0 (零宽) → mobile', () {
      expect(resolveShellLayout(0), WebShellLayout.mobile);
    });

    test('width 320 (小手机) → mobile', () {
      expect(resolveShellLayout(320), WebShellLayout.mobile);
    });

    test('width 768 (平板竖屏) → mobile', () {
      expect(resolveShellLayout(768), WebShellLayout.mobile);
    });

    test('width 899.99 (刚低于阈值) → mobile', () {
      expect(resolveShellLayout(899.99), WebShellLayout.mobile);
    });

    test('width -100 (非法负数, 安全默认) → mobile', () {
      expect(resolveShellLayout(-100), WebShellLayout.mobile);
    });
  });

  group('resolveShellLayout — twoColumn 分支 (900-1200)', () {
    test('width 900 (左闭边界) → twoColumn', () {
      expect(resolveShellLayout(900), WebShellLayout.twoColumn);
    });

    test('width 1024 (典型平板/小桌面) → twoColumn', () {
      expect(resolveShellLayout(1024), WebShellLayout.twoColumn);
    });

    test('width 1199.99 (刚低于上限) → twoColumn', () {
      expect(resolveShellLayout(1199.99), WebShellLayout.twoColumn);
    });
  });

  group('resolveShellLayout — threeColumn 分支 (>= 1200)', () {
    test('width 1200 (左闭边界) → threeColumn', () {
      expect(resolveShellLayout(1200), WebShellLayout.threeColumn);
    });

    test('width 1440 (典型笔记本) → threeColumn', () {
      expect(resolveShellLayout(1440), WebShellLayout.threeColumn);
    });

    test('width 1920 (Full HD) → threeColumn', () {
      expect(resolveShellLayout(1920), WebShellLayout.threeColumn);
    });

    test('width 3840 (4K) → threeColumn', () {
      expect(resolveShellLayout(3840), WebShellLayout.threeColumn);
    });
  });

  group('WebShellLayout enum 契约', () {
    test('恰好 3 个值且按宽度递增顺序', () {
      expect(WebShellLayout.values, [
        WebShellLayout.mobile,
        WebShellLayout.twoColumn,
        WebShellLayout.threeColumn,
      ]);
    });

    test('每个值都有稳定的 index（断点契约的依赖项）', () {
      expect(WebShellLayout.mobile.index, 0);
      expect(WebShellLayout.twoColumn.index, 1);
      expect(WebShellLayout.threeColumn.index, 2);
    });
  });
}
