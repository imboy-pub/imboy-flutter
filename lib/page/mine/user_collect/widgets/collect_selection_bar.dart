import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// Responsive actions for the current collection selection.
class CollectSelectionBar extends StatelessWidget {
  const CollectSelectionBar({
    super.key,
    required this.count,
    required this.onSelectAll,
    required this.onTag,
    required this.onDelete,
    required this.onCancel,
  });

  final int count;
  final VoidCallback onSelectAll;
  final VoidCallback onTag;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppSpacing.small,
        runSpacing: AppSpacing.tiny,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              '${t.main.selected}: $count',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onSelectAll,
            child: Icon(
              CupertinoIcons.square_list,
              size: 20,
              semanticLabel: t.common.selectAll,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onTag,
            child: Icon(
              CupertinoIcons.tag,
              size: 20,
              semanticLabel: t.common.editTag,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onDelete,
            child: Icon(
              CupertinoIcons.delete,
              color: AppColors.getIosRed(brightness),
              size: 20,
              semanticLabel: t.common.buttonDelete,
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onCancel,
            child: Icon(
              CupertinoIcons.xmark_circle,
              size: 20,
              semanticLabel: t.common.buttonCancel,
            ),
          ),
        ],
      ),
    );
  }
}
