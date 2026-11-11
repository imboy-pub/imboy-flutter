# 定位服务

`LocationService` 返回业务类型 `ImboyLocation`，包含经纬度、地址和行政区编码。获取失败返回 `null`，调用方应提示用户检查系统定位服务和权限。

```dart
final location = await LocationService().getCurrentPosition();
if (location != null) {
  print('${location.latitude}, ${location.longitude}');
}
```

Android/iOS 优先使用高德定位，失败时使用 geolocator；macOS/Web 使用 geolocator。系统定位结果通常没有地址或行政区编码。Windows/Linux 当前没有定位实现。`getPositionStream()` 返回 `Stream<ImboyLocation>?`，`distanceBetween()` 接收两个 `ImboyLocation` 并返回米数。

`LocationCapabilities.supportsNearbyPeople` 仅在 Android/iOS 原生应用为真。位置流不代表实时位置共享功能已开放。

高德地图与 POI 使用 GCJ-02 坐标；系统定位与地图之间的坐标转换仍待实现。macOS 现有签名配置包含定位 entitlement 和用途说明，实际权限与位置消息流程仍需真机验证。
