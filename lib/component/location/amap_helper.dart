import 'dart:async';
import 'dart:io';

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_location/amap_flutter_location.dart';
import 'package:amap_flutter_location/amap_location_option.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/permission.dart';
import 'package:imboy/config/const.dart';

/// https://lbs.amap.com/api/flutter/guide/positioning-flutter-plug-in/interface-info

/// LocationInfo? locationInfo = await AMapHelper().startLocation();
class AMapHelper {
  late AMapFlutterLocation location;
  late Completer<AMapPosition> completer;

  // 保存单例
  static final AMapHelper _to = AMapHelper._internal();

  /// 工厂构造函数
  factory AMapHelper() => _to;

  static void init() {
    updatePrivacyShow(true, true);
    updatePrivacyAgree(true);
  }

  /// AMapHelper.setApiKey()
  /// 设置Android和iOS的apikey
  static void setApiKey() {
    if (Platform.isAndroid || Platform.isIOS) {
      AMapFlutterLocation.setApiKey(AMAP_ANDROID_KEY, AMAP_IOS_KEY);
    }
  }

  // 私有构造函数
  AMapHelper._internal() {
    location = AMapFlutterLocation();
    completer = Completer();
    Stream<Map<String, Object>> stream = onLocationChanged(location);
    stream.listen((Map<String, Object> result) {
      // https://lbs.amap.com/api/android-location-sdk/guide/utilities/location-type
      // https://lbs.amap.com/api/flutter/guide/positioning-flutter-plug-in/interface-info
      debugPrint("AMapHelper listen result ${result.toString()}");
      // listen result {
      // callbackTime: 2023-04-07 14:08:07,
      // locationTime: 2023-04-07 14:08:07,
      // locationType: 5,
      // latitude: 22.591701,
      // longitude: 113.875861, accuracy: 39.0,
      // altitude: 0.0, bearing: 0.0, speed: 0.0,
      // country: 中国,
      // province: 广东省, city: 深圳市, district: 宝安区, street: 臣田三路,
      // streetNumber: 38号,
      // cityCode: 0755,
      // adCode: 440306,
      // address: 广东省深圳市宝安区臣田三路38号靠近裕华海鲜(西乡店),
      // description: 在裕华海鲜(西乡店)附近
      // }

      double longitude = double.tryParse(result['longitude'].toString()) ?? 0;
      double latitude = double.tryParse(result['latitude'].toString()) ?? 0;
      String address = result['address'].toString();

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
    AMapFlutterLocation.updatePrivacyShow(hasContains, hasShow);
  }

  /// 设置是否已经取得用户同意，如果未取得用户同意，高德定位SDK将不会工作
  static void updatePrivacyAgree(bool hasAgree) {
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
    location.setLocationOption(locationOption);
  }

  /// 开始定位
  Future<AMapPosition?> startLocation() async {
    // debugPrint("AMapHelper Start === ");
    bool p = await requestLocationPermission();
    if (!p) {
      return null;
    }
    init();
    // 开启定位
    location.startLocation();
    return completer.future;
  }

  /// 停止定位
  void stopLocation(AMapFlutterLocation location) {
    location.stopLocation();
  }

  ///销毁定位
  void destroy(AMapFlutterLocation location) {
    location.destroy();
  }

  ///定位结果返回
  Stream<Map<String, Object>> onLocationChanged(AMapFlutterLocation location) {
    return location.onLocationChanged();
  }
}

class AMapApi {
  /// 获取城市名称，高德地图的adCode
  static String getCityNameByGaoDe(String code) {
    return "${code.substring(0, 4)}00";
  }

  /// 高德定位搜索https://restapi.amap.com/v5/place/text?parameters
  /// https://lbs.amap.com/api/webservice/guide/api/search
  static Future<Response> getAmapPoi(
    String location,
    String types,
    int page,
    int size,
  ) async {
    Map<String, dynamic> queryParameters = {
      "key": AMAP_WEBS_KEY,
      "location": location,
      "types": types,
      "page_size": page.toString(),
      "page_num": size.toString()
    };
    debugPrint("amapapi_getAmapPoi ${queryParameters.toString()}");
    return await Dio().get(
      "https://restapi.amap.com/v5/place/around",
      queryParameters: queryParameters,
    );
  }

  static Future<Response> getMapByKeyword(
    String keywords,
    String types,
    String region,
    bool cityLimit,
    int page,
    int size,
  ) async {
    Map<String, dynamic> queryParameters = {
      "key": AMAP_WEBS_KEY,
      "keywords": keywords,
      "types": types,
      "region": region,
      "city_limit": cityLimit.toString(),
      "page_size": page.toString(),
      "page_num": size.toString()
    };
    debugPrint("amapapi_getMapByKeyword ${queryParameters.toString()}");
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
