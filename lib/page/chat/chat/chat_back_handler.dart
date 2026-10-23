import 'package:flutter/widgets.dart';

/// A delayed composer close may only pop the same, still-current chat route.
Future<void> popChatAfterHidingPanels(
  BuildContext context,
  VoidCallback hidePanels,
) async {
  final navigator = Navigator.of(context);
  final route = ModalRoute.of(context);
  hidePanels();
  await Future<void>.delayed(const Duration(milliseconds: 300));
  if (!context.mounted ||
      route?.isCurrent != true ||
      route?.navigator != navigator ||
      route?.popDisposition != RoutePopDisposition.pop ||
      !navigator.canPop()) {
    return;
  }
  navigator.pop();
}
