import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/view/list_tile_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/win_media.dart';
import 'package:imboy/page/personal_info/personal_info_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'mine_logic.dart';
import 'mine_state.dart';

class MinePage extends StatelessWidget {
  final MineLogic logic = Get.put(MineLogic());
  final MineState state = Get.find<MineLogic>().state;

  Widget buildContent(item) {
    return new ListTileView(
      border: item['border'],
      title: item['label'],
      titleStyle: TextStyle(fontSize: 15.0, color: AppColors.MainTextColor),
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

  DecorationImage dynamicAvatar(avatar) {
    String defAvatar = 'assets/images/def_avatar.png';
    return DecorationImage(
      image: strEmpty(avatar) || avatar == defAvatar
          ? AssetImage(defAvatar) as ImageProvider
          : CachedNetworkImageProvider(avatar),
      fit: BoxFit.cover,
    );
  }

  Widget body(BuildContext context) {
    List data = [
      {
        'label': '钱包',
        'icon': 'assets/images/mine/ic_wallet.webp',
        'vertical': 10.0,
        'border':
            Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
      },
      {
        'label': '朋友圈',
        'icon': 'assets/images/mine/ic_social_circle.png',
        'vertical': 0.0,
        'border':
            Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
      },
      {
        'label': '收藏',
        'icon': 'assets/images/mine/ic_collections.png',
        'vertical': 0.0,
        'border':
            Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
      },
      {
        'label': '相册',
        'icon': 'assets/images/mine/ic_album.png',
        'vertical': 0.0,
        'border':
            Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
      },
      {
        'label': '卡片',
        'icon': 'assets/images/mine/ic_card_package.png',
        'vertical': 0.0,
        'border':
            Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
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
        'border':
            Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
      },
    ];

    var row = [
      new SizedBox(
        width: 88.0,
        height: 88.0,
        child: new ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(4.0)),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(4.0),
              // color: defHeaderBgColor,
              image: dynamicAvatar(UserRepoLocal.to.currentUser.avatar),
            ),
            child: null,
          ),
        ),
      ),
      new Container(
        margin: EdgeInsets.only(left: 10.0),
        height: 50.0,
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            new Text(
              UserRepoLocal.to.currentUser.nickname!,
              style: TextStyle(
                  color: Colors.black,
                  fontSize: 20.0,
                  fontWeight: FontWeight.w500),
            ),
            new Text(
              '账号：' + UserRepoLocal.to.currentUser.account!,
              style: TextStyle(color: AppColors.MainTextColor),
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
          color: AppColors.MainTextColor.withOpacity(0.5),
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
      color: AppColors.AppBarColor,
      child: new SingleChildScrollView(child: body(context)),
    );
  }
}
