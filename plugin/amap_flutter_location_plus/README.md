##  前述 

1. 高德定位Flutter插件
2. 登录[高德开放平台官网](https://lbs.amap.com/api/)分别申请[Android端](https://lbs.amap.com/api/android-location-sdk/guide/create-project/get-key/)和[iOS端](https://lbs.amap.com/api/ios-location-sdk/guide/create-project/get-key)的key
3. 如需了解高德定位SDK的相关功能，请参阅[Android定位SDK开发指南](https://lbs.amap.com/api/android-location-sdk/locationsummary/)和[iOS定位SDK开发指南](https://lbs.amap.com/api/ios-location-sdk/summary/)


## 使用高德定位Flutter插件
* 请参考[在Flutter里使用Packages](https://flutter.cn/docs/development/packages-and-plugins/using-packages)， 引入amap_flutter_location插件
* 引入高德定位SDK，Android平台请参考[Android Sudio配置工程](https://lbs.amap.com/api/android-location-sdk/guide/create-project/android-studio-create-project), iOS平台请参考[ios安装定位SDK](https://lbs.amap.com/api/ios-location-sdk/guide/create-project/cocoapods)

### 常见问题：
1、[在iOS设备上运行或者运行iOS工程遇到： `Invalid `Podfile` file: cannot load such file - /flutter/packages/flutter_tools/bin/podhelper`](https://github.com/flutter/flutter/issues/59522)
```
$ rm ios/Podfile
$ flutter build ios
```


### 在需要的定位功能的页面中引入定位Flutter插件的dart类
``` Dart
import 'package:amap_flutter_location_plus/amap_flutter_location_plus.dart';
import 'package: amap_flutter_location_plus/amap_location_option.dart';
```
## 接口说明

### 设置定位参数
``` Dart
 /// 设置定位参数
 void setLocationOption(AMapLocationOption locationOption)
```
> 将您设置的参数传递到原生端对外接口，目前支持以下定位参数

``` Dart
 //// 是否需要地址信息，默认true
  bool needAddress = true;

  ///逆地理信息语言类型<br>
  ///默认[GeoLanguage.DEFAULT] 自动适配<br>
  ///可选值：<br>
  ///<li>[GeoLanguage.DEFAULT] 自动适配</li>
  ///<li>[GeoLanguage.EN] 英文</li>
  ///<li>[GeoLanguage.ZH] 中文</li>
  GeoLanguage geoLanguage;

  ///是否单次定位
  ///默认值：false
  bool onceLocation = false;

  ///Android端定位模式, 只在Android系统上有效<br>
  ///默认值：[AMapLocationMode.Hight_Accuracy]<br>
  ///可选值：<br>
  ///<li>[AMapLocationMode.Battery_Saving]</li>
  ///<li>[AMapLocationMode.Device_Sensors]</li>
  ///<li>[AMapLocationMode.Hight_Accuracy]</li>
  AMapLocationMode locationMode;

  ///Android端定位间隔<br>
  ///单位：毫秒<br>
  ///默认：2000毫秒<br>
  int locationInterval = 2000;

  ///iOS端是否允许系统暂停定位<br>
  ///默认：false
  bool pausesLocationUpdatesAutomatically = false;

  /// iOS端期望的定位精度， 只在iOS端有效<br>
  /// 默认值：最高精度<br>
  /// 可选值：<br>
  /// <li>[DesiredAccuracy.Best] 最高精度</li>
  /// <li>[DesiredAccuracy.BestForNavigation] 适用于导航场景的高精度 </li>
  /// <li>[DesiredAccuracy.NearestTenMeters] 10米 </li>
  /// <li>[DesiredAccuracy.Kilometer] 1000米</li>
  /// <li>[DesiredAccuracy.ThreeKilometers] 3000米</li>
  DesiredAccuracy desiredAccuracy = DesiredAccuracy.Best;

  /// iOS端定位最小更新距离<br>
  /// 单位：米<br>
  /// 默认值：-1，不做限制<br>
  double distanceFilter = -1;

  ///iOS 14中设置期望的定位精度权限
  AMapLocationAccuracyAuthorizationMode desiredLocationAccuracyAuthorizationMode = AMapLocationAccuracyAuthorizationMode.FullAccuracy;

  /// iOS 14中定位精度权限由模糊定位升级到精确定位时，需要用到的场景key fullAccuracyPurposeKey 这个key要和plist中的配置一样
  String fullAccuracyPurposeKey = "";
```
### 开始定位
``` Dart
void startLocation()
```
### 停止定位
``` Dart
void stopLocation()
```
### 销毁定位
> 高德定位Flutter插件，支持多实例，请在weidet执行dispose()时调用当前定位插件的销毁方法
``` Dart
void destroy()
```
### 定位结果获取
> 原生端以键值对map的形式回传定位结果到Flutter端, 通过onLoationChanged返回定位结果

``` Dart
Stream<Map<String, Object>> onLocationChanged(）
```

> 注册定位结果监听

``` Dart

_locationPlugin
        .onLocationChanged()
        .listen((Map<String, Object> result) {
          ///result即为定位结果
        }
```
 
 定位结果是以map的形式返回的，具体内容为
 ``` Dart
 
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
  
```


