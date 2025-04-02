import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/icon_image_provider.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/page/chat/chat/chat_view.dart';
import 'package:imboy/service/assets.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';

iPrint(String str) {
  return debugPrint("iPrint $str");
}

///验证网页URl
bool isUrl(String value) {
  RegExp url = RegExp(r"^((https|http|ftp|rtsp|mms)?://)\S+");
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
  if (val == null) {
    return true;
  }
  return val.trim().isEmpty;
}

/// 字符串不为空
bool strNoEmpty(String? val) {
  return !strEmpty(val);
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

double getMemoryImageCache() {
  return PaintingBinding.instance.imageCache.maximumSize / 1000;
}

void clearMemoryImageCache() {
  PaintingBinding.instance.imageCache.clear();
}

String hiddenPhone(String phone) {
  if (phone.isEmpty) return phone;

  // 去除所有非数字字符
  String cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');

  // 处理中国国际号码（+86开头，11位手机号）
  if (cleaned.startsWith('+86') && cleaned.length == 14) {
    // +8613812345678 → +86138****5678
    return '${cleaned.substring(0, 6)}****${cleaned.substring(10)}';
  } else if (cleaned.length == 13) {
    return '${cleaned.substring(0, 5)}****${cleaned.substring(9)}';
  } else if (cleaned.length == 12) {
    return '${cleaned.substring(0, 4)}****${cleaned.substring(8)}';
  }

  // 处理带0086前缀的中国号码
  if (cleaned.startsWith('0086') && cleaned.length == 15) {
    // 008613812345678 → 0086138****5678
    return '${cleaned.substring(0, 7)}****${cleaned.substring(11)}';
  }

  // 处理普通中国手机号（1开头，11位）
  if (cleaned.startsWith('1') && cleaned.length == 11) {
    return '${cleaned.substring(0, 3)}****${cleaned.substring(7)}';
  }

  // 处理其他国际号码（以+开头）
  if (cleaned.startsWith('+')) {
    if (cleaned.length <= 8) {
      // 短国际号码：显示前3位和最后2位
      return '${cleaned.substring(0, 3)}${'*' * (cleaned.length - 5)}${cleaned.substring(cleaned.length - 2)}';
    } else {
      // 长国际号码：显示前4位和最后4位
      return '${cleaned.substring(0, 5)}${'*' * (cleaned.length - 9)}${cleaned.substring(cleaned.length - 4)}';
    }
  }

  // 默认处理：显示前3位和最后4位
  if (cleaned.length > 7) {
    return '${cleaned.substring(0, 3)}${'*' * (cleaned.length - 7)}${cleaned.substring(cleaned.length - 4)}';
  }

  // 短号码处理
  if (cleaned.length > 3) {
    return '${cleaned.substring(0, 1)}${'*' * (cleaned.length - 2)}${cleaned.substring(cleaned.length - 1)}';
  }

  // 非常短的号码：显示首字符
  return cleaned.isNotEmpty ? '${cleaned[0]}****' : '';
}


// bool isPhone(String? value) {
//   if (strEmpty(value)) {
//     return false;
//   }
//
//   // 去除所有非数字字符和加号
//   String cleaned = value!.replaceAll(RegExp(r'[^0-9+]'), '');
//
//   // 国际号码正则（以+开头，后跟5-14位数字）
//   String internationalPattern = r'^\+\d{5,14}$';
//
//   // 中国手机号码正则（支持所有1[3-9]开头的11位号码，包含国际前缀）
//   String chinaPattern = r'^(?:(?:\+|00)86)?1[3-9]\d{9}$';
//
//   // 检查是否是国际号码或中国号码
//   return RegExp(internationalPattern).hasMatch(cleaned) ||
//       RegExp(chinaPattern).hasMatch(cleaned);
// }


// 预编译所有正则表达式
// final RegExp _digitRegExp = RegExp(r'\d');
final RegExp _plusRegExp = RegExp(r'\+');
final RegExp _internationalRegExp = RegExp(r'^\+\d{5,15}$');
final RegExp _chinaRegExp = RegExp(
  r'^(?:\+?(86)|0086)?(?!.*?(86|0086))1[3-9]\d{9}$',
  caseSensitive: false,
);
final RegExp _cleanRegExp = RegExp(r'[^\d+]'); // 清理正则
final RegExp _fullWidthDigitRegExp = RegExp(r'[０-９]'); // 全角数字正则

bool isPhone(String? value) {
  if (value == null || value.isEmpty) return false;
  // Step 1: 全角转半角
  String normalized = value.replaceAllMapped(_fullWidthDigitRegExp,
          (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 65248));

  // Step 2: 清理非数字和加号字符
  String cleaned = normalized.replaceAll(_cleanRegExp, '');

  // Step 3: 处理加号（只保留首个加号）
  final plusMatches = _plusRegExp.allMatches(cleaned);
  if (plusMatches.length > 1) {
    final firstPlusIndex = plusMatches.first.start;
    cleaned = cleaned[firstPlusIndex] +
        cleaned.substring(firstPlusIndex + 1).replaceAll('+', '');
  }

  // Step 4: 有效性验证
  return _validateInternational(cleaned) || _validateChina(cleaned);
}

bool _validateInternational(String s) {
  if (!s.startsWith('+')) return false;
  // 快速长度筛查
  if (s.length < 6 || s.length > 16) return false;
  return _internationalRegExp.hasMatch(s);
}

bool _validateChina(String s) {
  // 长度快速筛查
  final len = s.startsWith('+') ? s.length - 3 : s.length - 4;
  if (len != 11) return false;

  // 前缀处理
  if (s.startsWith('+86')) {
    s = s.substring(3);
  } else if (s.startsWith('0086')) {
    s = s.substring(4);
  }
  return _chinaRegExp.hasMatch(s);
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

///
/// w < 0 不要缓存大文件，以节省设备存储空间
ImageProvider<Object> cachedImageProvider(String url, {double w = 400}) {
  if (url.contains("def_avatar.png", 0)) {
    return IconImageProvider(Icons.person);
  }

  Uri u = AssetsService.viewUrl(url);
  // 不要缓存大文件，以节省设备存储空间
  if (w < 0) {
    return CachedNetworkImageProvider(
      u.toString(),
      cacheManager: cacheManager,
    );
  }
  String k = "${u.scheme}://${u.host}:${u.port}${u.path}";
  // iPrint("cachedImageProvider_url $u");
  return CachedNetworkImageProvider(
    w > 0 ? "${u.toString()}&width=$w" : u.toString(),
    cacheKey: EncrypterService.md5(k),
    cacheManager: cacheManager,
  );
}

DecorationImage dynamicAvatar(String? avatar, {double w = 400}) {
  // iPrint("dynamicAvatar_avatar $avatar; w $w");
  if (strEmpty(avatar)) {
    return DecorationImage(
      image: IconImageProvider(Icons.person, size: w.toInt()),
      fit: BoxFit.cover,
    );
  }
  return DecorationImage(
    image: cachedImageProvider(avatar!, w: w),
    fit: BoxFit.cover,
  );
}

Widget genderIcon(int gender) {
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
      () => ChatPage(
        peerId: peerId,
        type: type,
        peerTitle: peer.title,
        peerAvatar: peer.avatar,
        peerSign: peer.sign,
      ),
      transition: Transition.rightToLeft,
      popGesture: true, // 右滑，返回上一页
      // binding: ChatBinding(),
    );
  }
}

/// Returns text representation of a provided bytes value (e.g. 1kB, 1GB).
String formatBytes(int size, {int fractionDigits = 2, int num = 1024}) {
  if (size <= 0) return '0 B';
  final multiple = (math.log(size) / math.log(num)).floor();
  return '${(size / math.pow(num, multiple)).toStringAsFixed(fractionDigits)} ${[
    'B',
    'kB',
    'MB',
    'GB',
    'TB',
    'PB',
    'EB',
    'ZB',
    'YB',
  ][multiple]}';
}

/// 获取本地 主题配置
/// 0 白色
/// 1 黑色
/// 2 跟随系统
getLocalProfileAboutThemeModel({
  bool isUserCache = true,
  int themeType = 0,
}) {
  int type =
      isUserCache ? StorageService.to.getInt(Keys.themeType) ?? 0 : themeType;
  iPrint("getLocalProfileAboutThemeModel $type");
  if (type == 0) {
    return ThemeMode.light;
  } else if (type == 1) {
    return ThemeMode.dark;
  } else if (type == 2) {
    return ThemeMode.system;
  }
}
