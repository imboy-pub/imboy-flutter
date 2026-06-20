import 'package:flutter/foundation.dart';
import 'package:envied/envied.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/storage_secure.dart';

import 'package:imboy/config/init.dart';

import 'const.dart';
import 'env_pro.dart';
import 'env_dev.dart';
import 'env_field.dart';
import 'env_local.dart';
import 'env_local_home.dart';
import 'env_local_office.dart';

/// 环境映射配置
/// 可用环境: pro, dev, local, local_home, local_office
final envMap = {
  'pro': EnvPro(),
  'dev': EnvDev(),
  'local': EnvLocal(),
  'local_home': EnvLocalHome(),
  'local_office': EnvLocalOffice(),
};

abstract interface class Env implements EnvField {
  factory Env() => _to;

  // ┌─────────────────────────────────────────────────────────────┐
  // │ 🤖 AI 测试框架配置                                           │
  // └─────────────────────────────────────────────────────────────┘

  /// OpenAI API 密钥
  @override
  abstract final String openaiApiKey;

  /// Anthropic API 密钥
  @override
  abstract final String anthropicApiKey;

  /// AI 测试是否启用
  @override
  abstract final bool aiTestEnabled;

  // ┌─────────────────────────────────────────────────────────────┐
  // │ 原有字段                                                    │
  // └─────────────────────────────────────────────────────────────┘

  /// 动态获取当前环境配置（每次访问时重新计算）
  /// 确保当 currentEnv 改变时，Env() 会返回正确的配置
  static Env get _to {
    final env = envMap[currentEnv];
    if (env != null) {
      return env;
    }
    // 如果 currentEnv 不在 envMap 中，默认使用生产环境
    if (kDebugMode) debugPrint('⚠️ [Env] 当前环境无效，使用默认生产环境配置');
    return EnvPro();
  }

  /// 获取签名密钥
  /// 始终返回 solidifiedKey，与服务端保持一致
  /// 注意：不使用 buildSignature，因为 Android 的签名会随构建变化
  static Future<String> signKey() async {
    // 始终使用配置的 solidifiedKey，与服务端保持一致
    return _to.solidifiedKey;
  }

  /// 规范化 WebSocket URL
  /// - 剥掉路径尾部斜杠，后端 Cowboy 路由默认严格匹配 `/ws`，
  ///   若客户端拼成 `/ws/` 会导致 500
  static String? _normalizeWsUrl(String? url) {
    if (url == null || url.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final path = uri.path;
    if (path.length > 1 && path.endsWith('/')) {
      final trimmed = path.substring(0, path.length - 1);
      return uri.replace(path: trimmed).toString();
    }
    return url;
  }

  /// WebSocket URL - 优先从环境配置读取，如果没有则从本地存储读取
  /// Environment-specific WebSocket URL, falls back to cached value
  static String? get effectiveWsUrl {
    // 优先使用环境配置中的 wsUrl
    final envWsUrl = _to.wsUrl;
    if (envWsUrl != null && envWsUrl.isNotEmpty) {
      return _normalizeWsUrl(envWsUrl);
    }

    // 当 wsUrl 为空时的处理逻辑
    final cachedWsUrl = StorageService.to.getString(Keys.wsUrl);

    // 【安全】生产环境不应使用缓存的 WebSocket URL
    // 防止误用开发/测试环境的 WebSocket 地址
    if (currentEnv == 'pro') {
      if (cachedWsUrl.isNotEmpty) {
        if (kDebugMode) debugPrint('⚠️ [Env] 生产环境检测到缓存的 WebSocket URL，将被清除');
        // 清除缓存，防止下次使用
        StorageService.to.remove(Keys.wsUrl);
      }
      // 生产环境返回 null，让应用从服务器获取或使用 API 构造的 URL
      // WebSocket URL 通常从 initConfig API 获取
      return null;
    }

    // 非生产环境可以使用缓存（开发/测试环境）
    if (cachedWsUrl.isNotEmpty) {
      if (kDebugMode) debugPrint('ℹ️ [Env] 使用缓存的 WebSocket URL');
    }
    return _normalizeWsUrl(cachedWsUrl);
  }

  @EnviedField(defaultValue: '')
  static String? apiPublicKey = StorageService.to.getString(Keys.apiPublicKey);

  @EnviedField(defaultValue: '')
  static String uploadUrl = StorageService.to.getString(Keys.uploadUrl);

  @EnviedField(defaultValue: '')
  static String? uploadScene = StorageService.to.getString(Keys.uploadScene);

  /// 公开资源直读基址默认值（Garage 公开读桶 / CDN，见 resource-access-control.md §9）。
  static const String _publicBaseUrlDefault = 'https://s3.imboy.pub';

  /// 公开资源（scope=public，如头像/表情）直读基址。
  ///
  /// 优先用服务端 `/v1/init` 下发值（initConfig 写入 StorageService），未下发时
  /// 回退到内置默认，确保首次启动（init 完成前）头像即可渲染。末尾不带斜杠，
  /// 供 `AssetsService.publicUrl` 直拼 object_key（零 DB 查询、不签名、可 CDN）。
  static String get publicBaseUrl {
    final String cached = StorageService.to.getString(Keys.publicBaseUrl);
    final String base = cached.isNotEmpty ? cached : _publicBaseUrlDefault;
    return base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  }

  // H8: uploadKey stored in secure storage only; never in plaintext SharedPreferences.
  // Use getUploadKey() to load from secure storage and update in-memory cache.
  // Use uploadKeySync for synchronous access after initialization.
  static String? _uploadKeyCache;
  static String? get uploadKeySync => _uploadKeyCache;

  /// For testing only — sets the in-memory cache directly without secure storage.
  @visibleForTesting
  static set uploadKey(String? value) => _uploadKeyCache = value;

  static Future<String?> getUploadKey() async {
    final key = await StorageSecureService.to.read(key: Keys.uploadKey);
    _uploadKeyCache = key;
    return key;
  }
}
