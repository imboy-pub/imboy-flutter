import 'dart:typed_data';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

// ignore: implementation_imports
import 'package:flutter_chat_ui/src/widgets/state/inherited_chat_theme.dart'
    show InheritedChatTheme;
import 'package:niku/namespace.dart' as n;

import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/location/widget.dart';
import 'package:imboy/component/webrtc/func.dart';

import 'package:imboy/store/model/contact_model.dart';

class ExtraItem extends StatelessWidget {
  const ExtraItem({
    super.key,
    required this.onPressed,
    required this.image,
    this.width,
    this.height,
    required this.title,
  });

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
        top: 10,
        right: 15,
        bottom: 0,
        child: n.Column([
          SizedBox(
            width: width ?? 56,
            height: height ?? 56,
            // margin: EdgeInsets.symmetric(horizontal: 10),
            child: Material(
              color: InheritedChatTheme.of(context).theme.inputBackgroundColor,
              // INK可以实现装饰容器
              child: Ink(
                // 用ink圆角矩形
                decoration: BoxDecoration(
                  // 背景
                  color: Get.isDarkMode
                      ? const Color.fromRGBO(38, 38, 38, 1.0)
                      : const Color.fromRGBO(255, 255, 255, 1.0),
                  // 设置四周圆角 角度
                  borderRadius: const BorderRadius.all(Radius.circular(16.0)),
                  // 设置四周边框
                  border: Border.all(
                    width: 1,
                    color: Get.isDarkMode
                        ? const Color.fromRGBO(44, 44, 44, 1.0)
                        : const Color.fromRGBO(255, 255, 255, 1.0),
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
        ]),
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
    required this.options,
  });

  final Map options;
  final void Function()? handleImageSelection;
  final void Function()? handleFileSelection;
  final void Function()? handlePickerSelection;
  final void Function(String, Uint8List, String, String, String, String)?
      handleLocationSelection;
  final void Function()? handleVisitCardSelection;
  final void Function()? handleCollectSelection;

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
      n.Column([
        n.Row([
          ExtraItem(
            title: 'album'.tr,
            image: const Icon(Icons.photo, size: iconSize),
            onPressed: widget.handleImageSelection,
          ),
          ExtraItem(
            title: 'camera'.tr,
            image: const Icon(Icons.camera_alt, size: iconSize),
            onPressed: widget.handlePickerSelection,
          ),
          ExtraItem(
            title: 'video_call'.tr,
            image: const Icon(Icons.videocam, size: iconSize),
            onPressed: () {
              openCallScreen(
                ContactModel.fromMap({
                  "id": widget.options["to"],
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
            title: 'location'.tr,
            image: const Icon(Icons.location_on, size: iconSize),
            onPressed: () async {
              AMapPosition? l = await AMapHelper().startLocation();
              debugPrint("getLocation ${l?.latLng.toJson().toString()}");
              if (l != null) {
                // ignore: use_build_context_synchronously
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MapLocationPicker(arguments: {
                      "lat": double.parse(l.latLng.latitude.toString()),
                      "lng": double.parse(l.latLng.longitude.toString()),
                      "citycode": AMapApi.getCityNameByGaoDe(l.adCode),
                      "isMapImage": true
                    }),
                  ),
                ).then((value) {
                  // debugPrint("getLocation MapLocationPicker_reslut $value");
                  if (value != null) {
                    if (value["image"] == null) {
                      EasyLoading.showError('failed_get_map_try_again'.tr);
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
        ]),
        n.Row([
          ExtraItem(
            title: 'voice_call'.tr,
            image: const Icon(Icons.phone, size: iconSize),
            onPressed: () {
              openCallScreen(
                ContactModel.fromMap({
                  "id": widget.options["to"],
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
          // const SizedBox(width: 86, height: 56,),
          ExtraItem(
            title: 'personal_card'.tr, // visit card
            image: const Icon(Icons.person, size: iconSize),
            onPressed: widget.handleVisitCardSelection,
          ),
          ExtraItem(
            title: 'favorites'.tr,
            image: const Icon(Icons.collections_bookmark, size: iconSize),
            onPressed: widget.handleCollectSelection,
          ),
        ])
      ]),
      n.Column([
        n.Row([
          ExtraItem(
            title: 'file'.tr,
            image: const Icon(Icons.file_copy, size: iconSize),
            onPressed: widget.handleFileSelection,
          ),
          /**
              ExtraItem(
              title: 'voice_input'.tr,
              image: const Icon(Icons.keyboard_voice, size: iconSize),
              onPressed: null,
              ),
              ExtraItem(
              title: 'coupon'.tr,
              image: const AssetImage('assets/images/chat/extra_wallet.png'),
              onPressed: null,
              ),
           */
        ])
      ]),
    ];
    return n.Column([
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
      n.Row(
        items.asMap().entries.map((entry) {
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
                color: (Get.isDarkMode ? Colors.white : Colors.black)
                    .withOpacity(_current == entry.key ? 0.7 : 0.2),
              ),
            ),
          );
        }).toList(),
      )..mainAxisAlignment = MainAxisAlignment.center,
    ]);
  }
}
