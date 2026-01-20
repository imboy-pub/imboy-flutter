import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:visibility_detector/visibility_detector.dart';

import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:octo_image/octo_image.dart';

/// A class that represents image message widget. Supports different
/// aspect ratios, renders blurred image as a background which is visible
/// if the image is narrow, renders image in form of a file if aspect
/// ratio is very small or very big.
class IMBoyImageMessageBuilder extends StatefulWidget {
  /// Creates an image message widget based on [ImageMessage].
  const IMBoyImageMessageBuilder({
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
  State<IMBoyImageMessageBuilder> createState() => _IMBoyImageMessageState();
}

/// [ImageMessage] widget state.
class _IMBoyImageMessageState extends State<IMBoyImageMessageBuilder> {
  ImageProvider? _image;
  Size _size = Size.zero;
  ImageStream? _stream;

  @override
  void initState() {
    super.initState();

    _size = Size(widget.message.width ?? 0, widget.message.height ?? 0);
    _loadImage();
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
    return VisibilityDetector(
      key: Key(widget.message.id),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.3 && _image == null) {
          _loadImage();
        }
      },
      child: _buildImageContent(context),
    );
  }

  Widget _buildImageContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (_size.aspectRatio == 0) {
      return SizedBox(height: _size.height, width: _size.width);
    } else if (_size.aspectRatio < 0.1 || _size.aspectRatio > 10) {
      return SizedBox(
        width: screenWidth * 0.618,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 64,
              width: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _image != null
                    ? OctoImage(
                        width: screenWidth,
                        fit: BoxFit.cover,
                        image: _image!,
                        errorBuilder: (context, error, stacktrace) =>
                            const Icon(Icons.error),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.text!,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: 14.0,
                    ),
                    textWidthBasis: TextWidthBasis.longestLine,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    child: Text(
                      formatBytes((widget.message.size ?? 0).truncate()),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 12.0,
                      ),
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
        width: screenWidth * 0.618,
        child: AspectRatio(
          aspectRatio: _size.aspectRatio > 0 ? _size.aspectRatio : 1,
          child: _image != null
              ? Image(fit: BoxFit.contain, image: _image!)
              : Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
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
      _size = Size(info.image.width.toDouble(), info.image.height.toDouble());
    });
  }

  Future<void> _loadImage() async {
    try {
      final File file = await IMBoyCacheManager().getSingleFile(
        widget.message.source,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _image = FileImage(file);
      });
      if (_size.isEmpty) {
        _getImage();
      }
    } catch (_) {}
  }
}
