import 'package:flutter/foundation.dart';
import 'package:envied/envied.dart';
import 'package:imboy/service/storage.dart';

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

  /// WebSocket URL - 优先从环境配置读取，如果没有则从本地存储读取
  /// Environment-specific WebSocket URL, falls back to cached value
  static String? get effectiveWsUrl {
    // 优先使用环境配置中的 wsUrl
    final envWsUrl = _to.wsUrl;
    if (envWsUrl != null && envWsUrl.isNotEmpty) {
      return envWsUrl;
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
    return cachedWsUrl;
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
