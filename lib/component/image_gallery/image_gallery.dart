import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import 'package:imboy/component/helper/func.dart';

part 'image_gallery.g.dart';

/// A class that represents an image showed in a preview widget.
@immutable
class PreviewImage extends Equatable {
  /// Creates a preview image.
  const PreviewImage({required this.id, required this.uri});

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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, String? res) async {
        if (didPop) {
          return;
        }
        SystemNavigator.pop();
      },
      child: GestureDetector(
        onTap: () => onClosePressed(),
        child: Dismissible(
          key: const Key('imboy_photo_view_gallery'),
          direction: DismissDirection.down,
          onDismissed: (direction) => onClosePressed(),
          child: Stack(
            children: [
              PhotoViewGallery.builder(
                builder: (BuildContext context, int index) =>
                    PhotoViewGalleryPageOptions(
                      imageProvider: cachedImageProvider(
                        images[index].uri,
                        w: 0,
                      ),
                      minScale: options.minScale,
                      maxScale: options.maxScale,
                    ),
                itemCount: images.length,
                loadingBuilder: (context, event) =>
                    _imageGalleryLoadingBuilder(event),
                pageController: pageController,
                scrollPhysics: const ClampingScrollPhysics(),
              ),
            ],
          ),
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
  const IMBoyImageGalleryOptions({this.maxScale, this.minScale});

  /// See [PhotoViewGalleryPageOptions.maxScale].
  final dynamic maxScale;

  /// See [PhotoViewGalleryPageOptions.minScale].
  final dynamic minScale;
}

// Riverpod State
class ImageGalleryState {
  const ImageGalleryState({
    this.gallery = const [],
    this.isImageViewVisible = false,
  });

  final List<PreviewImage> gallery;
  final bool isImageViewVisible;

  ImageGalleryState copyWith({
    List<PreviewImage>? gallery,
    bool? isImageViewVisible,
  }) {
    return ImageGalleryState(
      gallery: gallery ?? this.gallery,
      isImageViewVisible: isImageViewVisible ?? this.isImageViewVisible,
    );
  }
}

// Riverpod Notifier (使用代码生成)
@riverpod
class ImageGalleryNotifier extends _$ImageGalleryNotifier {
  PageController? galleryPageController;
  final _imageIndexMap = <String, int>{};

  @override
  ImageGalleryState build() {
    ref.onDispose(() {
      galleryPageController?.dispose();
    });
    return const ImageGalleryState();
  }

  void onImagePressed(String imageId, String imageUri) {
    iPrint("onImagePressed: ${state.gallery.isEmpty}");
    pushToGallery(imageId, imageUri);

    final key = '$imageId-$imageUri';
    iPrint("onImagePressed: $key");
    final initialPage = _imageIndexMap[key] ?? 0;

    galleryPageController?.dispose();
    galleryPageController = PageController(
      initialPage: initialPage
          .clamp(0.0, state.gallery.length.toDouble())
          .toInt(),
    );
    state = state.copyWith(isImageViewVisible: true);
  }

  void onCloseGalleryPressed() {
    state = state.copyWith(isImageViewVisible: false);
    galleryPageController?.dispose();
    galleryPageController = null;
  }

  void pushToGallery(String msgId, String msgUri) {
    final key = '$msgId-$msgUri';
    if (!_imageIndexMap.containsKey(key)) {
      final newGallery = [
        PreviewImage(id: msgId, uri: msgUri),
        ...state.gallery,
      ];
      state = state.copyWith(gallery: newGallery);
      _updateIndexMap();
    }
  }

  void pushToLast(String msgId, String msgUri) {
    final key = '$msgId-$msgUri';
    if (!_imageIndexMap.containsKey(key)) {
      final newGallery = [
        ...state.gallery,
        PreviewImage(id: msgId, uri: msgUri),
      ];
      state = state.copyWith(gallery: newGallery);
      _updateIndexMap();
    }
  }

  void remoteFromGallery(String msgId) {
    final index = state.gallery.indexWhere((e) => e.id == msgId);
    if (index >= 0) {
      final newGallery = List<PreviewImage>.from(state.gallery);
      newGallery.removeAt(index);
      state = state.copyWith(gallery: newGallery);
      _imageIndexMap.removeWhere((key, _) => key.startsWith('$msgId-'));
      _updateIndexMap();
    }
  }

  void _updateIndexMap() {
    _imageIndexMap.clear();
    for (int i = 0; i < state.gallery.length; i++) {
      _imageIndexMap['${state.gallery[i].id}-${state.gallery[i].uri}'] = i;
    }
  }
}

/// 单击图片的时候放大显示图片的效果
Future<void> zoomInPhotoView(BuildContext context, String thumb) async {
  final size = MediaQuery.of(context).size;
  ImageProvider thumbProvider = cachedImageProvider(
    thumb,
    w: size.width.toDouble(),
  );
  // 检查网络状态
  var connectivityResult = await Connectivity().checkConnectivity();
  String width = Uri.parse(thumb).queryParameters['width'] ?? "";
  // 如果有网络、并且图片有设置width，就从网络读取2倍清晰图片
  if (!connectivityResult.contains(ConnectivityResult.none) &&
      width.isNotEmpty) {
    int w = int.parse(width) * 2;
    thumb = thumb.replaceAll('&width=$width', '&width=$w');
    thumbProvider = cachedImageProvider(thumb, w: -1);
  }
  if (!context.mounted) return;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (context) => InkWell(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: PhotoView(imageProvider: thumbProvider),
    ),
  );
}

/// 显示多个图像并让用户在它们之间进行更改的效果
Future<void> zoomInPhotoViewGallery(BuildContext context, List<dynamic> items) async {
  iPrint("zoomInPhotoViewGallery");
  final size = MediaQuery.of(context).size;
  List<dynamic> galleryItems = [];
  for (var e in items) {
    galleryItems.add(cachedImageProvider(e, w: size.width.toDouble()));
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (context) => InkWell(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: galleryItems[index],
            initialScale: PhotoViewComputedScale.contained * 0.8,
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
        pageController: PageController(),
      ),
    ),
  );
}

/// 显示多个图像并支持指定初始页面索引
///
/// [items] - 图片 URL 列表
/// [initialPage] - 初始显示的图片索引（从 0 开始）
Future<void> zoomInPhotoViewGalleryWithInitialPage(
  BuildContext context,
  List<String> items,
  int initialPage,
) async {
  iPrint(
    "zoomInPhotoViewGalleryWithInitialPage: initialPage=$initialPage, total=${items.length}",
  );
  final size = MediaQuery.of(context).size;
  List<ImageProvider> galleryItems = [];
  for (var e in items) {
    galleryItems.add(cachedImageProvider(e, w: size.width.toDouble()));
  }

  // 确保初始索引在有效范围内
  final validInitialPage = initialPage.clamp(0, items.length - 1);

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    builder: (context) => InkWell(
      onTap: () {
        Navigator.of(context).pop();
      },
      child: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: galleryItems[index],
            initialScale: PhotoViewComputedScale.contained * 0.8,
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
        pageController: PageController(initialPage: validInitialPage),
      ),
    ),
  );
}
