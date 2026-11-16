import 'package:flutter/widgets.dart';
import 'package:imboy/service/web_writer_gate.dart';

import 'init_error_page.dart';

/// Retain the app tree: unmount cleanup must not erase drafts on poison.
/// Actual sink guards and the runtime supervisor, not this overlay, stop writers.
class WebWriterFailureBoundary extends StatelessWidget {
  const WebWriterFailureBoundary({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: webWriterFailure,
    builder: (context, snapshot) {
      final failed = snapshot.connectionState == ConnectionState.done;
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: failed,
              child: ExcludeSemantics(
                excluding: failed,
                child: AbsorbPointer(absorbing: failed, child: child),
              ),
            ),
            if (failed)
              Positioned.fill(
                child: InitErrorPage(
                  error: const WebWriterGateFailure(
                    WebWriterFailureKind.poisoned,
                  ),
                  onRetry: reloadWebWriterPage,
                ),
              ),
          ],
        ),
      );
    },
  );
}
