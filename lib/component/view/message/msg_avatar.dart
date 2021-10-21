import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/contact_detail/contact_detail_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/model/message_model.dart';

///封装之后的拍一拍效果[ShakeView]
class MsgAvatar extends StatefulWidget {
  // final GlobalModel global;
  final MessageModel model;

  MsgAvatar({
    // @required this.global,
    required this.model,
  });

  _MsgAvatarState createState() => _MsgAvatarState();
}

class _MsgAvatarState extends State<MsgAvatar> with TickerProviderStateMixin {
  Animation<double>? animation;
  AnimationController? controller;

  @override
  initState() {
    super.initState();
    start(true);
  }

  start(bool isInit) {
    controller = AnimationController(
        duration: const Duration(milliseconds: 500), vsync: this);
    animation = TweenSequence<double>([
      //使用TweenSequence进行多组补间动画
      TweenSequenceItem<double>(tween: Tween(begin: 0, end: 10), weight: 1),
      TweenSequenceItem<double>(tween: Tween(begin: 10, end: 0), weight: 1),
      TweenSequenceItem<double>(tween: Tween(begin: 0, end: -10), weight: 1),
      TweenSequenceItem<double>(tween: Tween(begin: -10, end: 0), weight: 1),
    ]).animate(controller!);
    if (!isInit) controller!.forward();
  }

  Widget build(BuildContext context) {
    ContactModel? to = widget.model.to as ContactModel?;
    return new InkWell(
      child: AnimateWidget(
        animation: animation!,
        child: new Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(5.0)),
          ),
          margin: EdgeInsets.only(right: 10.0),
          child: new ImageView(
            img: to!.avatar ?? defIcon,
            height: 50,
            width: 50,
            fit: BoxFit.cover,
          ),
        ),
      ),
      onDoubleTap: () {
        setState(() => start(false));
      },
      onTap: () {
        Get.to(() => ContactDetailPage(
              area: to.area,
              nickname: to.nickname!,
              avatar: to.avatar!,
              account: to.account!,
              id: to.uid!,
            ));
      },
    );
  }

  dispose() {
    controller!.dispose();
    super.dispose();
  }
}

class AnimateWidget extends AnimatedWidget {
  final Widget? child;

  AnimateWidget({
    required Animation<double> animation,
    this.child,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) {
    final Animation<double> animation = listenable as Animation<double>;
    var result = Transform(
      transform: Matrix4.rotationZ(animation.value * pi / 180),
      alignment: Alignment.bottomCenter,
      child: new ClipRRect(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        child: child,
      ),
    );
    return result;
  }
}
