import 'dart:typed_data';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:fl_amap/fl_amap.dart' as amap;
import 'package:niku/namespace.dart' as n;
import 'package:imboy/component/location/index.dart';
import 'package:imboy/component/location/widget.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/user_model.dart';

class ExtraItem extends StatelessWidget {
  const ExtraItem({
    Key? key,
    required this.onPressed,
    required this.image,
    this.width,
    this.height,
    required this.title,
  }) : super(key: key);

  final Widget image;
  final void Function()? onPressed;
  final double? width;
  final double? height;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed ?? () => Get.snackbar('Tips', '功能暂未实现'),
      child: n.Padding(
        left: 15,
        top: 13,
        right: 15,
        bottom: 0,
        child: n.Column(
          [
            SizedBox(
              width: width ?? 56,
              height: height ?? 56,
              // margin: EdgeInsets.symmetric(horizontal: 10),
              child: Material(
                color: AppColors.ChatInputBackgroundColor,
                // INK可以实现装饰容器
                child: Ink(
                  // 用ink圆角矩形
                  decoration: BoxDecoration(
                    // 背景
                    color: AppColors.ChatInputFillGgColor,
                    // 设置四周圆角 角度
                    borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                    // 设置四周边框
                    border: Border.all(
                      width: 1,
                      color: AppColors.ChatInputBackgroundColor,
                    ),
                  ),
                  child: image is ImageProvider
                      ? Image(
                          image: image as ImageProvider,
                        )
                      : image,
                ),
              ),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }
}

class ExtraItems extends StatefulWidget {
  const ExtraItems({
    Key? key,
    this.handleImageSelection,
    this.handleFileSelection,
    this.handlePickerSelection,
    this.handleLocationSelection,
    required this.options,
  }) : super(key: key);
  final Map options;
  final void Function()? handleImageSelection;
  final void Function()? handleFileSelection;
  final void Function()? handlePickerSelection;
  final void Function(String, Uint8List, String, String, String, String)?
      handleLocationSelection;

  @override
  // ignore: library_private_types_in_public_api
  _ExtraItemsState createState() => _ExtraItemsState();
}

class _ExtraItemsState extends State<ExtraItems> {
  int _current = 0;
  final CarouselController _controller = CarouselController();

  @override
  Widget build(BuildContext context) {
    const double iconSize = 30;
    var items = [
      n.Column(
        [
          n.Row(
            [
              ExtraItem(
                title: "照片".tr,
                image: const Icon(Icons.photo, size: iconSize),
                onPressed: widget.handleImageSelection,
              ),
              ExtraItem(
                title: "拍摄".tr,
                image: const Icon(Icons.camera_alt, size: iconSize),
                onPressed: widget.handlePickerSelection,
              ),
              ExtraItem(
                title: "视频通话".tr,
                image: const Icon(Icons.videocam, size: iconSize),
                onPressed: () {
                  openCallScreen(
                    UserModel.fromJson({
                      "uid": widget.options["to"],
                      "nickname": widget.options["title"],
                      "avatar": widget.options["avatar"],
                      "sign": widget.options["sign"],
                    }),
                    {
                      'media': 'video',
                    },
                  );
                },
              ),
              ExtraItem(
                title: "语音通话".tr,
                image: const Icon(Icons.phone, size: iconSize),
                onPressed: () {
                  openCallScreen(
                    UserModel.fromJson({
                      "uid": widget.options["to"],
                      "nickname": widget.options["title"],
                      "avatar": widget.options["avatar"],
                      "sign": widget.options["sign"],
                    }),
                    {
                      'media': 'audio',
                    },
                  );
                },
              ),
            ],
          ),
          n.Row(
            [
              ExtraItem(
                title: "位置".tr,
                image: const Icon(Icons.location_on, size: iconSize),
                onPressed: () async {
                  amap.AMapLocation? location = await getLocation(true);
                  debugPrint("getLocation ${location?.toMap()}");
                  if (location != null && location.latLng != null) {
                    // ignore: use_build_context_synchronously
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MapLocationPicker(arguments: {
                          "lat": double.parse(
                              location.latLng!.latitude.toString()),
                          "lng": double.parse(
                              location.latLng!.longitude.toString()),
                          "citycode": LocationHelper.getCityNameByGaoDe(
                              location.adCode!),
                          "isMapImage": true
                        }),
                      ),
                    ).then((value) {
                      debugPrint("getLocation MapLocationPicker_reslut $value");
                      if (value != null) {
                        if (value["image"] == null) {
                          EasyLoading.showError("获取地图失败,请重试".tr);
                          FocusScope.of(context).requestFocus(FocusNode());
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
                title: "收藏".tr,
                image: const Icon(Icons.collections_bookmark, size: iconSize),
                onPressed: null,
              ),
              ExtraItem(
                title: "文件".tr,
                image: const Icon(Icons.file_copy, size: iconSize),
                onPressed: widget.handleFileSelection,
              ),
              ExtraItem(
                title: "个人名片".tr, // visit card
                image: const Icon(Icons.person, size: iconSize),
                onPressed: null,
              ),
            ],
          )
        ],
      ),
      n.Column(
        [
          n.Row([
            ExtraItem(
              title: "语音输入".tr,
              image: const Icon(Icons.keyboard_voice, size: iconSize),
              onPressed: null,
            ),
            /**
                ExtraItem(
                title: "卡券".tr,
                image: const AssetImage('assets/images/chat/extra_wallet.png'),
                onPressed: null,
                ),
             */
          ]),
        ],
      ),
    ];
    return n.Column(
      [
        Expanded(
          child: CarouselSlider(
            options: CarouselOptions(
              height: Get.height,
              viewportFraction: 1.0,
              aspectRatio: 2.0,
              scrollDirection: Axis.horizontal,
              disableCenter: true,
              initialPage: 2,
              onPageChanged: (index, reason) {
                setState(() {
                  _current = index;
                });
              },
            ),
            items: items.map((tab) {
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: tab,
              );
            }).toList(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: items.asMap().entries.map((entry) {
            return GestureDetector(
              onTap: () => _controller.animateToPage(entry.key),
              child: Container(
                width: 10.0,
                height: 10.0,
                margin: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 6.0,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black)
                      .withOpacity(_current == entry.key ? 0.7 : 0.2),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
