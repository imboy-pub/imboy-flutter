import 'package:flutter/material.dart';

class NoDataView extends StatelessWidget {
  final String text;
  final VoidCallback? onTop;

  const NoDataView({
    super.key,
    required this.text,
    this.onTop,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTop,
        child: Text(
          text,
          // style: const TextStyle(color: AppColors.MainTextColor),
        ),
      ),
    );
  }
}
