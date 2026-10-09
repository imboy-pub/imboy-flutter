import 'package:flutter/cupertino.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Each field is one tag; punctuation inside a tag is never a delimiter.
class PostTagsDialog extends StatefulWidget {
  const PostTagsDialog({super.key, required this.initialTags});
  final List<String> initialTags;
  @override
  State<PostTagsDialog> createState() => _PostTagsDialogState();
}

class _PostTagsDialogState extends State<PostTagsDialog> {
  late final List<TextEditingController> _inputs = List.generate(
    5,
    (index) => TextEditingController(
      text: index < widget.initialTags.length ? widget.initialTags[index] : '',
    ),
  );
  @override
  void dispose() {
    for (final input in _inputs) {
      input.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CupertinoAlertDialog(
    title: Text(context.t.channel.editPostTags),
    content: Column(
      children: [
        for (var index = 0; index < _inputs.length; index++)
          Padding(
            padding: AppSpacing.allSmall,
            child: CupertinoTextField(
              key: Key('mc_post_tags_input_$index'),
              controller: _inputs[index],
            ),
          ),
      ],
    ),
    actions: [
      CupertinoDialogAction(
        onPressed: () => Navigator.pop(context),
        child: Text(context.t.common.buttonCancel),
      ),
      CupertinoDialogAction(
        key: const Key('mc_post_tags_confirm'),
        onPressed: () => Navigator.pop(
          context,
          _inputs
              .map((input) => input.text.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(),
        ),
        child: Text(context.t.common.buttonConfirm),
      ),
    ],
  );
}
