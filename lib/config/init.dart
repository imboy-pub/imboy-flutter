import 'dart:io';

import 'package:dio/dio.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:get/get.dart' as Getx;
import 'package:imboy/component/view/controller.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/helper/func.dart';
import 'package:imboy/helper/http/http_client.dart';
import 'package:imboy/helper/http/http_config.dart';
import 'package:imboy/helper/websocket.dart';
import 'package:imboy/service/message.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';
import 'package:logger/logger.dart';

typedef Callback(data);

const API_BASE_URL = 'http://dev.api.imboy.pub:9800';
const String ws_url = 'ws://dev.api.imboy.pub:9800/ws/';

const RECORD_LOG = true;
// const API_BASE_URL = 'http://local.api.imoby.pub:9800';
// const ws_url = 'ws://local.api.imoby.pub:9800/ws/';

// const API_BASE_URL = 'http://172.20.10.10:9800';
// const ws_url = 'ws://172.20.10.10:9800/ws/';

DefaultCacheManager cacheManager = new DefaultCacheManager();

typedef VoidCallbackConfirm = void Function(bool isOk);

enum ClickType { select, open }

var logger = Logger();

/// The global [EventBus] object.
EventBus eventBus = EventBus();

class ImboyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    print('REQUEST[${options.method}] => PATH: ${options.path}');
    options.headers['Accept'] = Headers.jsonContentType;
    options.headers['device-type'] = Platform.operatingSystem;
    options.headers['device-type-vsn'] = Platform.operatingSystemVersion;

    String tk = UserRepoSP.user.accessToken;
    // debugPrint(">>>>>>> on ImboyInterceptor tk" + (tk == null ? "" : tk));
    if (strNoEmpty(tk)) {
      options.headers[Keys.tokenKey] = tk;
    }

    return super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    return super.onResponse(response, handler);
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    return super.onError(err, handler);
  }
}

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized();
  Getx.Get.lazyPut(() => ThemeController());

  // permanent: true  需要这个实例在整个应用生命周期中保留在那里

  // Get.put<AuthController>(AuthController(), permanent: true);
  HttpConfig dioConfig = HttpConfig(
    baseUrl: API_BASE_URL,
    // proxy: '192.168.100.19:8888',
    interceptors: [ImboyInterceptor()],
  );

  Getx.Get.put(HttpClient(dioConfig: dioConfig), permanent: true);

  // 放在 UserRepoSP 前面
  await Getx.Get.putAsync<StorageService>(() => StorageService().init(), permanent: true);
  // 放在 wshb 前面
  Getx.Get.put(UserRepoSP(), permanent: true);
  // 初始化 WebSocket 链接
  Getx.Get.put(WebSocket(), permanent: true);
  Getx.Get.put(MessageService(), permanent: true);
}
