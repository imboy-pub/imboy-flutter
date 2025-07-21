import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';

import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:octo_image/octo_image.dart';

/// A class that represents image message widget. Supports different
/// aspect ratios, renders blurred image as a background which is visible
/// if the image is narrow, renders image in form of a file if aspect
/// ratio is very small or very big.
class ImageMessageBuilder extends StatefulWidget {
  /// Creates an image message widget based on [ImageMessage].
  const ImageMessageBuilder({
    super.key,
    required this.message,
    required this.messageWidth,
    this.user,
  });

  final User? user;

  /// [ImageMessage].
  final ImageMessage message;

  /// Maximum message width.
  final int messageWidth;

  @override
  State<ImageMessageBuilder> createState() => _ImageMessageState();
}

/// [ImageMessage] widget state.
class _ImageMessageState extends State<ImageMessageBuilder> {
  ImageProvider? _image;
  Size _size = Size.zero;
  ImageStream? _stream;

  @override
  void initState() {
    super.initState();

    _image = cachedImageProvider(widget.message.source, w: Get.width);
    _size = Size(widget.message.width ?? 0, widget.message.height ?? 0);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_size.isEmpty) {
      _getImage();
    }
  }

  @override
  void dispose() {
    _stream?.removeListener(ImageStreamListener(_updateImage));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    if (_size.aspectRatio == 0) {
      return SizedBox(
        height: _size.height,
        width: _size.width,
      );
    } else if (_size.aspectRatio < 0.1 || _size.aspectRatio > 10) {
      return SizedBox(
        width: Get.width * 0.618,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              // TODO fix InheritedChatTheme
              // margin: EdgeInsetsDirectional.fromSTEB(
              //   InheritedChatTheme.of(context).theme.messageInsetsVertical,
              //   InheritedChatTheme.of(context).theme.messageInsetsVertical,
              //   16,
              //   InheritedChatTheme.of(context).theme.messageInsetsVertical,
              // ),
              width: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: OctoImage(
                  width: Get.width,
                  fit: BoxFit.cover,
                  image: _image!,
                  errorBuilder: (context, error, stacktrace) =>
                      const Icon(Icons.error),
                ),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.text!,
                    // TODO fix InheritedChatTheme
                    // style: user.id == widget.message.author.id
                    //     ? InheritedChatTheme.of(context)
                    //         .theme
                    //         .sentMessageBodyTextStyle
                    //     : InheritedChatTheme.of(context)
                    //         .theme
                    //         .receivedMessageBodyTextStyle,
                    textWidthBasis: TextWidthBasis.longestLine,
                  ),
                  Container(
                    margin: const EdgeInsets.only(
                      top: 4,
                    ),
                    child: Text(
                      formatBytes((widget.message.size??0).truncate()),
                      // TODO fix InheritedChatTheme
                      // style: user.id == widget.message.author.id
                      //     ? InheritedChatTheme.of(context)
                      //         .theme
                      //         .sentMessageCaptionTextStyle
                      //     : InheritedChatTheme.of(context)
                      //         .theme
                      //         .receivedMessageCaptionTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        width: Get.width * 0.618,
        child: AspectRatio(
          aspectRatio: _size.aspectRatio > 0 ? _size.aspectRatio : 1,
          child: Image(
            fit: BoxFit.contain,
            image: _image!,
          ),
        ),
      );
    }
  }

  void _getImage() {
    final oldImageStream = _stream;
    _stream = _image?.resolve(createLocalImageConfiguration(context));
    if (_stream?.key == oldImageStream?.key) {
      return;
    }
    final listener = ImageStreamListener(_updateImage);
    oldImageStream?.removeListener(listener);
    _stream?.addListener(listener);
  }

  void _updateImage(ImageInfo info, bool _) {
    setState(() {
      _size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
    });
  }
}
