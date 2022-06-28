import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';

class NoDataView extends StatelessWidget {
  final String text;
  final VoidCallback? onTop;

  const NoDataView({
    Key? key,
    required this.text,
    this.onTop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.MainTextColor),
        ),
        onTap: onTop,
      ),
    );
  }
}
