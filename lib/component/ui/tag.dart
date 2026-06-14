import 'package:flutter/material.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_spacing.dart';

///
class TagItem extends StatelessWidget {
  final String tag;
  final void Function(String tag) onTagDelete;

  final Color backgroundColor;
  final Color selectedBackgroundColor;
  final Color tagSelectedColor;

  const TagItem({
    super.key,
    required this.tag,
    required this.onTagDelete,
    this.backgroundColor = AppColors.tagBackground,
    this.selectedBackgroundColor = AppColors.tagAccent,
    this.tagSelectedColor = AppColors.tagAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(20.0)),
        color: selectedBackgroundColor,
      ),
      margin: const EdgeInsets.only(right: 10.0, top: 6, bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: AppSpacing.tiny,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            child: Text(
              tag,
              style: TextStyle(fontSize: 18, color: tagSelectedColor),
            ),
            onTap: () {
              //print("$tag selected");
            },
          ),
          const SizedBox(width: 4.0),
          InkWell(
            child: Icon(Icons.cancel, size: 14.0, color: tagSelectedColor),
            onTap: () {
              onTagDelete(tag);
            },
          ),
        ],
      ),
    );
  }
}
