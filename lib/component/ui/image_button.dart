import 'package:flutter/material.dart';

class ImageButton extends StatefulWidget {
  const ImageButton({
    Key? key,
    required this.onPressed,
    required this.image,
    int? width,
    int? height,
  }) : super(key: key);

  final ImageProvider image;
  final void Function()? onPressed;

  @override
  _ImageButtonState createState() => _ImageButtonState();
}

class _ImageButtonState extends State<ImageButton> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        child: Image(
          image: widget.image,
          width: 35,
          height: 35,
        ),
      ),
    );
  }
}
