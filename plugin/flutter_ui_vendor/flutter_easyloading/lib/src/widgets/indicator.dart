import 'package:material_ui/material_ui.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../types.dart';

/// A built-in animated indicator backed by `flutter_spinkit`.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    required this.type,
    required this.color,
    required this.size,
    required this.lineWidth,
  });

  final EasyLoadingIndicatorType type;
  final Color color;
  final double size;
  final double lineWidth;

  @override
  Widget build(BuildContext context) {
    var width = size;
    final Widget indicator;
    switch (type) {
      case EasyLoadingIndicatorType.fadingCircle:
        indicator = SpinKitFadingCircle(color: color, size: size);
      case EasyLoadingIndicatorType.circle:
        indicator = SpinKitCircle(color: color, size: size);
      case EasyLoadingIndicatorType.threeBounce:
        indicator = SpinKitThreeBounce(color: color, size: size);
        width = size * 2;
      case EasyLoadingIndicatorType.chasingDots:
        indicator = SpinKitChasingDots(color: color, size: size);
      case EasyLoadingIndicatorType.wave:
        indicator = SpinKitWave(color: color, size: size, itemCount: 6);
        width = size * 1.25;
      case EasyLoadingIndicatorType.wanderingCubes:
        indicator = SpinKitWanderingCubes(color: color, size: size);
      case EasyLoadingIndicatorType.rotatingPlain:
        indicator = SpinKitRotatingPlain(color: color, size: size);
      case EasyLoadingIndicatorType.doubleBounce:
        indicator = SpinKitDoubleBounce(color: color, size: size);
      case EasyLoadingIndicatorType.fadingFour:
        indicator = SpinKitFadingFour(color: color, size: size);
      case EasyLoadingIndicatorType.fadingCube:
        indicator = SpinKitFadingCube(color: color, size: size);
      case EasyLoadingIndicatorType.pulse:
        indicator = SpinKitPulse(color: color, size: size);
      case EasyLoadingIndicatorType.cubeGrid:
        indicator = SpinKitCubeGrid(color: color, size: size);
      case EasyLoadingIndicatorType.rotatingCircle:
        indicator = SpinKitRotatingCircle(color: color, size: size);
      case EasyLoadingIndicatorType.foldingCube:
        indicator = SpinKitFoldingCube(color: color, size: size);
      case EasyLoadingIndicatorType.pumpingHeart:
        indicator = SpinKitPumpingHeart(color: color, size: size);
      case EasyLoadingIndicatorType.dualRing:
        indicator = SpinKitDualRing(
          color: color,
          size: size,
          lineWidth: lineWidth,
        );
      case EasyLoadingIndicatorType.hourGlass:
        indicator = SpinKitHourGlass(color: color, size: size);
      case EasyLoadingIndicatorType.pouringHourGlass:
        indicator = SpinKitPouringHourGlass(color: color, size: size);
      case EasyLoadingIndicatorType.fadingGrid:
        indicator = SpinKitFadingGrid(color: color, size: size);
      case EasyLoadingIndicatorType.ring:
        indicator = SpinKitRing(color: color, size: size, lineWidth: lineWidth);
      case EasyLoadingIndicatorType.ripple:
        indicator = SpinKitRipple(color: color, size: size);
      case EasyLoadingIndicatorType.spinningCircle:
        indicator = SpinKitSpinningCircle(color: color, size: size);
      case EasyLoadingIndicatorType.squareCircle:
        indicator = SpinKitSquareCircle(color: color, size: size);
      case EasyLoadingIndicatorType.dancingSquare:
        indicator = SpinKitDancingSquare(color: color, size: size);
      case EasyLoadingIndicatorType.pianoWave:
        indicator = SpinKitPianoWave(color: color, size: size);
        width = size * 1.25;
      case EasyLoadingIndicatorType.pouringHourGlassRefined:
        indicator = SpinKitPouringHourGlassRefined(
          color: color,
          size: size,
          strokeWidth: lineWidth,
        );
      case EasyLoadingIndicatorType.pulsingGrid:
        indicator = SpinKitPulsingGrid(color: color, size: size);
      case EasyLoadingIndicatorType.spinningLines:
        indicator = SpinKitSpinningLines(
          color: color,
          size: size,
          lineWidth: lineWidth,
        );
      case EasyLoadingIndicatorType.threeInOut:
        indicator = SpinKitThreeInOut(color: color, size: size);
        width = size * 2;
      case EasyLoadingIndicatorType.waveSpinner:
        indicator = SpinKitWaveSpinner(color: color, size: size);
    }

    return SizedBox(
      width: width,
      height: size,
      child: Center(child: indicator),
    );
  }
}
