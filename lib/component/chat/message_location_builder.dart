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
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/modules/messaging/infrastructure/message_model_mapper.dart';

class LocationMessageBuilder extends StatefulWidget {
  final User user;
  final CustomMessage? message;
  final Map<String, dynamic>? info;

  final void Function()? onPlay;

  const LocationMessageBuilder({
    super.key,
    required this.user,
    this.message,
    this.info,
    this.onPlay,
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

  void _showMapsSheet(BuildContext context, CustomMessage msg) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Container(
        color: Theme.of(context).colorScheme.surface,
        child: availableMaps.isEmpty
            ? Center(child: Text(t.common.notInstallAnyMapApp))
            : SingleChildScrollView(
                child: Wrap(
                  children: availableMaps.map<Widget>((map) {
                    return ListTile(
                      onTap: () {
                        final lat = double.tryParse(
                          msg.metadata?['latitude']?.toString() ?? '',
                        );
                        final lng = double.tryParse(
                          msg.metadata?['longitude']?.toString() ?? '',
                        );
                        if (lat == null || lng == null) return;
                        map.showMarker(
                          coords: Coords(lat, lng),
                          title: msg.metadata?['title']?.toString() ?? '',
                          description:
                              msg.metadata?['description']?.toString() ?? '',
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
  }

  Widget _buildMessageView(BuildContext context, CustomMessage msg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSentByMe = widget.user.id == msg.authorId;

    final borderRadius = MessageSpacing.getBubbleBorderRadius(isSentByMe);
    final backgroundColor = AppColors.getChatBubbleBackground(
      isSentByMe,
      false,
      theme.brightness,
    );

    final titleColor = isSentByMe
        ? AppColors.sentMessageText
        : AppColors.getTextColor(theme.brightness);
    final addressColor = isSentByMe
        ? AppColors.sentMessageText.withValues(alpha: 0.7)
        : AppColors.getTextColor(theme.brightness, isSecondary: true);

    String thumb = msg.metadata?['thumb'] as String? ?? '';

    return Container(
      width: 240,
      height: 200,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: AppColors.getReceivedBubbleDivider(
          isSentByMe,
          theme.brightness,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _showMapsSheet(context, msg),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    msg.metadata?['title']?.toString() ?? '',
                    style: TextStyle(
                      color: titleColor,
                      fontSize: FontSizeType.normal.size,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    msg.metadata?['address']?.toString() ?? '',
                    style: TextStyle(
                      color: addressColor,
                      fontSize: FontSizeType.caption2.size,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () async {
                zoomInPhotoView(context, thumb);
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OctoImage(
                    fit: BoxFit.cover,
                    image: cachedImageProvider(
                      thumb,
                      w: MediaQuery.of(context).size.width,
                    ),
                    errorBuilder: (context, error, stacktrace) => Container(
                      color: isDark
                          ? AppColors.placeholderSurfaceDark
                          : AppColors.placeholderSurfaceLight,
                      child: Icon(
                        Icons.map,
                        color: isDark
                            ? AppColors.mediaScrimWhite.withValues(alpha: 0.3)
                            : AppColors.mediaScrimBlack.withValues(alpha: 0.26),
                        size: 36,
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.location_on,
                      color: AppColors.getIosRed(theme.brightness),
                      size: 32,
                    ),
                  ),
                ],
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
  MessagePluginSurface get surface => MessagePluginSurface.standalone;

  @override
  String get type => MessageType.location;

  @override
  Widget build(MessageViewModel message, MessageRenderContext context) {
    return LocationMessageBuilder(message: message, user: context.user);
  }
}
