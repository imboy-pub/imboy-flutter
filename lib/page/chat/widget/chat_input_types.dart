import 'dart:async';

import 'package:flutter/material.dart';
import 'package:imboy/service/quick_reply_service.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/service/auth_session_scope.dart';

/// 生产环境的 [QuickReplyStore] 适配器：桥接项目已有的 [StorageService]。
///
/// 不放在 `quick_reply_service.dart` 里是为了保持 domain 层纯测试（不
/// 传递依赖 StorageService → config/init.dart 等单例链）。
class StorageServiceQuickReplyStore implements QuickReplyStore {
  StorageServiceQuickReplyStore()
    : _owner = AccountLocalTaskOwner.capture(),
      _session = authSessionReader.current;

  final AccountLocalTaskOwner _owner;
  final AuthSessionScope _session;

  bool _ownsCurrent(String key) =>
      key == 'quick_replies:${_owner.uid}' &&
      authSessionReader.isCurrent(_session) &&
      AccountLocalTaskOwner.capture() == _owner;

  @override
  Future<String?> getString(String key) async {
    if (!_ownsCurrent(key)) return null;
    final v = StorageService.to.getString(key);
    return v.isEmpty ? null : v;
  }

  @override
  Future<void> setString(String key, String value) async {
    await _write(key, () => StorageService.to.setString(key, value));
  }

  @override
  Future<void> remove(String key) async {
    await _write(key, () => StorageService.to.remove(key));
  }

  Future<void> _write(String key, Future<bool> Function() write) async {
    if (!_ownsCurrent(key)) return;
    try {
      await AccountLocalTaskRegistry.instance.run<void>(
        _owner,
        operation: (task) async {
          if (_ownsCurrent(key) && !task.isCancelled) {
            await StorageService.to.persistPreference(write);
          }
        },
      );
    } on AccountLocalTaskCancelledException {
      // A disposed account's page can still finish a prompt or a queued callback.
    }
  }
}

/// 键盘高度观察者
class ChatKeyboardObserver with WidgetsBindingObserver {
  final VoidCallback onKeyboardChanged;

  ChatKeyboardObserver(this.onKeyboardChanged);

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    onKeyboardChanged();
  }
}

/// 部分代码来自该项目，感谢作者 CaiJingLong https://github.com/CaiJingLong/flutter_like_wechat_input
/// 输入类型枚举
enum InputType {
  text, // 文本输入
  voice, // 语音输入
  emoji, // 表情输入
  extra, // 附加功能
}

/// 发送按钮显示模式
enum SendButtonVisibilityMode {
  editing, // 编辑时显示
  always, // 始终显示
}
