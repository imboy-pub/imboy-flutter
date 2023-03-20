import 'package:bubble/bubble.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/config/init.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:niku/namespace.dart' as n;

// import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';

class LocationMessageBuilder extends StatelessWidget {
  const LocationMessageBuilder({
    Key? key,
    required this.user,
    required this.message,
  }) : super(key: key);

  final types.User user;
  final types.CustomMessage message;

  @override
  Widget build(BuildContext context) {
    bool userIsAuthor = user.id == message.author.id;

    String thumb = message.metadata?['thumb'];
    return Bubble(
      color: userIsAuthor
          ? AppColors.ChatSendMessageBgColor
          : AppColors.ChatReceivedMessageBodyBgColor,
      nip: userIsAuthor ? BubbleNip.rightBottom : BubbleNip.leftBottom,
      // style: const BubbleStyle(nipWidth: 16),
      nipRadius: 4,
      alignment: userIsAuthor ? Alignment.centerRight : Alignment.centerLeft,
      child: SizedBox(
        width: Get.width * 0.618,
        height: 240,
        child: n.Column(
          [
            InkWell(
              onTap: () {
                Get.bottomSheet(
                  Container(
                    color: AppColors.primaryBackground,
                    // child: Center(
                    //   child: Text('您没有安装任何地区APP哦'.tr),
                    // )
                    child: availableMaps.isEmpty
                        ? Center(
                            child: Text('您没有安装任何地区APP哦'.tr),
                          )
                        : SingleChildScrollView(
                            child: Wrap(
                              //使用 ListTile 平铺布局即可
                              children: availableMaps.map<Widget>((map) {
                                return ListTile(
                                  onTap: () {
                                    map.showMarker(
                                      coords: Coords(
                                        double.parse(
                                            message.metadata?['latitude']),
                                        double.parse(
                                            message.metadata?['longitude']),
                                      ),
                                      title: message.metadata?['title'],
                                      description:
                                          message.metadata?['description'],
                                    );
                                  },
                                  title: Text(map.mapName),
                                  leading: SvgPicture.asset(
                                    map.icon,
                                    height: 30.0,
                                    width: 30.0,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                  ),
                );
              },
              child: n.Column(
                [
                  n.Padding(
                    child: Text(
                      // '大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发'
                      //     .tr,
                      message.metadata?['title'],
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 15.0,
                      ),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  n.Padding(
                    bottom: 8,
                    child: Text(
                      message.metadata?['address'],
                      // '大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发'.tr,
                      textAlign: TextAlign.left,
                      style: const TextStyle(
                        color: AppColors.thirdElementText,
                        // backgroundColor: AppColors.ChatBg,
                        fontSize: 13.0,
                      ),
                      maxLines: 8,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                // 内容文本左对齐
                crossAxisAlignment: CrossAxisAlignment.start,
              ),
            ),
            Expanded(
              flex: 2,
              child: InkWell(
                onTap: () async {
                  zoomInPhotoView(thumb);
                },
                child: Image(
                  width: Get.width,
                  fit: BoxFit.cover,
                  image: CachedNetworkImageProvider(
                    thumb,
                    cacheKey: generateMD5(thumb),
                  ),
                ),
              ),
            ),
          ],
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
        ),
      ),
    );
  }
}
