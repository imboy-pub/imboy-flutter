import 'package:dio/dio.dart' show Options;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
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
      if (!current() || boundDid.isEmpty)
        throw StateError('Invalid logout owner');
      final trustedDid = await (readWebDeviceId?.call() ?? DeviceExt.did);
      if (!current()) return false;
      if (trustedDid != boundDid)
        throw StateError('Web device binding changed');
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
              repo.isLoggedOutAfter(generation)))
        return true;
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
    return CupertinoAlertDialog(
      title: Text(dialogContext.t.account.logOut, style: bodyStyle),
      content: Text(
        dialogContext.t.account.areYouSureLogOut,
        style: contentStyle,
      ),
      actions: [
        CupertinoDialogAction(
          textStyle: bodyStyle,
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(dialogContext.t.common.buttonCancel),
        ),
        CupertinoDialogAction(
          textStyle: bodyStyle,
          isDestructiveAction: true,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(dialogContext.t.common.buttonConfirm),
        ),
      ],
    );
  },
);
