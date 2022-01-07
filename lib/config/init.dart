import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart' as Getx;
import 'package:imboy/component/observder/lifecycle.dart';
import 'package:imboy/component/view/controller.dart';
import 'package:imboy/helper/http/http_client.dart';
import 'package:imboy/helper/http/http_config.dart';
import 'package:imboy/helper/http/http_interceptor.dart';
import 'package:imboy/helper/sqflite.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/service/websocket.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:logger/logger.dart';

typedef Callback(data);

// const API_BASE_URL = 'http://dev.api.imboy.pub:9800';
// const String ws_url = 'ws://dev.api.imboy.pub:9800/ws/';

const RECORD_LOG = true;
// const API_BASE_URL = 'http://local.api.imoby.pub:9800';
// const ws_url = 'ws://local.api.imoby.pub:9800/ws/';

// 阿里云 Dev
const API_BASE_URL = 'http://81.68.209.56:9800';
const ws_url = 'ws://81.68.209.56:9800/ws/';

DefaultCacheManager cacheManager = new DefaultCacheManager();

typedef VoidCallbackConfirm = void Function(bool isOk);

enum ClickType { select, open }

var logger = Logger();

/// The global [EventBus] object.
EventBus eventBus = EventBus();

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();

  WidgetsBinding.instance?.addObserver(
    LifecycleEventHandler(resumeCallBack: () async {
      // app 恢复
      debugPrint(">>>>> on LifecycleEventHandler resumeCallBack");
      // WebSocket();
      WSService.to.openSocket();
    }, suspendingCallBack: () async {
      // app 挂起
      debugPrint(">>>>> on LifecycleEventHandler suspendingCallBack");
    }),
  );

  // 放在 UserRepoLocal 前面
  await Getx.Get.putAsync<StorageService>(() => StorageService().init());
  Getx.Get.put(UserRepoLocal(), permanent: true);
  Getx.Get.lazyPut(() => ThemeController());

  // Get.put<AuthController>(AuthController());
  HttpConfig dioConfig = HttpConfig(
    baseUrl: API_BASE_URL,
    // proxy: '192.168.100.19:8888',
    interceptors: [ImboyInterceptor()],
  );

  Getx.Get.put(HttpClient(dioConfig: dioConfig));

  Getx.Get.put(Sqlite.instance);
  // 初始化 WebSocket 链接
  // Getx.Get.put(WebSocket());
  Getx.Get.put(WSService());
  Getx.Get.put(MessageService());
}
