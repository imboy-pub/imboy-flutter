import 'package:flutter/material.dart';

class DragArea extends StatefulWidget {
  final Widget child;

  const DragArea({Key? key, required this.child}) : super(key: key);

  @override
  _DragAreaStateStateful createState() => _DragAreaStateStateful();
}

class _DragAreaStateStateful extends State<DragArea> {
  Offset position = const Offset(0, 200);
  double prevScale = 1;
  double scale = 1;

  void updateScale(double zoom) => setState(() => scale = prevScale * zoom);
  void commitScale() => setState(() => prevScale = scale);
  void updatePosition(Offset newPosition) {
    bool isLeft = true;
    final maxY = MediaQuery.of(context).size.height - 90;
    if (newPosition.dx + 48 > MediaQuery.of(context).size.width / 2) {
      isLeft = false;
    }
    final rebuildPosition = Offset(
        isLeft ? 2 : MediaQuery.of(context).size.width - 98,
        newPosition.dy < 45
            ? 45
            : newPosition.dy > maxY
                ? maxY
                : newPosition.dy);
    setState(() => position = rebuildPosition);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // onScaleUpdate: (details) => updateScale(details.scale),
      // onScaleEnd: (_) => commitScale(),
      child: Stack(
        children: [
          Positioned(
            left: position.dx,
            top: position.dy,
            child: Draggable(
              maxSimultaneousDrags: 1,
              feedback: widget.child,
              childWhenDragging: Container(),
              onDragEnd: (details) => updatePosition(details.offset),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}
