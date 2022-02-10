import 'package:flutter/material.dart';

class ImageButton extends StatefulWidget {
  const ImageButton({
    Key? key,
    required this.onPressed,
    required this.image,
    double? this.width,
    double? this.height,
    String? this.title,
  }) : super(key: key);

  final ImageProvider image;
  final void Function()? onPressed;
  final double? width;
  final double? height;
  final String? title;

  @override
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
        child: Image(
          image: widget.image,
          width: widget.width ?? 35,
          height: widget.height ?? 35,
        ),
      ),
    );
  }
}
