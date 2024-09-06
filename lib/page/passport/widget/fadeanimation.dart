import 'package:flutter/material.dart';

class FadeAnimation extends StatelessWidget {
  final double delay;
  final Widget child;

  const FadeAnimation(
      {super.key, required this.delay, required this.child, AssetImage? image});

  @override
  Widget build(BuildContext context) {
    // final tween = MultiTween<AniProps>()
    //   ..add(AniProps.opacity, 0.0.tweenTo(1.0), 500.milliseconds)
    //   ..add(AniProps.translateY, (-30.0).tweenTo(0.0), 500.milliseconds,
    //       Curves.easeOut);
    /*
    final tween = MultiTrackTween([
      Track("opacity").add(Duration(milliseconds: 500), Tween(begin: 0.0, end: 1.0)),
      Track("translateY").add(
          Duration(milliseconds: 500), Tween(begin: -30.0, end: 0.0),
          curve: Curves.easeOut)
    ]);*/

    return AnimatedOpacity(
      // If the widget is visible, animate to 0.0 (invisible).
      // If the widget is hidden, animate to 1.0 (fully visible).
      // opacity: _visible ? 1.0 : 0.0,
      opacity: .9,
      duration: Duration(milliseconds: delay.toInt()),
      // The green box must be a child of the AnimatedOpacity widget.
      child: child,
    );
  }
}
