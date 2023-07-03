import 'package:flutter/material.dart';

///
class TagItem extends StatelessWidget {
  final String tag;
  final Function(String tag) onTagDelete;

  final Color backgroundColor;
  final Color selectedBackgroundColor;

  const TagItem({
    Key? key,
    required this.tag,
    required this.onTagDelete,
    this.backgroundColor = const Color(0xfff8f8f8),
    this.selectedBackgroundColor = const Color(0xFF649BEC),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(
          Radius.circular(20.0),
        ),
        color: selectedBackgroundColor,
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
              style: TextStyle(
                fontSize: 18,
                color: backgroundColor,
              ),
            ),
            onTap: () {
              //print("$tag selected");
            },
          ),
          const SizedBox(width: 4.0),
          InkWell(
            child: Icon(
              Icons.cancel,
              size: 14.0,
              color: backgroundColor,
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