import 'package:envied/envied.dart';
import 'package:imboy/service/storage.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:imboy/config/init.dart';

import 'const.dart';
import 'env_pro.dart';
import 'env_dev.dart';
import 'env_field.dart';
import 'env_local.dart';

final envMap = {
  'pro': EnvPro(),
  'local': EnvLocal(),
  'dev': EnvDev(),
};

abstract interface class Env implements EnvField {
  factory Env() => _to;

  static final Env _to = envMap[currentEnv] ?? EnvPro();

  /// iso 的 buildSignature 未空字符串
  @EnviedField(obfuscate: true)
  static Future<String> signKey() async {
    String key = (await PackageInfo.fromPlatform()).buildSignature;
    // iPrint("aesDecrypt key 1 $key ;");
    if (key.isEmpty) {
      key = _to.solidifiedKey;
    }
    // iPrint("aesDecrypt key 2 $key ;");
    return key;
  }

  @EnviedField(defaultValue: '')
  static String? wsUrl = StorageService.to.getString(Keys.wsUrl);

  @EnviedField(defaultValue: '')
  static String? apiPublicKey = StorageService.to.getString(Keys.apiPublicKey);

  @EnviedField(defaultValue: '')
  static String uploadUrl = StorageService.to.getString(Keys.uploadUrl)!;

  @EnviedField(defaultValue: '')
  static String? uploadScene = StorageService.to.getString(Keys.uploadScene);

  @EnviedField(defaultValue: '')
  static String? uploadKey = StorageService.to.getString(Keys.uploadKey);
}
