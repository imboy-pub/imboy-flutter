import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:isar/isar.dart';

part 'contact.g.dart';

@Collection()
class Contact {
  int? id;

  @Index(unique: true)
  late String? uid; // 用户ID
  late String account; // 用户ID
  late String nickname; // 备注 or 昵称
  late String avatar; // 用户头像
  late int gender; // 1 男  2 女  3 保密  0 未知
  late String? status; // offline | online |
  late String remark;
  late String region;
  late String sign;
  late String source;
  int? updateTime;
  late int isfriend;
  late int isfrom;

  String? nameIndex;
  String? namePinyin;
  Color? bgColor;
  Widget? iconData;
  String? firstletter;

  VoidCallback? onPressed;
  VoidCallback? onLongPressed;

  /// 联系人来源描述
  String get sourceTr {
    String sourceTr = "";
    // 通过QQ好友添加
    // 通过群聊添加
    switch (source.toLowerCase()) {
      case 'qrcode':
        // sourceTr = 'source_qrcode'.tr;
        sourceTr = '通过扫一扫添加'.tr;
        break;
    }
    return sourceTr;
  }

  /// 联系人title显示规则： remark > nickname > account
  String get title {
    if (strNoEmpty(remark)) {
      return remark;
    } else if (strNoEmpty(nickname)) {
      return nickname;
    } else {
      return account;
    }
  }
}
