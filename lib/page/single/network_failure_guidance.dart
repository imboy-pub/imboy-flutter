import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';

class NetworkFailureGuidancePage extends ConsumerWidget {
  const NetworkFailureGuidancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.common.networkException,
      ),
      body: Card(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                t.common.error.suggestCheckNetwork,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 17.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ), // left: 16, right: 16
                        child: Text(
                          '${t.common.error.networkTroubleshootingStep1}\n\n'
                          '${t.common.error.networkTroubleshootingStep2}\n\n'
                          '${t.common.error.networkTroubleshootingStep3}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
