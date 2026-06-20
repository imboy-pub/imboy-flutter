import 'dart:async';
import 'dart:io';

import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:amap_flutter_location_plus/amap_flutter_location_plus.dart';
import 'package:amap_flutter_location_plus/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/env.dart';

/// https://lbs.amap.com/api/flutter/guide/positioning-flutter-plug-in/interface-info

/// LocationInfo? locationInfo = await AMapHelper().startLocation();
class AMapHelper {
  late AMapFlutterLocation location;
  late Completer<AMapPosition?> completer;

  // 保存单例
  static final AMapHelper _to = AMapHelper._internal();

  /// 工厂构造函数
  factory AMapHelper() => _to;

  static void init() {
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
  AMapHelper._internal() {
    completer = Completer<AMapPosition?>();

    // Web 平台不支持高德地图原生插件，跳过初始化
    if (kIsWeb) {
      return;
    }

    location = AMapFlutterLocation();
    Stream<Map<String, Object>> stream = onLocationChanged(location);
    stream.listen((Map<String, Object> result) {
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
    // 仅支持 iOS/Android 平台
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }
    AMapFlutterLocation.updatePrivacyShow(hasContains, hasShow);
  }

  /// 设置是否已经取得用户同意，如果未取得用户同意，高德定位SDK将不会工作
  static void updatePrivacyAgree(bool hasAgree) {
    // 仅支持 iOS/Android 平台
    if (kIsWeb || Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      return;
    }
    AMapFlutterLocation.updatePrivacyAgree(hasAgree);
  }

  // 初始化
  AMapLocationOption locationOption = AMapLocationOption(
    // 是否需要地址信息，默认true
    needAddress: true,
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
    desiredAccuracy: DesiredAccuracy.Best,
  );

  /// 设置定位参数
  void setLocationOption(AMapFlutterLocation location) {
    if (kIsWeb) return;
    location.setLocationOption(locationOption);
  }

  /// 开始定位
  Future<AMapPosition?> startLocation() async {
    // Web 平台不支持高德地图定位
    if (kIsWeb) {
      return null;
    }

    // 1. 检查权限
    bool p = await requestLocationPermission();
    debugPrint('[AMap] 权限/定位服务检查结果 = $p');
    if (!p) {
      return null;
    }

    // 2. 初始化隐私协议（如果未初始化）
    init();

    // 3. 设置定位参数
    setLocationOption(location);

    // 4. 创建新的 Completer（支持多次调用）
    if (completer.isCompleted) {
      completer = Completer<AMapPosition?>();
    }

    // 5. 添加超时保护（15秒）
    final Future<AMapPosition?> timeoutFuture =
        Future<dynamic>.delayed(const Duration(seconds: 15), () => null).then((
          _,
        ) {
          if (!completer.isCompleted) {
            completer.complete(null);
          }
          return null;
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
    final result = await Future.any([completer.future, timeoutFuture]);

    return result;
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
    Map<String, dynamic> queryParameters = {
      "key": Env().aMapWebKey,
      "location": location,
      "types": types,
      "page_size": page.toString(),
      "page_num": size.toString(),
    };
    return await Dio().get(
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
    return await Dio().get(
      "https://restapi.amap.com/v5/place/text",
      queryParameters: queryParameters,
    );
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
