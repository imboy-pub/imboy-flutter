import 'dart:async';
import 'dart:io' as io;
import 'dart:io';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';

// import 'package:fvp/fvp.dart';
import 'package:get/get.dart' as getx;
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/service/encrypter.dart';
import 'package:imboy/service/rsa.dart';
import 'package:logger/logger.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

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
import 'package:imboy/component/webrtc/session.dart';

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
Map<String, dynamic>? iceConfiguration;

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

Future<Map<String, dynamic>> initConfig() async {
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
  Map<String, dynamic> payload = jsonDecode(EncrypterService.aesDecrypt(
    encrypted,
    EncrypterService.md5(key),
    Env().solidifiedKeyIv,
  ));
  if (payload.containsKey('error')) {
    return payload;
  }
  // iPrint("initConfig_payload ${payload.toString()}");
  await StorageService.to.setString(Keys.wsUrl, payload['ws_url']);
  await StorageService.to.setString(Keys.uploadUrl, payload['upload_url']);
  await StorageService.to.setString(Keys.uploadKey, payload['upload_key']);
  await StorageService.to.setString(Keys.uploadScene, payload['upload_scene']);

  await StorageService.to.setString(
    Keys.apiPublicKey,
    payload['login_rsa_pub_key'],
  );

  return payload;
}

Future<void> init({required String signKeyVsn}) async {
  // step 1
  WakelockPlus.enable();
  // step 2
  await StorageService.init();
  // 放在 UserRepoLocal 前面
  // getx.Get.put(StorageService());
  getx.Get.lazyPut(() => StorageService());

  globalSignKeyVsn = signKeyVsn;
  // step 3
  if (Platform.isAndroid || Platform.isIOS) {
    await RSAService.publicKey();
  }
  // step 4
  bool changedEnv = StorageService.to.getBool('changedEnv') ?? false;
  if (changedEnv) {
    currentEnv = StorageService.to.getString('env') ?? '';
  } else {
    currentEnv = const String.fromEnvironment('IMBOYENV', defaultValue: 'pro');
  }
  iPrint(
      "currentEnv $currentEnv, IMBOYENV ${const String.fromEnvironment('IMBOYENV')};");

  // currentEnv = 'dev';
  // StorageService.to.setString('env', currentEnv);
  // iPrint("init env 2 $env, currentEnv $currentEnv;");

  // step 5
  // Get.put(DeviceExt()); 需要放到靠前
  getx.Get.lazyPut(() => DeviceExt());
  final PackageInfo packageInfo = await PackageInfo.fromPlatform();
  packageName = packageInfo.packageName;
  appVsn = packageInfo.version;
  appName = packageInfo.appName;
  List<String> li = appVsn.split(RegExp(r"(\.)"));
  appVsnMajor = li[0].toString();
  // iPrint("packageInfo appVsnMajor $appVsnMajor ${packageInfo.toString()}");
  deviceId = await DeviceExt.did;
  iPrint("init deviceId $deviceId");

  // step 6
  // 解决使用自签证书报错问题
  io.HttpOverrides.global = GlobalHttpOverrides();
  HttpConfig dioConfig = HttpConfig(
    baseUrl: Env().apiBaseUrl,
    // proxy: '192.168.100.19:8888',
    interceptors: [IMBoyInterceptor()],
  );

  getx.Get.put(HttpClient(conf: dioConfig));

  // step 7
  getx.Get.put(UserRepoLocal(), permanent: true);
  // UserRepoLocal().onInit(); 放在 put UserRepoLocal()后面
  UserRepoLocal().onInit();

  // step 8
  String? v = Env.apiPublicKey;
  if (strEmpty(v)) {
    await initConfig();
  }

  // iPrint("> on UP_AUTH_KEY: ${dotEnv.get('UP_AUTH_KEY')}");

  // Get.put<AuthController>(AuthController());

  // step 9
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
  // GroupListLogic 不能用 lazyPut
  getx.Get.put(GroupListLogic());

  // step 10
  ntpOffset = await DateTimeHelper.getNtpOffset();
  AMapHelper.setApiKey();

  // 初始化单例 WebSocketService
  // WebSocketService.to.init();

  // step 11
  // fvp libary register
  // registerWith(options: {
  //   'platforms': ['windows', 'macos', 'linux']
  // }); // only these platforms will use this plugin implementation

  // step 12
  WidgetsBinding.instance.addObserver(
    LifecycleEventHandler(
      resumeCallBack: () async {
        // app 恢复
        String tk = await UserRepoLocal.to.accessToken;
        if (tokenExpired(tk)) {
          String? rtk = await UserRepoLocal.to.refreshToken;

          iPrint('LifecycleEventHandler tokenExpired true');
          await (UserProvider()).refreshAccessTokenApi(rtk);
        }
        // 统计新申请好友数量
        bnLogic.countNewFriendRemindCounter();
        iPrint("> on LifecycleEventHandler resumeCallBack");
        ntpOffset = await DateTimeHelper.getNtpOffset();
        // 检查WS链接状态
        await WebSocketService.to.openSocket(from: 'resumeCallBack');
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

  // step 13
  // 监听网络状态
  Connectivity()
      .onConnectivityChanged
      .listen((List<ConnectivityResult> r) async {
    iPrint("onConnectivityChanged ${r.toString()}");
    if (r.contains(ConnectivityResult.none)) {
      // 关闭网络的情况下，没有必要开启WS服务了
      await WebSocketService.to.closeSocket();
    } else {
      // 检查WS链接状态
      await WebSocketService.to.openSocket(from: 'onConnectivityChanged');
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
