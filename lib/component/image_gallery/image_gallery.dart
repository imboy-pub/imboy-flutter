// ignore: depend_on_referenced_packages
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/helper/func.dart';
// ignore: depend_on_referenced_packages
import 'package:niku/namespace.dart' as n;
import 'package:photo_view/photo_view_gallery.dart';

/// A class that represents an image showed in a preview widget.
@immutable
class PreviewImage extends Equatable {
  /// Creates a preview image.
  const PreviewImage({
    required this.id,
    required this.uri,
  });

  /// Unique ID of the image.
  final String id;

  /// Image's URI.
  final String uri;

  /// Equatable props.
  @override
  List<Object> get props => [id, uri];
}

class IMBoyImageGallery extends StatelessWidget {
  const IMBoyImageGallery({
    Key? key,
    required this.images,
    required this.onClosePressed,
    this.options = const IMBoyImageGalleryOptions(),
    required this.pageController,
  }) : super(key: key);

  /// Images to show in the gallery.
  final List<PreviewImage> images;

  /// Triggered when the gallery is swiped down or closed via the icon.
  final VoidCallback onClosePressed;

  /// Customisation options for the gallery.
  final IMBoyImageGalleryOptions options;

  /// Page controller for the image pages.
  final PageController pageController;

  @override
  Widget build(BuildContext context) => WillPopScope(
        onWillPop: () async {
          onClosePressed();
          return false;
        },
        child: GestureDetector(
          onTap: () => onClosePressed(),
          child: Dismissible(
            key: const Key('imboy_photo_view_gallery'),
            direction: DismissDirection.down,
            onDismissed: (direction) => onClosePressed(),
            child: n.Stack([
              PhotoViewGallery.builder(
                builder: (BuildContext context, int index) =>
                    PhotoViewGalleryPageOptions(
                  imageProvider: cachedImageProvider(images[index].uri, w: 0),
                  minScale: options.minScale,
                  maxScale: options.maxScale,
                ),
                itemCount: images.length,
                loadingBuilder: (context, event) =>
                    _imageGalleryLoadingBuilder(event),
                pageController: pageController,
                scrollPhysics: const ClampingScrollPhysics(),
              ),
              // Positioned.directional(
              //   end: 16,
              //   textDirection: Directionality.of(context),
              //   top: 56,
              //   child: CloseButton(
              //     color: Colors.white,
              //     onPressed: onClosePressed,
              //   ),
              // ),
            ]),
          ),
        ),
      );

  Widget _imageGalleryLoadingBuilder(ImageChunkEvent? event) => Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            value: event == null || event.expectedTotalBytes == null
                ? 0
                : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
          ),
        ),
      );
}

class IMBoyImageGalleryOptions {
  const IMBoyImageGalleryOptions({
    this.maxScale,
    this.minScale,
  });

  /// See [PhotoViewGalleryPageOptions.maxScale].
  final dynamic maxScale;

  /// See [PhotoViewGalleryPageOptions.minScale].
  final dynamic minScale;
}
