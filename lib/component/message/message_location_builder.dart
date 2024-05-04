
import 'package:flutter/material.dart';

// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:niku/namespace.dart' as n;
import 'package:octo_image/octo_image.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/message_model.dart';


class LocationMessageBuilder extends StatefulWidget {
  final types.User user;
  final types.CustomMessage? message;
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
  late Future<types.CustomMessage?> messageFuture;

  @override
  void initState() {
    super.initState();
    messageFuture = _getMessage();
  }

  Future<types.CustomMessage?> _getMessage() async {
    if (widget.message != null) {
      return widget.message;
    } else if (widget.info != null) {
      return await MessageModel.fromJson(widget.info!).toTypeMessage() as types.CustomMessage;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<types.CustomMessage?>(
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

  Widget _buildMessageView(types.CustomMessage msg) {
    // bool userIsAuthor = user.id == message.author.id;
    String thumb = msg.metadata?['thumb'];
    return Container(
        width: widget.width ?? Get.width * 0.618,
        height: widget.height ?? 240,
        color: const Color.fromRGBO(230, 230, 230, 1.0),
        child: n.Column([
          InkWell(
            onTap: () {
              Get.bottomSheet(
                backgroundColor: Get.isDarkMode
                    ? const Color.fromRGBO(80, 80, 80, 1)
                    : const Color.fromRGBO(240, 240, 240, 1),
                Container(
                  color: Theme.of(Get.context!).colorScheme.background,
                  child: availableMaps.isEmpty
                      ? Center(
                    child: Text('not_install_any_map_app'.tr),
                  )
                      : SingleChildScrollView(
                    child: Wrap(
                      //使用 ListTile 平铺布局即可
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
            child: n.Column([
              n.Padding(
                left: 8,
                right: 8,
                top: 8,
                child: Text(
                  // '大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发',
                  msg.metadata?['title'],
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: Color.fromRGBO(44, 44, 44, 1.0),
                    fontSize: 15.0,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              n.Padding(
                left: 8,
                bottom: 8,
                child: Text(
                  msg.metadata?['address'],
                  // '大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发大声道发生的发生的发生大发是打发',
                  textAlign: TextAlign.left,
                  style: const TextStyle(
                    color: Color.fromRGBO(56, 56, 56, 1.0),
                    fontSize: 13.0,
                  ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ])
            // 内容文本左对齐
              ..crossAxisAlignment = CrossAxisAlignment.start,
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
        ])
          ..mainAxisSize = MainAxisSize.min
          ..mainAxisAlignment = MainAxisAlignment.start
          ..crossAxisAlignment = CrossAxisAlignment.start);
  }
}