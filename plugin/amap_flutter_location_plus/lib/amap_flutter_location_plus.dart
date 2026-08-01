import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'amap_location_option.dart';

///高德定位Flutter插件入口类
class AMapFlutterLocation {
  static const String _CHANNEL_METHOD_LOCATION = "amap_flutter_location";
  static const String _CHANNEL_STREAM_LOCATION = "amap_flutter_location_stream";

  static const MethodChannel _methodChannel =
      MethodChannel(_CHANNEL_METHOD_LOCATION);

  static const EventChannel _eventChannel =
      EventChannel(_CHANNEL_STREAM_LOCATION);

  static final Stream<Map<String, Object>> _onLocationChanged = _eventChannel
      .receiveBroadcastStream()
      .asBroadcastStream()
      .map<Map<String, Object>>((element) => element.cast<String, Object>());

  StreamController<Map<String, Object>>? _receiveStream;
  StreamSubscription<Map<String, Object>>? _subscription;
  String? _pluginKey;

  /// 适配iOS 14定位新特性，只在iOS平台有效
  Future<AMapAccuracyAuthorization> getSystemAccuracyAuthorization() async {
    int result = -1;
    if (Platform.isIOS) {
      result = await _methodChannel.invokeMethod(
          "getSystemAccuracyAuthorization", {'pluginKey': _pluginKey});
    }
    if (result == 0) {
      return AMapAccuracyAuthorization.AMapAccuracyAuthorizationFullAccuracy;
    } else if (result == 1) {
      return AMapAccuracyAuthorization.AMapAccuracyAuthorizationReducedAccuracy;
    }
    return AMapAccuracyAuthorization.AMapAccuracyAuthorizationInvalid;
  }

  ///初始化
  AMapFlutterLocation() {
    _pluginKey = DateTime.now().millisecondsSinceEpoch.toString();
  }

  ///开始定位
  void startLocation() {
    _methodChannel.invokeMethod('startLocation', {'pluginKey': _pluginKey});
    return;
  }

  ///停止定位
  void stopLocation() {
    _methodChannel.invokeMethod('stopLocation', {'pluginKey': _pluginKey});
    return;
  }

  ///设置Android和iOS的apikey，建议在weigdet初始化时设置<br>
  ///apiKey的申请请参考高德开放平台官网<br>
  ///Android端: https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key<br>
  ///iOS端: https://lbs.amap.com/api/ios-location-sdk/guide/create-project/get-key<br>
  ///[androidKey] Android平台的key<br>
  ///[iosKey] ios平台的key<br>
  static void setApiKey(String androidKey, String iosKey) {
    _methodChannel
        .invokeMethod('setApiKey', {'android': androidKey, 'ios': iosKey});
  }

  /// 设置定位参数
  void setLocationOption(AMapLocationOption locationOption) {
    Map option = locationOption.getOptionsMap();
    option['pluginKey'] = _pluginKey;
    _methodChannel.invokeMethod('setLocationOption', option);
  }

  ///销毁定位
  void destroy() {
    _methodChannel.invokeListMethod('destroy', {'pluginKey': _pluginKey});
    if (_subscription != null) {
      _receiveStream?.close();
      _subscription?.cancel();
      _receiveStream = null;
      _subscription = null;
    }
  }

  ///定位结果回调
  ///
  ///定位结果以map的形式透出，其中包含的key已经含义如下：
  ///
  /// `callbackTime`:回调时间，格式为"yyyy-MM-dd HH:mm:ss"
  ///
  /// `locationTime`:定位时间， 格式为"yyyy-MM-dd HH:mm:ss"
  ///
  /// `locationType`:  定位类型， 具体类型可以参考https://lbs.amap.com/api/android-location-sdk/guide/utilities/location-type
  ///
  /// `latitude`:纬度
  ///
  /// `longitude`:精度
  ///
  /// `accuracy`:精确度
  ///
  /// `altitude`:海拔, android上只有locationType==1时才会有值
  ///
  /// `bearing`: 角度，android上只有locationType==1时才会有值
  ///
  /// `speed`:速度， android上只有locationType==1时才会有值
  ///
  /// `country`: 国家，android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `province`: 省，android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `city`: 城市，android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `district`: 城镇（区），android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `street`: 街道，android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `streetNumber`: 门牌号，android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `cityCode`: 城市编码，android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `adCode`: 区域编码， android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `address`: 地址信息， android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `description`: 位置语义， android上只有通过[AMapLocationOption.needAddress]为true时才有可能返回值
  ///
  /// `errorCode`: 错误码，当定位失败时才会返回对应的错误码， 具体错误请参考：https://lbs.amap.com/api/android-location-sdk/guide/utilities/errorcode
  ///
  /// `errorInfo`: 错误信息， 当定位失败时才会返回
  Stream<Map<String, Object>> onLocationChanged() {
    if (_receiveStream == null) {
      _receiveStream = StreamController();
      _subscription = _onLocationChanged.listen((Map<String, Object> event) {
        if (event['pluginKey'] == _pluginKey) {
          Map<String, Object> newEvent = Map<String, Object>.of(event);
          newEvent.remove('pluginKey');
          _receiveStream?.add(newEvent);
        }
      });
    }
    return _receiveStream!.stream;
  }

  /// 设置是否已经包含高德隐私政策并弹窗展示显示用户查看，如果未包含或者没有弹窗展示，高德定位SDK将不会工作<br>
  /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy<br>
  /// <b>必须保证在调用定位功能之前调用， 建议首次启动App时弹出《隐私政策》并取得用户同意</b><br>
  /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy
  /// [hasContains] 隐私声明中是否包含高德隐私政策说明<br>
  /// [hasShow] 隐私权政策是否弹窗展示告知用户<br>
  static void updatePrivacyShow(bool hasContains, bool hasShow) {
    _methodChannel
        .invokeMethod('updatePrivacyStatement', {'hasContains': hasContains, 'hasShow': hasShow});
  }

  /// 设置是否已经取得用户同意，如果未取得用户同意，高德定位SDK将不会工作<br>
  /// 高德SDK合规使用方案请参考官网地址：https://lbs.amap.com/news/sdkhgsy<br>
  /// <b>必须保证在调用定位功能之前调用, 建议首次启动App时弹出《隐私政策》并取得用户同意</b><br>
  /// [hasAgree] 隐私权政策是否已经取得用户同意<br>
  static void updatePrivacyAgree(bool hasAgree) {
    _methodChannel
        .invokeMethod('updatePrivacyStatement', {'hasAgree': hasAgree});
  }
}
