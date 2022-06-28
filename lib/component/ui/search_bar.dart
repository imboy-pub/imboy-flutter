import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';
import 'package:niku/namespace.dart' as n;

class SearchBar extends StatelessWidget {
  final GestureTapCallback? onTap;
  final String text;
  final bool isBorder;

  const SearchBar({
    Key? key,
    this.onTap,
    required this.text,
    this.isBorder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: isBorder
              ? const Border(
                  bottom: BorderSide(color: Colors.grey, width: 0.2),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 15.0),
        child: n.Row([
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0),
            child: Icon(Icons.search, color: AppColors.MainTextColor),
          ),
          Text(
            text,
            style: const TextStyle(color: AppColors.MainTextColor),
          )
        ]),
      ),
      onTap: onTap ?? () {},
    );
  }
}
