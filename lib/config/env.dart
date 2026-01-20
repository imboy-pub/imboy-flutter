import 'package:envied/envied.dart';
import 'package:imboy/service/storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:imboy/config/init.dart';

import 'const.dart';
import 'env_pro.dart';
import 'env_dev.dart';
import 'env_field.dart';
import 'env_local_home.dart';
import 'env_local_office.dart';

/// 环境映射配置
/// 可用环境: pro, dev, local_home, local_office
final envMap = {
  'pro': EnvPro(),
  'dev': EnvDev(),
  'local_home': EnvLocalHome(),
  'local_office': EnvLocalOffice(),
  // 保留 'local' 作为向后兼容，默认使用 local_office
  'local': EnvLocalOffice(),
};

abstract interface class Env implements EnvField {
  factory Env() => _to;

  static final Env _to = envMap[currentEnv] ?? EnvPro();

  /// iso 的 buildSignature 未空字符串
  @EnviedField(obfuscate: true)
  static Future<String> signKey() async {
    String key = (await PackageInfo.fromPlatform()).buildSignature;
    // debugPrint("aesDecrypt key 1 $key ;");
    if (key.isEmpty) {
      key = _to.solidifiedKey;
    }
    // debugPrint("aesDecrypt key 2 $key ;");
    return key;
  }

  /// WebSocket URL - 优先从环境配置读取，如果没有则从本地存储读取
  /// Environment-specific WebSocket URL, falls back to cached value
  static String? get effectiveWsUrl {
    // 优先使用环境配置中的 wsUrl
    final envWsUrl = _to.wsUrl;
    if (envWsUrl != null && envWsUrl.isNotEmpty) {
      return envWsUrl;
    }
    // 降级到本地存储的缓存值
    return StorageService.to.getString(Keys.wsUrl);
  }

  @EnviedField(defaultValue: '')
  static String? apiPublicKey = StorageService.to.getString(Keys.apiPublicKey);

  @EnviedField(defaultValue: '')
  static String uploadUrl = StorageService.to.getString(Keys.uploadUrl);

  @EnviedField(defaultValue: '')
  static String? uploadScene = StorageService.to.getString(Keys.uploadScene);

  @EnviedField(defaultValue: '')
  static String? uploadKey = StorageService.to.getString(Keys.uploadKey);
}
