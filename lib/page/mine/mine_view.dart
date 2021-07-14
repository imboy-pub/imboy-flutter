import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/view/image_view.dart';
import 'package:imboy/component/view/list_tile_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/win_media.dart';
import 'package:imboy/page/personal_info/personal_info_view.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repository.dart';

import 'mine_logic.dart';
import 'mine_state.dart';

class MinePage extends StatelessWidget {
  final MineLogic logic = Get.put(MineLogic());
  final MineState state = Get.find<MineLogic>().state;

  Widget buildContent(item) {
    return new ListTileView(
      border: item['border'],
      title: item['label'],
      titleStyle: TextStyle(fontSize: 15.0),
      isLabel: false,
      padding: EdgeInsets.symmetric(vertical: 16.0),
      icon: item['icon'],
      margin: EdgeInsets.symmetric(vertical: item['vertical']),
      onPressed: () => logic.action(item['label']),
      width: 25.0,
      fit: BoxFit.cover,
      horizontal: 15.0,
    );
  }

  Widget dynamicAvatar(avatar, {size}) {
    return new ImageView(
      img: avatar,
      width: size ?? null,
      height: size ?? null,
      fit: BoxFit.fill,
    );
  }

  Widget body(BuildContext context) {
    List data = [
      {
        'label': '钱包',
        'icon': 'assets/images/mine/ic_wallet.webp',
        'vertical': 10.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {
        'label': '朋友圈',
        'icon': 'assets/images/mine/ic_social_circle.png',
        'vertical': 0.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {
        'label': '收藏',
        'icon': 'assets/images/mine/ic_collections.png',
        'vertical': 0.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {
        'label': '相册',
        'icon': 'assets/images/mine/ic_album.png',
        'vertical': 0.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {
        'label': '卡片',
        'icon': 'assets/images/mine/ic_card_package.png',
        'vertical': 0.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
      {
        'label': '表情',
        'icon': 'assets/images/mine/ic_emoji.png',
        'vertical': 0.0
      },
      {
        'label': '设置',
        'icon': 'assets/images/mine/ic_setting.png',
        'vertical': 10.0,
        'border': Border(bottom: BorderSide(color: lineColor, width: 0.2)),
      },
    ];

    UserModel currentUser = UserRepository.currentUser();
    currentUser?.avatar = strNoEmpty(currentUser?.avatar)
        ? currentUser?.avatar
        : 'assets/images/logo.png';
    var row = [
      new SizedBox(
        width: 60.0,
        height: 60.0,
        child: new ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(5.0)),
          child: strNoEmpty(currentUser?.avatar)
              ? dynamicAvatar(currentUser.avatar)
              : new Image(
                  image: AssetImage(currentUser.avatar),
                  fit: BoxFit.cover,
                ),
        ),
      ),
      new Container(
        margin: EdgeInsets.only(left: 15.0),
        height: 60.0,
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            new Text(
              currentUser.nickname ?? '--',
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20.0,
                  fontWeight: FontWeight.w500),
            ),
            new Text(
              '账号：' + currentUser.account ?? '',
              style: TextStyle(color: mainTextColor),
            ),
          ],
        ),
      ),
      new Spacer(),
      new Container(
        width: 13.0,
        margin: EdgeInsets.only(right: 12.0),
        child: new Image(
          image: AssetImage('assets/images/mine/ic_small_code.png'),
          color: mainTextColor.withOpacity(0.5),
          fit: BoxFit.cover,
        ),
      ),
      new Image(
        image: AssetImage('assets/images/ic_right_arrow_grey.webp'),
        width: 7.0,
        fit: BoxFit.cover,
      )
    ];

    return new Column(
      children: <Widget>[
        new InkWell(
          child: new Container(
            color: Colors.white,
            height: (topBarHeight(context) * 2.5) - 10,
            padding: EdgeInsets.only(left: 20.0, right: 20.0, top: 40.0),
            child: new Row(
                crossAxisAlignment: CrossAxisAlignment.center, children: row),
          ),
          onTap: () => Get.to(() => PersonalInfoPage()),
        ),
        new Column(
          children: data.map(buildContent).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Container(
      color: appBarColor,
      child: new SingleChildScrollView(child: body(context)),
    );
  }
}
