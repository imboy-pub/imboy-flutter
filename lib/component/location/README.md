# 定位服务 (Location Service)

跨平台定位服务，支持 macOS、iOS、Android 和 Web 平台。

## 概述

`LocationService` 是一个统一的定位服务类，根据不同平台自动选择最优的定位方案：

- **iOS/Android**: 使用高德地图定位（AMapFlutterLocation）
  - 优点：定位精度高，返回详细的地址信息（省市区、街道、POI等）
  
- **macOS/Web**: 使用 geolocator 定位
  - 优点：真正的跨平台支持，能获取经纬度
  - 缺点：不直接返回地址信息（需经逆地理编码转换）

## 功能特性

✅ 一次性定位
✅ 持续位置监听
✅ 距离计算
✅ 自动权限请求
✅ 平台自动适配
✅ 统一的返回格式

## 使用方法

### 基础使用

```dart
import 'package:imboy/component/location/location_service.dart';
import 'package:imboy/component/location/amap_helper.dart';

// 获取当前位置
final LocationService locationService = LocationService();
AMapPosition? position = await locationService.getCurrentPosition();

if (position != null) {
  print('纬度: ${position.latLng.latitude}');
  print('经度: ${position.latLng.longitude}');
  
  // iOS/Android 上有详细地址
  if (position.address.isNotEmpty) {
    print('地址: ${position.address}');
  }
}
```

### 持续位置监听

```dart
final LocationService locationService = LocationService();

// 获取位置流
Stream<AMapPosition>? stream = locationService.getPositionStream();

if (stream != null) {
  stream.listen((position) {
    print('位置更新: ${position.latLng.latitude}, ${position.latLng.longitude}');
  });
}
```

### 计算距离

```dart
final LocationService locationService = LocationService();

// 计算两点之间的距离（单位：米）
double distance = locationService.distanceBetween(
  LatLng(39.9042, 116.4074),  // 北京
  LatLng(31.2304, 121.4737),  // 上海
);

print('北京到上海的距离: ${distance / 1000} 公里');
```

### 发送位置消息

```dart
// 在聊天中发送位置
AMapPosition? l = await LocationService().getCurrentPosition();
if (l != null) {
  // 使用经纬度创建位置消息
  await messageRepo.sendLocationMessage(
    conversationId: 'xxx',
    latitude: l.latLng.latitude,
    longitude: l.latLng.longitude,
    address: l.address.isNotEmpty ? l.address : '未知位置',
    title: l.name.isNotEmpty ? l.name : '位置',
  );
}
```

## 平台差异说明

### iOS/Android

```dart
AMapPosition position = await LocationService().getCurrentPosition();

print('纬度: ${position.latLng.latitude}');       // 22.591701
print('经度: ${position.latLng.longitude}');     // 113.875861
print('地址: ${position.address}');              // 广东省深圳市宝安区臣田三路38号...
print('区域编码: ${position.adCode}');           // 440306
print('地点名称: ${position.name}');             // 裕华海鲜(西乡店)
print('精度: ${position.distance}');             // 39.0 (米)
```

### macOS

```dart
AMapPosition position = await LocationService().getCurrentPosition();

print('纬度: ${position.latLng.latitude}');       // 22.591701
print('经度: ${position.latLng.longitude}');     // 113.875861
print('地址: ${position.address}');              // "" (空)
print('区域编码: ${position.adCode}');           // "" (空)
print('地点名称: ${position.name}');             // "" (空)
print('精度: ${position.distance}');             // 39.0 (米)
```

## API 文档

### LocationService

#### getCurrentPosition()

获取当前位置（一次性定位）。

```dart
Future<AMapPosition?> getCurrentPosition()
```

**返回值**
- `AMapPosition?` - 定位成功返回位置信息，失败返回 `null`

#### getPositionStream()

获取位置变化流（持续监听）。

```dart
Stream<AMapPosition>? getPositionStream()
```

**返回值**
- `Stream<AMapPosition>`? - 位置变化流，macOS 上使用 geolocator，iOS/Android 上使用高德

#### distanceBetween()

计算两个位置之间的距离。

```dart
double distanceBetween(LatLng start, LatLng end)
```

**参数**
- `start` - 起始位置坐标
- `end` - 结束位置坐标

**返回值**
- `double` - 两点之间的距离（单位：米）

### AMapPosition

定位结果模型。

```dart
class AMapPosition {
  LatLng latLng;        // 经纬度坐标
  String id;            // 地点ID
  String name;          // 地点名称（仅 iOS/Android）
  String address;       // 详细地址（仅 iOS/Android）
  String adCode;        // 行政区划编码（仅 iOS/Android）
  String distance;      // 定位精度（字符串形式的米）
}
```

## 错误处理

```dart
AMapPosition? position = await LocationService().getCurrentPosition();

if (position == null) {
  // 可能的原因：
  // 1. 用户拒绝了定位权限
  // 2. 定位服务未开启
  // 3. 定位超时
  // 4. 其他系统错误
  
  AppLoading.showError('获取位置失败，请检查定位权限和设置');
  return;
}
```

## 权限配置

### Android

在 `android/app/src/main/AndroidManifest.xml` 中添加：

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### iOS

在 `ios/Runner/Info.plist` 中已包含：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>请允许$(PRODUCT_NAME)获取您的位置信息</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app needs access to location when open and in the background.</string>
```

### macOS

在 `macos/Runner/Info.plist` 中已包含：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>请允许$(PRODUCT_NAME)获取您的位置信息</string>
```

在 `macos/Runner/DebugProfile.entitlements` 和 `macos/Runner/Release.entitlements` 中已包含：

```xml
<key>com.apple.security.personal-information.location</key>
<true/>
```

## 从 AMapHelper 迁移

**旧代码:**

```dart
import 'package:imboy/component/location/amap_helper.dart';

AMapPosition? l = await AMapHelper().startLocation();
```

**新代码:**

```dart
import 'package:imboy/component/location/location_service.dart';

AMapPosition? l = await LocationService().getCurrentPosition();
```

## 注意事项

1. **首次使用**: 首次获取位置会弹出权限请求对话框，用户需要手动授权
2. **macOS 地址**: macOS 上无法直接获取地址信息，如需显示地址需要使用逆地理编码 API
3. **超时设置**: 一次性定位有 10 秒超时限制
4. **精度**: iOS/Android 使用高德地图定位精度更高，macOS 使用系统定位
5. **后台定位**: 如需后台持续定位，需要在 Info.plist 中配置 `UIBackgroundModes`

## 依赖

```yaml
dependencies:
  geolocator: ^13.0.2          # 跨平台定位（支持 macOS/Web）
  amap_flutter_location_plus:  # 高德地图定位（iOS/Android）
  permission_handler: ^12.0.1  # 权限管理
```

## 相关文件

- `location_service.dart` - 主服务类
- `amap_helper.dart` - 高德地图辅助类（保留用于 API 调用）
- `permission.dart` - 权限请求辅助函数

## 常见问题

### Q: macOS 上为什么没有地址信息？
A: geolocator 插件在 macOS 上只返回经纬度，不提供地址信息。如果需要显示地址，可以调用高德 API 的逆地理编码接口。

### Q: 如何将经纬度转换为地址？
A: 使用 `AMapApi.getMapByKeyword()` 或高德地图逆地理编码 API。

### Q: 定位失败怎么办？
A: 检查以下几点：
1. 设备定位服务是否开启
2. 应用是否有定位权限
3. 网络连接是否正常（高德定位需要网络）

---

**维护者**: ImBoy 开发团队
**最后更新**: 2025-01-01