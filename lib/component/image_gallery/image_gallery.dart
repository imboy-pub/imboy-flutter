import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

// ignore: depend_on_referenced_packages
import 'package:niku/namespace.dart' as n;
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:imboy/component/helper/func.dart';

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
    super.key,
    required this.images,
    required this.onClosePressed,
    this.options = const IMBoyImageGalleryOptions(),
    required this.pageController,
  });

  /// Images to show in the gallery.
  final List<PreviewImage> images;

  /// Triggered when the gallery is swiped down or closed via the icon.
  final VoidCallback onClosePressed;

  /// Customisation options for the gallery.
  final IMBoyImageGalleryOptions options;

  /// Page controller for the image pages.
  final PageController pageController;

  @override
  Widget build(BuildContext context) {
    iPrint("IMBoyImageGallery build ${images.length}");
    // return PopScope(
    //   canPop: false,
    //   onPopInvoked: (bool didPop) async {
    //     iPrint('IMBoyImageGallery didPop: $didPop');
    //     // var canPop = await controller.confirmDiscard();
    //   },
    return PopScope(
      canPop: false, // 允许返回
      // 防止连续点击两次退出
      onPopInvokedWithResult: (bool didPop, String? res) async {
        if (didPop) {
          return;
        }
        // 系统级别导航栈 退出程序
        SystemNavigator.pop();
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
  }

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

/// 单击图片的时候放大显示图片的效果
void zoomInPhotoView(String thumb) async {
  ImageProvider thumbProvider = cachedImageProvider(
    thumb,
    w: Get.width,
  );
  // 检查网络状态
  var connectivityResult = await Connectivity().checkConnectivity();
  String width = Uri.parse(thumb).queryParameters['width'] ?? "";
  // 如果有网络、并且图片有设置width，就从网络读取2倍清晰图片
  if (connectivityResult.contains(ConnectivityResult.none) &&
      width.isNotEmpty) {
    int w = int.parse(width) * 2;
    thumb = thumb.replaceAll('&width=$width', '&width=$w');
    thumbProvider = cachedImageProvider(
      thumb,
      // 不要缓存大文件，以节省设备存储空间
      w: -1,
    );
  }
  Get.bottomSheet(
    InkWell(
      onTap: () {
        Get.closeAllBottomSheets();
      },
      child: PhotoView(
        imageProvider: thumbProvider,
      ),
    ),
    // 是否支持全屏弹出，默认false
    isScrollControlled: true,
    enableDrag: false,
  );
}

/// 显示多个图像并让用户在它们之间进行更改的效果
void zoomInPhotoViewGallery(List items) async {
  iPrint("zoomInPhotoViewGallery");
  List galleryItems = [];
  for (var e in items) {
    galleryItems.add(cachedImageProvider(
      e,
      w: Get.width,
    ));
  }
  Get.bottomSheet(
    InkWell(
      onTap: () {
        Get.closeAllBottomSheets();
      },
      child: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: galleryItems[index],
            initialScale: PhotoViewComputedScale.contained * 0.8,
            // heroAttributes:
            //     PhotoViewHeroAttributes(tag: galleryItems[index].toString()),
          );
        },
        itemCount: galleryItems.length,
        loadingBuilder: (context, event) => Center(
          child: SizedBox(
            width: 20.0,
            height: 20.0,
            child: CircularProgressIndicator(
              value: event == null
                  ? 0
                  : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
            ),
          ),
        ),
        // backgroundDecoration: widget.backgroundDecoration,
        pageController: PageController(),
        // onPageChanged: () {},
      ),
    ),
    // 是否支持全屏弹出，默认false
    isScrollControlled: true,
    enableDrag: false,
  );
}
