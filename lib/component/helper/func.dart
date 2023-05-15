import 'dart:convert';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';

// ignore: depend_on_referenced_packages
import 'package:convert/convert.dart';

// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/chat/chat_binding.dart';
import 'package:imboy/page/chat/chat_view.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

// This alphabet uses `A-Za-z0-9_-` symbols. The genetic algorithm helped
// optimize the gzip compression for this alphabet.
const _alphabet =
    'ModuleSymbhasOwnPr-0123456789ABCDEFGHNRVfgctiUvz_KqYTJkLxpZXIjQW';

/// Generates a random String id
/// Adopted from: https://github.com/ai/nanoid/blob/main/non-secure/index.js
String randomId({int size = 21}) {
  var id = '';
  for (var i = 0; i < size; i++) {
    id += _alphabet[(math.Random().nextDouble() * 64).floor() | 0];
  }
  return id;
}

///验证网页URl
bool isUrl(String value) {
  RegExp url = RegExp(r"^((https|http|ftp|rtsp|mms)?:\/\/)\S+");
  return url.hasMatch(value);
}

///校验身份证
bool isIdCard(String value) {
  RegExp identity = RegExp(r"\d{17}[\d|x]|\d{15}");

  return identity.hasMatch(value);
}

///正浮点数
bool isMoney(String value) {
  RegExp identity =
      RegExp(r"^((\d+\.\d*[1-9]\d*)|(\d*[1-9]\d*\.\d+)|(\d*[1-9]\d*))$");
  return identity.hasMatch(value);
}

///校验中文
bool isChinese(String value) {
  RegExp identity = RegExp(r"[\u4e00-\u9fa5]");

  return identity.hasMatch(value);
}

///校验支付宝名称
bool isAliPayName(String value) {
  RegExp identity = RegExp(r"[\u4e00-\u9fa5_a-zA-Z]");

  return identity.hasMatch(value);
}

bool strEmpty(String? val) {
  return !strNoEmpty(val);
}

/// 字符串不为空
bool strNoEmpty(String? value) {
  if (value == null) {
    return false;
  }
  return value.trim().isNotEmpty;
}

/// 字符串不为空
bool mapNoEmpty(Map? value) {
  if (value == null) {
    return false;
  }
  return value.isNotEmpty;
}

///判断List是否为空
bool listEmpty(List? list) {
  if (list == null) {
    return true;
  }
  return list.isEmpty;
}

///判断List是否为非空
bool listNoEmpty(List? list) {
  if (list == null) {
    return false;
  }
  return list.isNotEmpty;
}

/// 判断是否网络
bool isNetWorkImg(String? img) {
  if (img == null) {
    return false;
  }
  return img.startsWith('http') || img.startsWith('https');
}

/// 判断是否资源图片
bool isAssetsImg(String? img) {
  if (img == null) {
    return false;
  }
  return img.startsWith('asset') || img.startsWith('assets');
}

double getMemoryImageCashe() {
  return PaintingBinding.instance.imageCache.maximumSize / 1000;
}

void clearMemoryImageCache() {
  PaintingBinding.instance.imageCache.clear();
}

String hiddenPhone(String phone) {
  String sub = phone.substring(0, 3);
  String end = phone.substring(phone.length - 3, phone.length);
  return '$sub****$end';
}

bool isPhone(String? value) {
  if (strEmpty(value) || value!.length != 11) {
    return false;
  }
  String pt = '^(\\+\\d{1,2}\\s)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}\$';
  return RegExp(pt).hasMatch(value);
}

bool isEmail(String value) {
  if (strEmpty(value)) {
    return false;
  }
  String pt =
      "^([a-z0-9A-Z]+[-|\\.]?)+[a-z0-9A-Z]@([a-z0-9A-Z]+(-[a-z0-9A-Z]+)?\\.)+[a-zA-Z]{2,}\$";
  // debugPrint("> on isEmail ${value} : ${RegExp(pt).hasMatch(value)}");
  return RegExp(pt).hasMatch(value);
}

///去除后面的0
String stringDisposeWithDouble(v, [fix = 2]) {
  double b = double.parse(v.toString());
  String vStr = b.toStringAsFixed(fix);
  int len = vStr.length;
  for (int i = 0; i < len; i++) {
    if (vStr.contains('.') && vStr.endsWith('0')) {
      vStr = vStr.substring(0, vStr.length - 1);
    } else {
      break;
    }
  }

  if (vStr.endsWith('.')) {
    vStr = vStr.substring(0, vStr.length - 1);
  }

  return vStr;
}

///去除小数点
String removeDot(v) {
  String vStr = v.toString().replaceAll('.', '');
  return vStr;
}

// md5 加密
String generateMD5(String data) {
  // var content = Utf8Encoder().convert(data);
  // var digest = md5.convert(content);
  var digest = md5.convert(utf8.encode(data));
  // 这里其实就是 digest.toString()
  return hex.encode(digest.bytes);
}

ImageProvider cachedImageProvider(String? url, {int w = 400}) {
  if (strEmpty(url)) {
    return const AssetImage(defAvatar);
  }
  if (url!.contains("def_avatar.png", 0)) {
    return const AssetImage(defAvatar);
  }

  return CachedNetworkImageProvider(
    w > 0 ? "$url&width=$w" : url,
    cacheKey: generateMD5(url),
  );
}

DecorationImage dynamicAvatar(String? avatar, {int w = 400}) {
  return DecorationImage(
    image: cachedImageProvider(avatar, w: w),
    fit: BoxFit.cover,
  );
}

dynamic genderIcon(int gender) {
  Widget icon;
  if (gender == 1) {
    icon = const Icon(
      Icons.male,
      color: Colors.lightBlueAccent,
    );
  } else if (gender == 2) {
    icon = const Icon(
      Icons.female,
      color: Colors.pink,
    );
  } else if (gender == 3) {
    icon = const Icon(
      Icons.security,
      color: Colors.black87,
    );
  } else {
    icon = const Icon(
      Icons.battery_unknown,
      color: Colors.grey,
    );
  }
  return icon;
}

void toChatPage(String peerId, String type) async {
  ContactModel? peer = await ContactRepo().findByUid(peerId);
  /*
  // 如果没有联系人，同步去取
  peer ??= await (ContactProvider()).syncByUid(peerId);
  debugPrint("to_chat_page peerId ${peerId} ${peer.toJson().toString()}");

  */
  debugPrint(
      "toChatPage peerId $peerId, type $type, ${peer?.title} peer ${peer?.toJson().toString()}");
  if (peer != null && peer.title != '') {
    debugPrint("toChatPage peerId $peerId, type $type, ${peer.title}");
    Get.to(
      ChatPage(
        peerId: peerId,
        type: type,
        peerTitle: peer.title,
        peerAvatar: peer.avatar,
        peerSign: peer.sign,
      ),
      transition: Transition.rightToLeft,
      popGesture: true, // 右滑，返回上一页
      binding: ChatBinding(),
    );
  }
}
