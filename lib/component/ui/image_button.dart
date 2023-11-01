import 'package:flutter/material.dart';

class ImageButton extends StatefulWidget {
  const ImageButton({
    super.key,
    required this.onPressed,
    required this.image,
    this.width,
    this.height,
    this.title,
  });

  final Widget image;
  final void Function()? onPressed;
  final double? width;
  final double? height;
  final String? title;

  @override
  // ignore: library_private_types_in_public_api
  _ImageButtonState createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: widget.width ?? 44,
        height: widget.height ?? 44,
        alignment: Alignment.center,
        child: widget.image,
      ),
    );
  }
}
