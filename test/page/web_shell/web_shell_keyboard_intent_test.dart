/// Phase 1.1.l — Web Shell 快捷键纯函数测试
///
/// 覆盖：
/// - 4 个 sealed 变体的解析（Cmd/Ctrl + K/N/,） + Esc
/// - macOS / Windows 修饰键切换（meta vs control）
/// - 严格匹配（拒绝多余 Shift/Alt）
/// - 边界：空集合 / 单 modifier / 不匹配组合
/// - sealed switch 穷尽性契约
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_shell_keyboard_intent.dart';

void main() {
  group('resolveShellShortcut — Esc 单按', () {
    test('仅 Esc → CloseRightPanelShortcut (macOS)', () {
      final result = resolveShellShortcut(
        pressed: {LogicalKeyboardKey.escape},
        isMacOS: true,
      );
      expect(result, isA<CloseRightPanelShortcut>());
    });

    test('仅 Esc → CloseRightPanelShortcut (Windows)', () {
      final result = resolveShellShortcut(
        pressed: {LogicalKeyboardKey.escape},
        isMacOS: false,
      );
      expect(result, isA<CloseRightPanelShortcut>());
    });

    test('Esc + Cmd → 不响应（严格匹配，避免与系统冲突）', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.escape,
          LogicalKeyboardKey.meta,
        },
        isMacOS: true,
      );
      expect(result, isNull);
    });
  });

  group('resolveShellShortcut — Cmd+K (macOS)', () {
    test('Cmd+K → OpenGlobalSearchShortcut', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyK,
        },
        isMacOS: true,
      );
      expect(result, isA<OpenGlobalSearchShortcut>());
    });

    test('Ctrl+K (macOS) → 不响应（macOS 用 meta）', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyK,
        },
        isMacOS: true,
      );
      expect(result, isNull);
    });
  });

  group('resolveShellShortcut — Ctrl+K (Windows/Linux)', () {
    test('Ctrl+K → OpenGlobalSearchShortcut', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyK,
        },
        isMacOS: false,
      );
      expect(result, isA<OpenGlobalSearchShortcut>());
    });

    test('Cmd+K (Windows) → 不响应（Windows 用 control）', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyK,
        },
        isMacOS: false,
      );
      expect(result, isNull);
    });
  });

  group('resolveShellShortcut — mod+N 新建会话', () {
    test('Cmd+N (macOS) → NewChatShortcut', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyN,
        },
        isMacOS: true,
      );
      expect(result, isA<NewChatShortcut>());
    });

    test('Ctrl+N (Windows) → NewChatShortcut', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.keyN,
        },
        isMacOS: false,
      );
      expect(result, isA<NewChatShortcut>());
    });
  });

  group('resolveShellShortcut — mod+, 设置', () {
    test('Cmd+, (macOS) → OpenSettingsShortcut', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.comma,
        },
        isMacOS: true,
      );
      expect(result, isA<OpenSettingsShortcut>());
    });

    test('Ctrl+, (Windows) → OpenSettingsShortcut', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.control,
          LogicalKeyboardKey.comma,
        },
        isMacOS: false,
      );
      expect(result, isA<OpenSettingsShortcut>());
    });
  });

  group('resolveShellShortcut — 严格匹配（拒绝多余修饰键）', () {
    test('Cmd+Shift+K → 不响应（多余 Shift，避免与 devtools 冲突）', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.shift,
          LogicalKeyboardKey.keyK,
        },
        isMacOS: true,
      );
      expect(result, isNull);
    });

    test('Cmd+Alt+N → 不响应（多余 Alt）', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.alt,
          LogicalKeyboardKey.keyN,
        },
        isMacOS: true,
      );
      expect(result, isNull);
    });

    test('Cmd+K+L (多余字母键) → 不响应', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyK,
          LogicalKeyboardKey.keyL,
        },
        isMacOS: true,
      );
      expect(result, isNull);
    });
  });

  group('resolveShellShortcut — 边界', () {
    test('空集合 → null', () {
      final result = resolveShellShortcut(
        pressed: {},
        isMacOS: true,
      );
      expect(result, isNull);
    });

    test('仅 modifier 单按（无字母键）→ null', () {
      final result = resolveShellShortcut(
        pressed: {LogicalKeyboardKey.meta},
        isMacOS: true,
      );
      expect(result, isNull);
    });

    test('仅字母键（无 modifier）→ null', () {
      final result = resolveShellShortcut(
        pressed: {LogicalKeyboardKey.keyK},
        isMacOS: true,
      );
      expect(result, isNull);
    });

    test('mod + 不识别的字母 → null', () {
      final result = resolveShellShortcut(
        pressed: {
          LogicalKeyboardKey.meta,
          LogicalKeyboardKey.keyZ,
        },
        isMacOS: true,
      );
      expect(result, isNull);
    });
  });

  group('WebShellShortcut sealed switch 穷尽性契约', () {
    /// 测试所有变体可在 switch 中穷尽（编译器强制未来新增变体时同步更新）
    String describe(WebShellShortcut shortcut) {
      return switch (shortcut) {
        OpenGlobalSearchShortcut() => 'open-search',
        NewChatShortcut() => 'new-chat',
        CloseRightPanelShortcut() => 'close-panel',
        OpenSettingsShortcut() => 'open-settings',
      };
    }

    test('OpenGlobalSearchShortcut → open-search', () {
      expect(describe(const OpenGlobalSearchShortcut()), 'open-search');
    });

    test('NewChatShortcut → new-chat', () {
      expect(describe(const NewChatShortcut()), 'new-chat');
    });

    test('CloseRightPanelShortcut → close-panel', () {
      expect(describe(const CloseRightPanelShortcut()), 'close-panel');
    });

    test('OpenSettingsShortcut → open-settings', () {
      expect(describe(const OpenSettingsShortcut()), 'open-settings');
    });
  });
}
