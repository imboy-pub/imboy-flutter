import 'package:imboy/component/http/web_writer_http_adapter.dart';
import 'package:imboy/config/local_external_services_policy.dart';
import 'package:imboy/service/optional_sdk_consent.dart';

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:amap_flutter_location_plus/amap_flutter_location_plus.dart';
import 'package:amap_flutter_location_plus/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, debugPrint, visibleForTesting;

import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/env.dart';

/// https://lbs.amap.com/api/flutter/guide/positioning-flutter-plug-in/interface-info

/// LocationInfo? locationInfo = await AMapHelper().startLocation();
class AMapHelper {
  late AMapFlutterLocation location;
  late Completer<AMapPosition?> completer;

  static AMapHelper? _active;

  /// 测试注入的合成 maps 授权（仅测试可见；生产恒 null）。
  ///
  /// host 单测（macOS VM）无法满足下方 Android/iOS 平台守卫——[grant] 对
  /// 非移动平台恒 null，「已授权」路径的 picker/POI 合同因此无法在单测
  /// 覆盖（FL-17 基线：location_picker_state_test 因缺此缝隙 29 例全红）。
  /// 注入的固定对象只进内存判定，不读取真实同意存储，也不触达原生插件；
  /// 生产语义（平台守卫 + OptionalSdkConsent 授权 + mapsSuppressed）不变。
  @visibleForTesting
  static Object? grantOverrideForTest;

  static Object? get grant {
    final override = grantOverrideForTest;
    if (override != null) return override;
    return LocalExternalServicesPolicy.mapsSuppressed ||
            kIsWeb ||
            (!Platform.isAndroid && !Platform.isIOS)
        ? null
        : OptionalSdkConsent.instance.grant(OptionalSdkPurpose.maps);
  }

  factory AMapHelper() {
    final current = grant;
    if (current == null) return AMapHelper._internal(null);
    if (_active?._grant != current) {
      stopForConsent();
      init();
      setApiKey();
      _active = AMapHelper._internal(current);
    }
    return _active!;
  }

  final Object? _grant;
  StreamSubscription<Map<String, Object>>? _subscription;

  static void clearIfScopeChanged() {
    final active = _active;
    if (active != null && active._grant != grant) stopForConsent();
  }

  static void stopForConsent() {
    final active = _active;
    _active = null;
    if (active == null) return;
    if (!active.completer.isCompleted) active.completer.complete(null);
    unawaited(active._subscription?.cancel());
    active.stopLocation(active.location);
    active.destroy(active.location);
    AMapFlutterLocation.updatePrivacyAgree(false);
  }

  static void init() {
    if (grant == null) return;
    // 仅在 iOS/Android 平台初始化高德地图隐私协议
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }
    updatePrivacyShow(true, true);
    updatePrivacyAgree(true);
  }

  /// AMapHelper.setApiKey()
  /// 设置Android和iOS的apikey
  static void setApiKey() {
    if (grant == null) return;
    // 仅支持 iOS/Android
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }

    if (Platform.isAndroid || Platform.isIOS) {
      final androidKey = Env().aMapAndroidKey;
      final iosKey = Env().aMapIosKey;

      AMapFlutterLocation.setApiKey(androidKey, iosKey);
    }
  }

  // 私有构造函数
  AMapHelper._internal(this._grant) {
    if (_grant == null) return;
    completer = Completer<AMapPosition?>();

    // Web 平台不支持高德地图原生插件，跳过初始化
    if (kIsWeb) {
      return;
    }

    location = AMapFlutterLocation();
    Stream<Map<String, Object>> stream = onLocationChanged(location);
    _subscription = stream.listen((Map<String, Object> result) {
      if (grant != _grant || !identical(_active, this)) {
        if (identical(_active, this)) stopForConsent();
        return;
      }
      // https://lbs.amap.com/api/android-location-sdk/guide/utilities/location-type
      // https://lbs.amap.com/api/flutter/guide/positioning-flutter-plug-in/interface-info

      // 【增强】检查高德返回的错误码
      final errorCode = result['errorCode'];

      if (errorCode != null && errorCode != 0) {
        debugPrint(
          '[AMap] 定位失败 errorCode=$errorCode errorInfo=${result['errorInfo']}',
        );
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        stopLocation(location);
        return;
      }

      double longitude = double.tryParse(result['longitude'].toString()) ?? 0;
      double latitude = double.tryParse(result['latitude'].toString()) ?? 0;
      String address = result['address'].toString();

      // 【增强】检查坐标有效性
      if (latitude == 0.0 && longitude == 0.0) {
        debugPrint('[AMap] 返回无效坐标(0,0) errorInfo=${result['errorInfo']}');
        if (!completer.isCompleted) {
          completer.complete(null);
        }
        stopLocation(location);
        return;
      }
      debugPrint('[AMap] 定位成功 lat=$latitude lng=$longitude');

      AMapPosition p = AMapPosition(
        latLng: LatLng(latitude, longitude),
        id: '',
        name: '',
        address: address,
        adCode: result['adCode'].toString(),
        distance: '',
      );

      if (!completer.isCompleted) {
        completer.complete(p);
      }

      stopLocation(location);
    });
  }

  /// 设置是否已经包含高德隐私政策并弹窗展示显示用户查看，如果未包含或者没有弹窗展示，高德定位SDK将不会工作
  static void updatePrivacyShow(bool hasContains, bool hasShow) {
    if (LocalExternalServicesPolicy.mapsSuppressed) return;
    // 仅支持 iOS/Android 平台
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }
    if (grant != null) {
      AMapFlutterLocation.updatePrivacyShow(hasContains, hasShow);
    }
  }

  /// 设置是否已经取得用户同意，如果未取得用户同意，高德定位SDK将不会工作
  static void updatePrivacyAgree(bool hasAgree) {
    if (LocalExternalServicesPolicy.mapsSuppressed) return;
    // 仅支持 iOS/Android 平台
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }
    if (!hasAgree || grant != null) {
      AMapFlutterLocation.updatePrivacyAgree(hasAgree);
    }
  }

  // 初始化
  AMapLocationOption locationOption = AMapLocationOption(
    // 是否需要地址信息：关闭。开启时 SDK 会额外发起逆地理编码请求，
    // 当前 AMap Key 的逆地理权限/签名配置有误，稳定返回
    // errorCode=3 INVALID_USER_SCODE，导致整次定位被判失败，
    // 拖累「地点」按钮降级到 geolocator 重新走一次完整定位（慢，
    // 感觉像点了半天没反应）。getCurrentPosition() 的三个调用方
    // （extra_item.dart / people_nearby_provider.dart /
    // face_to_face_provider.dart）都只用经纬度，从不读 .address，
    // 关掉即可让高德直接返回原始坐标，不再打这趟必挂的逆地理请求。
    needAddress: false,
    // 逆地理信息语言类型
    geoLanguage: GeoLanguage.ZH,
    // 是否单次定位 默认值：false
    onceLocation: true,
    // Android端定位模式, 只在Android系统上有效>
    locationMode: AMapLocationMode.Hight_Accuracy,
    // Android端定位间隔 2000毫秒
    locationInterval: 2000,
    // iOS端是否允许系统暂停定位
    pausesLocationUpdatesAutomatically: false,
    // iOS端期望的定位精度， 只在iOS端有效
    // 不用 Best：kCLLocationAccuracyBest 会让 CoreLocation 一直等 GPS 收敛到
    // 最佳精度才回调，冷启动/室内典型要 3~10s（真机反馈「首次进附近的人 3 秒+」）。
    // 四个调用方（附近的人 / 面对面建群 / 聊天发位置 / 朋友圈发位置）都不需要
    // 亚米级——10 米足够，达标即回调，不再空等收敛。
    // 注意：这只影响 iOS。Android 走下面的 locationMode，同样的慢在 Android
    // 另有原因，靠 [PeopleNearbyPerf] 埋点定位，别指望这一行。
    desiredAccuracy: DesiredAccuracy.NearestTenMeters,
  );

  /// 设置定位参数
  void setLocationOption(AMapFlutterLocation location) {
    if (LocalExternalServicesPolicy.mapsSuppressed) return;
    if (kIsWeb) return;
    location.setLocationOption(locationOption);
  }

  /// 开始定位
  Future<AMapPosition?> startLocation() async {
    if (_grant == null || grant != _grant) return null;
    // Web 平台不支持高德地图定位
    if (kIsWeb) {
      return null;
    }

    // 1. 检查权限
    final swPerm = Stopwatch()..start();
    bool p = await requestLocationPermission();
    debugPrint(
      '[PeopleNearbyPerf]     权限检查 ${swPerm.elapsedMilliseconds}ms 结果=$p',
    );
    if (!p || grant != _grant) return null;
    final swFix = Stopwatch()..start();

    // 3. 设置定位参数
    setLocationOption(location);

    // 4. 创建新的 Completer（支持多次调用）
    if (completer.isCompleted) {
      completer = Completer<AMapPosition?>();
    }

    // 5. 添加超时保护（15秒）
    final request = completer;
    final timeout = Timer(const Duration(seconds: 15), () {
      if (!request.isCompleted) {
        request.complete(null);
        stopLocation(location);
      }
    });

    // 6. 开启定位
    try {
      location.startLocation();
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }

    // 7. 等待定位结果或超时
    final result = await request.future;
    timeout.cancel();
    debugPrint(
      '[PeopleNearbyPerf]     高德SDK出坐标 ${swFix.elapsedMilliseconds}ms '
      '${result == null ? '(超时/失败)' : '成功'}',
    );

    return grant == _grant ? result : null;
  }

  /// 停止定位
  void stopLocation(AMapFlutterLocation location) {
    if (kIsWeb) return;
    location.stopLocation();
  }

  ///销毁定位
  void destroy(AMapFlutterLocation location) {
    if (kIsWeb) return;
    location.destroy();
  }

  ///定位结果返回
  Stream<Map<String, Object>> onLocationChanged(AMapFlutterLocation location) {
    if (kIsWeb) {
      return const Stream.empty();
    }
    return location.onLocationChanged();
  }
}

class AMapApi {
  /// 与定位链路 15s 超时保护（startLocation 内 Future.delayed 15s）保持一致，
  /// 避免 POI/静态图请求在弱网下无超时悬挂。
  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
    ),
  );

  /// 获取城市名称，高德地图的adCode
  static String getCityNameByGaoDe(String code) {
    // 检查 code 是否为空或长度不足
    if (code.isEmpty || code.length < 4) {
      iPrint('⚠️ AMapApi: adCode 无效，使用默认值: code="$code"');
      return '000000'; // 返回默认的行政区划代码
    }
    return "${code.substring(0, 4)}00";
  }

  /// 高德定位搜索https://restapi.amap.com/v5/place/text?parameters
  /// https://lbs.amap.com/api/webservice/guide/api/search
  static Future<Response<dynamic>> getAmapPoi(
    String location,
    String types,
    int page,
    int size,
  ) async {
    if (AMapHelper.grant == null) throw StateError('AMap consent required');
    Map<String, dynamic> queryParameters = {
      "key": Env().aMapWebKey,
      "location": location,
      "types": types,
      "page_size": page.toString(),
      "page_num": size.toString(),
    };
    guardWebWriterDio(_dio);
    return await _dio.get(
      "https://restapi.amap.com/v5/place/around",
      queryParameters: queryParameters,
    );
  }

  static Future<Response<dynamic>> getMapByKeyword(
    String keywords,
    String types,
    String region,
    bool cityLimit,
    int page,
    int size,
  ) async {
    if (AMapHelper.grant == null) throw StateError('AMap consent required');
    Map<String, dynamic> queryParameters = {
      "key": Env().aMapWebKey,
      "keywords": keywords,
      "types": types,
      "region": region,
      "city_limit": cityLimit.toString(),
      "page_size": page.toString(),
      "page_num": size.toString(),
    };
    // https://lbs.amap.com/api/webservice/guide/api/newpoisearch
    guardWebWriterDio(_dio);
    return await _dio.get(
      "https://restapi.amap.com/v5/place/text",
      queryParameters: queryParameters,
    );
  }

  /// 静态地图 URL——官方 Web 服务 API 产品（非逆向抓瓦片），返回一张带 marker
  /// 的 PNG 预览图。跟 aMapWebKey 是同一个 Key，跟 getAmapPoi 坐标系
  /// （GCJ-02）天然对齐，且是纯 HTTP 请求，全平台可用。
  /// https://lbs.amap.com/api/webservice/guide/api/staticmaps
  static String staticMapUrl({
    required double latitude,
    required double longitude,
    int zoom = 16,
    int width = 750,
    int height = 400,
    int scale = 2,
  }) {
    final loc = '$longitude,$latitude';
    return Uri.https('restapi.amap.com', '/v3/staticmap', {
      'location': loc,
      'zoom': zoom.toString(),
      'size': '$width*$height',
      'scale': scale.toString(),
      'markers': 'mid,,A:$loc',
      'key': Env().aMapWebKey,
    }).toString();
  }

  /// 拉取静态地图图片二进制，用于"发送位置"内嵌预览图场景
  /// （原来靠 AMapController.takeSnapshot() 截图交互式地图，现在直接用
  /// 官方静态地图接口生成，不再需要等地图渲染/加 marker 再截屏）
  static Future<Uint8List?> fetchStaticMapBytes({
    required double latitude,
    required double longitude,
  }) async {
    if (AMapHelper.grant == null) return null;
    try {
      guardWebWriterDio(_dio);
      final resp = await _dio.get<List<int>>(
        staticMapUrl(latitude: latitude, longitude: longitude),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      return data == null ? null : Uint8List.fromList(data);
    } catch (_) {
      return null;
    }
  }
}

// https://lbs.amap.com/api/flutter/guide/positioning-flutter-plug-in/interface-info
class AMapPosition {
  String id = "";
  String name = "";
  LatLng latLng;
  String address = "";

  // String pcode = "";

  // Android：定位类型为GPS时有可能返回空
  // iOS：连续定位时有可能返回空
  String adCode = "";
  String distance = "";

  AMapPosition({
    required this.id,
    required this.name,
    required this.latLng,
    required this.address,
    // required this.pcode,
    required this.adCode,
    required this.distance,
  });
}
