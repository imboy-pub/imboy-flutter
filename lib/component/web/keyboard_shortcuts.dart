/// Web 平台键盘快捷键服务
///
/// 提供类似 WhatsApp Web 的键盘快捷键功能
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 快捷键定义
class ShortcutKey {
  /// 主键
  final LogicalKeyboardKey key;

  /// 是否需要 Ctrl/Cmd
  final bool control;

  /// 是否需要 Shift
  final bool shift;

  /// 是否需要 Alt
  final bool alt;

  const ShortcutKey({
    required this.key,
    this.control = false,
    this.shift = false,
    this.alt = false,
  });

  /// 检查是否匹配当前按键
  bool matches(Set<LogicalKeyboardKey> keys) {
    final isControlPressed = keys.contains(LogicalKeyboardKey.controlLeft) ||
        keys.contains(LogicalKeyboardKey.controlRight) ||
        keys.contains(LogicalKeyboardKey.metaLeft) ||
        keys.contains(LogicalKeyboardKey.metaRight);

    final isShiftPressed = keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);

    final isAltPressed = keys.contains(LogicalKeyboardKey.altLeft) ||
        keys.contains(LogicalKeyboardKey.altRight);

    if (control != isControlPressed) return false;
    if (shift != isShiftPressed) return false;
    if (alt != isAltPressed) return false;

    return keys.contains(key);
  }

  @override
  String toString() {
    final parts = <String>[];
    if (control) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');
    parts.add(_keyToString(key));
    return parts.join(' + ');
  }

  String _keyToString(LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.keyA:
        return 'A';
      case LogicalKeyboardKey.keyB:
        return 'B';
      case LogicalKeyboardKey.keyC:
        return 'C';
      case LogicalKeyboardKey.keyD:
        return 'D';
      case LogicalKeyboardKey.keyE:
        return 'E';
      case LogicalKeyboardKey.keyF:
        return 'F';
      case LogicalKeyboardKey.keyN:
        return 'N';
      case LogicalKeyboardKey.keyP:
        return 'P';
      case LogicalKeyboardKey.keyS:
        return 'S';
      case LogicalKeyboardKey.keyV:
        return 'V';
      case LogicalKeyboardKey.enter:
        return 'Enter';
      case LogicalKeyboardKey.escape:
        return 'Esc';
      case LogicalKeyboardKey.slash:
        return '/';
      case LogicalKeyboardKey.arrowUp:
        return '↑';
      case LogicalKeyboardKey.arrowDown:
        return '↓';
      case LogicalKeyboardKey.arrowLeft:
        return '←';
      case LogicalKeyboardKey.arrowRight:
        return '→';
      default:
        return key.keyLabel;
    }
  }
}

/// 快捷键动作
typedef ShortcutAction = void Function();

/// 键盘快捷键服务
///
/// 管理全局和局部键盘快捷键
class KeyboardShortcutService {
  static final KeyboardShortcutService _instance =
      KeyboardShortcutService._internal();
  factory KeyboardShortcutService() => _instance;
  KeyboardShortcutService._internal();

  /// 注册的快捷键
  final Map<ShortcutKey, ShortcutAction> _shortcuts = {};

  /// 是否启用
  bool _enabled = true;

  /// 注册快捷键
  void register(ShortcutKey key, ShortcutAction action) {
    _shortcuts[key] = action;
  }

  /// 取消注册快捷键
  void unregister(ShortcutKey key) {
    _shortcuts.remove(key);
  }

  /// 清空所有快捷键
  void clear() {
    _shortcuts.clear();
  }

  /// 启用/禁用
  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// 处理按键事件
  bool handleKey(Set<LogicalKeyboardKey> keys) {
    if (!_enabled) return false;

    for (final entry in _shortcuts.entries) {
      if (entry.key.matches(keys)) {
        entry.value();
        return true;
      }
    }
    return false;
  }
}

/// WhatsApp Web 风格的快捷键定义
class WhatsAppShortcuts {
  /// 搜索会话: Ctrl/Cmd + /
  static final search = ShortcutKey(key: LogicalKeyboardKey.slash, control: true);

  /// 新建会话: Ctrl/Cmd + N
  static final newChat =
      ShortcutKey(key: LogicalKeyboardKey.keyN, control: true);

  /// 打开设置: Ctrl/Cmd + ,
  static final settings =
      ShortcutKey(key: LogicalKeyboardKey.comma, control: true);

  /// 归档会话: Ctrl/Cmd + E
  static final archive =
      ShortcutKey(key: LogicalKeyboardKey.keyE, control: true);

  /// 静音会话: Ctrl/Cmd + Shift + M
  static final mute = ShortcutKey(
    key: LogicalKeyboardKey.keyM,
    control: true,
    shift: true,
  );

  /// 删除会话: Ctrl/Cmd + Shift + D
  static final delete = ShortcutKey(
    key: LogicalKeyboardKey.keyD,
    control: true,
    shift: true,
  );

  /// 标记已读: Ctrl/Cmd + Shift + U
  static final markRead = ShortcutKey(
    key: LogicalKeyboardKey.keyU,
    control: true,
    shift: true,
  );

  /// 下一个会话: Ctrl/Cmd + Tab
  static final nextChat =
      ShortcutKey(key: LogicalKeyboardKey.tab, control: true);

  /// 上一个会话: Ctrl/Cmd + Shift + Tab
  static final prevChat = ShortcutKey(
    key: LogicalKeyboardKey.tab,
    control: true,
    shift: true,
  );

  /// 放大: Ctrl/Cmd + =
  static final zoomIn =
      ShortcutKey(key: LogicalKeyboardKey.equal, control: true);

  /// 缩小: Ctrl/Cmd + -
  static final zoomOut =
      ShortcutKey(key: LogicalKeyboardKey.minus, control: true);

  /// 重置缩放: Ctrl/Cmd + 0
  static final zoomReset =
      ShortcutKey(key: LogicalKeyboardKey.digit0, control: true);

  /// 发送消息: Enter
  static final sendMessage = ShortcutKey(key: LogicalKeyboardKey.enter);

  /// 换行: Shift + Enter
  static final newLine =
      ShortcutKey(key: LogicalKeyboardKey.enter, shift: true);

  /// 全选: Ctrl/Cmd + A
  static final selectAll =
      ShortcutKey(key: LogicalKeyboardKey.keyA, control: true);

  /// 复制: Ctrl/Cmd + C
  static final copy = ShortcutKey(key: LogicalKeyboardKey.keyC, control: true);

  /// 粘贴: Ctrl/Cmd + V
  static final paste =
      ShortcutKey(key: LogicalKeyboardKey.keyV, control: true);

  /// 关闭对话框/返回: Escape
  static final close = ShortcutKey(key: LogicalKeyboardKey.escape);
}

/// 键盘快捷键监听组件
///
/// 用法：
/// ```dart
/// KeyboardShortcutListener(
///   shortcuts: {
///     WhatsAppShortcuts.search: () => _openSearch(),
///     WhatsAppShortcuts.newChat: () => _createNewChat(),
///   },
///   child: YourWidget(),
/// )
/// ```
class KeyboardShortcutListener extends StatefulWidget {
  /// 子组件
  final Widget child;

  /// 快捷键映射
  final Map<ShortcutKey, ShortcutAction>? shortcuts;

  /// 是否启用
  final bool enabled;

  const KeyboardShortcutListener({
    super.key,
    required this.child,
    this.shortcuts,
    this.enabled = true,
  });

  @override
  State<KeyboardShortcutListener> createState() =>
      _KeyboardShortcutListenerState();
}

class _KeyboardShortcutListenerState extends State<KeyboardShortcutListener> {
  final Set<LogicalKeyboardKey> _pressedKeys = {};
  final KeyboardShortcutService _service = KeyboardShortcutService();

  @override
  void initState() {
    super.initState();
    _registerShortcuts();
  }

  @override
  void didUpdateWidget(KeyboardShortcutListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    _registerShortcuts();
  }

  void _registerShortcuts() {
    _service.clear();
    if (widget.shortcuts != null) {
      widget.shortcuts!.forEach((key, action) {
        _service.register(key, action);
      });
    }
    _service.setEnabled(widget.enabled);
  }

  @override
  Widget build(BuildContext context) {
    // 非 Web 平台直接返回子组件
    if (!kIsWeb) {
      return widget.child;
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          _pressedKeys.add(event.logicalKey);
          _service.handleKey(_pressedKeys);
        } else if (event is KeyUpEvent) {
          _pressedKeys.remove(event.logicalKey);
        }
      },
      child: widget.child,
    );
  }
}

/// 快捷键帮助对话框
class ShortcutHelpDialog extends StatelessWidget {
  const ShortcutHelpDialog({super.key});

  /// 显示对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const ShortcutHelpDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shortcuts = [
      ('搜索会话', WhatsAppShortcuts.search),
      ('新建会话', WhatsAppShortcuts.newChat),
      ('发送消息', WhatsAppShortcuts.sendMessage),
      ('换行', WhatsAppShortcuts.newLine),
      ('全选', WhatsAppShortcuts.selectAll),
      ('复制', WhatsAppShortcuts.copy),
      ('粘贴', WhatsAppShortcuts.paste),
      ('归档会话', WhatsAppShortcuts.archive),
      ('关闭', WhatsAppShortcuts.close),
    ];

    return AlertDialog(
      backgroundColor: const Color(0xFF222E35),
      title: const Text(
        '键盘快捷键',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 400,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: shortcuts.length,
          itemBuilder: (context, index) {
            final (name, key) = shortcuts[index];
            return _buildShortcutItem(name, key);
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            '关闭',
            style: TextStyle(color: Color(0xFF00A884)),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutItem(String name, ShortcutKey key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(color: Colors.white70),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF2A3942),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key.toString(),
              style: const TextStyle(
                color: Color(0xFF00A884),
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
