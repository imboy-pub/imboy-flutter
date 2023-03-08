import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';

/// 1.长按  2.单击
enum PressType { longPress, singleClick }

class WPopupMenu extends StatefulWidget {
  const WPopupMenu({
    Key? key,
    required this.onValueChanged,
    required this.actions,
    required this.child,
    this.pressType = PressType.singleClick,
    this.pageMaxChildCount = 5,
    this.backgroundColor = Colors.black,
    this.menuWidth = 250,
    this.menuHeight = 250,
    this.alignment,
    this.padding,
    Color? color,
    // required Decoration decoration,
    this.foregroundDecoration,
    double? width,
    double? height,
    // BoxConstraints? constraints,
    this.margin,
    this.transform,
    this.constraints,
    this.decoration,
  }) : super(key: key);

  final BoxConstraints? constraints;
  final Decoration? decoration;
  final AlignmentGeometry? alignment;
  final EdgeInsets? padding;
  final Decoration? foregroundDecoration;
  final EdgeInsets? margin;
  final Matrix4? transform;
  final ValueChanged<String> onValueChanged;
  final List actions;
  final Widget child;
  final PressType pressType; // 点击方式 长按 还是单击
  final int pageMaxChildCount;
  final Color backgroundColor;
  final double menuWidth;
  final double menuHeight;

  @override
  // ignore: library_private_types_in_public_api
  _WPopupMenuState createState() => _WPopupMenuState();
}

class _WPopupMenuState extends State<WPopupMenu> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      child: Container(
        key: widget.key,
        padding: widget.padding,
        margin: widget.margin,
        decoration: widget.decoration,
        constraints: widget.constraints,
        transform: widget.transform,
        alignment: widget.alignment,
        child: widget.child,
      ),
      onTap: () {
        if (widget.pressType == PressType.singleClick) {
          onTap();
        }
      },
    );
  }

  void onTap() {
    Navigator.push(
        context,
        PopupMenuRoute(
          context,
          widget.actions,
          widget.pageMaxChildCount,
          widget.backgroundColor,
          widget.menuWidth,
          widget.menuHeight,
          widget.padding!,
          widget.margin!,
          widget.onValueChanged,
        )).then((index) {
      widget.onValueChanged(index);
    });
  }
}

class PopupMenuRoute extends PopupRoute {
  final BuildContext btnContext;
  double? _height;
  double? _width;
  final List actions;
  final int _pageMaxChildCount;
  final Color backgroundColor;
  final double menuWidth;
  final double menuHeight;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final ValueChanged<String> onValueChanged;

  PopupMenuRoute(
      this.btnContext,
      this.actions,
      this._pageMaxChildCount,
      this.backgroundColor,
      this.menuWidth,
      this.menuHeight,
      this.padding,
      this.margin,
      this.onValueChanged) {
    _height = btnContext.size!.height - margin.vertical;
    _width = btnContext.size!.width - margin.horizontal;
  }

  @override
  Animation<double> createAnimation() {
    return CurvedAnimation(
      parent: super.createAnimation(),
      curve: Curves.linear,
      reverseCurve: const Interval(0.0, 2.0 / 3.0),
    );
  }

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    return MenuPopWidget(
        btnContext,
        _height!,
        _width!,
        actions,
        _pageMaxChildCount,
        backgroundColor,
        menuWidth,
        menuHeight,
        padding,
        margin);
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);
}

class MenuPopWidget extends StatefulWidget {
  final BuildContext btnContext;
  final double _height;
  final double _width;
  final List actions;
  final int _pageMaxChildCount;
  final Color backgroundColor;
  final double menuWidth;
  final double menuHeight;
  final EdgeInsets padding;
  final EdgeInsets margin;

  // ignore: use_key_in_widget_constructors
  const MenuPopWidget(
    this.btnContext,
    this._height,
    this._width,
    this.actions,
    this._pageMaxChildCount,
    this.backgroundColor,
    this.menuWidth,
    this.menuHeight,
    this.padding,
    this.margin,
  );

  @override
  // ignore: library_private_types_in_public_api
  _MenuPopWidgetState createState() => _MenuPopWidgetState();
}

class _MenuPopWidgetState extends State<MenuPopWidget> {
  final int _curPage = 0;
  final double _separatorWidth = 1;
  final double _triangleHeight = 10;
  bool isShow = true;

  Color itemColor = AppColors.ItemBgColor;

  RenderBox? button;
  RenderBox? overlay;
  RelativeRect? position;

  @override
  void initState() {
    super.initState();
    button = widget.btnContext.findRenderObject() as RenderBox?;
    overlay =
        Overlay.of(widget.btnContext).context.findRenderObject() as RenderBox?;
    position = RelativeRect.fromRect(
      Rect.fromPoints(
        button!.localToGlobal(const Offset(-10, 100), ancestor: overlay),
        button!.localToGlobal(const Offset(-10, 0), ancestor: overlay),
      ),
      Offset.zero & overlay!.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: Builder(builder: (BuildContext context) {
        return CustomSingleChildLayout(
          // 这里计算偏移量
          delegate: PopupMenuRouteLayout(
              position!,
              widget.menuHeight + _triangleHeight,
              Directionality.of(widget.btnContext),
              widget._width,
              widget.menuWidth,
              widget._height),
          child: contentBuild(),
        );
      }),
    );
  }

  Widget body(width) {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Visibility(
        visible: isShow,
        child: CustomPaint(
          size: Size(width, _triangleHeight),
          painter: TrianglePainter(
              color: AppColors.ItemBgColor,
              position: position!,
              isInverted: true,
              size: button!.size),
        ),
      ),
      Visibility(
        visible: isShow,
        child: Expanded(
          child: Stack(children: <Widget>[
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(5)),
              child: Container(
                  color: AppColors.ItemBgColor, height: widget.menuHeight),
            ),
            Column(
              children: widget.actions.map(itemBuild).toList(),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget contentBuild() {
    // 这里计算出来 当前页的 child 一共有多少个
    int curPageChildCount =
        (_curPage + 1) * widget._pageMaxChildCount > widget.actions.length
            ? widget.actions.length % widget._pageMaxChildCount
            : widget._pageMaxChildCount;

    double curArrowWidth = 0;
    int curArrowCount = 0; // 一共几个箭头
    double curPageWidth = widget.menuWidth +
        (curPageChildCount - 1 + curArrowCount) * _separatorWidth +
        curArrowWidth;
    return SizedBox(
      height: widget.menuHeight + _triangleHeight,
      width: curPageWidth,
      child: Material(color: Colors.transparent, child: body(curPageWidth)),
    );
  }

  Widget itemBuild(item) {
    var row = [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10.0),
        child: strNoEmpty(item['icon'])
            ? Image(image: AssetImage(item['icon']))
            : const Icon(Icons.phone, color: Colors.white),
      ),
      Expanded(
        child: Container(
          height: 50,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
              border: item['title'] == widget.actions[0]['title']
                  ? null
                  : Border(
                      top: BorderSide(
                          color: Colors.white.withOpacity(0.3), width: 0.2))),
          child: Text(
            item['title'],
            style: const TextStyle(color: Colors.white),
          ),
        ),
      )
    ];
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: EdgeInsets.zero,
        // backgroundColor: Colors.white,
      ),
      autofocus: true,
      onPressed: () {
        isShow = false;
        setState(() {});
        Navigator.of(context).pop(item['title']);
      },
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        padding: const EdgeInsets.only(left: 10.0),
        child: Row(children: row),
      ),
    );
  }
}

const double _kMenuScreenPadding = 8.0;

// Positioning of the menu on the screen.
class PopupMenuRouteLayout extends SingleChildLayoutDelegate {
  PopupMenuRouteLayout(this.position, this.selectedItemOffset,
      this.textDirection, this.width, this.menuWidth, this.height);

  // Rectangle of underlying button, relative to the overlay's dimensions.
  final RelativeRect position;

  // The distance from the top of the menu to the middle of selected item.
  //
  // This will be null if there's no item to position in this way.
  final double selectedItemOffset;

  // Whether to prefer going to the left or to the right.
  final TextDirection textDirection;

  final double width;
  final double height;
  final double menuWidth;

  // We put the child wherever position specifies, so long as it will fit within
  // the specified parent size padded (inset) by 8. If necessary, we adjust the
  // child's position so that it fits.

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    // The menu can be at most the size of the overlay minus 8.0 pixels in each
    // direction.
    return BoxConstraints.loose(constraints.biggest -
            const Offset(_kMenuScreenPadding * 2.0, _kMenuScreenPadding * 2.0)
        as Size);
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    // size: The size of the overlay.
    // childSize: The size of the menu, when fully open, as determined by
    // getConstraintsForChild.

    // Find the ideal vertical position.
    double y = position.bottom +
        (size.height - position.top - position.bottom) / 2.0 -
        selectedItemOffset;

    // Find the ideal horizontal position.
    double x;

    // 如果menu 的宽度 小于 child 的宽度，则直接把menu 放在 child 中间
    if (childSize.width < width) {
      x = position.left + (width - childSize.width) / 2;
    } else {
      // 如果靠右
      if (position.left > size.width - (position.left + width)) {
        if (size.width - (position.left + width) >
            childSize.width / 2 + _kMenuScreenPadding) {
          x = position.left - (childSize.width - width) / 2;
        } else {
          x = position.left + width - childSize.width;
        }
      } else if (position.left < size.width - (position.left + width)) {
        if (position.left > childSize.width / 2 + _kMenuScreenPadding) {
          x = position.left - (childSize.width - width) / 2;
        } else {
          x = position.left;
        }
      } else {
        x = position.right - width / 2 - childSize.width / 2;
      }
    }

    if (y < _kMenuScreenPadding) {
      y = _kMenuScreenPadding;
    } else if (y + childSize.height > size.height - _kMenuScreenPadding) {
      y = size.height - childSize.height;
    } else if (y < childSize.height * 2) {
      y = position.top + height;
    }
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(PopupMenuRouteLayout oldDelegate) {
    return position != oldDelegate.position;
  }
}

class TrianglePainter extends CustomPainter {
  Paint? _paint;
  final Color color;
  final RelativeRect position;
  final Size size;
  final double radius;
  final bool isInverted;

  TrianglePainter({
    required this.color,
    required this.position,
    required this.size,
    this.radius = 20,
    this.isInverted = false,
  }) {
    _paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color
      ..strokeWidth = 10
      ..isAntiAlias = true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path();

    // 如果 menu 的长度 大于 child 的长度
    if (size.width > this.size.width) {
      // 靠右
      if (position.left + this.size.width / 2 > position.right) {
        path.moveTo(size.width - this.size.width + this.size.width / 2,
            isInverted ? 0 : size.height);
        path.lineTo(
            size.width - this.size.width + this.size.width / 2 - radius / 2,
            isInverted ? size.height : 0);
        path.lineTo(
            size.width - this.size.width + this.size.width / 2 + radius / 2,
            isInverted ? size.height : 0);
      } else {
        // 靠左
        path.moveTo(this.size.width / 2, isInverted ? 0 : size.height);
        path.lineTo(
            this.size.width / 2 - radius / 2, isInverted ? size.height : 0);
        path.lineTo(
            this.size.width / 2 + radius / 2, isInverted ? size.height : 0);
      }
    } else {
      path.moveTo(size.width / 2, isInverted ? 0 : size.height);
      path.lineTo(size.width / 2 - radius / 2, isInverted ? size.height : 0);
      path.lineTo(size.width / 2 + radius / 2, isInverted ? size.height : 0);
    }

    path.close();

    canvas.drawPath(
      path,
      _paint!,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
