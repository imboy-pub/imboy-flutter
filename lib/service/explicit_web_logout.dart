import 'package:dio/dio.dart' show Options;
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart' show Theme;
import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyDownEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/http/http_request_policy.dart';
import 'package:imboy/config/init.dart' show deviceId;
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/user_device_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

/// Per-entry explicit Web logout only; auth-expired and Native cleanup stay local.
class ExplicitWebLogoutAction {
  ExplicitWebLogoutAction({
    this.readWebDeviceId,
    this.revokeWebDevice,
    this.quitLocal,
    this.isLoggedOutAfter,
  });

  final Future<String> Function()? readWebDeviceId;
  final Future<bool> Function(String did, void Function() guard)?
  revokeWebDevice;
  final Future<bool> Function(int? expectedGeneration)? quitLocal;
  final bool Function(int originalGeneration)? isLoggedOutAfter;
  bool _running = false;

  Future<bool> run({
    required bool Function() isMounted,
    required Future<bool?> Function() confirm,
    required VoidCallback onFailure,
  }) async {
    if (_running) return false;
    _running = true;
    final repo = UserRepoLocal.to;
    final uid = repo.currentUid;
    final generation = repo.sessionGeneration;
    final boundDid = deviceId;
    bool current() =>
        isMounted() &&
        uid.isNotEmpty &&
        repo.currentUid == uid &&
        repo.isCurrentSession(generation) &&
        !repo.isAuthTransitioning &&
        deviceId == boundDid;
    try {
      if (!current() || boundDid.isEmpty) {
        throw StateError('Invalid logout owner');
      }
      final trustedDid = await (readWebDeviceId?.call() ?? DeviceExt.did);
      if (!current()) return false;
      if (trustedDid != boundDid) {
        throw StateError('Web device binding changed');
      }
      if (await confirm() != true || !current()) return false;
      void guard() {
        if (!current()) throw StateError('Logout owner changed');
      }

      final revoked =
          await (revokeWebDevice?.call(boundDid, guard) ??
              UserDeviceApi().deleteDevice(
                deviceId: boundDid,
                showError: false,
                options: Options(
                  extra: {
                    httpRequestGuard: guard,
                    httpSuppressErrorToast: true,
                    httpNoAutoRetry: true,
                  },
                ),
              ));
      if (!current()) return false;
      if (!revoked) {
        onFailure();
        return false;
      }
      final ok =
          await (quitLocal?.call(generation) ??
              repo.quitLogin(expectedGeneration: generation));
      if (ok &&
          (isLoggedOutAfter?.call(generation) ??
              repo.isLoggedOutAfter(generation))) {
        return true;
      }
      if (!ok && current()) onFailure();
      return false;
    } on Object {
      if (current()) onFailure();
      return false;
    } finally {
      _running = false;
    }
  }
}

/// 弹层键盘行为收口（DEF-LAY05-A/B，P3）：
///
/// - **Esc 关闭**：CupertinoDialogRoute 框架层零 Escape 处理（引擎源码
///   grep=0），lay-run4 实测 after_esc dlgGone=false。Esc 语义=取消
///   （pop(false)），与「危险操作默认取消」的产品口径一致。
/// - **焦点陷阱**：弹层开着时 Tab 不得逃逸到背景路由（lay-run4 tab_cycle
///   在对话框与背景 INPUT×3 间循环）。autofocus 落在「取消」（Enter=安全
///   默认），Tab/Shift+Tab 在两个动作间循环，永不交还引擎默认遍历。
///
/// 只拦截 Escape 与 Tab；其余按键原样放行（引擎默认行为不变）。
///
/// Tab 循环直接在弹层 Focus 子树的 focusable 间折返（builder context 位于
/// 弹层 widget 上方，FocusTraversalGroup.of 会误取根组策略，故不依赖它）。
KeyEventResult _dialogKeyboardHandler(
  FocusNode dialogNode,
  BuildContext dialogContext,
  KeyEvent event,
) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }
  if (event.logicalKey == LogicalKeyboardKey.escape) {
    Navigator.of(dialogContext).pop(false);
    return KeyEventResult.handled;
  }
  if (event.logicalKey != LogicalKeyboardKey.tab) {
    return KeyEventResult.ignored;
  }
  final focusables = dialogNode.descendants
      .where((node) => node.canRequestFocus)
      .toList();
  if (focusables.isEmpty) {
    return KeyEventResult.ignored;
  }
  final focus = FocusManager.instance.primaryFocus;
  final index = focus == null ? -1 : focusables.indexOf(focus);
  final shift = HardwareKeyboard.instance.isShiftPressed;
  final next = shift
      // 组首反向折返到末端；当前不在组内则取末端。
      ? (index <= 0 ? focusables.last : focusables[index - 1])
      // 组尾正向折返到首端；当前不在组内则取首端。
      : (index == -1 || index == focusables.length - 1
            ? focusables.first
            : focusables[index + 1]);
  next.requestFocus();
  return KeyEventResult.handled;
}

Future<bool?> confirmExplicitWebLogout(
  BuildContext context, {
  bool followAppFont = true,
}) => showCupertinoDialog<bool>(
  context: context,
  builder: (dialogContext) {
    final scale =
        Theme.of(dialogContext).textTheme.bodyMedium!.fontSize! /
        FontSizeType.normal.size;
    final bodyStyle = followAppFont
        ? TextStyle(fontSize: FontSizeType.body.size * scale)
        : null;
    final contentStyle = followAppFont
        ? TextStyle(fontSize: FontSizeType.footnote.size * scale)
        : null;
    return Focus(
      onKeyEvent: (node, event) =>
          _dialogKeyboardHandler(node, dialogContext, event),
      child: CupertinoAlertDialog(
        title: Text(dialogContext.t.account.logOut, style: bodyStyle),
        content: Text(
          dialogContext.t.account.areYouSureLogOut,
          style: contentStyle,
        ),
        actions: [
          // CupertinoDialogAction 本版本无 autofocus：Focus(autofocus) 落
          // 「取消」（弹层打开即有焦点，Enter/Space 平台默认行为不变）。
          Focus(
            autofocus: true,
            child: CupertinoDialogAction(
              textStyle: bodyStyle,
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(dialogContext.t.common.buttonCancel),
            ),
          ),
          Focus(
            child: CupertinoDialogAction(
              textStyle: bodyStyle,
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dialogContext.t.common.buttonConfirm),
            ),
          ),
        ],
      ),
    );
  },
);
