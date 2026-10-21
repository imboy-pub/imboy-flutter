/// Android foreground recording requires a visible ongoing notification.
library;

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'talk_record_prepare_sections.dart';

enum TalkRecordNotificationPermissionStatus { granted, denied, restricted }

abstract class TalkRecordNotificationPermissionGateway {
  bool get required;
  Future<TalkRecordNotificationPermissionStatus> request();
  Future<void> openSettings();
}

class PermissionHandlerRecordingNotificationGateway
    implements TalkRecordNotificationPermissionGateway {
  const PermissionHandlerRecordingNotificationGateway();
  @override
  bool get required => !kIsWeb && Platform.isAndroid;
  @override
  Future<TalkRecordNotificationPermissionStatus> request() async {
    if (!required) return TalkRecordNotificationPermissionStatus.granted;
    final status = await Permission.notification.request();
    return switch (status) {
      PermissionStatus.granted || PermissionStatus.limited =>
        TalkRecordNotificationPermissionStatus.granted,
      PermissionStatus.permanentlyDenied || PermissionStatus.restricted =>
        TalkRecordNotificationPermissionStatus.restricted,
      _ => TalkRecordNotificationPermissionStatus.denied,
    };
  }

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }
}

final talkRecordNotificationPermissionGatewayProvider =
    Provider<TalkRecordNotificationPermissionGateway>(
      (ref) => const PermissionHandlerRecordingNotificationGateway(),
    );

class TalkRecordNotificationDeniedPanel extends StatelessWidget {
  const TalkRecordNotificationDeniedPanel({
    super.key,
    required this.onRetry,
    required this.onOpenSettings,
  });
  final VoidCallback onRetry;
  final Future<void> Function() onOpenSettings;
  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('talk_record_notification_denied_panel'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TalkRecordInfoPanel(
        title: t.talkRecord.notificationRequiredTitle,
        message: t.talkRecord.notificationRequiredMessage,
      ),
      const SizedBox(height: AppSpacing.small),
      Wrap(
        children: [
          CupertinoButton(
            key: const ValueKey('talk_record_notification_retry'),
            onPressed: onRetry,
            child: Text(t.common.retry),
          ),
          CupertinoButton(
            key: const ValueKey('talk_record_notification_settings'),
            onPressed: onOpenSettings,
            child: Text(t.talkRecord.openNotificationSettings),
          ),
        ],
      ),
    ],
  );
}
