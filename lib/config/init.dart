import 'dart:async';
import 'dart:io' as io;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:fvp/fvp.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/controller.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/extension/imboy_cache_manager.dart';
import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/jwt.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/http/http_interceptor.dart';
import 'package:imboy/component/location/amap_helper.dart';
import 'package:imboy/component/observer/lifecycle.dart';
import 'package:imboy/component/webrtc/func.dart';
import 'package:imboy/component/webrtc/session.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/bottom_navigation/bottom_navigation_logic.dart';
import 'package:imboy/page/chat/chat/chat_logic.dart';
import 'package:imboy/page/contact/contact/contact_logic.dart';
import 'package:imboy/page/contact/new_friend/new_friend_logic.dart';
import 'package:imboy/page/conversation/conversation_logic.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/provider/user_provider.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:logger/logger.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
// 全局timer
Timer? gTimer;
GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Map<String, WebRTCSession> webRTCSessions = {};

List<AvailableMap> availableMaps = [];

// JPush push = JPush();

String appVsn = '';
String appVsnXY = '';
String deviceId = '';

Future<void> init() async {
  WakelockPlus.enable();

  await StorageService.init();
  // 放在 UserRepoLocal 前面
  getx.Get.lazyPut(() => StorageService());

  // 解决使用自签证书报错问题
  io.HttpOverrides.global = GlobalHttpOverrides();
  // Get.put(DeviceExt()); 需要放到靠前
  getx.Get.lazyPut(() => DeviceExt());

  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  appVsn = packageInfo.version;
  List<String> li = appVsn.split(RegExp(r"(\.)"));
  appVsnXY = '${li[0]}.${li[1]}';
  iPrint("packageInfo appVsnXY $appVsnXY ${packageInfo.toString()}");
  deviceId = await DeviceExt.did;
  iPrint("init deviceId $deviceId");
  await dotenv.load(fileName: ".env"); //
  // iPrint("> on UP_AUTH_KEY: ${dotenv.get('UP_AUTH_KEY')}");

  getx.Get.put(UserRepoLocal(), permanent: true);
  getx.Get.lazyPut(() => ThemeController());

  // Get.put<AuthController>(AuthController());
  HttpConfig dioConfig = HttpConfig(
    baseUrl: API_BASE_URL,
    // proxy: '192.168.100.19:8888',
    interceptors: [IMBoyInterceptor()],
  );

  getx.Get.put(HttpClient(dioConfig: dioConfig));

  // 需要放在 Get.put(MessageService()); 前
  final bnLogic = getx.Get.put(BottomNavigationLogic());
  bnLogic.countNewFriendRemindCounter();
  getx.Get.lazyPut(() => ContactLogic());
  getx.Get.lazyPut(() => NewFriendLogic());
  getx.Get.lazyPut(() => ConversationLogic());

  // ChatLogic 不能用 lazyPut
  getx.Get.put(ChatLogic());
  // MessageService 不能用 lazyPut
  getx.Get.put(MessageService());
  // getx.Get.lazyPut(() => DeviceExt());

  ntpOffset = await DateTimeHelper.getNtpOffset();
  AMapHelper.setApiKey();

  // 初始化单例 WebSocketService
  // WebSocketService.to.init();
  await initIceServers();

  // fvp libary register
  registerWith();

  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(
      resumeCallBack: () async {
        // app 恢复
        String? token = UserRepoLocal.to.accessToken;
        if (tokenExpired(token)) {
          iPrint('LifecycleEventHandler tokenExpired true');
          await (UserProvider()).refreshAccessTokenApi(
            UserRepoLocal.to.refreshToken,
          );
        }
        // 统计新申请好友数量
        bnLogic.countNewFriendRemindCounter();
        iPrint("> on LifecycleEventHandler resumeCallBack");
        ntpOffset = await DateTimeHelper.getNtpOffset();
        // 检查WS链接状态
        WebSocketService.to.openSocket();
      },
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
  // 监听网络状态
  Connectivity().onConnectivityChanged.listen((ConnectivityResult r) {
    iPrint("onConnectivityChanged ${r.toString()}");
    if (r == ConnectivityResult.none) {
      // 关闭网络的情况下，没有必要开启WS服务了
      WebSocketService.to.closeSocket();
    } else {
      // 检查WS链接状态
      WebSocketService.to.openSocket();
    }
  });
  // iPrint("> on currentTimeMillis init ${ntpOffset}");
}

/*
Future<void> initJPush() async {
  push.addEventHandler(
    // 接收通知回调方法。
    onReceiveNotification: (Map<String, dynamic> message) async {
      iPrint("push onReceiveNotification: $message");
      // Map<dynamic, dynamic> extra = message['extras'];
      // String androidExtra = extra['cn.jpush.android.EXTRA'] ?? '';
      // Map<String, dynamic> extra2 = jsonDecode(androidExtra);
    },

    // 点击通知回调方法。
    onOpenNotification: (Map<String, dynamic> message) async {
      // iPrint("push onOpenNotification: $message");
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
      iPrint("push onReceiveMessage: $message");
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
