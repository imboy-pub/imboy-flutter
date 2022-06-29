import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

class SearchMainView extends StatelessWidget {
  final GestureTapCallback? onTap;
  final String? text;
  final bool? isBorder;

  const SearchMainView({Key? key,
    this.onTap,
    this.text,
    this.isBorder = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var row = Row(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.0),
          child: Icon(Icons.search, color: AppColors.MainTextColor),
        ),
        Text(
          text!,
          style: const TextStyle(color: AppColors.MainTextColor),
        )
      ],
    );

    return InkWell(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: isBorder!
              ? const Border(
                  bottom: BorderSide(color: AppColors.LineColor, width: 0.2),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(vertical: 15.0),
        child: row,
      ),
      onTap: onTap ?? () {},
    );
  }
}
