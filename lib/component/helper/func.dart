import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/icon_image_provider.dart';
import 'package:imboy/component/ui/imboy_cached_image_provider.dart';

import 'package:imboy/service/assets.dart';
import 'package:imboy/theme/theme_manager.dart';

// 导出语言辅助工具，方便其他文件使用
export 'locale_helper.dart';

void iPrint(String str) {
  return debugPrint("iPrint $str");
}

/// 获取系统版本（Web 兼容）
///
/// 在 Web 平台返回默认值，在移动端返回实际版本
String getSystemVersion() {
  if (kIsWeb) {
    return 'Web Browser';
  }
  try {
    return Platform.operatingSystemVersion;
  } catch (e) {
    return 'Unknown';
  }
}

/// 获取操作系统类型（Web 兼容）
///
/// 在 Web 平台返回 'web'，在移动端返回 'ios' 或 'android'
String getOperatingSystem() {
  if (kIsWeb) {
    return 'web';
  }
  try {
    if (Platform.isIOS) {
      return 'ios';
    } else if (Platform.isAndroid) {
      return 'android';
    } else if (Platform.isMacOS) {
      return 'macos';
    } else if (Platform.isWindows) {
      return 'windows';
    } else if (Platform.isLinux) {
      return 'linux';
    }
    return 'unknown';
  } catch (e) {
    return 'unknown';
  }
}

///验证网页URl
bool isUrl(String value) {
  RegExp url = RegExp(r"^((https|http|ftp|rtsp|mms)?://)\S+");
  return url.hasMatch(value);
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

String hiddenPhone(String phone) {
  if (phone.isEmpty) return phone;

  final raw = phone.trim();
  if (raw.isEmpty) return '';

  final normalized = raw
      .replaceAll('＋', '+')
      .replaceAllMapped(
        _fullWidthDigitRegExp,
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 65248),
      );

  String cleaned = normalized.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.isEmpty) return '';

  final preservedPrefixMatch = RegExp(r'^[+＋][0-9０-９]{2}').firstMatch(raw);
  final preservedPrefix = preservedPrefixMatch?.group(0) ?? '';

  // 处理中国国际号码（+86开头，11位手机号）
  if (cleaned.startsWith('+86') && cleaned.length == 14) {
    final national = cleaned.substring(3);
    if (national.length == 11) {
      final prefix = preservedPrefix.isNotEmpty ? preservedPrefix : '+86';
      final prefixHasFullWidth = RegExp(r'[０-９]').hasMatch(prefix);
      if (prefixHasFullWidth) {
        return '$prefix${national.substring(0, 2)}****${national.substring(7)}';
      }
      return '$prefix${national.substring(0, 3)}****${national.substring(7)}';
    }
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

final RegExp _internationalRegExp = RegExp(r'^\+\d{5,15}$');
final RegExp _cleanRegExp = RegExp(r'[^\d+]'); // 清理正则
final RegExp _fullWidthDigitRegExp = RegExp(r'[０-９]'); // 全角数字正则
final RegExp _intlCandidateRegExp = RegExp(r'\+\d[\d\s\-\(\)\./]{3,40}\d');
final RegExp _chinaMobileRegExp = RegExp(r'^1[3-9]\d{9}$');
final RegExp _chinaLandlineRegExp = RegExp(r'^(?:0?\d{2,3})\d{7,8}$');

bool isPhone(String? value) {
  if (value == null) return false;
  final raw = value.trim();
  if (raw.isEmpty) return false;

  String normalized = raw
      .replaceAll('＋', '+')
      .replaceAllMapped(
        _fullWidthDigitRegExp,
        (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 65248),
      );

  if (normalized.contains('@')) return false;
  if (normalized.contains('++')) return false;
  if (RegExp(r'\+\s*\d[\d\s\-\(\)\./]*\+').hasMatch(normalized)) return false;

  final isPhoneLikeOnly = RegExp(r'^[\d+\s\-\(\)\./]+$').hasMatch(normalized);
  if (isPhoneLikeOnly) {
    final cleaned = normalized.replaceAll(_cleanRegExp, '');
    return _validateInternational(cleaned) || _validateChina(cleaned);
  }

  for (final m in _intlCandidateRegExp.allMatches(normalized)) {
    final candidate = m.group(0);
    if (candidate == null) continue;
    final compact = candidate.replaceAll(RegExp(r'[\s\-\(\)\./]'), '');
    if (_validateChina(compact) || _validateInternational(compact)) return true;
  }

  final cleaned = normalized.replaceAll(_cleanRegExp, '');
  if (_validateChina(cleaned)) return true;

  final digitsOnly = normalized.replaceAll(RegExp(r'\D'), '');
  final m = RegExp(r'(?:0086|86)?1[3-9]\d{9}').firstMatch(digitsOnly);
  return m != null;
}

bool _validateInternational(String s) {
  if (!s.startsWith('+')) return false;
  // 快速长度筛查
  if (s.length < 6 || s.length > 16) return false;
  if (!_internationalRegExp.hasMatch(s)) return false;

  final digits = s.substring(1);
  if (digits.startsWith('966')) {
    final national = digits.substring(3);
    return national.length == 9 && national.startsWith('5');
  }

  if (digits.startsWith('86')) {
    return _validateChina('+$digits');
  }

  if (digits.startsWith('1')) {
    if (digits.length == 11) return true;
    if (digits.length == 10) return false;
  }

  if (digits.startsWith('44')) {
    var national = digits.substring(2);
    if (national.startsWith('0')) national = national.substring(1);
    return national.length == 10;
  }

  if (digits.startsWith('49')) {
    var national = digits.substring(2);
    if (national.startsWith('0')) national = national.substring(1);
    final n = national.length;
    return n == 10 || n == 11;
  }

  if (digits.startsWith('81')) {
    final n = digits.substring(2).length;
    return n == 9 || n == 10;
  }

  if (digits.startsWith('61')) {
    return digits.substring(2).length == 9;
  }

  if (digits.startsWith('91')) {
    return digits.substring(2).length == 10;
  }

  if (digits.startsWith('55')) {
    final n = digits.substring(2).length;
    return n == 10 || n == 11;
  }

  if (digits.startsWith('7')) {
    return digits.substring(1).length == 10;
  }

  if (digits.startsWith('27')) {
    return digits.substring(2).length == 9;
  }

  if (digits.startsWith('82')) {
    final n = digits.substring(2).length;
    return n >= 8 && n <= 10;
  }

  if (digits.startsWith('33')) {
    return digits.substring(2).length == 9;
  }

  if (digits.startsWith('39')) {
    final n = digits.substring(2).length;
    return n == 10 || n == 11;
  }

  if (digits.startsWith('52')) {
    final national = digits.substring(2);
    return national.length == 10 && !national.startsWith('1');
  }

  if (digits.startsWith('62')) {
    final n = digits.substring(2).length;
    return n >= 7 && n <= 12;
  }

  for (final ccLen in [1, 2, 3]) {
    if (digits.length != ccLen + 11) continue;
    final cc = digits.substring(0, ccLen);
    if (cc == '86') continue;
    final national = digits.substring(ccLen);
    if (_chinaMobileRegExp.hasMatch(national)) return false;
  }

  return true;
}

bool _validateChina(String s) {
  String v = s.replaceAll(_cleanRegExp, '');
  final bool hasChinaPrefix =
      v.startsWith('+86') ||
      v.startsWith('0086') ||
      (v.startsWith('86') && v.length > 11);

  if (v.startsWith('+86')) {
    v = v.substring(3);
  } else if (v.startsWith('0086')) {
    v = v.substring(4);
  } else if (v.startsWith('86') && v.length > 11) {
    v = v.substring(2);
  } else if (v.startsWith('+')) {
    return false;
  }

  if (_chinaMobileRegExp.hasMatch(v)) return true;

  if (hasChinaPrefix) {
    if (v.startsWith('400') || v.startsWith('800')) return false;
    if (_chinaLandlineRegExp.hasMatch(v)) return true;
  }

  return false;
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

ImageProvider<Object> cachedImageProvider(String url, {double w = 400}) {
  if (url.isEmpty) {
    return IconImageProvider(Icons.broken_image);
  }
  if (url.contains("def_avatar.png", 0)) {
    return IconImageProvider(Icons.person);
  }

  try {
    Uri u = AssetsService.viewUrl(url);
    String finalUrl = w > 0 ? "${u.toString()}&width=$w" : u.toString();
    final headers = <String, String>{'User-Agent': 'imboy/1.0.0'};
    return IMBoyCachedImageProvider(finalUrl, headers);
  } on FormatException {
    return IconImageProvider(Icons.broken_image);
  }
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
    icon = const Icon(Icons.male, color: Colors.lightBlueAccent);
  } else if (gender == 2) {
    icon = const Icon(Icons.female, color: Colors.pink);
  } else if (gender == 3) {
    icon = const Icon(Icons.security, color: Colors.black87);
  } else {
    icon = const Icon(Icons.battery_unknown, color: Colors.grey);
  }
  return icon;
}

/// Returns text representation of a provided bytes value (e.g. 1kB, 1GB).
String formatBytes(int size, {int fractionDigits = 2, int num = 1024}) {
  if (size <= 0) return '0 B';
  final multiple = (math.log(size) / math.log(num)).floor();
  return '${(size / math.pow(num, multiple)).toStringAsFixed(fractionDigits)} ${['B', 'kB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'][multiple]}';
}

/// 获取本地主题配置
/// 使用 ThemeManager 获取当前主题模式
ThemeMode getLocalProfileAboutThemeModel({
  bool isUserCache = true,
  int themeType = 0,
}) {
  // 优先使用 ThemeManager 的状态
  final themeManager = ThemeManager.instance;

  if (isUserCache) {
    // 从 ThemeManager 获取当前主题模式
    if (themeManager.followSystemTheme) {
      return ThemeMode.system;
    }
    return themeManager.isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  // 使用传入的 themeType 参数（兼容旧代码）
  iPrint("getLocalProfileAboutThemeModel $themeType");
  if (themeType == 0) {
    return ThemeMode.light;
  } else if (themeType == 1) {
    return ThemeMode.dark;
  } else if (themeType == 2) {
    return ThemeMode.system;
  } else {
    return ThemeMode.system;
  }
}
