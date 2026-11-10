import 'package:flutter/cupertino.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';

/// A missing or unavailable post still has a title and a return path.
class MomentDetailStateView extends StatelessWidget {
  const MomentDetailStateView({
    super.key,
    required this.loadFailed,
    required this.onRetry,
  });

  final bool loadFailed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return IosPageTemplate(
      title: t.discovery.moments,
      useLargeTitle: false,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: NoDataView(
            text: loadFailed ? t.common.loadError : t.common.momentsNotFound,
            icon: loadFailed
                ? CupertinoIcons.wifi_exclamationmark
                : CupertinoIcons.chat_bubble,
            onTop: loadFailed ? onRetry : null,
          ),
        ),
      ],
    );
  }
}
