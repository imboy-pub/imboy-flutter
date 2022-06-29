import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/more_item_card.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import 'chat_more_logic.dart';
import 'chat_more_state.dart';

class ChatMorePage extends StatefulWidget {
  final int? index;
  final String? id;
  final String? type;
  final double? keyboardHeight;

  const ChatMorePage({Key? key, this.index = 0, this.id, this.type, this.keyboardHeight,}):super(key: key);

  @override
  _ChatMorePageState createState() => _ChatMorePageState();
}

class _ChatMorePageState extends State<ChatMorePage> {
  final logic = Get.put(ChatMoreLogic());
  final ChatMoreState state = Get.find<ChatMoreLogic>().state;

  List data = [
    {"name": "相册", "icon": "assets/images/chat/extra_photo.webp"},
    {"name": "拍摄", "icon": "assets/images/chat/extra_camera.webp"},
    {"name": "视频通话", "icon": "assets/images/chat/extra_media.webp"},
    {"name": "位置", "icon": "assets/images/chat/extra_localtion.webp"},
    {"name": "红包", "icon": "assets/images/chat/extra_red.webp"},
    {"name": "转账", "icon": "assets/images/chat/extra_transfer.webp"},
    {"name": "语音输入", "icon": "assets/images/chat/extra_voice.webp"},
    {"name": "我的收藏", "icon": "assets/images/chat/extra_favorite.webp"},
  ];

  List dataS = [
    {"name": "名片", "icon": "assets/images/chat/extra_card.webp"},
    {"name": "文件", "icon": "assets/images/chat/extra_file.webp"},
  ];

  List<AssetEntity> assets = <AssetEntity>[];

  action(String name) async {
    if (name == '相册') {
      // AssetPicker.pickAssets(
      //   context,
      //   maxAssets: 9,
      //   pageSize: 320,
      //   pathThumbSize: 80,
      //   gridCount: 4,
      //   selectedAssets: assets,
      //   themeColor: Colors.green,
      //   routeCurve: Curves.easeIn,
      //   routeDuration: const Duration(milliseconds: 500),
      // ).then((List<AssetEntity!> result) {
      //   result!.forEach((AssetEntity element) async {
      //     sendImageMsg(widget.id, widget.type, file: await element.file,
      //         callback: (v) {
      //       if (v == null) return;
      //       Notice.send(ChatActions.msg(), v ?? '');
      //     });
      //     element.file;
      //   });
      // });
    } else if (name == '拍摄') {
      // try {
      //   List<CameraDescription> cameras;
      //
      //   WidgetsFlutterBinding.ensureInitialized();
      //   cameras = await availableCameras();
      //
      //   routePush(ShootPage(cameras));
      // } on CameraException catch (e) {
      //   logError(e.code, e.description);
      // }
    } else {
      Get.snackbar('', '敬请期待$name');
    }
  }

  itemBuild(data) {
    return Container(
      margin: const EdgeInsets.all(20.0),
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Wrap(
        runSpacing: 10.0,
        spacing: 10,
        children: List.generate(data.length, (index) {
          String name = data[index]['name'];
          String icon = data[index]['icon'];
          return MoreItemCard(
            name: name,
            icon: icon,
            keyboardHeight: widget.keyboardHeight,
            onPressed: () => action(name),
          );
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.index == 0) {
      return itemBuild(data);
    } else {
      return itemBuild(dataS);
    }
  }

  @override
  void dispose() {
    Get.delete<ChatMoreLogic>();
    super.dispose();
  }
}
