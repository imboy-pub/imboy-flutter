import 'package:imboy/service/ack_manager.dart';
import 'package:imboy/service/account_local_task_registry.dart';
import 'package:imboy/config/local_external_services_policy.dart';
import 'package:imboy/app_core/feature_flags/runtime_feature_recovery.dart';

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';

import 'package:imboy/page/group/group_avatar_cache.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart'
    show kDebugMode, kIsWeb, visibleForTesting;
import 'package:flutter/widgets.dart';

import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/http/http_interceptor.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/observer/lifecycle.dart';

import 'package:imboy/service/message_offline.dart';
import 'package:imboy/component/upload/resumable_attachment_uploader.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_webrtc.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/web_writer_gate.dart';
import 'package:imboy/service/account_local_data_service.dart';
import 'package:imboy/service/storage_secure.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/service/jpush_flutter_binding.dart';
import 'package:imboy/service/app_logger.dart';
import 'package:imboy/service/app_upgrade_service.dart';
import 'package:imboy/service/event_bus.dart';
import 'package:imboy/app_core/feature_flags/app_feature_registry.dart';
import 'package:imboy/app_core/feature_flags/app_manifest_service.dart';
import 'package:imboy/modules/group_collab/public.dart';
import 'package:imboy/modules/messaging/public.dart';
import 'package:imboy/modules/security_privacy/public.dart';
import 'package:imboy/store/api/user_api.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:xid/xid.dart';

import 'env.dart';
import 'env_factory_web.dart' as webEnv;

import 'package:imboy/service/rsa.dart' show RSAService;

import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'routes.dart';

export 'p2p_call_session.dart';

part 'service_container.dart';

IMBoyCacheManager cacheManager = IMBoyCacheManager();

/// initConfig 缓存（避免重复请求）
Map<String, dynamic>? _initConfigCache;
Completer<Map<String, dynamic>>? _initConfigCompleter;
(String, String)? _initConfigScope;
Completer<Map<String, int>>? _groupSelfHealCompleter;

// ice 配置信息
// Map<String, dynamic>? iceConfiguration;

/// 全局事件总线对象（原始 EventBus 实例）
///
/// 提供 eventBus.fire() 和 eventBus.on<>() 方法
/// 推荐使用静态方法: AppEventBus.fire() / AppEventBus.on<>()
@Deprecated('推荐使用静态方法 AppEventBus.fire() / AppEventBus.on<>()')
dynamic eventBus = AppEventBus.i;
// 全局timer
Timer? gTimer;
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root_navigator',
);

bool _isNavigatingToSignIn = false;

/// 全局标记：App 正在关闭/重新初始化，禁止导航
bool _isAppDisposing = false;

Future<void> quitLoginAndNavigateToSignIn({required String source}) async {
  final repo = UserRepoLocal.to;
  final generation = repo.sessionGeneration;
  await repo.quitLogin(expectedGeneration: generation);
  if (repo.isLoggedOutAfter(generation)) {
    navigateToSignIn(source: source);
  }
}

void navigateToSignIn({String source = 'unknown'}) {
  final generation = UserRepoLocal.to.sessionGeneration;
  if (_isAppDisposing) {
    AppLogger.info('navigateToSignIn skipped (app disposing), source=$source');
    return;
  }
  if (_isNavigatingToSignIn) {
    AppLogger.info('navigateToSignIn skipped (in-flight), source=$source');
    return;
  }

  _isNavigatingToSignIn = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      if (_isAppDisposing ||
          !UserRepoLocal.to.isCurrentSession(generation) ||
          UserRepoLocal.to.isLoggedIn) {
        return;
      }
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.go(AppRoutes.signIn);
      } else {
        AppLogger.warning(
          'navigateToSignIn skipped: context unavailable, source=$source',
        );
      }
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        _isNavigatingToSignIn = false;
      });
    }
  });
  // post-frame 不会自行请求新帧；异步注销结束时界面可能已静止。
  WidgetsBinding.instance.ensureVisualUpdate();
}

/// Connectivity监听器订阅（需要在dispose时取消）
StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

// JPush push = JPush();

String currentEnv = '';

String packageName = '';
String appName = '';
String appVsn = '';
String appVsnMajor = '';
String deviceId = '';

// signKeyVsn 告知服务端用哪个签名key 不同设备类型签名不一样
String globalSignKeyVsn = '1';

// 使用响应式变量来跟踪当前字体大小
ValueNotifier<String> currentFontSize = ValueNotifier('normal');

/// 全局服务容器实例
final serviceContainer = ServiceContainer();

class AppInitializer {
  static bool _initialized = false;

  static bool _observingWriterFailure = false;

  static void _observeWriterFailure() {
    if (!kIsWeb || _observingWriterFailure) return;
    _observingWriterFailure = true;
    unawaited(webWriterFailure.then((_) => _suspendForWriterFailure()));
  }

  static void _suspendForWriterFailure() {
    _isAppDisposing = true;
    void stop(void Function() action) {
      try {
        action();
      } on Object catch (error) {
        AppLogger.warning('Writer pause failed: ${error.runtimeType}');
      }
    }

    stop(AccountLocalTaskRegistry.instance.suspendForStorageFailure);
    stop(PersistentMessageQueue.suspendForStorageFailure);
    stop(MessageRetry.suspendForStorageFailure);
    stop(MessageOfflineService.suspendForStorageFailure);
    stop(AckManager.suspendForStorageFailure);
    stop(WebSocketService.suspendForStorageFailure);
    stop(RuntimeFeatureRecovery.dispose);
    if (serviceContainer.isRegistered<NetworkMonitorService>()) {
      stop(NetworkMonitorService.to.dispose);
    }
    stop(AppUpgradeService.to.dispose);
    gTimer?.cancel();
    gTimer = null;
    final connectivity = _connectivitySubscription;
    _connectivitySubscription = null;
    if (connectivity != null) {
      unawaited(
        connectivity.cancel().catchError((Object error) {
          AppLogger.warning(
            'Writer connectivity pause failed: ${error.runtimeType}',
          );
        }),
      );
    }
    unawaited(
      GroupAvatarMemberCache.instance.suspendAndDrain().catchError((
        Object error,
      ) {
        AppLogger.warning('Writer avatar pause failed: ${error.runtimeType}');
      }),
    );
  }

  static Future<void> initialize({
    required String env,
    required String signKeyVsn,
  }) async {
    LocalExternalServicesPolicy.validateEnvironment(env);
    await prepareWebWriter();
    _observeWriterFailure();
    if (_initialized) return;
    GroupAvatarMemberCache.instance.resume();

    try {
      await _initializeCore(env: env, signKeyVsn: signKeyVsn);
      requireWebWriter();
      await _initializeServices();
      requireWebWriter();
      await _initializeListeners();
      requireWebWriter();
      // 当前字体初始化应该放到最后
      currentFontSize.value = UserRepoLocal.to.setting.fontSize;
      // 成功后才置位：失败路径不置位，InitErrorPage 的「重试」才能重新
      // 走完整初始化（#95：提前置位曾使失败后进程内永久无法自愈）。
      // 并发防御：调用方（main）为单次串行调用，重试由用户显式触发。
      _initialized = true;
    } catch (e, stack) {
      AppLogger.error("Initialization failed", e, stack);
      rethrow;
    }
  }

  static Future<void> _initializeCore({
    required String env,
    required String signKeyVsn,
  }) async {
    // 👇 Web 平台 FFI 初始化（必须在数据库操作前）
    if (kIsWeb) {
      // sqflite FFI 初始化已在 sqlite.dart 中处理
      iPrint('✅ [INIT] Web 平台初始化');
    }

    // 初始化存储 - 必须在使用前先初始化
    await StorageService.init();
    requireWebWriter();
    // Freeze legacy storage evidence before environment setup or any writer.
    await AccountLocalDataService.captureInitialOwnership();
    requireWebWriter();

    // 【重要】先设置环境变量，确保数据库路径正确
    await _setupEnvironment(env, false);
    requireWebWriter();

    // 初始化用户仓库 - 必须在数据库迁移之前注册
    // UserRepoLocal 现在是单例，会自动初始化
    UserRepoLocal.to; // 触发单例初始化

    // 数据库迁移由 SqliteService 的 onUpgrade 回调处理
    // 禁用 MigrationService 的自动迁移，避免双重迁移冲突导致数据丢失
    // await _autoMigrateDatabase();

    // 初始化NTP时间同步（后台补充通道，R20-3：不阻塞必要初始化）
    //
    // sv_ts 校正随每个成功 HTTP 响应发生（主通道），NTP 不可达时
    // 最多白等 2×3s 超时；失败保留 last-good 偏移（NtpHelper 语义），
    // 启动路径不再 await。
    unawaited(NtpHelper.getOffset());

    // 获取设备信息
    await _setupDeviceInfo();
    requireWebWriter();

    // 配置HTTP客户端
    _setupHttpClient();

    // 清理旧的数据库迁移备份（保留7天）
    // Web 平台不支持 path_provider，跳过清理
    if (!kIsWeb) {
      await _cleanupOldMigrationBackups();
    }
  }

  /// 清理旧的数据库迁移备份
  static Future<void> _cleanupOldMigrationBackups() async {
    try {
      final cleaned = await MigrationService.to.cleanupOldSnapshots(
        maxAge: Duration(days: 7),
      );
      if (cleaned > 0) {
        AppLogger.info('Cleaned up $cleaned old migration backups');
      }
    } on Exception catch (e) {
      AppLogger.warning(
        'Failed to cleanup old migration backups: ${e.runtimeType}',
      );
    }
  }

  static Future<void> _setupEnvironment(String env, bool changedEnv) async {
    // 获取之前保存的环境
    final previousEnv = StorageService.to.getString('env');

    if (changedEnv) {
      final savedEnv = previousEnv;
      currentEnv = savedEnv.isEmpty ? env : savedEnv;
    } else {
      currentEnv = env;
    }

    // 确保环境不为空
    if (currentEnv.isEmpty) {
      currentEnv = env;
    }

    // 检测环境变化，清除缓存并重新获取配置
    if (previousEnv.isNotEmpty && previousEnv != currentEnv) {
      AppLogger.info('🔄 Environment changed from $previousEnv to $currentEnv');
      // 【关键】清除 initConfig 缓存，强制从新环境获取配置
      clearInitConfigCache();

      // 【关键】清除存储的旧配置，防止使用旧环境的配置
      await StorageService.to.remove(Keys.apiPublicKey);
      await StorageService.to.remove(Keys.wsUrl);
      await StorageService.to.remove(Keys.uploadUrl);
      await StorageService.to.remove(Keys.uploadKey);
      await StorageService.to.remove(Keys.uploadScene);
      await StorageService.to.remove(Keys.publicBaseUrl);
      await StorageService.to.remove(Keys.effectiveProductExperience);
      await AppFeatureRegistry.clear();

      AppLogger.info(
        '🔄 Cleared all cached configurations due to environment change',
      );

      // 配置请求依赖 HttpClient，而 HttpClient 在 _initializeCore 的后段
      // 注册。这里仅清理旧缓存，交由 _initializeServices 在 HttpClient
      // 注册后统一拉取，避免环境切换时出现 “Service HttpClient not registered”。
      AppLogger.info(
        '🔄 New environment configuration fetch deferred until HttpClient setup',
      );
    }

    await StorageService.to.setString('env', currentEnv);
    AppLogger.info(
      "Running in environment: $currentEnv, Env().apiBaseUrl: ${Env().apiBaseUrl}, wsUrl: ${Env.effectiveWsUrl};",
    );
  }

  static Future<void> _setupDeviceInfo() async {
    serviceContainer.put(DeviceExt());

    if (kIsWeb) {
      deviceId = '';
      try {
        final persistentId = await DeviceExt.did;
        requireWebWriter();
        deviceId = persistentId;
      } on Object {
        throw StateError('Persistent Web device identity is unavailable');
      }
    } else {
      // 【改进】添加错误处理和日志
      try {
        deviceId = await DeviceExt.did;

        if (deviceId.isEmpty) {
          iPrint('❌ [INIT] deviceId 获取失败，使用备用方案');
          deviceId = Xid().toString();
        }

        iPrint('✅ [INIT] deviceId 初始化成功 (长度: ${deviceId.length})');

        // 验证deviceId长度
        if (deviceId.length < 5) {
          throw Exception('deviceId 长度过短: ${deviceId.length}');
        }
      } on Exception catch (e) {
        iPrint('❌ [INIT] deviceId 初始化异常: ${e.runtimeType}');
        // 使用错误备用方案
        deviceId = Xid().toString();
        iPrint('⚠️  [INIT] 使用备用deviceId');
      }
    }

    final packageInfo = await PackageInfo.fromPlatform();
    packageName = packageInfo.packageName;
    appVsn = packageInfo.version;
    appName = packageInfo.appName;

    final versionParts = appVsn.split(RegExp(r"(\.)"));
    appVsnMajor = versionParts.isNotEmpty ? versionParts[0] : '1';
  }

  static void _setupHttpClient() {
    HttpOverrides.global = GlobalHttpOverrides();
    final dioConfig = HttpConfig(
      baseUrl: Env().apiBaseUrl,
      interceptors: [IMBoyInterceptor()],
    );
    serviceContainer.put(HttpClient(conf: dioConfig));
    HttpClient.onAuthExpired = () {
      navigateToSignIn(source: 'http_auth_expired_callback');
    };
  }

  static (String, String) _currentInitScope() {
    final root = Env().apiBaseUrl;
    return (currentEnv, kIsWeb ? webEnv.validateWebApiBaseUrl(root) : root);
  }

  static Map<String, dynamic>? get currentWebBootstrap {
    if (!kIsWeb || _initConfigCache == null) return null;
    try {
      if (_initConfigScope == _currentInitScope()) {
        return Map<String, dynamic>.unmodifiable(_initConfigCache!);
      }
    } on Object {
      // An unavailable/new public origin cannot reuse a previous bootstrap.
    }
    clearInitConfigCache();
    return null;
  }

  static bool _isInitScopeCurrent((String, String) scope) {
    try {
      return _initConfigScope == scope && scope == _currentInitScope();
    } on Object {
      return false;
    }
  }

  static String _webBootstrapUrl(dynamic value, {required bool socket}) {
    if (value is! String || value.isEmpty || RegExp(r'\s').hasMatch(value)) {
      throw const FormatException('Invalid Web bootstrap URL');
    }
    final uri = Uri.tryParse(value);
    final secure = socket ? 'wss' : 'https';
    final local = socket ? 'ws' : 'http';
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.authority.contains('@') ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.hasPort && (uri.port <= 0 || uri.port > 65535)) ||
        (socket && uri.path != '/api/v1/web/ws') ||
        !(uri.scheme == secure ||
            // Loopback 明文放行含 release：本地实验室/self-host 部署形态
            // （127.0.0.1:52392 直连）无 TLS 终结，kReleaseMode 硬性 wss/https
            // 会把这类部署逼到自签证书信任链上；非 loopback 的明文仍拒。
            (uri.scheme == local && webEnv.isWebLoopbackHost(uri.host)))) {
      throw const FormatException('Invalid Web bootstrap URL');
    }
    return socket ? uri.toString() : value.replaceFirst(RegExp(r'/+$'), '');
  }

  @visibleForTesting
  static Map<String, dynamic> validateWebBootstrapPayload(dynamic raw) {
    if (raw is! Map || raw.keys.any((key) => key is! String)) {
      throw const FormatException('Invalid Web bootstrap payload');
    }
    final payload = Map<String, dynamic>.from(raw);
    final rsa = payload['login_pwd_rsa_encrypt'];
    final key = payload['login_rsa_pub_key'];
    final features = payload['features'];
    final terms = payload['terminology'];
    if (!const ['0', '1'].contains(rsa) ||
        key is! String ||
        features is! Map ||
        features.entries.any((e) => e.key is! String || e.value is! bool) ||
        terms is! Map ||
        terms['profile'] is! String ||
        (terms['profile'] as String).isEmpty ||
        terms['hash'] is! String ||
        (terms['hash'] as String).isEmpty ||
        terms['terms'] is! Map ||
        (terms['terms'] as Map).entries.any(
          (e) =>
              e.key is! String ||
              e.value is! String ||
              (e.value as String).isEmpty,
        ) ||
        !const [
          'chat',
          'workspace',
        ].contains(payload['effective_product_experience']) ||
        payload['config_version'] is! String ||
        (payload['config_version'] as String).isEmpty) {
      throw const FormatException('Invalid Web bootstrap fields');
    }
    if (rsa == '1' || key.isNotEmpty) _validateWebBootstrapKey(key);
    payload['ws_url'] = _webBootstrapUrl(payload['ws_url'], socket: true);
    payload['public_base_url'] = _webBootstrapUrl(
      payload['public_base_url'],
      socket: false,
    );
    // Copy JSON containers before persistence awaits or publishing the cache.
    dynamic freeze(dynamic value) {
      if (value is Map) {
        return Map<dynamic, dynamic>.unmodifiable(
          value.map((key, item) => MapEntry(key, freeze(item))),
        );
      }
      if (value is List) return List<dynamic>.unmodifiable(value.map(freeze));
      return value;
    }

    return Map<String, dynamic>.unmodifiable(
      payload.map((key, value) => MapEntry(key, freeze(value))),
    );
  }

  static void _validateWebBootstrapKey(String key) {
    if (!key.startsWith('-----BEGIN PUBLIC KEY-----') ||
        !key.trimRight().endsWith('-----END PUBLIC KEY-----')) {
      throw const FormatException('Invalid Web bootstrap RSA key');
    }
    final publicKey = RSAService.parsePublicKeyFromPem(key);
    if (publicKey.modulus == null ||
        publicKey.modulus!.bitLength < 2048 ||
        publicKey.exponent == null ||
        publicKey.exponent! <= BigInt.one ||
        publicKey.exponent!.isEven) {
      throw const FormatException('Invalid Web bootstrap RSA key');
    }
  }

  static Future<void> _persistWebBootstrap(
    Map<String, dynamic> payload,
    void Function() requireCurrent,
  ) async {
    final values = <String, String>{
      Keys.wsUrl: payload['ws_url'] as String,
      Keys.apiPublicKey: payload['login_rsa_pub_key'] as String,
      Keys.publicBaseUrl: payload['public_base_url'] as String,
      Keys.effectiveProductExperience:
          payload['effective_product_experience'] as String,
    };
    for (final entry in values.entries) {
      requireCurrent();
      final saved = await StorageService.to.setString(entry.key, entry.value);
      requireCurrent();
      if (!saved) throw StateError('Web bootstrap persistence failed');
    }
  }

  static Future<Map<String, dynamic>> initConfig() async {
    final scope = _currentInitScope();
    if (_initConfigScope != scope) {
      clearInitConfigCache();
      _initConfigScope = scope;
    }
    // 1. 如果已有缓存，直接返回
    if (_initConfigCache != null) {
      if (kDebugMode) debugPrint('🔧 initConfig: 返回缓存结果');
      return _initConfigCache!;
    }

    // 2. 如果有正在进行的请求，等待其完成
    final pendingCompleter = _initConfigCompleter;
    if (pendingCompleter != null) {
      if (kDebugMode) debugPrint('🔧 initConfig: 等待进行中的请求');
      final result = await pendingCompleter.future;
      if (!_isInitScopeCurrent(scope) ||
          (!result.containsKey('error') &&
              !identical(_initConfigCache, result))) {
        return {'error': t.common.initConfigFetchFailed};
      }
      return result;
    }

    // 3. 创建新的 Completer 并开始请求
    // 立即捕获局部引用：clearInitConfigCache() 可能在本次调用进行中
    // 被外部（如登出/切换环境）并发调用，把静态字段置空；下方一律用
    // 局部变量 completer 而非重新解引用静态字段，避免 `!` 空值崩溃。
    final completer = Completer<Map<String, dynamic>>();
    _initConfigCompleter = completer;
    void requireCurrent() {
      if (!_isInitScopeCurrent(scope) ||
          !identical(_initConfigCompleter, completer)) {
        throw StateError('Initialization scope changed');
      }
    }

    if (kDebugMode) debugPrint('🔧 initConfig: 开始获取配置');

    try {
      // 重试逻辑：最多 3 次，指数退避 (1s, 2s, 4s)
      const maxRetries = 3;
      IMBoyHttpResponse? resp1;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        requireCurrent();
        resp1 = await HttpClient.client
            .get(kIsWeb ? '${scope.$2}/api/v1/web/bootstrap' : API.initConfig)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                if (kDebugMode) debugPrint('❌ initConfig: 请求超时 (10秒)');
                return IMBoyHttpResponse.failure(
                  errMsg: t.common.initConfigTimeout,
                  errCode: 408,
                );
              },
            );

        requireCurrent();
        if (resp1.ok) break;

        if (attempt < maxRetries) {
          final delay = Duration(seconds: 1 << (attempt - 1)); // 1s, 2s, 4s
          await Future<dynamic>.delayed(delay);
          requireCurrent();
        }
      }

      if (!resp1!.ok) {
        final error = {
          "error": t.common.initConfigNetworkError(code: resp1.code.toString()),
        };
        completer.complete(error);
        return error;
      }

      late final Map<String, dynamic> payload;
      if (kIsWeb) {
        payload = validateWebBootstrapPayload(resp1.payload);
      } else {
        // res_v2 = AES-256-GCM 自包含密文（AEAD 有认证 + 每次随机 IV）；
        // res = 旧的 AES-256-CBC + 固定 IV + 无认证标签，仅在后端
        // init_config_legacy_cbc=on 的过渡期还会下发。优先吃 v2。
        final encryptedV2 =
            IMBoyHttpResponse.payloadStr(resp1.payload, 'res_v2') ?? '';
        final encrypted =
            IMBoyHttpResponse.payloadStr(resp1.payload, 'res') ?? '';
        final bool useGcm = encryptedV2.isNotEmpty;
        if (kDebugMode) {
          debugPrint(
            '🔧 initConfig: 加密内容长度='
            '${useGcm ? encryptedV2.length : encrypted.length}'
            ' 模式=${useGcm ? "gcm" : "cbc(legacy)"}',
          );
        }

        if (!useGcm && encrypted.isEmpty) {
          if (kDebugMode) debugPrint('❌ initConfig: ��密内容为空');
          final error = {"error": t.common.initConfigProtocolError};
          completer.complete(error);
          return error;
        }

        if (kDebugMode) debugPrint('🔧 initConfig: 开始解密配置');
        final key = await Env.signKey();
        requireCurrent();
        if (kDebugMode) debugPrint('🔐 [INIT] signKey initialized');
        final String md5Key = EncrypterService.md5(key);
        final String decrypted;
        try {
          decrypted = useGcm
              ? utf8.decode(
                  EncrypterService.aesGcmDecryptSelfContained(
                    encryptedV2,
                    Uint8List.fromList(utf8.encode(md5Key)),
                  ),
                )
              : EncrypterService.aesDecrypt(
                  encrypted,
                  md5Key,
                  Env().solidifiedKeyIv,
                );
        } on Exception catch (e) {
          // H2 真机走查发现③：解密失败 = 密钥不匹配或密文损坏——能走到这里
          // 说明网络与后端都正常，笼统报"请检查网络连接"会误导排障方向。
          // 单独分类并给出行动指引（更新应用/核对密钥）。
          if (kDebugMode) {
            debugPrint('❌ initConfig: 配置解密失败（APP 与服务端密钥不一致？）: $e');
          }
          final error = {"error": t.common.initConfigDecryptFailed};
          if (!completer.isCompleted) {
            completer.complete(error);
          }
          return error;
        }
        payload = jsonDecode(decrypted) as Map<String, dynamic>;
        if (kDebugMode) debugPrint('🔧 initConfig: 解密完成');
      }
      requireCurrent();

      if (payload.containsKey('error')) {
        if (kDebugMode) debugPrint('❌ initConfig: payload包含错误');
        completer.complete(payload);
        return payload;
      }

      // 安全日志：不输出完整配置负载，可能包含敏感的 URL 和密钥
      if (kDebugMode) {
        debugPrint(
          '🔧 initConfig 诊断: env=$currentEnv keys=${payload.keys.toList()}',
        );
      }

      if (kIsWeb) {
        await _persistWebBootstrap(payload, requireCurrent);
      } else {
        requireCurrent();
        final wsUrl = payload['ws_url'];
        if (kDebugMode) {
          debugPrint(
            '🔧 initConfig 诊断: ws_url=${wsUrl == null ? "null" : "(${wsUrl.runtimeType}, len=${wsUrl.toString().length})"}',
          );
        }

        if (wsUrl != null && wsUrl.isNotEmpty == true) {
          requireCurrent();
          await StorageService.to.setString(Keys.wsUrl, wsUrl as String);
          requireCurrent();
          if (kDebugMode) debugPrint('✅ initConfig: Saved ws_url to storage');
        }

        // null 安全转换：后端 E2EE 改造后 upload_key/upload_scene 可能为空串或缺失，
        // 直接 `as String` 遇 null 会抛 TypeError(Error 子类)，无法被 on Exception 捕获，导致 init 硬崩
        requireCurrent();
        await StorageService.to.setString(
          Keys.uploadUrl,
          IMBoyHttpResponse.payloadStr(payload, 'upload_url') ?? '',
        );
        requireCurrent();
        // H8: upload_key 改用加密安全存储，同时更新内存缓存供同步访问。
        // macOS 桌面 ad-hoc 签名（project.pbxproj: CODE_SIGN_IDENTITY="-"、
        // DEVELOPMENT_TEAM="") 下 keychain-access-groups 无有效 team 前缀，
        // Keychain 一律拒绝 → PlatformException -34018，安全存储 read/write 均抛；
        // 此处隔离该失败，避免单个 upload_key 拖垮整个 initConfig
        //（否则 apiPublicKey/缓存无法落盘 → 登录链断）。
        try {
          await StorageSecureService.to.write(
            key: Keys.uploadKey,
            value: IMBoyHttpResponse.payloadStr(payload, 'upload_key') ?? '',
          );
          requireCurrent();
          await Env.getUploadKey(); // populate in-memory cache
          requireCurrent();
        } on Exception catch (e) {
          AppLogger.warning('upload_key secure persistence unavailable: $e');
        }
        requireCurrent();
        await StorageService.to.setString(
          Keys.uploadScene,
          IMBoyHttpResponse.payloadStr(payload, 'upload_scene') ?? '',
        );

        requireCurrent();
        await StorageService.to.setString(
          Keys.apiPublicKey,
          IMBoyHttpResponse.payloadStr(payload, 'login_rsa_pub_key') ?? '',
        );

        // 公开资源直读基址（scope=public，如头像）：缺失时存空串，
        // Env.publicBaseUrl 读取时回退到内置默认（见 resource-access-control.md §9）。
        requireCurrent();
        await StorageService.to.setString(
          Keys.publicBaseUrl,
          IMBoyHttpResponse.payloadStr(payload, 'public_base_url') ?? '',
        );

        // 保留旧安装级体验字段的缓存兼容；首页模式由账号本机选择决定，
        // 不再用服务端默认值代替用户选择企业。
        requireCurrent();
        await StorageService.to.setString(
          Keys.effectiveProductExperience,
          IMBoyHttpResponse.payloadStr(
                payload,
                'effective_product_experience',
              ) ??
              '',
        );
      }
      requireCurrent();

      // 4. 缓存结果并完成
      final result = kIsWeb
          ? Map<String, dynamic>.unmodifiable(payload)
          : payload;
      _initConfigCache = result;
      completer.complete(result);
      return result;
    } on Object catch (e, stack) {
      // 记录真实异常以便诊断（如 macOS Keychain entitlement 缺失会抛 PlatformException）
      if (kIsWeb) {
        AppLogger.error('Web bootstrap failed: ${e.runtimeType}');
      } else {
        AppLogger.error(
          "initConfig failed during payload persistence",
          e,
          stack,
        );
      }
      if (kDebugMode) {
        debugPrint('❌ initConfig: 配置处理异常 ${e.runtimeType}');
      }
      final error = {"error": t.common.initConfigFetchFailed};
      // 确保在异常情况下也清理 Completer
      if (!completer.isCompleted) {
        completer.complete(error);
      }
      return error;
    } finally {
      // 5. 清理 Completer：仅当静态字段仍指向本次调用创建的实例时才清空，
      // 避免覆盖并发场景下由外部竞态（clearInitConfigCache）产生的另一个
      // in-flight completer。
      if (identical(_initConfigCompleter, completer)) {
        _initConfigCompleter = null;
      }
    }
  }

  static Future<void> _initializeServices() async {
    requireWebWriter();
    // UserRepoLocal 已在 _initializeCore() 中提前注册

    // AppEventBus 已改为静态方法封装，无需注册
    // 提供统一的事件发布/订阅机制，用于服务间解耦通信
    iPrint('✅ [INIT] AppEventBus 使用静态方法模式');

    // 初始化网络监控服务（必须在HttpClient使用之前初始化）
    final networkMonitorService = NetworkMonitorService.to;
    serviceContainer.put(networkMonitorService);
    networkMonitorService.init(); // 调用初始化方法

    // 检查API公钥或是否需要重新获取配置
    // 【重要】如果之前是其他环境，需要重新获取配置
    final needFetchConfig =
        strEmpty(Env.apiPublicKey) || _initConfigCache == null;
    if (needFetchConfig) {
      AppLogger.info(
        '🔧 Fetching initConfig (apiPublicKey empty: ${strEmpty(Env.apiPublicKey)}, cache null: ${_initConfigCache == null})',
      );
      final config = await initConfig();
      requireWebWriter();
      if (kIsWeb &&
          (config.containsKey('error') || currentWebBootstrap == null)) {
        throw StateError('Web bootstrap initialization failed');
      }
    } else {
      AppLogger.info('✅ Using cached initConfig (apiPublicKey exists)');
    }

    AppFeatureRegistry.bindScope(
      endpoint: Env().apiBaseUrl,
      uid: UserRepoLocal.to.currentUid,
    );
    AppManifestService.loadFromCache();
    await RuntimeFeatureRecovery.refreshNow();
    requireWebWriter();

    // 初始化WebSocket和相关服务
    await _initializeWebSocketServices();
    requireWebWriter();
    unawaited(ResumableAttachmentUploader.recoverCurrentSession());

    // 初始化推送通知服务（FCM token 注册 + 前台消息监听）
    await PushNotificationService.instance.initialize();

    // Q09/G2（AC23 Android 前置）：JPush SDK 接线（EPGZ-06 W3 桥的 W4
    // 集成波次落点）。一期 phase1 profile 语义：`--dart-define
    // IMBOY_JPUSH_ENABLED` 缺省 false → standard 构建零行为变化；
    // Android + 构建开关开启才 setup/注册（JPushSdkWiring 内部守卫）。
    // 安全性：unawaited（不阻塞启动链）+ 内部 _initialized 幂等守卫 +
    // 原生异常 try-catch 降级（失败 = 无推送，不影响其余功能）。
    unawaited(JPushSdkWiring().initialize());

    // 初始化地图服务
    AMapHelper.init(); // 设置隐私协议（必须先调用）
    AMapHelper.setApiKey(); // 设置 API key

    // 初始化APP升级检查服务（延迟3秒检查，不阻塞启动）
    await AppUpgradeService.to.init();
  }

  static Future<void> _initializeWebSocketServices() async {
    requireWebWriter();
    // 注册消息队列服务
    final messageQueue = PersistentMessageQueue.to;
    await messageQueue.init();
    requireWebWriter();
    serviceContainer.put(messageQueue);

    // 使用lazyPut注册消息相关服务，避免循环依赖问题
    // 注册顺序很重要，被依赖的模块必须先注册
    // AckManager 使用单例模式，通过 AckManager.to 访问，无需手动注册
    serviceContainer.lazyPut<MessagingFacade>(() => MessagingFacade.instance);
    serviceContainer.lazyPut<MessageWebrtc>(() => MessageWebrtc.instance);
    serviceContainer.lazyPut<MessageOfflineService>(
      () => MessageOfflineService.instance,
    );
    serviceContainer.lazyPut<MessageRetry>(() => MessageRetry.instance);

    // 初始化各种逻辑控制器
    // ChatLogic 已迁移到 Riverpod，不再需要手动注册
    // serviceContainer.put(ChatLogic()); // 1

    // 初始化 E2EE 健康检查与自愈服务（支持增量通知拉取与设备权威状态对账）
    E2EEHealthCheckService.to.init();
    iPrint('✅ [INIT] E2EE健康检查与自愈服务已初始化');

    // 最后初始化WebSocket服务，确保依赖的服务都已注册
    final wsService = WebSocketService.to;
    serviceContainer.put<WebSocketService>(wsService);
    wsService.init(); // 调用初始化方法

    // 如果已登录，尝试连接WebSocket
    if (UserRepoLocal.to.isLoggedIn) {
      await wsService.openSocket(from: 'initialization');
      unawaited(triggerGroupMembershipSelfHeal(source: 'initialization'));
    }
  }

  static Future<Map<String, int>> triggerGroupMembershipSelfHeal({
    bool force = false,
    String source = 'manual',
  }) async {
    if (_groupSelfHealCompleter != null) {
      AppLogger.info(
        'Group membership self-heal already running, source=$source',
      );
      return _groupSelfHealCompleter!.future;
    }
    _groupSelfHealCompleter = Completer<Map<String, int>>();
    try {
      final result = await _runGroupMembershipSelfHeal(
        force: force,
        source: source,
      );
      if (!_groupSelfHealCompleter!.isCompleted) {
        _groupSelfHealCompleter!.complete(result);
      }
      return result;
    } on Object catch (e) {
      final fallback = {'skipped': 1, 'errors': 1, 'reason': 500};
      AppLogger.warning(
        'Group membership self-heal trigger failed: ${e.runtimeType}',
      );
      if (!_groupSelfHealCompleter!.isCompleted) {
        _groupSelfHealCompleter!.complete(fallback);
      }
      return fallback;
    } finally {
      _groupSelfHealCompleter = null;
    }
  }

  static Future<Map<String, int>> _runGroupMembershipSelfHeal({
    bool force = false,
    String source = 'internal',
  }) async {
    if (!UserRepoLocal.to.isLoggedIn) {
      return {'skipped': 1, 'errors': 0, 'reason': 401};
    }
    final uid = UserRepoLocal.to.currentUid;
    if (uid.isEmpty) {
      return {'skipped': 1, 'errors': 0, 'reason': 400};
    }

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      AppLogger.info(
        'Group membership self-heal skipped (offline), source=$source',
      );
      return {'skipped': 1, 'errors': 0, 'reason': 0};
    }

    final dayMark = DateTime.now().toIso8601String().split('T').first;
    final markerKey =
        '${Keys.groupMembershipSelfHealPrefix}_${currentEnv}_$uid';
    final lastMark = StorageService.to.getString(markerKey);
    if (!force && lastMark == dayMark) {
      AppLogger.info(
        'Group membership self-heal skipped (already done today), source=$source',
      );
      return {'skipped': 1, 'errors': 0, 'reason': 1};
    }

    try {
      final result = await GroupListService().selfHealMembershipShadows();
      final errors = result['errors'] ?? 0;
      final groupRows = result['groupRows'] ?? 0;
      final ownerRows = result['ownerRows'] ?? 0;
      final joinRows = result['joinRows'] ?? 0;
      final managerRows = result['managerRows'] ?? 0;
      final beforeOwner = result['beforeOwner'] ?? 0;
      final beforeJoin = result['beforeJoin'] ?? 0;
      final beforeManager = result['beforeManager'] ?? 0;
      final afterOwner = result['afterOwner'] ?? 0;
      final afterJoin = result['afterJoin'] ?? 0;
      final afterManager = result['afterManager'] ?? 0;
      final deltaOwner = result['deltaOwner'] ?? 0;
      final deltaJoin = result['deltaJoin'] ?? 0;
      final deltaManager = result['deltaManager'] ?? 0;
      if (errors == 0) {
        await StorageService.to.setString(markerKey, dayMark);
      }
      AppLogger.info(
        'Group membership self-heal done: '
        'groupRows=$groupRows, ownerRows=$ownerRows, joinRows=$joinRows, '
        'managerRows=$managerRows, '
        'before(owner/join/manager)=($beforeOwner/$beforeJoin/$beforeManager), '
        'after(owner/join/manager)=($afterOwner/$afterJoin/$afterManager), '
        'delta(owner/join/manager)=($deltaOwner/$deltaJoin/$deltaManager), '
        'errors=$errors, source=$source',
      );
      return result;
    } on Exception catch (e) {
      AppLogger.warning('Group membership self-heal failed: ${e.runtimeType}');
      return {'skipped': 0, 'errors': 1, 'reason': 500};
    }
  }

  static Future<void> _initializeListeners() async {
    requireWebWriter();
    // 应用生命周期监听
    WidgetsBinding.instance.addObserver(
      LifecycleEventHandler(
        resumeCallBack: _onAppResume,
        suspendingCallBack: () async {
          // app 挂起
          iPrint("> on LifecycleEventHandler suspendingCallBack");
        },
        pausedCallBack: () async {
          iPrint("> on LifecycleEventHandler pausedCallBack");
          // 已暂停的
        },
      ),
    );

    // 网络连接状态监听（保存订阅以便后续取消）
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );
  }

  static Future<void> _onAppResume() async {
    if (!isWebWriterReady) return;
    AppLogger.info("App resumed");
    unawaited(RuntimeFeatureRecovery.refreshNow());

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!isWebWriterReady) return;
      if (UserRepoLocal.to.isLoggedIn) {
        final token = await UserRepoLocal.to.accessToken;
        if (tokenExpired(token)) {
          await _refreshToken();
        }

        // App恢复时主动拉取E2EE密钥通知，保证最新的换机公钥对齐
        unawaited(E2EEHealthCheckService.to.pullKeyNotifications());

        // 检查WebSocket服务是否已注册
        if (serviceContainer.isRegistered<WebSocketService>()) {
          // 【修复】不再强制重连WebSocket，避免消息入队延迟
          // 如果WebSocket连接正常，直接拉取离线消息即可
          final wsService = WebSocketService.to;
          if (wsService.status == SocketStatus.connected) {
            AppLogger.info('App恢复，WebSocket已连接，拉取离线消息...');
            // 【关键优化】App恢复时主动拉取离线消息，兜底处理
            await MessageOfflineService.instance.requestPull(
              source: 'AppResume',
              reason: '应用恢复',
            );
            unawaited(triggerGroupMembershipSelfHeal(source: 'app_resume'));
          } else {
            AppLogger.info('App恢复，WebSocket未连接(${wsService.status})，主动重连...');
            wsService.openSocket(from: 'AppResume');
          }
        } else {
          AppLogger.info('WebSocket服务未注册，跳过连接检查');
        }

        // 检查是否需要设置密码
        final needSetPwd = StorageService.to.getBool(Keys.needSetPwd) ?? false;
        if (needSetPwd) {
          final ctx = navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            // 使用 go_router 导航
            ctx.go('/set_password');
          }
        }
      }
    });
  }

  // 获取 context 的辅助方法
  static BuildContext? get context => navigatorKey.currentContext;

  static Future<void> _refreshToken() async {
    try {
      AppLogger.info('Refreshing expired token');
      final refreshToken = await UserRepoLocal.to.refreshToken;
      if (refreshToken != "") {
        await UserApi.to.refreshAccessTokenApi(refreshToken);
      }
    } on Exception catch (e) {
      AppLogger.error("Failed to refresh token", e);
      // 可以考虑在这里处理token刷新失败的情况，比如退出登录
    }
  }

  static Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    if (!isWebWriterReady) return;
    AppLogger.info("Connectivity changed: $results");
    if (!results.contains(ConnectivityResult.none)) {
      unawaited(RuntimeFeatureRecovery.refreshNow());
    }

    // 检查WebSocket服务是否已注册
    if (!serviceContainer.isRegistered<WebSocketService>()) {
      AppLogger.info('WebSocket服务未注册，跳过连接状态处理');
      return;
    }

    try {
      if (results.contains(ConnectivityResult.none)) {
        await WebSocketService.to.closeSocket();
      } else if (UserRepoLocal.to.isLoggedIn) {
        await WebSocketService.to.openSocket(from: 'connectivityChanged');
      }
    } on Exception catch (e) {
      AppLogger.error('WebSocket连接状态处理失败: ${e.runtimeType}');
    }
  }

  /// 清理 initConfig 缓存（强制下次调用时重新获取配置）
  static void clearInitConfigCache() {
    _initConfigCache = null;
    _initConfigCompleter = null;
    _initConfigScope = null;
    if (kDebugMode) debugPrint('🔧 initConfig: 缓存已清理');
  }

  /// 释放资源（在应用退出或重新初始化前调用）
  static Future<void> dispose() async {
    AppLogger.info('Disposing AppInitializer resources...');
    _isAppDisposing = true;
    RuntimeFeatureRecovery.dispose();
    await GroupAvatarMemberCache.instance.suspendAndDrain();

    // 取消网络监听器
    await _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    // 取消全局定时器
    gTimer?.cancel();
    gTimer = null;

    // 清理WebSocket连接
    try {
      if (serviceContainer.isRegistered<WebSocketService>()) {
        await WebSocketService.to.closeSocket();
      }
    } on Exception catch (e) {
      AppLogger.warning('Failed to close WebSocket: ${e.runtimeType}');
    }

    // 清理MessageOfflineService资源
    try {
      MessageOfflineService.instance.onDispose();
    } on Exception catch (e) {
      AppLogger.warning(
        'Failed to dispose MessageOfflineService: ${e.runtimeType}',
      );
    }

    // 清理MessageRetry资源（定时器和事件订阅）
    try {
      MessageRetry.instance.dispose();
    } on Exception catch (e) {
      AppLogger.warning('Failed to dispose MessageRetry: ${e.runtimeType}');
    }

    // 停止升级检查定时器
    AppUpgradeService.to.dispose();

    // 清理 initConfig 缓存
    clearInitConfigCache();

    AppLogger.info('AppInitializer dispose completed');
  }

  /// 重置初始化状态（用于测试或重新初始化）
  static void reset() {
    _initialized = false;
    _isAppDisposing = false;
    serviceContainer.clear();
    AppLogger.info('AppInitializer reset completed');
  }
}
