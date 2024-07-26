import 'package:imboy/config/const.dart';
import 'package:imboy/config/init.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

// API_BASE_URL 结尾不要 /
Map<String, dynamic> envMap = {
  "dev": {
    "apiBaseUrl": "https://dev.imboy.pub",
    "wsUrl": "wss://dev.imboy.pub/ws/",
    "iosAppId": "",
  },
  "pro": {
    "apiBaseUrl": "https://pro.imboy.pub",
    "wsUrl": "wss://pro.imboy.pub/ws/",
  },
  "local": {
    "apiBaseUrl": "http://192.168.2.226:9800",
    "wsUrl": "ws://192.168.2.226:9800/ws/",
    "iosAppId": "",
  },
};

class Env {
  static String get apiBaseUrl {
    return envMap[currentEnv]['apiBaseUrl'].toString();
  }

  static String get iosAppId {
    return envMap[currentEnv]['iosAppId'].toString();
  }

  static String? get wsUrl {
    return envMap[currentEnv]['wsUrl'].toString();
    // return StorageService.to.getString(Keys.wsUrl);
  }

  static String get solidifiedKey {
    return solidifiedKeyEnv;
  }
  static String get solidifiedKeyIv {
    return solidifiedKeyIvEnv;
  }

  static String? get apiPublicKey {
    return StorageService.to.getString(Keys.apiPublicKey);
  }

  static String get uploadUrl {
    return StorageService.to.getString(Keys.uploadUrl)!;
  }

  static String? get uploadScene {
    return StorageService.to.getString(Keys.uploadScene);
  }

  static String? get uploadKey {
    return StorageService.to.getString(Keys.uploadKey);
  }

  static String get amapAndroidKey {
    return EncrypterService.aesDecrypt(
      'kwhyJCFmJXyPYCto3DucDKJu3902sN6owIF44buQM3fQK7CwTFa+dHEeJbCt13aV',
      Env.solidifiedKey,
      Env.solidifiedKeyIv,
    );
  }

  static String get amapIosKey {
    return EncrypterService.aesDecrypt(
      'JivlGIsYLqTqaPRQ+izX2SveLpQasUlAJpKiCdJ5XlMbaKyI0fP+hAZjxyuM9LaP',
      Env.solidifiedKey,
      Env.solidifiedKeyIv,
    );
  }

  static String get amapWebKey {
    return EncrypterService.aesDecrypt(
      'Q4lYiZqNp5gp6/IOS4FfRGuzQIV7Ec6fH2ahPqneZiAfBoGgRQlGrazVOdG8KtxX',
      Env.solidifiedKey,
      Env.solidifiedKeyIv,
    );
  }

  static String get jpushKey {
    String encrypted = 'vuYigRb1o+lUF9hQr06hJUWuAuJiRurw6bLvrl4Qpi4=';
    return EncrypterService.aesDecrypt(
      encrypted,
      Env.solidifiedKey,
      Env.solidifiedKeyIv,
    );
  }

  /// iso 的 buildSignature 未空字符串
  static Future<String> signKey() async {
    String key = (await PackageInfo.fromPlatform()).buildSignature;
    // iPrint("aesDecrypt key 1 $key ;");
    if (key.isEmpty) {
      key = Env.solidifiedKey;
    }
    // iPrint("aesDecrypt key 2 $key ;");
    return key;
  }
}
