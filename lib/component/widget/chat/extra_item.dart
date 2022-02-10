import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get_utils/src/extensions/internacionalization.dart';
import 'package:imboy/config/const.dart';

class ExtraItem extends StatelessWidget {
  const ExtraItem({
    Key? key,
    required this.onPressed,
    required this.image,
    double? this.width,
    double? this.height,
    required this.title,
  }) : super(key: key);

  final ImageProvider image;
  final void Function()? onPressed;
  final double? width;
  final double? height;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: this.onPressed,
      child: Padding(
        padding: EdgeInsets.only(left: 10, top: 6, right: 10, bottom: 0),
        child: Column(
          children: [
            Container(
              width: this.width ?? 64,
              height: this.height ?? 64,
              // margin: EdgeInsets.symmetric(horizontal: 10),
              child: Material(
                color: AppColors.ChatInputBackgroundColor,
                //INK可以实现装饰容器
                child: new Ink(
                  //用ink圆角矩形
                  decoration: BoxDecoration(
                    //背景
                    color: AppColors.ChatInputFillGgColor,
                    //设置四周圆角 角度
                    borderRadius: BorderRadius.all(Radius.circular(16.0)),
                    //设置四周边框
                    border: new Border.all(
                      width: 1,
                      color: AppColors.ChatInputBackgroundColor,
                    ),
                  ),
                  child: Image(
                    image: this.image,
                  ),
                ),
              ),
            ),
            Text(this.title),
          ],
        ),
      ),
    );
  }
}

class ExtraItems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Row(children: <Widget>[
              ExtraItem(
                title: "照片".tr,
                image: AssetImage('assets/images/chat/extra_photo.webp'),
                onPressed: () {},
              ),
              ExtraItem(
                title: "拍摄".tr,
                image: AssetImage('assets/images/chat/extra_camera.webp'),
                onPressed: () {},
              ),
              ExtraItem(
                title: "语音通话".tr,
                image: AssetImage('assets/images/chat/extra_media.webp'),
                onPressed: () {},
              ),
              ExtraItem(
                title: "位置".tr,
                image: AssetImage('assets/images/chat/extra_localtion.webp'),
                onPressed: () {},
              ),
            ]),
            Row(
              children: <Widget>[
                ExtraItem(
                  title: "语音输入".tr,
                  image: AssetImage('assets/images/chat/extra_voice.webp'),
                  onPressed: () {},
                ),
                ExtraItem(
                  title: "收藏".tr,
                  image: AssetImage('assets/images/chat/extra_favorite.webp'),
                  onPressed: () {},
                ),
                ExtraItem(
                  title: "个人名片".tr,
                  image: AssetImage('assets/images/chat/extra_card.webp'),
                  onPressed: () {},
                ),
                ExtraItem(
                  title: "文件".tr,
                  image: AssetImage('assets/images/chat/extra_file.webp'),
                  onPressed: () {},
                ),
                // ExtraItem(
                //   title: "卡券".tr,
                //   image: AssetImage('assets/images/chat/extra_wallet.webp'),
                //   onPressed: () {},
                // ),
              ],
            ),
          ],
        ));
  }
}
