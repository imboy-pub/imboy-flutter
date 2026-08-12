import 'package:envied/envied.dart';
import 'env.dart';
import 'env_field.dart';

part 'env_local.g.dart';

@Envied(name: 'Env', path: '.env.local', obfuscate: true)
final class EnvLocal implements Env, EnvField {
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL_OVERRIDE',
    defaultValue: '',
  );
  static const String _wsUrlOverride = String.fromEnvironment(
    'WS_URL_OVERRIDE',
    defaultValue: '',
  );
  static const String _solidifiedKeyOverride = String.fromEnvironment(
    'SOLIDIFIED_KEY_OVERRIDE',
    defaultValue: '',
  );
  static const String _solidifiedKeyIvOverride = String.fromEnvironment(
    'SOLIDIFIED_KEY_IV_OVERRIDE',
    defaultValue: '',
  );

  @override
  @EnviedField(varName: 'API_BASE_URL', obfuscate: false)
  final String apiBaseUrl = _apiBaseUrlOverride.isNotEmpty
      ? _apiBaseUrlOverride
      : _Env.apiBaseUrl;

  @override
  @EnviedField(defaultValue: '', varName: "IOS_APP_ID", obfuscate: false)
  final String iosAppId = _Env.iosAppId;

  @override
  @EnviedField(varName: 'SOLIDIFIED_KEY')
  final String solidifiedKey = _solidifiedKeyOverride.isNotEmpty
      ? _solidifiedKeyOverride
      : _Env.solidifiedKey;

  @override
  @EnviedField(varName: 'SOLIDIFIED_KEY_IV')
  final String solidifiedKeyIv = _solidifiedKeyIvOverride.isNotEmpty
      ? _solidifiedKeyIvOverride
      : _Env.solidifiedKeyIv;

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

  // ┌─────────────────────────────────────────────────────────────┐
  // │ 🤖 AI 测试框架配置                                           │
  // └─────────────────────────────────────────────────────────────┘
  @override
  @EnviedField(defaultValue: '', varName: 'OPENAI_API_KEY', obfuscate: false)
  final String openaiApiKey = _Env.openaiApiKey;

  @override
  @EnviedField(defaultValue: '', varName: 'ANTHROPIC_API_KEY', obfuscate: false)
  final String anthropicApiKey = _Env.anthropicApiKey;

  @override
  @EnviedField(
    defaultValue: false,
    varName: 'AI_TEST_ENABLED',
    obfuscate: false,
  )
  final bool aiTestEnabled = _Env.aiTestEnabled;

  @override
  String? get wsUrl => _wsUrlOverride.isNotEmpty ? _wsUrlOverride : null;
}
