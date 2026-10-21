import 'package:flutter/cupertino.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

/// The card contains a locator only. Details always re-check the actor's ACL.
class TalkRecordCardMessageBuilder extends StatelessWidget {
  const TalkRecordCardMessageBuilder({super.key, required this.message});
  final CustomMessage message;
  @override
  Widget build(BuildContext context) {
    final id = message.metadata?['record_id']?.toString() ?? '';
    return CupertinoButton(
      padding: const EdgeInsets.all(AppSpacing.regular),
      onPressed: RegExp(r'^[0-9]+$').hasMatch(id)
          ? () => context.push('/talk-records/$id')
          : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(CupertinoIcons.doc_text),
          const SizedBox(width: AppSpacing.small),
          Flexible(
            child: Text(
              t.talkRecord.entryTitle,
              style: context.textStyle(FontSizeType.body),
            ),
          ),
          const SizedBox(width: AppSpacing.small),
          const Icon(CupertinoIcons.chevron_right),
        ],
      ),
    );
  }
}
