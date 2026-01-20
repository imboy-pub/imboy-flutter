import 'package:envied/envied.dart';
import 'env.dart';
import 'env_field.dart';

part 'env_local_office.g.dart';

@Envied(name: 'Env', path: '.env.local_office', obfuscate: true)
final class EnvLocalOffice implements Env, EnvField {
  @override
  @EnviedField(varName: 'API_BASE_URL', obfuscate: false)
  final String apiBaseUrl = _Env.apiBaseUrl;

  @override
  @EnviedField(defaultValue: '', varName: "IOS_APP_ID", obfuscate: false)
  final String iosAppId = _Env.iosAppId;

  @override
  @EnviedField(varName: 'SOLIDIFIED_KEY')
  final String solidifiedKey = _Env.solidifiedKey;

  @override
  @EnviedField(varName: 'SOLIDIFIED_KEY_IV')
  final String solidifiedKeyIv = _Env.solidifiedKeyIv;

  @override
  @EnviedField(varName: 'A_MAP_IOS_KEY')
  final String aMapIosKey = _Env.aMapIosKey;

  @override
  @EnviedField(varName: 'A_MAP_ANDROID_KEY')
  final String aMapAndroidKey = _Env.aMapAndroidKey;

  @override
  @EnviedField(varName: 'A_MAP_WEBS_KEY')
  final String aMapWebKey = _Env.aMapWebKey;

  @override
  @EnviedField(varName: 'JPUSH_APPKEY', obfuscate: false)
  final String jiguangAppKey = _Env.jiguangAppKey;

  @override
  @EnviedField(defaultValue: '', varName: 'WS_URL', obfuscate: false)
  final String wsUrl = _Env.wsUrl;
}
