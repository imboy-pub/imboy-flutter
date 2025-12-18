import 'dart:typed_data';

import 'package:carousel_slider_plus/carousel_slider_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/location/widget.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/theme/theme_manager.dart';

import 'package:imboy/store/model/contact_model.dart';

class ExtraItem extends StatelessWidget {
  const ExtraItem({
    super.key,
    required this.onPressed,
    required this.image,
    required this.title,
    this.width,
    this.height,
  });

  final Widget image;
  final void Function()? onPressed;
  final double? width;
  final double? height;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed ?? () => Get.snackbar('Tips', '功能暂未实现'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: width ?? 64,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 图标容器 - 使用Material 3设计
              Container(
                width: width ?? 48,
                height: height ?? 48,
                decoration: BoxDecoration(
                  // 使用主题颜色
                  color: ThemeManager.instance.getThemeColor(
                    'surfaceContainer',
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: ThemeManager.instance
                        .getThemeColor('outline')
                        .withValues(alpha: 0.12),
                    width: 1,
                  ),
                  // 添加阴影效果
                  boxShadow: [
                    BoxShadow(
                      color: ThemeManager.instance
                          .getThemeColor('shadow')
                          .withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(
                      color: ThemeManager.instance.getThemeColor('primary'),
                      size: 24,
                    ),
                    child: image is ImageProvider
                        ? Image(
                            image: image as ImageProvider,
                            width: 24,
                            height: 24,
                          )
                        : image,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // 标题文字
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ThemeManager.instance.getThemeColor('onSurface'),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExtraItems extends StatefulWidget {
  const ExtraItems({
    super.key,
    this.handleImageSelection,
    this.handleFileSelection,
    this.handlePickerSelection,
    this.handleLocationSelection,
    this.handleVisitCardSelection,
    this.handleCollectSelection,
    required this.type,
    required this.options,
  });

  final String type; // [C2C | C2G | C2S]
  final Map options;
  final void Function()? handleImageSelection;
  final void Function()? handleFileSelection;
  final void Function(BuildContext)? handlePickerSelection;
  final void Function(String, Uint8List, String, String, String, String)?
  handleLocationSelection;
  final void Function()? handleVisitCardSelection;
  final void Function()? handleCollectSelection;

  @override
  ExtraItemsState createState() => ExtraItemsState();
}

class ExtraItemsState extends State<ExtraItems> {
  int _current = 0;
  final CarouselSliderController _controller = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    const double iconSize = 28; // 调整图标大小
    var items = [
      // 第一页
      _buildItemsGrid([
        ExtraItem(
          title: 'album'.tr,
          image: const Icon(Icons.photo_library_outlined, size: iconSize),
          onPressed: widget.handleImageSelection,
        ),
        ExtraItem(
          title: 'camera'.tr,
          image: const Icon(Icons.camera_alt_outlined, size: iconSize),
          onPressed: () {
            if (widget.handlePickerSelection != null) {
              widget.handlePickerSelection!(context);
            }
          },
        ),
        ExtraItem(
          title: 'location'.tr,
          image: const Icon(Icons.location_on_outlined, size: iconSize),
          onPressed: () async {
            AMapPosition? l = await AMapHelper().startLocation();
            debugPrint("getLocation ${l?.latLng.toJson().toString()}");
            if (l != null) {
              Navigator.push(
                Get.context!,
                CupertinoPageRoute(
                  builder: (context) => MapLocationPicker(
                    arguments: {
                      "lat": double.parse(l.latLng.latitude.toString()),
                      "lng": double.parse(l.latLng.longitude.toString()),
                      "citycode": AMapApi.getCityNameByGaoDe(l.adCode),
                      "isMapImage": true,
                    },
                  ),
                ),
              ).then((value) {
                if (value != null) {
                  if (value["image"] == null) {
                    EasyLoading.showError('failed_get_map_try_again'.tr);
                    FocusScope.of(Get.context!).requestFocus(FocusNode());
                    return;
                  }
                  if (widget.handleLocationSelection != null &&
                      value["image"] != null) {
                    widget.handleLocationSelection!(
                      value["id"],
                      value["image"],
                      value["address"],
                      value["title"],
                      value["latitude"].toString(),
                      value["longitude"].toString(),
                    );
                  }
                }
              });
            }
          },
        ),
        ExtraItem(
          title: 'personal_card'.tr,
          image: const Icon(Icons.person_outline, size: iconSize),
          onPressed: widget.handleVisitCardSelection,
        ),
        if (widget.type != 'C2G')
          ExtraItem(
            title: 'voice_call'.tr,
            image: const Icon(Icons.phone_outlined, size: iconSize),
            onPressed: () {
              openCallScreen(
                ContactModel.fromMap({
                  "id": widget.options["to"],
                  "nickname": widget.options["title"],
                  "avatar": widget.options["avatar"],
                  "sign": widget.options["sign"],
                }),
                {'media': 'audio'},
              );
            },
          ),
        if (widget.type != 'C2G')
          ExtraItem(
            title: 'video_call'.tr,
            image: const Icon(Icons.videocam_outlined, size: iconSize),
            onPressed: () {
              openCallScreen(
                ContactModel.fromMap({
                  "id": widget.options["to"],
                  "nickname": widget.options["title"],
                  "avatar": widget.options["avatar"],
                  "sign": widget.options["sign"],
                }),
                {'media': 'video'},
              );
            },
          ),
        ExtraItem(
          title: 'favorites'.tr,
          image: const Icon(
            Icons.collections_bookmark_outlined,
            size: iconSize,
          ),
          onPressed: widget.handleCollectSelection,
        ),
        ExtraItem(
          title: 'file'.tr,
          image: const Icon(Icons.insert_drive_file_outlined, size: iconSize),
          onPressed: widget.handleFileSelection,
        ),
      ]),
    ];

    // 防止手势冲突，确保ExtraItems内部交互不会影响输入框
    return GestureDetector(
      // 阻止手势向上传递
      onTap: () {},
      child: Container(
        // height: 240, // Remove fixed height to adapt to panel height
        decoration: BoxDecoration(
          color: ThemeManager.instance.getThemeColor('surface'),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(
              color: ThemeManager.instance
                  .getThemeColor('outline')
                  .withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          children: [
            // 顶部指示器
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: ThemeManager.instance
                    .getThemeColor('outline')
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: items.length > 1
                  ? CarouselSlider(
                      controller: _controller,
                      options: CarouselOptions(
                        height: double.infinity,
                        viewportFraction: 1.0,
                        aspectRatio: 1.0,
                        scrollDirection: Axis.horizontal,
                        enableInfiniteScroll: false,
                        initialPage: 0,
                        onPageChanged: (index, reason) {
                          setState(() {
                            _current = index;
                          });
                        },
                      ),
                      items: items,
                    )
                  : items.first,
            ),
            // 页面指示器
            if (items.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: items.asMap().entries.map((entry) {
                    return GestureDetector(
                      onTap: () => _controller.animateToPage(entry.key),
                      child: Container(
                        width: 8.0,
                        height: 8.0,
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _current == entry.key
                              ? ThemeManager.instance.getThemeColor('primary')
                              : ThemeManager.instance
                                    .getThemeColor('outline')
                                    .withValues(alpha: 0.3),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 构建网格布局的项目
  /// 构建网格布局的项目
  Widget _buildItemsGrid(List<ExtraItem> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.count(
        crossAxisCount: 4, // 每行4个
        childAspectRatio: 0.75, // 调整宽高比，给文字更多空间
        mainAxisSpacing: 8,
        crossAxisSpacing: 12,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: items,
      ),
    );
  }
}
