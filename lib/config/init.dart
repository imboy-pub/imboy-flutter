import 'dart:io' as io;

import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/controller.dart';
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/http/http_interceptor.dart';
import 'package:imboy/component/observder/lifecycle.dart';
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
import 'package:logger/logger.dart';
import 'package:sqflite/sqflite.dart';

// ignore: prefer_generic_function_type_aliases
typedef Callback(data);

DefaultCacheManager cacheManager = DefaultCacheManager();

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

// https://github.com/dart-lang/web_socket_channel/issues/134
class GlobalHttpOverrides extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    // 全局忽略Https证书验证
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (io.X509Certificate cert, String host, int port) => true;
  }
}

Future<void> init() async {
  // 解决使用自签证书报错问题
  io.HttpOverrides.global = GlobalHttpOverrides();

  await dotenv.load(fileName: "assets/.env"); //
  // debugPrint(">>> on UP_AUTH_KEY: ${dotenv.get('UP_AUTH_KEY')}");

  // 放在 UserRepoLocal 前面
  await getx.Get.putAsync<StorageService>(() => StorageService().init());
  // Get.put(DeviceExt()); 需要放到靠前
  getx.Get.put(DeviceExt());
  getx.Get.put(UserRepoLocal(), permanent: true);
  getx.Get.lazyPut(() => ThemeController());

  Sqflite.setDebugModeOn();

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

  // 初始化 WebSocket 链接
  // getx.Get.put(WebSocket());
  getx.Get.put(WSService());
  // MessageService 不能用 lazyPut
  getx.Get.put(MessageService());
  // getx.Get.lazyPut(() => DeviceExt());

  ntpOffset = await StorageService.to.ntpOffset();

  await initIceServers();

  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(resumeCallBack: () async {
      // 统计新申请好友数量
      bnLogic.countNewFriendRemindCounter();

      // app 恢复
      debugPrint(">>> on LifecycleEventHandler resumeCallBack");
      ntpOffset = await StorageService.to.ntpOffset();
      WSService.to.openSocket();
    }, suspendingCallBack: () async {
      // app 挂起
      debugPrint(">>> on LifecycleEventHandler suspendingCallBack");
    }),
  );
  // debugPrint(">>> on currentTimeMillis init ${ntpOffset}");
}
