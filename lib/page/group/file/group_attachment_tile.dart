import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:imboy/theme/default/app_colors.dart';
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
      leading: const Icon(CupertinoIcons.doc),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          category,
          size,
          if (time != null) DateFormat('MM/dd HH:mm').format(time.toLocal()),
        ].where((value) => value.isNotEmpty).join(' · '),
      ),
      trailing: onDelete == null
          ? const CupertinoListTileChevron()
          : IconButton(
              tooltip: deleteLabel,
              icon: const Icon(CupertinoIcons.delete, color: AppColors.iosRed),
              onPressed: onDelete,
            ),
      onTap: onOpen,
    );
  }
}
