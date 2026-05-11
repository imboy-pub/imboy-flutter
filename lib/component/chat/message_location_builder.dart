import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:octo_image/octo_image.dart';

import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/chat/message_spacing.dart';
import 'package:imboy/component/image_gallery/image_gallery.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/plugins/contracts/message_type_plugin.dart';
import 'package:imboy/service/message_type_constants.dart';

class LocationMessageBuilder extends StatefulWidget {
  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;

  final void Function()? onPlay;
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
      return await MessageModel.fromJson(widget.info!).toTypeMessage()
          as CustomMessage;
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
        return _buildMessageView(context, msg);
      },
    );
  }

  Widget _buildMessageView(BuildContext context, CustomMessage msg) {
    // bool userIsAuthor = user.id == message.author.id;
    String thumb = msg.metadata?['thumb'] as String;
    return SizedBox(
      width: widget.width ?? MediaQuery.of(context).size.width * 0.618,
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
              showModalBottomSheet<void>(
                context: context,
                builder: (context) => Container(
                  color: Theme.of(context).colorScheme.surface,
                  child: availableMaps.isEmpty
                      ? Center(child: Text(t.notInstallAnyMapApp))
                      : SingleChildScrollView(
                          child: Wrap(
                            children: availableMaps.map<Widget>((map) {
                              return ListTile(
                                onTap: () {
                                  final lat = double.tryParse(
                                    msg.metadata?['latitude']?.toString() ?? '',
                                  );
                                  final lng = double.tryParse(
                                    msg.metadata?['longitude']?.toString() ??
                                        '',
                                  );
                                  if (lat == null || lng == null) return;
                                  map.showMarker(
                                    coords: Coords(lat, lng),
                                    title:
                                        msg.metadata?['title']?.toString() ??
                                        '',
                                    description:
                                        msg.metadata?['description']
                                            ?.toString() ??
                                        '',
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
                // 使用统一间距 8dp
                Padding(
                  padding: MessageSpacing.locationTitlePadding,
                  child: Text(
                    msg.metadata?['title']?.toString() ?? '',
                    textAlign: TextAlign.left,
                    // style: const TextStyle(
                    //   color: Color.fromRGBO(44, 44, 44, 1.0),
                    //   fontSize: 15.0,
                    // ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // 使用统一间距 8dp
                Padding(
                  padding: MessageSpacing.locationAddressPadding,
                  child: Text(
                    msg.metadata?['address']?.toString() ?? '',
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
                zoomInPhotoView(context, thumb);
              },
              child: OctoImage(
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.cover,
                image: cachedImageProvider(
                  thumb,
                  w: MediaQuery.of(context).size.width,
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

class LocationMessageTypePlugin implements MessageTypePlugin {
  const LocationMessageTypePlugin();

  @override
  String get id => 'builtin:${MessageType.location}';

  @override
  bool get isEnabled => true;

  @override
  MessagePluginSurface get surface => MessagePluginSurface.bubble;

  @override
  String get type => MessageType.location;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return LocationMessageBuilder(message: message, user: context.user);
  }
}
