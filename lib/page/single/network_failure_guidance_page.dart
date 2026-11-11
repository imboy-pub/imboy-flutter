import 'package:flutter/material.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/resource_page_layout.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

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
      body: ResourcePageLayout(
        child: SingleChildScrollView(
          padding: AppSpacing.allRegular,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.error.suggestCheckNetwork,
                style: context.textStyle(
                  FontSizeType.body,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              AppSpacing.verticalRegular,
              Text(
                '${t.error.networkTroubleshootingStep1}\n\n'
                '${t.error.networkTroubleshootingStep2}\n\n'
                '${t.error.networkTroubleshootingStep3}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
