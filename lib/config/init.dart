import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';

// import 'package:fvp/fvp.dart';
import 'package:get/get.dart' as getx;
import 'package:get/get.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/page/mine/change_password/set_password_view.dart';
// FontSizeLogic 已移除，功能迁移到 ThemeManager
import 'package:imboy/service/encrypter.dart';
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

import 'package:imboy/page/bottom_navigation/bottom_navigation_logic.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/contact/new_friend/new_friend_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/message_actions.dart';
import 'package:imboy/service/message_offline.dart';
import 'package:imboy/service/message_retry.dart';
import 'package:imboy/service/message_webrtc.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/service/network_monitor.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

import 'env.dart';

// ignore: prefer_generic_function_type_aliases
typedef Callback(data);

IMBoyCacheManager cacheManager = IMBoyCacheManager();

typedef VoidCallbackConfirm = void Function(bool isOk);

enum ClickType { select, open }

bool p2pCallScreenOn = false;

var logger = Logger();
int ntpOffset = 0;

OverlayEntry? p2pEntry;
// ice 配置信息
// Map<String, dynamic>? iceConfiguration;

/// The global [EventBus] object.
/// sync 不要设置为 true
EventBus eventBus = EventBus();
// 全局timer
Timer? gTimer;
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, WebRTCSession> webRTCSessions = {};

List<AvailableMap> availableMaps = [];

// JPush push = JPush();

String currentEnv = '';

String packageName = '';
String appName = '';
String appVsn = '';
String appVsnMajor = '';
String deviceId = '';
String solidifiedKeyEnv = '';

// signKeyVsn 告知服务端用哪个签名key 不同设备类型签名不一样
String globalSignKeyVsn = '1';

// 使用响应式变量来跟踪当前字体大小
RxString currentFontSize = 'normal'.obs;

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
    // 保持屏幕常亮
    await WakelockPlus.enable();
    
    // 初始化存储 - 必须在使用前先初始化
    await StorageService.init();

    // 检查是否已经切换过环境
    // final changedEnv = StorageService.to.getBool('changedEnv') ?? false;
    // await _setupEnvironment(env, changedEnv);
    // 设置环境变量
    await _setupEnvironment(env, false);

    // 获取NTP时间偏移
    ntpOffset = await NtpHelper.getOffset();

    // 获取设备信息
    await _setupDeviceInfo();

    // 配置HTTP客户端
    _setupHttpClient();
  }

  static Future<void> _setupEnvironment(String env, bool changedEnv) async {
    if (changedEnv) {
      currentEnv = StorageService.to.getString('env') ?? env;
    } else {
      currentEnv = env;
    }

    // 确保环境不为空
    if (currentEnv.isEmpty) {
      currentEnv = env;
    }

    await StorageService.to.setString('env', currentEnv);
    logger.i("Running in environment: $currentEnv, Env().apiBaseUrl ${Env().apiBaseUrl}, wsUrl ${Env.wsUrl}");
  }

  static Future<void> _setupDeviceInfo() async {
    Get.put(DeviceExt());
    deviceId = await DeviceExt.did;

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
    Get.put(HttpClient(conf: dioConfig));
  }

  static Future<Map<String, dynamic>> initConfig() async {
    IMBoyHttpResponse resp1 = await HttpClient.client.get(API.initConfig);
    debugPrint("initConfig ${resp1.payload.toString()}");
    if (!resp1.ok) {
      return {"error": "网络故障或服务故障"};
    }
    final encrypted = resp1.payload['res'] ?? '';
    if (encrypted.isEmpty) {
      return {"error": "服务故障协议有误"};
    }
    final key = await Env.signKey();
    // iPrint("initConfig signKey $key ;");
    // final jsonStr = EncrypterService.aesDecrypt(
    //   encrypted,
    //   EncrypterService.md5(key),
    //   Env().solidifiedKeyIv,
    // );
    // iPrint("initConfig_jsonStr $jsonStr");
    Map<String, dynamic> payload = jsonDecode(
      EncrypterService.aesDecrypt(
        encrypted,
        EncrypterService.md5(key),
        Env().solidifiedKeyIv,
      ),
    );
    if (payload.containsKey('error')) {
      return payload;
    }
    iPrint("initConfig_payload ${payload.toString()}");
    await StorageService.to.setString(Keys.wsUrl, payload['ws_url']);
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

    return payload;
  }

  static Future<void> _initializeServices() async {
    // 初始化用户仓库
    Get.put(UserRepoLocal(), permanent: true);
    UserRepoLocal().onInit();

    // 初始化网络监控服务（必须在HttpClient使用之前初始化）
    Get.put(NetworkMonitorService());

    // 检查API公钥
    if (strEmpty(Env.apiPublicKey)) {
      await initConfig();
    }

    // 初始化WebSocket和相关服务
    await _initializeWebSocketServices();

    // 初始化地图服务
    AMapHelper.setApiKey();
  }

  static Future<void> _initializeWebSocketServices() async {
    // 初始化底部导航逻辑
    final bnLogic = Get.put(BottomNavigationLogic());
    await bnLogic.countNewFriendRemindCounter();

    // 注册消息队列服务
    Get.put(PersistentMessageQueue());

    // 注册会话逻辑控制器，必须在消息相关服务之前注册
    Get.lazyPut(() => ConversationLogic(), fenix: true);

    // 使用lazyPut注册消息相关服务，避免循环依赖问题
    // 注册顺序很重要，被依赖的模块必须先注册
    Get.lazyPut<MessageService>(() => MessageService(), fenix: true);
    Get.lazyPut<MessageActions>(() => MessageActions(), fenix: true);
    Get.lazyPut<MessageWebrtc>(() => MessageWebrtc(), fenix: true);
    Get.lazyPut<MessageOfflineService>(() => MessageOfflineService(), fenix: true);
    Get.lazyPut<MessageRetry>(() => MessageRetry(), fenix: true);

    // 初始化各种逻辑控制器
    Get.put(ChatLogic()); // 1
    Get.put(GroupListLogic()); // 2
    Get.lazyPut(() => ContactLogic());
    Get.lazyPut(() => NewFriendLogic());
    // FontSizeLogic 功能已迁移到 ThemeManager

    // 最后初始化WebSocket服务，确保依赖的服务都已注册
    final wsService = Get.put<WebSocketService>(WebSocketService());

    // 如果已登录，尝试连接WebSocket
    if (UserRepoLocal.to.isLoggedIn) {
      await wsService.openSocket(from: 'initialization');
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

    // 网络连接状态监听
    Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  static Future<void> _onAppResume() async {
    logger.i("App resumed");

    // 更新NTP时间偏移
    ntpOffset = await NtpHelper.getOffset();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (UserRepoLocal.to.isLoggedIn) {
        final token = await UserRepoLocal.to.accessToken;
        if (tokenExpired(token)) {
          await _refreshToken();
        }

        // 更新好友提醒计数
        final bnLogic = Get.find<BottomNavigationLogic>();
        await bnLogic.countNewFriendRemindCounter();

        // 检查WebSocket服务是否已注册
        if (Get.isRegistered<WebSocketService>()) {
          try {
            // 检查WebSocket连接
            await WebSocketService.to.openSocket(from: 'resumeCallBack');
          } catch (e) {
            logger.e('WebSocket连接失败: $e');
          }
        } else {
          logger.i('WebSocket服务未注册，跳过连接检查');
        }

        // 检查是否需要设置密码
        final needSetPwd = StorageService.to.getBool(Keys.needSetPwd) ?? false;
        if (needSetPwd) {
          Get.off(() => SetPasswordPage());
        }
      }
    });
  }

  static Future<void> _refreshToken() async {
    try {
      logger.i('Refreshing expired token');
      final refreshToken = await UserRepoLocal.to.refreshToken;
      if (refreshToken != "") {
        await UserProvider().refreshAccessTokenApi(refreshToken);
      }
    } catch (e) {
      logger.e("Failed to refresh token", error: e);
      // 可以考虑在这里处理token刷新失败的情况，比如退出登录
    }
  }

  static Future<void> _onConnectivityChanged(
    List<ConnectivityResult> results,
  ) async {
    logger.i("Connectivity changed: $results");

    // 检查WebSocket服务是否已注册
    if (!Get.isRegistered<WebSocketService>()) {
      logger.i('WebSocket服务未注册，跳过连接状态处理');
      return;
    }

    try {
      if (results.contains(ConnectivityResult.none)) {
        await WebSocketService.to.closeSocket();
      } else if (UserRepoLocal.to.isLoggedIn) {
        await WebSocketService.to.openSocket(from: 'connectivityChanged');
      }
    } catch (e) {
      logger.e('WebSocket连接状态处理失败: $e');
    }
  }
}
