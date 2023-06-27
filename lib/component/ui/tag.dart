import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

///
class TagItem extends StatelessWidget {
  final String tag;
  final Function(String tag) onTagDelete;

  const TagItem({
    Key? key,
    required this.tag,
    required this.onTagDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
        color: AppColors.primaryElement.withOpacity(0.2),
      ),
      margin: const EdgeInsets.only(right: 10.0),
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 4.0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 18,
                color: AppColors.primaryElement,
              ),
            ),
            onTap: () {
              //print("$tag selected");
            },
          ),
          const SizedBox(width: 4.0),
          InkWell(
            child: const Icon(
              Icons.cancel,
              size: 14.0,
              color: AppColors.primaryElement,
            ),
            onTap: () {
              onTagDelete(tag);
            },
          )
        ],
      ),
    );
  }
}
