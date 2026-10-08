import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 投票内容是普通文本：允许输入法候选词与中文 composing，避免安全键盘。
class GroupVoteInputFields extends StatelessWidget {
  const GroupVoteInputFields({
    super.key,
    required this.titleController,
    required this.optionsController,
  });
  final TextEditingController titleController;
  final TextEditingController optionsController;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: AppSpacing.small),
      CupertinoTextField(
        controller: titleController,
        keyboardType: TextInputType.text,
        enableSuggestions: true,
        autocorrect: true,
        placeholder: t.groupVote.voteTitle,
      ),
      const SizedBox(height: AppSpacing.regular),
      CupertinoTextField(
        controller: optionsController,
        keyboardType: TextInputType.multiline,
        enableSuggestions: true,
        autocorrect: true,
        maxLines: 4,
        placeholder: t.groupVote.eachOptionPerLine,
      ),
    ],
  );
}
