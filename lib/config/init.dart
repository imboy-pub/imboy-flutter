import 'dart:io' as io;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart' as getx;
import 'package:get/get.dart';
import 'package:imboy/component/controller.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:logger/logger.dart';
import 'package:map_launcher/map_launcher.dart';

import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/http/http_interceptor.dart';
import 'package:imboy/component/observer/lifecycle.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_logic.dart';
import 'package:imboy/page/contact/contact_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/page/friend/new_friend_logic.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

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
Map<String, dynamic>? iceConfiguration;

/// The global [EventBus] object.
EventBus eventBus = EventBus();
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, WebRTCSession> webRTCSessions = {};

List<AvailableMap> availableMaps = [];

// JPush push = JPush();

Future<void> init() async {
  // 解决使用自签证书报错问题
  io.HttpOverrides.global = GlobalHttpOverrides();

  await dotenv.load(fileName: "assets/.env"); //
  // debugPrint("> on UP_AUTH_KEY: ${dotenv.get('UP_AUTH_KEY')}");

  // 放在 UserRepoLocal 前面
  await getx.Get.putAsync<StorageService>(() => StorageService().init());
  // Get.put(DeviceExt()); 需要放到靠前
  getx.Get.put(DeviceExt());
  getx.Get.put(UserRepoLocal(), permanent: true);
  getx.Get.lazyPut(() => ThemeController());

  // Get.put<AuthController>(AuthController());
  HttpConfig dioConfig = HttpConfig(
    baseUrl: API_BASE_URL,
    // proxy: '192.168.100.19:8888',
    interceptors: [ImboyInterceptor()],
  );

  getx.Get.put(HttpClient(dioConfig: dioConfig));

  // 需要放在 Get.put(MessageService()); 前
  final bnLogic = getx.Get.put(BottomNavigationLogic());
  bnLogic.countNewFriendRemindCounter();
  getx.Get.lazyPut(() => ContactLogic());
  getx.Get.lazyPut(() => NewFriendLogic());
  getx.Get.lazyPut(() => ConversationLogic());

  // MessageService 不能用 lazyPut
  getx.Get.put(MessageService());
  // getx.Get.lazyPut(() => DeviceExt());

  ntpOffset = await StorageService.to.ntpOffset();
  AMapHelper.setApiKey();

  // 初始化 WebSocket 链接
  await WebSocketService.to.init();
  await initIceServers();

  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(
      resumeCallBack: () async {
        // app 恢复
        // 统计新申请好友数量
        bnLogic.countNewFriendRemindCounter();
        debugPrint("> on LifecycleEventHandler resumeCallBack");
        ntpOffset = await StorageService.to.ntpOffset();
        // 检查WS链接状态
        WebSocketService.to.init();
      },
      suspendingCallBack: () async {
        // app 挂起
        debugPrint("> on LifecycleEventHandler suspendingCallBack");
      },
      pausedCallBack: () async {
        // 已暂停的
      },
    ),
  );
  // 监听网络状态
  Connectivity().onConnectivityChanged.listen((ConnectivityResult r) {
    if (r != ConnectivityResult.none) {
      // 检查WS链接状态
      WebSocketService.to.init();
    }
  });
  // debugPrint("> on currentTimeMillis init ${ntpOffset}");
}

/*
Future<void> initJPush() async {
  push.addEventHandler(
    // 接收通知回调方法。
    onReceiveNotification: (Map<String, dynamic> message) async {
      debugPrint("push onReceiveNotification: $message");
      // Map<dynamic, dynamic> extra = message['extras'];
      // String androidExtra = extra['cn.jpush.android.EXTRA'] ?? '';
      // Map<String, dynamic> extra2 = jsonDecode(androidExtra);
    },

    // 点击通知回调方法。
    onOpenNotification: (Map<String, dynamic> message) async {
      // debugPrint("push onOpenNotification: $message");
      Map<dynamic, dynamic> extra = message['extras'];
      String androidExtra = extra['cn.jpush.android.EXTRA'] ?? '';
      Map<String, dynamic> extra2 = jsonDecode(androidExtra);

      String type = extra2['type'] ?? '';
      String msgType = extra2['msgType'] ?? '';
      String peerId = extra2['peerId'] ?? '';
      type = type.toLowerCase();
      msgType = msgType.toLowerCase();
      if (type == 'c2c' || type == 'c2g') {
        toChatPage(peerId, type);
      }
    },
    // 接收自定义消息回调方法。
    onReceiveMessage: (Map<String, dynamic> message) async {
      debugPrint("push onReceiveMessage: $message");
    },
  );
  // https://docs.jiguang.cn/jpush/practice/compliance
  // push.setAuth(enable: false); // 后续初始化过程将被拦截

  // 调整点二：隐私政策授权获取成功后调用
  // push.setAuth(enable: true); //如初始化被拦截过，将重试初始化过程

  // https://github.com/jpush/jpush-flutter-plugin/blob/master/documents/APIs.md
  // addEventHandler 方法建议放到 setup 之前，其他方法需要在 setup 方法之后调用
  push.setup(
    appKey: JPUSH_APPKEY,
    channel: "theChannel", //
    production: false,
    debug: kDebugMode ? true : false, // 设置是否打印 debug 日志
  );
}
*/
