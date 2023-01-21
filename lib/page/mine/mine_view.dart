import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;
import 'package:photo_view/photo_view.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/list_tile_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/personal_info/personal_info_view.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

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
      // 'border': const Border(
      //   bottom: BorderSide(
      //     color: AppColors.LineColor,
      //     width: 0.2,
      //   ),
      // ),
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
      // 'border': const Border(
      //   bottom: BorderSide(
      //     color: AppColors.LineColor,
      //     width: 0.2,
      //   ),
      // ),
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
              builder: (controller) => InkWell(
                child: Container(
                  color: Colors.white,
                  height: 200,
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
                      Container(
                        margin: const EdgeInsets.only(top: 16.0),
                        width: 88.0,
                        height: 88.0,
                        child: ClipRRect(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(10.0)),
                          child: InkWell(
                            onTap: () {
                              String avatar = controller.currentUser.avatar;
                              Get.bottomSheet(
                                InkWell(
                                  onTap: () {
                                    Get.back();
                                  },
                                  child: PhotoView(
                                    imageProvider: avatarImageProvider(avatar),
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
                                image: dynamicAvatar(controller.currentUser.avatar),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 10.0, top: 10.0),
                        width: 200.0,
                        child: n.Column(
                          <Widget>[
                            ExtendedText(
                              controller.currentUser.nickname,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 18.0,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.left,
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, bottom: 8.0),
                              child: Text(
                                '账号：'.tr + controller.currentUser.account,
                                style: const TextStyle(
                                  color: AppColors.MainTextColor,
                                ),
                              ),
                            ),
                            strNoEmpty(controller.currentUser.region)
                                ? Text(
                                    '地区：'.tr + controller.currentUser.region,
                                    style: const TextStyle(
                                        color: AppColors.MainTextColor),
                                  )
                                : const SizedBox.shrink(),
                          ],
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                        ),
                      ),
                      const Spacer(),

                      Container(
                        width: 18.0,
                        margin: const EdgeInsets.only(right: 10.0),
                        child: const Icon(Icons.qr_code_2),
                      ),
                      const Image(
                        image: AssetImage('assets/images/ic_right_arrow_grey.webp'),
                        width: 7.0,
                        fit: BoxFit.cover,
                      )
                    ],
                    // mainAxisAlignment: MainAxisAlignment.end,
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
