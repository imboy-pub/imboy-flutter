import 'package:cached_network_image/cached_network_image.dart';
import 'package:extended_text/extended_text.dart';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/init.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:niku/namespace.dart' as n;
// import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/config/const.dart';
import 'package:photo_view/photo_view.dart';

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
    // bool userIsAuthor = user.id == message.author.id;

    // String nickname = userIsAuthor ? '你' : '"${message.author.firstName}"';
    // int now = DateTimeHelper.currentTimeMillis();
    String thumb = message.metadata?['thumb'];
    String width = Uri.parse(message.metadata?['thumb']).queryParameters['width'] ?? "" ;
    if (width.isNotEmpty) {
      int w = int.parse(width) * 2;
      thumb = thumb.replaceAll('&width=$width', '&width=$w');
    }
    ImageProvider thumbProvider = CachedNetworkImageProvider(
      thumb,
      cacheKey: generateMD5(thumb),
    );
    // debugPrint(
    //     "LocationMessageBuilder width $width, ${message.metadata?['thumb']} ; thumb $thumb");
    return Container(
      width: Get.width,
      height: 240,
      alignment: Alignment.center,
      color: AppColors.ChatReceivedMessageBodyBgColor,
      child: n.Column([
        ListTile(
          isThreeLine: true,
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

                        // leading: Icon(Icons.assistant_navigation),
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
          title: ExtendedText(
            message.metadata?['title'],
            textAlign: TextAlign.left,
            style: const TextStyle(
              color: AppColors.MainTextColor,
              fontSize: 14.0,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: ExtendedText(
            message.metadata?['address'],
            textAlign: TextAlign.left,
            style: TextStyle(
              color: Colors.grey.shade500,
              // backgroundColor: AppColors.ChatBg,
              fontSize: 12.0,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            overflowWidget: TextOverflowWidget(
              position: TextOverflowPosition.end,
              align: TextOverflowAlign.left,
              child: n.Row(
                const [
                  Text('...'),
                ],
                mainAxisSize: MainAxisSize.min,
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: () {
              Get.bottomSheet(
                InkWell(
                  onTap: () {
                    Get.back();
                  },
                  child: PhotoView(
                    imageProvider: thumbProvider,
                  ),
                ),
                // 是否支持全屏弹出，默认false
                isScrollControlled: true,
                enableDrag: false,
              );
            },
            child: Image(
              width: Get.width,
              fit: BoxFit.cover,
              image: thumbProvider,
            ),
          ),
        ),
      ]),
    );
  }
}
