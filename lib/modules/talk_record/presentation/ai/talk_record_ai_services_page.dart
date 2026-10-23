import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/config/router/routes/talk_record_routes.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/talk_record/application/ai/talk_record_ai_credentials.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'talk_record_ai_providers.dart';
import 'talk_record_ai_widgets.dart';

class TalkRecordAiServicesPage extends ConsumerWidget {
  const TalkRecordAiServicesPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(talkRecordAiSessionProvider);
    return IosPageTemplate(
      title: t.talkRecord.aiServicesTitle,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.regular),
          children: [
            TalkRecordAiText(t.talkRecord.aiServicesSubtitle),
            TalkRecordAiText(t.talkRecord.aiAsrOptionalNotice),
            const SizedBox(height: AppSpacing.regular),
            if (identity == null)
              TalkRecordAiText(t.talkRecord.aiAccountChanged, error: true)
            else
              TalkRecordAiCard(
                child: Column(
                  children: [
                    for (final provider in TalkRecordAiProvider.values)
                      _ProviderRow(provider: provider),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.regular),
            TalkRecordAiText(t.talkRecord.aiDeviceOnlyNotice),
            const SizedBox(height: AppSpacing.regular),
            TalkRecordAiText(t.talkRecord.aiEnterprisePolicyNotice),
          ],
        ),
      ),
    );
  }
}

class _ProviderRow extends ConsumerWidget {
  const _ProviderRow({required this.provider});
  final TalkRecordAiProvider provider;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(talkRecordAiStatusProvider(provider));
    final state = status.when(
      data: (value) => value.configured
          ? t.talkRecord.aiConfigured
          : t.talkRecord.aiNotConfigured,
      loading: () => t.talkRecord.aiLoading,
      error: (error, _) => talkRecordAiError(error),
    );
    final use = talkRecordAiProviderPurpose(provider);
    return TalkRecordAiEntryRow(
      key: ValueKey('talk_record_ai_${provider.name}'),
      title: talkRecordAiProviderTitle(provider),
      subtitle: '$use\n$state',
      onTap: () => context.push('$kTalkRecordAiServicesPath/${provider.name}'),
    );
  }
}
