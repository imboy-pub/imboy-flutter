import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/cupertino.dart';

import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/migration_service.dart';
import 'package:imboy/service/websocket_message_queue.dart';
import 'package:logger/logger.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/http/http_interceptor.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/observer/lifecycle.dart';
import 'package:imboy/component/webrtc/session.dart';

import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_webrtc.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/service/push_notification_service.dart';
import 'package:imboy/service/encryption_mode.dart';
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
import 'package:go_router/go_router.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'routes.dart';

IMBoyCacheManager cacheManager = IMBoyCacheManager();

typedef VoidCallbackConfirm = void Function(bool isOk);

enum ClickType { select, open }

bool p2pCallScreenOn = false;

var logger = Logger();

/// initConfig 缓存（避免重复请求）
Map<String, dynamic>? _initConfigCache;
Completer<Map<String, dynamic>>? _initConfigCompleter;
Completer<Map<String, int>>? _groupSelfHealCompleter;

OverlayEntry? p2pEntry;
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

void navigateToSignIn({String source = 'unknown'}) {
  if (_isAppDisposing) {
    logger.i('navigateToSignIn skipped (app disposing), source=$source');
    return;
  }

  if (_isNavigatingToSignIn) {
    logger.i('navigateToSignIn skipped (in-flight), source=$source');
    return;
  }

  _isNavigatingToSignIn = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      if (_isAppDisposing) return;
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        context.go(AppRoutes.signIn);
      } else {
        logger.w(
          'navigateToSignIn skipped: context unavailable, source=$source',
        );
      }
    } finally {
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        _isNavigatingToSignIn = false;
      });
    }
  });
}

Map<String, WebRTCSession> webRTCSessions = {};

/// Connectivity监听器订阅（需要在dispose时取消）
StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

List<AvailableMap> availableMaps = [];

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

/// 服务容器
///
/// 提供单例服务的注册和获取功能
class ServiceContainer {
  static final ServiceContainer _instance = ServiceContainer._internal();
  factory ServiceContainer() => _instance;
  ServiceContainer._internal();

  final Map<Type, dynamic> _services = {};
  final Map<Type, dynamic Function()> _factories = {};

  /// 注册单例服务
  T put<T>(T service) {
    _services[T] = service;
    return service;
  }

  /// 注册延迟初始化的服务
  T lazyPut<T>(T Function() factory) {
    _factories[T] = factory;
    return factory();
  }

  /// 获取服务
  T get<T>() {
    // 首先检查是否已注册
    if (_services.containsKey(T)) {
      return _services[T] as T;
    }

    // 检查是否有工厂函数
    if (_factories.containsKey(T)) {
      final factory = _factories[T];
      if (factory != null) {
        return factory() as T;
      }
    }

    throw Exception('Service $T not registered');
  }

  /// 检查服务是否已注册
  bool isRegistered<T>() {
    return _services.containsKey(T) || _factories.containsKey(T);
  }

  /// 清空所有服务（仅用于测试）
  void clear() {
    _services.clear();
    _factories.clear();
  }
}

/// 全局服务容器实例
final serviceContainer = ServiceContainer();

class AppInitializer {
  static bool _initialized = false;

  static Future<void> initialize({
    required String env,
    required String signKeyVsn,
  }) async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _initializeCore(env: env, signKeyVsn: signKeyVsn);
      await _initializeServices();
      await _initializeListeners();
      // 当前字体初始化应该放到最后
      currentFontSize.value = UserRepoLocal.to.setting.fontSize;
    } catch (e, stack) {
      logger.e("Initialization failed", error: e, stackTrace: stack);
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

    // 保持屏幕常亮（Web 平台不需要）
    if (!kIsWeb) {
      await WakelockPlus.enable();
    }

    // 初始化存储 - 必须在使用前先初始化
    await StorageService.init();

    // 【重要】先设置环境变量，确保数据库路径正确
    await _setupEnvironment(env, false);

    // 初始化用户仓库 - 必须在数据库迁移之前注册
    // UserRepoLocal 现在是单例，会自动初始化
    UserRepoLocal.to; // 触发单例初始化

    // 数据库迁移由 SqliteService 的 onUpgrade 回调处理
    // 禁用 MigrationService 的自动迁移，避免双重迁移冲突导致数据丢失
    // await _autoMigrateDatabase();

    // 初始化NTP时间同步（获取时间偏移量）
    await NtpHelper.getOffset();

    // 获取设备信息
    await _setupDeviceInfo();

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
        logger.i('Cleaned up $cleaned old migration backups');
      }
    } on Exception catch (e) {
      logger.w('Failed to cleanup old migration backups: ${e.runtimeType}');
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
      logger.i('🔄 Environment changed from $previousEnv to $currentEnv');
      // 【关键】清除 initConfig 缓存，强制从新环境获取配置
      clearInitConfigCache();

      // 【关键】清除存储的旧配置，防止使用旧环境的配置
      await StorageService.to.remove(Keys.apiPublicKey);
      await StorageService.to.remove(Keys.wsUrl);
      await StorageService.to.remove(Keys.uploadUrl);
      await StorageService.to.remove(Keys.uploadKey);
      await StorageService.to.remove(Keys.uploadScene);
      await AppFeatureRegistry.clear();

      logger.i(
        '🔄 Cleared all cached configurations due to environment change',
      );

      // 【关键】立即从新环境获取配置，获取正确的 ws_url、upload_url 等
      logger.i('🔄 Fetching new environment configuration...');
      final config = await initConfig();
      if (config.containsKey('error')) {
        logger.w(
          '⚠️ Failed to fetch config for new environment: ${config['error']}',
        );
      } else {
        logger.i('✅ Successfully fetched config for new environment');
      }
    }

    await StorageService.to.setString('env', currentEnv);
    logger.i(
      "Running in environment: $currentEnv, Env().apiBaseUrl: ${Env().apiBaseUrl}, wsUrl: ${Env.effectiveWsUrl};",
    );
  }

  static Future<void> _setupDeviceInfo() async {
    serviceContainer.put(DeviceExt());

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

  static Future<Map<String, dynamic>> initConfig() async {
    // 1. 如果已有缓存，直接返回
    if (_initConfigCache != null) {
      if (kDebugMode) debugPrint('🔧 initConfig: 返回缓存结果');
      return _initConfigCache!;
    }

    // 2. 如果有正在进行的请求，等待其完成
    if (_initConfigCompleter != null) {
      if (kDebugMode) debugPrint('🔧 initConfig: 等待进行中的请求');
      return await _initConfigCompleter!.future;
    }

    // 3. 创建新的 Completer 并开始请求
    _initConfigCompleter = Completer<Map<String, dynamic>>();
    if (kDebugMode) debugPrint('🔧 initConfig: 开始获取配置');

    try {
      // 重试逻辑：最多 3 次，指数退避 (1s, 2s, 4s)
      const maxRetries = 3;
      IMBoyHttpResponse? resp1;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        final startTime = DateTime.now();
        if (kDebugMode) {
          debugPrint('🔧 initConfig: attempt $attempt/$maxRetries');
        }

        resp1 = await HttpClient.client
            .get(API.initConfig)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                if (kDebugMode) debugPrint('❌ initConfig: 请求超时 (10秒)');
                return IMBoyHttpResponse.failure(
                  errMsg: t.initConfigTimeout,
                  errCode: 408,
                );
              },
            );

        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        if (kDebugMode) {
          debugPrint('🔧 initConfig: 请求完成 code=${resp1.code}, 耗时=${elapsed}ms');
        }

        if (resp1.ok) break;

        if (attempt < maxRetries) {
          final delay = Duration(seconds: 1 << (attempt - 1)); // 1s, 2s, 4s
          if (kDebugMode) {
            debugPrint(
              '⚠️ initConfig: 请求失败 code=${resp1.code}，${delay.inSeconds}秒后重试...',
            );
          }
          await Future<dynamic>.delayed(delay);
        }
      }

      if (kDebugMode) {
        debugPrint("initConfig completed with code ${resp1!.code}");
      }
      if (!resp1!.ok) {
        if (kDebugMode) {
          debugPrint('❌ initConfig: 请求失败 ${resp1.code} (已重试 $maxRetries 次)');
        }
        final error = {
          "error": t.initConfigNetworkError(code: resp1.code.toString()),
        };
        _initConfigCompleter!.complete(error);
        return error;
      }

      final encrypted = resp1.payload['res'] ?? '';
      if (kDebugMode) debugPrint('🔧 initConfig: 加密内容长度=${encrypted.length}');

      if (encrypted.isEmpty) {
        if (kDebugMode) debugPrint('❌ initConfig: ��密内容为空');
        final error = {"error": t.initConfigProtocolError};
        _initConfigCompleter!.complete(error);
        return error;
      }

      if (kDebugMode) debugPrint('🔧 initConfig: 开始解密配置');
      final key = await Env.signKey();
      if (kDebugMode) debugPrint('🔐 [INIT] signKey initialized');
      if (kDebugMode) {
        debugPrint(
          '🔐 [INIT] signKey value: $key, iv: ${Env().solidifiedKeyIv}',
        );
      }
      Map<String, dynamic> payload = jsonDecode(
        EncrypterService.aesDecrypt(
          encrypted,
          EncrypterService.md5(key),
          Env().solidifiedKeyIv,
        ),
      );
      if (kDebugMode) debugPrint('🔧 initConfig: 解密完成');

      if (payload.containsKey('error')) {
        if (kDebugMode) debugPrint('❌ initConfig: payload包含错误');
        _initConfigCompleter!.complete(payload);
        return payload;
      }

      // 安全日志：不输出完整配置负载，可能包含敏感的 URL 和密钥
      if (kDebugMode) {
        debugPrint(
          "initConfig_payload received ${payload.keys.length} config items",
        );
      }

      final wsUrl = payload['ws_url'];
      if (kDebugMode) {
        debugPrint(
          '🔧 initConfig: ws_url present: ${wsUrl != null && wsUrl.isNotEmpty}',
        );
      }

      if (wsUrl != null && wsUrl.isNotEmpty) {
        await StorageService.to.setString(Keys.wsUrl, wsUrl);
        if (kDebugMode) debugPrint('✅ initConfig: Saved ws_url to storage');
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ initConfig: ws_url is null or empty, not saved');
        }
      }

      await StorageService.to.setString(Keys.uploadUrl, payload['upload_url']);
      await StorageService.to.setString(Keys.uploadKey, payload['upload_key']);
      await StorageService.to.setString(
        Keys.uploadScene,
        payload['upload_scene'],
      );

      await StorageService.to.setString(
        Keys.apiPublicKey,
        payload['login_rsa_pub_key'],
      );

      // 4. 缓存结果并完成
      _initConfigCache = payload;
      _initConfigCompleter!.complete(payload);
      return payload;
    } on Exception catch (e, stack) {
      if (kDebugMode) {
        debugPrint('❌ initConfig: 请求异常 ${e.runtimeType}');
        debugPrint('❌ initConfig: 堆栈追踪: $stack');
      }
      final error = {"error": t.initConfigFetchFailed};
      // 确保在异常情况下也清理 Completer
      if (!_initConfigCompleter!.isCompleted) {
        _initConfigCompleter!.complete(error);
      }
      return error;
    } finally {
      // 5. 清理 Completer
      _initConfigCompleter = null;
    }
  }

  static Future<void> _initializeServices() async {
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
      logger.i(
        '🔧 Fetching initConfig (apiPublicKey empty: ${strEmpty(Env.apiPublicKey)}, cache null: ${_initConfigCache == null})',
      );
      await initConfig();
    } else {
      logger.i('✅ Using cached initConfig (apiPublicKey exists)');
    }

    await AppFeatureRegistry.refresh();
    AppManifestService.loadFromCache();
    await AppManifestService.refresh();

    // 从后端 policy 刷新加密模式（决定消息是否强制加密）
    await EncryptionModeService.refresh();

    // 初始化WebSocket和相关服务
    await _initializeWebSocketServices();

    // 初始化推送通知服务（FCM token 注册 + 前台消息监听）
    await PushNotificationService.instance.initialize();

    // 初始化地图服务
    AMapHelper.init(); // 设置隐私协议（必须先调用）
    AMapHelper.setApiKey(); // 设置 API key

    // 初始化APP升级检查服务（延迟3秒检查，不阻塞启动）
    await AppUpgradeService.to.init();
  }

  static Future<void> _initializeWebSocketServices() async {
    // 注册消息队列服务
    final messageQueue = PersistentMessageQueue.to;
    await messageQueue.init();
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

    // 初始化 E2EE 分片消息处理器（零信任架构）
    // 必须在 WebSocket 服务初始化之前初始化，以便监听消息
    E2EEShardMessageHandler.to.init();
    iPrint('✅ [INIT] E2EE分片消息处理器已初始化');

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
      logger.i('Group membership self-heal already running, source=$source');
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
    } on Exception catch (e) {
      final fallback = {'skipped': 1, 'errors': 1, 'reason': 500};
      logger.w('Group membership self-heal trigger failed: ${e.runtimeType}');
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
      logger.i('Group membership self-heal skipped (offline), source=$source');
      return {'skipped': 1, 'errors': 0, 'reason': 0};
    }

    final dayMark = DateTime.now().toIso8601String().split('T').first;
    final markerKey =
        '${Keys.groupMembershipSelfHealPrefix}_${currentEnv}_$uid';
    final lastMark = StorageService.to.getString(markerKey);
    if (!force && lastMark == dayMark) {
      logger.i(
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
      logger.i(
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
      logger.w('Group membership self-heal failed: ${e.runtimeType}');
      return {'skipped': 0, 'errors': 1, 'reason': 500};
    }
  }

  static Future<void> _initializeListeners() async {
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
    logger.i("App resumed");

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (UserRepoLocal.to.isLoggedIn) {
        final token = await UserRepoLocal.to.accessToken;
        if (tokenExpired(token)) {
          await _refreshToken();
        }

        // 检查WebSocket服务是否已注册
        if (serviceContainer.isRegistered<WebSocketService>()) {
          // 【修复】不再强制重连WebSocket，避免消息入队延迟
          // 如果WebSocket连接正常，直接拉取离线消息即可
          final wsService = WebSocketService.to;
          if (wsService.status == SocketStatus.connected) {
            logger.i('App恢复，WebSocket已连接，拉取离线消息...');
            // 【关键优化】App恢复时主动拉取离线消息，兜底处理
            await MessageOfflineService.instance.requestPull(
              source: 'AppResume',
              reason: '应用恢复',
            );
            unawaited(triggerGroupMembershipSelfHeal(source: 'app_resume'));
          } else {
            logger.i('App恢复，WebSocket未连接，跳过重连（会自动重连）');
          }
        } else {
          logger.i('WebSocket服务未注册，跳过连接检查');
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
      logger.i('Refreshing expired token');
      final refreshToken = await UserRepoLocal.to.refreshToken;
      if (refreshToken != "") {
        await UserApi.to.refreshAccessTokenApi(refreshToken);
      }
    } on Exception catch (e) {
      logger.e("Failed to refresh token", error: e);
      // 可以考虑在这里处理token刷新失败的情况，比如退出登录
    }
  }

  static Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    logger.i("Connectivity changed: $results");

    // 检查WebSocket服务是否已注册
    if (!serviceContainer.isRegistered<WebSocketService>()) {
      logger.i('WebSocket服务未注册，跳过连接状态处理');
      return;
    }

    try {
      if (results.contains(ConnectivityResult.none)) {
        await WebSocketService.to.closeSocket();
      } else if (UserRepoLocal.to.isLoggedIn) {
        await WebSocketService.to.openSocket(from: 'connectivityChanged');
      }
    } on Exception catch (e) {
      logger.e('WebSocket连接状态处理失败: ${e.runtimeType}');
    }
  }

  /// 清理 initConfig 缓存（强制下次调用时重新获取配置）
  static void clearInitConfigCache() {
    _initConfigCache = null;
    _initConfigCompleter = null;
    if (kDebugMode) debugPrint('🔧 initConfig: 缓存已清理');
  }

  /// 释放资源（在应用退出或重新初始化前调用）
  static Future<void> dispose() async {
    logger.i('Disposing AppInitializer resources...');
    _isAppDisposing = true;

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
      logger.w('Failed to close WebSocket: ${e.runtimeType}');
    }

    // 清理MessageOfflineService资源
    try {
      MessageOfflineService.instance.onDispose();
    } on Exception catch (e) {
      logger.w('Failed to dispose MessageOfflineService: ${e.runtimeType}');
    }

    // 清理MessageRetry资源（定时器和事件订阅）
    try {
      MessageRetry.instance.dispose();
    } on Exception catch (e) {
      logger.w('Failed to dispose MessageRetry: ${e.runtimeType}');
    }

    // 清理WebRTC会话
    webRTCSessions.clear();

    // 停止升级检查定时器
    AppUpgradeService.to.dispose();

    // 清理 initConfig 缓存
    clearInitConfigCache();

    logger.i('AppInitializer dispose completed');
  }

  /// 重置初始化状态（用于测试或重新初始化）
  static void reset() {
    _initialized = false;
    _isAppDisposing = false;
    serviceContainer.clear();
    logger.i('AppInitializer reset completed');
  }
}
