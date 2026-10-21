import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import '../application/talk_record_recording_runtime.dart';
import 'talk_record_entry_context.dart';
import 'talk_record_providers.dart';
import 'talk_record_recording_bar.dart';

/// Keeps recording controls visible across the root navigator's routes.
/// The footer reserves layout space instead of covering page content.
class TalkRecordRecordingHost extends ConsumerWidget {
  const TalkRecordRecordingHost({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authorized =
        UserRepoLocal.to.isLoggedIn && !UserRepoLocal.to.isAuthTransitioning;
    final runtime = authorized
        ? ref.watch(talkRecordRecordingRuntimeProvider).asData?.value
        : null;
    final ownsCapture =
        authorized &&
        runtime?.binding != null &&
        runtime!.binding!.account == currentTalkRecordAccount();
    final capture = ref.watch(talkRecordActiveCaptureProvider);
    return TalkRecordRecordingHostScope(
      child: Column(
        children: [
          Expanded(child: child),
          if (ref.watch(talkRecordStopUnconfirmedProvider))
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.regular),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.talkRecord.microphoneStopUnconfirmed),
                    TextButton(
                      onPressed: () async {
                        try {
                          final controller = await ref.read(
                            talkRecordRecordingRuntimeProvider.future,
                          );
                          await controller.retryMicrophoneStop();
                          if (context.mounted) {
                            ref
                                .read(
                                  talkRecordStopUnconfirmedProvider.notifier,
                                )
                                .set(controller.microphoneStopUnconfirmed);
                          }
                        } on Object {
                          // Failed resolution/stop retains the safety warning.
                        }
                      },
                      child: Text(t.common.retry),
                    ),
                  ],
                ),
              ),
            ),
          if (capture.visible && ownsCapture)
            SafeArea(
              top: false,
              child: TalkRecordGlobalRecordingBar(
                applicationHost: true,
                currentContext: const TalkRecordEntryContext.personal(),
                modalContext: () => navigatorKey.currentState?.overlay?.context,
              ),
            ),
        ],
      ),
    );
  }
}
