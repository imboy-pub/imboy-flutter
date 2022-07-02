import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/list_tile_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/personal_info/personal_info_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:niku/namespace.dart' as n;
import 'package:photo_view/photo_view.dart';

import 'mine_logic.dart';

// ignore: must_be_immutable
class MinePage extends StatelessWidget {
  final MineLogic logic = Get.put(MineLogic());

  List data = [
    // {
    //   'label': '钱包',
    //   'icon': 'assets/images/mine/ic_wallet.webp',
    //   'vertical': 10.0,
    //   'border':
    //       Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
    // },
    {
      'label': '朋友圈',
      'icon': 'assets/images/mine/ic_social_circle.png',
      'vertical': 0.0,
      'border': const Border(
        bottom: BorderSide(
          color: AppColors.LineColor,
          width: 0.2,
        ),
      ),
    },
    {
      'label': '收藏',
      'icon': 'assets/images/mine/ic_collections.png',
      'vertical': 0.0,
      'border': const Border(
        bottom: BorderSide(
          color: AppColors.LineColor,
          width: 0.2,
        ),
      ),
    },
    // {
    //   'label': '相册',
    //   'icon': 'assets/images/mine/ic_album.png',
    //   'vertical': 0.0,
    //   'border':
    //       Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
    // },
    // {
    //   'label': '卡片',
    //   'icon': 'assets/images/mine/ic_card_package.png',
    //   'vertical': 0.0,
    //   'border':
    //       Border(bottom: BorderSide(color: AppColors.LineColor, width: 0.2)),
    // },
    // {'label': '表情', 'icon': 'assets/images/mine/ic_emoji.png', 'vertical': 0.0},
    {
      'label': '设置',
      'icon': 'assets/images/mine/ic_setting.png',
      'vertical': 10.0,
      'border': const Border(
        bottom: BorderSide(
          color: AppColors.LineColor,
          width: 0.2,
        ),
      ),
    },
  ];

  MinePage({Key? key}) : super(key: key);

  Widget buildContent(item) {
    return ListTileView(
      border: item['border'],
      title: item['label'],
      titleStyle: const TextStyle(
        fontSize: 15.0,
        color: AppColors.MainTextColor,
      ),
      isLabel: false,
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      icon: item['icon'],
      margin: EdgeInsets.symmetric(vertical: item['vertical']),
      onPressed: () => logic.action(item['label']),
      width: 25.0,
      fit: BoxFit.cover,
      horizontal: 15.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.AppBarColor,
      child: SingleChildScrollView(
        child: Column(
          children: <Widget>[
            GetBuilder<UserRepoLocal>(
              builder: (_c) => InkWell(
                child: Container(
                  color: Colors.white,
                  height: 160,
                  padding: const EdgeInsets.only(
                    left: 15.0,
                    right: 12.0,
                    top: 32.0,
                  ),
                  margin: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: n.Row(
                    [
                      SizedBox(
                        width: 88.0,
                        height: 88.0,
                        child: ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          child: InkWell(
                            onTap: () {
                              String avatar = _c.currentUser.avatar;
                              Get.bottomSheet(
                                InkWell(
                                  onTap: () {
                                    Get.back();
                                  },
                                  child: PhotoView(
                                    imageProvider:
                                        strEmpty(avatar) || avatar == defAvatar
                                            ? const AssetImage(defAvatar)
                                                as ImageProvider
                                            : NetworkImage(avatar),
                                    // imageProvider: NetworkImage(avatar),
                                  ),
                                ),
                                // 是否支持全屏弹出，默认false
                                isScrollControlled: true,
                                enableDrag: false,
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                borderRadius: BorderRadius.circular(10.0),
                                // color: defHeaderBgColor,
                                image: dynamicAvatar(_c.currentUser.avatar),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 10.0),
                        width: 172.0,
                        height: 72.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            ExtendedText(
                              _c.currentUser.nickname,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),

                            Text(
                              '账号：' + _c.currentUser.account,
                              style: const TextStyle(
                                  color: AppColors.MainTextColor),
                            ),
                            //TODO
                            // Text(
                            //   '地区：' + _c.currentUser.region,
                            //   style: TextStyle(color: AppColors.MainTextColor),
                            // ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        width: 16.0,
                        margin: const EdgeInsets.only(right: 8.0),
                        child: Image(
                          image: const AssetImage(
                              'assets/images/mine/ic_small_code.png'),
                          color: AppColors.MainTextColor.withOpacity(0.5),
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Image(
                        image: AssetImage(
                            'assets/images/ic_right_arrow_grey.webp'),
                        width: 7.0,
                        fit: BoxFit.cover,
                      )
                    ],
                    mainAxisAlignment: MainAxisAlignment.end,
                  ),
                ),
                onTap: () => Get.to(() => const PersonalInfoPage()),
              ),
            ),
            n.Column(
              data.map(buildContent).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
