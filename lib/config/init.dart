import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/extension/device_ext.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_config.dart';
import 'package:imboy/component/http/http_interceptor.dart';
import 'package:imboy/component/observder/lifecycle.dart';
import 'package:imboy/component/view/controller.dart';
import 'package:imboy/config/const.dart';
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

var logger = Logger();
int ntpOffset = 0;

/// The global [EventBus] object.
EventBus eventBus = EventBus();

Future<void> init() async {
  await dotenv.load(fileName: "assets/.env"); //
  // debugPrint(">>> on UP_AUTH_KEY: ${dotenv.get('UP_AUTH_KEY')}");
  // 放在 UserRepoLocal 前面
  await getx.Get.putAsync<StorageService>(() => StorageService().init());
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

  // 初始化 WebSocket 链接
  // getx.Get.put(WebSocket());
  getx.Get.put(WSService());
  // MessageService 不能用 lazyPut
  getx.Get.put(MessageService());
  getx.Get.put(DeviceExt());
  // getx.Get.lazyPut(() => DeviceExt());

  ntpOffset = await StorageService.to.ntpOffset();
  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(resumeCallBack: () async {
      // app 恢复
      debugPrint(">>> on LifecycleEventHandler resumeCallBack");
      ntpOffset = await StorageService.to.ntpOffset();
      WSService.to.sentHeart();
      WSService.to.openSocket();
    }, suspendingCallBack: () async {
      // app 挂起
      debugPrint(">>> on LifecycleEventHandler suspendingCallBack");
    }),
  );
  // debugPrint(">>> on currentTimeMillis init ${ntpOffset}");
}
