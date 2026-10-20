import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/theme/default/app_spacing.dart';

class GroupAttachmentTile extends StatelessWidget {
  const GroupAttachmentTile({
    super.key,
    required this.name,
    required this.category,
    required this.size,
    required this.createdAt,
    required this.onOpen,
    required this.deleteLabel,
    this.onDelete,
  });
  final String name, category, size, createdAt, deleteLabel;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.tryParse(createdAt);
    return CupertinoListTile(
      padding: AppSpacing.allRegular,
      leading: SizedBox.square(
        dimension: AppSpacing.xxLarge,
        child: Icon(
          CupertinoIcons.doc,
          color: AppColors.getIosBlue(Theme.of(context).brightness),
        ),
      ),
      leadingSize: AppSpacing.xxLarge,
      leadingToTitle: AppSpacing.medium,
      title: Text(
        name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.body,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        [
          category,
          size,
          if (time != null) DateFormat('MM/dd HH:mm').format(time.toLocal()),
        ].where((value) => value.isNotEmpty).join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.textStyle(
          FontSizeType.footnote,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: onDelete == null
          ? const CupertinoListTileChevron()
          : IconButton(
              tooltip: deleteLabel,
              icon: Icon(
                CupertinoIcons.delete,
                color: AppColors.getIosRed(Theme.of(context).brightness),
              ),
              onPressed: onDelete,
            ),
      onTap: onOpen,
    );
  }
}
