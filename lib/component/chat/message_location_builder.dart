import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:octo_image/octo_image.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/message_model.dart';

class LocationMessageBuilder extends StatefulWidget {
  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;

  final Function()? onPlay;
  final double? width, height;

  const LocationMessageBuilder({
    super.key,
    required this.user,
    this.message,
    this.info,
    this.onPlay,
    this.width,
    this.height,
  });

  @override
  LocationMessageBuilderState createState() => LocationMessageBuilderState();
}

class LocationMessageBuilderState extends State<LocationMessageBuilder> {
  late Future<CustomMessage?> messageFuture;

  @override
  void initState() {
    super.initState();
    messageFuture = _getMessage();
  }

  Future<CustomMessage?> _getMessage() async {
    if (widget.message != null) {
      return widget.message;
    } else if (widget.info != null) {
      return await MessageModel.fromJson(widget.info!).toTypeMessage() as CustomMessage;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CustomMessage?>(
      future: messageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final msg = snapshot.data;
        if (msg == null) {
          return Container(); // 或者一些错误提示
        }
        // 构建消息视图
        return _buildMessageView(msg);
      },
    );
  }

  Widget _buildMessageView(CustomMessage msg) {
    // bool userIsAuthor = user.id == message.author.id;
    String thumb = msg.metadata?['thumb'];
    return SizedBox(
      width: widget.width ?? Get.width * 0.618,
      height: widget.height ?? 240,
      // color: const Color(0xFFF5F5F8), // 优化：统一背景色，可根据需求调整
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              // 优化：支持选择地图APP打开位置
              Get.bottomSheet(
                Container(
                  color: Theme.of(Get.context!).colorScheme.surface,
                  child: availableMaps.isEmpty
                      ? Center(
                    child: Text('not_install_any_map_app'.tr),
                  )
                      : SingleChildScrollView(
                    child: Wrap(
                      children: availableMaps.map<Widget>((map) {
                        return ListTile(
                          onTap: () {
                            map.showMarker(
                              coords: Coords(
                                double.parse(msg.metadata?['latitude']),
                                double.parse(msg.metadata?['longitude']),
                              ),
                              title: msg.metadata?['title'],
                              description: msg.metadata?['description'],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 内容文本左对齐
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 8),
                  child: Text(
                    msg.metadata?['title'],
                    textAlign: TextAlign.left,
                    // style: const TextStyle(
                    //   color: Color.fromRGBO(44, 44, 44, 1.0),
                    //   fontSize: 15.0,
                    // ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, bottom: 8),
                  child: Text(
                    msg.metadata?['address'],
                    textAlign: TextAlign.left,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () async {
                zoomInPhotoView(thumb);
              },
              child: OctoImage(
                width: Get.width,
                fit: BoxFit.cover,
                image: cachedImageProvider(
                  thumb,
                  w: Get.width,
                ),
                errorBuilder: (context, error, stacktrace) =>
                const Icon(Icons.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
