import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class IconTextView extends StatefulWidget {
  // 左侧 图标
  final Widget? leftIcon;
  // 左侧 图标资源地址
  final String? leftIconAsset;
  // 左侧 文案
  final String? leftText;
  // 左侧 文案组件
  final Widget? leftTextWidget;
  // 右侧 文案
  final String? rightText;
  // 右侧 文案组件
  final Widget? rightTextWidget;
  // 右侧 图标组件
  final Widget? rightIcon;
  // 右侧 图标资源地址
  final String? rightIconAsset;
  // 是否显示右侧箭头，默认显示
  final bool? shotArrow;
  // 点击事件
  final VoidCallback? onPressed;
  final decoration;
  final double height;
  final double paddingLeft;

  const IconTextView({
    this.leftIcon,
    this.leftIconAsset,
    this.leftText,
    this.leftTextWidget,
    this.rightText,
    this.rightTextWidget,
    this.rightIcon,
    this.rightIconAsset,
    this.onPressed,
    this.shotArrow = true,
    this.decoration,
    this.height = 48,
    this.paddingLeft = 10,
  });

  @override
  _IconTextViewState createState() => _IconTextViewState();
}

class _IconTextViewState extends State<IconTextView> {
  bool _isClickDown = false;

  @override
  Widget build(BuildContext context) {
    final List<Widget> leftList = [];
    final List<Widget> rightList = [];

    if (widget.leftIcon != null) {
      leftList.add(Container(
        padding: const EdgeInsets.only(left: 0, right: 10),
        child: widget.leftIcon,
      ));
    }

    if (widget.leftIconAsset != null) {
      Widget leftIconAssetWidget = Container(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Image.asset(widget.leftIconAsset!, width: 36, height: 36),
      );
      leftList.add(leftIconAssetWidget);
    }

    if (widget.leftText != null) {
      leftList.add(Container(
          padding: const EdgeInsets.only(left: 0),
          child: Text(widget.leftText!, style: const TextStyle(fontSize: 16))));
    }

    if (widget.leftTextWidget != null) {
      leftList.add(widget.leftTextWidget!);
    }

    if (widget.rightText != null) {
      rightList.add(Text(
        widget.rightText!,
        style: const TextStyle(fontSize: 15),
      ));
    }

    if (widget.rightTextWidget != null) {
      rightList.add(widget.rightTextWidget!);
    }

    if (widget.rightIcon != null) {
      rightList.add(widget.rightIcon!);
    }

    if (widget.rightIconAsset != null) {
      Widget leftIconAssetWidget = Container(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Image.asset(widget.rightIconAsset!, width: 36, height: 36),
      );
      rightList.add(leftIconAssetWidget);
    }

    if (widget.shotArrow == true) {
      Widget leftIconAssetWidget = Container(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: const Icon(Icons.chevron_right),
      );
      rightList.add(leftIconAssetWidget);
    }

    void _onViewClickDown(TapDownDetails d) {
      setState(() {
        _isClickDown = true;
      });
    }

    void _onViewClickUp(TapUpDetails d) {
      setState(() {
        _isClickDown = false;
      });
    }

    void _onViewClickCancel() {
      setState(() {
        _isClickDown = false;
      });
    }

    return GestureDetector(
      onTap: widget.onPressed,
      onTapDown: _onViewClickDown,
      onTapUp: _onViewClickUp,
      onTapCancel: _onViewClickCancel,
      child: Container(
//          color: isClickDown ? Colors.red : Colors.white,
          height: widget.height,
          decoration: widget.decoration ??
              (BoxDecoration(
                  color: _isClickDown ? const Color(0xFFEEEEEE) : Colors.white)),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: widget.paddingLeft,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: leftList.toList(),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: rightList.toList(),
                ),
              ),
            ],
          )),
    );
  }
}
