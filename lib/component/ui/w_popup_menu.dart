import 'package:flutter/material.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';

/// 1.长按  2.单击
enum PressType { longPress, singleClick }

class WPopupMenu extends StatefulWidget {
  WPopupMenu({
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
  })  : assert(onValueChanged != null),
        assert(actions != null && actions.length > 0),
        assert(child != null),
        assert(margin == null || margin.isNonNegative),
        assert(padding == null || padding.isNonNegative),
        assert(decoration == null || decoration.debugAssertIsValid()),
        assert(constraints == null || constraints.debugAssertIsValid()),
        assert(
            color == null || decoration == null,
            'Cannot provide both a color and a decoration\n'
            'The color argument is just a shorthand for "decoration: new BoxDecoration(color: color)".'),
        // decoration =
        //     decoration ?? (color != null ? BoxDecoration(color: color) : null),
        // constraints = (width != null || height != null)
        //     ? constraints?.tighten(width: width, height: height) ??
        //         BoxConstraints.tightFor(width: width, height: height)
        //     : constraints,
        super(key: key);

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
  _WPopupMenuState createState() => _WPopupMenuState();
}

class _WPopupMenuState extends State<WPopupMenu> {
  @override
  Widget build(BuildContext context) {
    return new InkWell(
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
        new PopupMenuRoute(
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
    _height = btnContext.size!.height -
        (padding == null
            ? margin == null
                ? 0
                : margin.vertical
            : padding.vertical);
    _width = btnContext.size!.width -
        (padding == null
            ? margin == null
                ? 0
                : margin.horizontal
            : padding.horizontal);
  }

  @override
  Animation<double> createAnimation() {
    return new CurvedAnimation(
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
    return new MenuPopWidget(
        this.btnContext,
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
  Duration get transitionDuration => new Duration(milliseconds: 300);
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

  MenuPopWidget(
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
  _MenuPopWidgetState createState() => _MenuPopWidgetState();
}

class _MenuPopWidgetState extends State<MenuPopWidget> {
  int _curPage = 0;
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
        Overlay.of(widget.btnContext)!.context.findRenderObject() as RenderBox?;
    position = new RelativeRect.fromRect(
      new Rect.fromPoints(
        button!.localToGlobal(Offset(-10, 100), ancestor: overlay),
        button!.localToGlobal(Offset(-10, 0), ancestor: overlay),
      ),
      Offset.zero & overlay!.size,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeBottom: true,
      removeLeft: true,
      removeRight: true,
      child: Builder(builder: (BuildContext context) {
        return new CustomSingleChildLayout(
          // 这里计算偏移量
          delegate: new PopupMenuRouteLayout(
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
    return new Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      new Visibility(
        visible: isShow,
        child: new CustomPaint(
          size: Size(width, _triangleHeight),
          painter: new TrianglePainter(
              color: AppColors.ItemBgColor,
              position: position!,
              isInverted: true,
              size: button!.size),
        ),
      ),
      new Visibility(
        visible: isShow,
        child: new Expanded(
          child: Stack(children: <Widget>[
            new ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              child: Container(color: AppColors.ItemBgColor, height: widget.menuHeight),
            ),
            new Column(
              children: widget.actions.map(itemBuild).toList(),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget contentBuild() {
    // 这里计算出来 当前页的 child 一共有多少个
    int _curPageChildCount =
        (_curPage + 1) * widget._pageMaxChildCount > widget.actions.length
            ? widget.actions.length % widget._pageMaxChildCount
            : widget._pageMaxChildCount;

    double _curArrowWidth = 0;
    int _curArrowCount = 0; // 一共几个箭头
    double _curPageWidth = widget.menuWidth +
        (_curPageChildCount - 1 + _curArrowCount) * _separatorWidth +
        _curArrowWidth;
    return SizedBox(
      height: widget.menuHeight + _triangleHeight,
      width: _curPageWidth,
      child:
          new Material(color: Colors.transparent, child: body(_curPageWidth)),
    );
  }

  Widget itemBuild(item) {
    var row = [
      new Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0),
        child: strNoEmpty(item['icon'])
            ? new Image(image: AssetImage(item['icon']))
            : new Icon(Icons.phone, color: Colors.white),
      ),
      new Expanded(
        child: new Container(
          height: 50,
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(
              border: item['title'] == widget.actions[0]['title']
                  ? null
                  : Border(
                      top: BorderSide(
                          color: Colors.white.withOpacity(0.3), width: 0.2))),
          child: new Text(
            item['title'],
            style: TextStyle(color: Colors.white),
          ),
        ),
      )
    ];
    return new TextButton(
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
      child: new Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        padding: EdgeInsets.only(left: 10.0),
        child: new Row(children: row),
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
    double y;
    if (selectedItemOffset == null) {
      y = position.top;
    } else {
      y = position.bottom +
          (size.height - position.top - position.bottom) / 2.0 -
          selectedItemOffset;
    }

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
        } else
          x = position.left + width - childSize.width;
      } else if (position.left < size.width - (position.left + width)) {
        if (position.left > childSize.width / 2 + _kMenuScreenPadding) {
          x = position.left - (childSize.width - width) / 2;
        } else
          x = position.left;
      } else {
        x = position.right - width / 2 - childSize.width / 2;
      }
    }

    if (y < _kMenuScreenPadding)
      y = _kMenuScreenPadding;
    else if (y + childSize.height > size.height - _kMenuScreenPadding)
      y = size.height - childSize.height;
    else if (y < childSize.height * 2) {
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
