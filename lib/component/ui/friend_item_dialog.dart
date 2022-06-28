import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/config/const.dart';

import 'confirm_alert.dart';

typedef OnSuCc = void Function(bool v);

friendItemDialog(BuildContext context, {String? userId, OnSuCc? suCc}) {
  action(v) {
    Navigator.of(context).pop();
    if (v == '删除') {
      confirmAlert(
        context,
        (bool) {
          // if (bool) delFriend(userId, context, suCc: (v) => suCc(v));
        },
        tips: '你确定要删除此联系人吗',
        okBtn: '删除',
        warmStr: '删除联系人',
        isWarm: true,
        style: const TextStyle(fontWeight: FontWeight.w500),
      );
    } else {
      Get.snackbar('', '参数有误');
    }
  }

  Widget item(item) {
    return Container(
      width: Get.width,
      decoration: BoxDecoration(
        border: item != '删除'
            ? const Border(
                bottom: BorderSide(color: AppColors.LineColor, width: 0.2),
              )
            : null,
      ),
      child: TextButton(
        // padding: EdgeInsets.symmetric(vertical: 15.0),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15.0),
          backgroundColor: Colors.white,
        ),
        autofocus: true,
        onPressed: () => action(item),
        child: Text(item),
      ),
    );
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      List data = [
        '设置备注和标签',
        '把她推荐给朋友',
        '设为星标好友',
        '设置朋友圈和视频动态权限',
        '加入黑名单',
        '投诉',
        '添加到桌面',
        '删除',
      ];

      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: <Widget>[
              Expanded(
                child: InkWell(
                  child: Container(),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.all(
                  Radius.circular(10.0),
                ),
                child: Container(
                  color: Colors.white,
                  child: Column(
                    children: <Widget>[
                      Column(children: data.map(item).toList()),
                      HorizontalLine(
                          color: AppColors.AppBarColor, height: 10.0),
                      TextButton(
                        // padding: EdgeInsets.symmetric(vertical: 15.0),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15.0),
                          backgroundColor: Colors.white,
                        ),
                        autofocus: true,
                        onPressed: () => Navigator.of(context).pop(),
                        child: Container(
                          width: Get.width,
                          alignment: Alignment.center,
                          child: const Text('取消'),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      );
    },
  );
}
