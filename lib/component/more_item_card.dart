import 'package:flutter/material.dart';

class MoreItemCard extends StatelessWidget {
  final String? name, icon;
  final VoidCallback? onPressed;
  final double? keyboardHeight;

  const MoreItemCard({
    super.key,
    this.name,
    this.icon,
    this.onPressed,
    this.keyboardHeight,
  });

  @override
  Widget build(BuildContext context) {
    double margin = keyboardHeight != 0.0 ? keyboardHeight! : 0.0;
    double top = margin != 0.0 ? margin / 10 : 20.0;

    return Container(
      padding: EdgeInsets.only(top: top, bottom: 5.0),
      width: (MediaQuery.of(context).size.width - 70) / 4,
      child: Column(
        children: <Widget>[
          Container(
            width: 50,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10.0)),
            ),
            child: TextButton(
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              onPressed: () {
                if (onPressed != null) {
                  onPressed!();
                }
              },
              // shape: RoundedRectangleBorder(
              //   borderRadius: BorderRadius.all(
              //     Radius.circular(10.0),
              //   ),
              // ),
              child: SizedBox(
                width: 50.0,
                child: Image(image: AssetImage(icon!), fit: BoxFit.cover),
              ),
            ),
          ),
          SizedBox(width: 5.0), // 使用 SizedBox 替代 Space
          Text(name ?? ''),
        ],
      ),
    );
  }
}
