import 'dart:async';
import 'dart:io';

import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:imboy/component/location/amap_helper.dart';

/// 跨平台定位服务
///
/// 根据平台自动选择最优的定位方案：
/// - iOS/Android: 使用高德地图定位 (amap_flutter_location_plus)
/// - macOS/Web: 使用 geolocator 定位
///
/// 使用示例：
/// ```dart
/// final LocationService locationService = LocationService();
/// AMapPosition? position = await locationService.getCurrentPosition();
/// if (position != null) {
///   print('纬度: ${position.latLng.latitude}');
///   print('经度: ${position.latLng.longitude}');
/// }
/// ```
class LocationService {
  // 单例模式
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// 获取当前位置（一次性定位）
  ///
  /// 返回 [AMapPosition] 对象，包含经纬度和可能的地址信息
  /// 失败时返回 null
  Future<AMapPosition?> getCurrentPosition() async {
    if (kIsWeb) {
      return _getCurrentPositionGeolocator();
    } else if (Platform.isMacOS) {
      return _getCurrentPositionGeolocator();
    } else if (Platform.isIOS || Platform.isAndroid) {
      return await AMapHelper().startLocation();
    }
    debugPrint('LocationService: Unsupported platform');
    return null;
  }

  /// 获取位置变化流（持续监听）
  ///
  /// 注意：macOS 上使用 geolocator，iOS/Android 上使用高德地图
  /// 返回 null 表示平台不支持流式定位
  Stream<AMapPosition>? getPositionStream() {
    if (kIsWeb || Platform.isMacOS) {
      return _getPositionStreamGeolocator();
    } else if (Platform.isIOS || Platform.isAndroid) {
      final amapHelper = AMapHelper();
      return amapHelper.onLocationChanged(amapHelper.location).map((result) {
        final longitude = double.tryParse(result['longitude'].toString()) ?? 0;
        final latitude = double.tryParse(result['latitude'].toString()) ?? 0;
        final address = result['address'].toString();

        return AMapPosition(
          latLng: LatLng(latitude, longitude),
          id: '',
          name: '',
          address: address,
          adCode: result['adCode'].toString(),
          distance: '',
        );
      });
    }
    return null;
  }

  /// 计算两个位置之间的距离（单位：米）
  ///
  /// 使用 Haversine 公式计算球面距离
  double distanceBetween(LatLng start, LatLng end) {
    return Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );
  }

  // ========== Geolocator 定位 (macOS/Web) ==========

  /// 使用 geolocator 获取当前位置（macOS/Web）
  Future<AMapPosition?> _getCurrentPositionGeolocator() async {
    try {
      // 检查定位服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: 定位服务未启用');
        return null;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('LocationService: 定位权限被拒绝');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: 定位权限被永久拒绝');
        return null;
      }

      // 获取当前位置
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint(
        'LocationService: Geolocator定位成功 - '
        '纬度: ${position.latitude}, 经度: ${position.longitude}',
      );

      return AMapPosition(
        latLng: LatLng(position.latitude, position.longitude),
        id: '',
        name: '',
        address: '', // geolocator 不直接提供地址信息
        adCode: '',
        distance: position.accuracy.toString(),
      );
    } catch (e) {
      debugPrint('LocationService: Geolocator定位失败 - $e');
      return null;
    }
  }

  /// 使用 geolocator 获取位置流（macOS/Web）
  Stream<AMapPosition>? _getPositionStreamGeolocator() {
    try {
      // 创建位置设置
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 每10米触发一次更新
      );

      return Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).map((position) {
        debugPrint(
          'LocationService: Geolocator位置更新 - '
          '纬度: ${position.latitude}, 经度: ${position.longitude}',
        );

        return AMapPosition(
          latLng: LatLng(position.latitude, position.longitude),
          id: '',
          name: '',
          address: '',
          adCode: '',
          distance: position.accuracy.toString(),
        );
      });
    } catch (e) {
      debugPrint('LocationService: Geolocator定位流失败 - $e');
      return null;
    }
  }
}

// 为了保持向后兼容，提供一个便捷方法
///
/// 获取当前位置的便捷方法
/// 直接调用 LocationService().getCurrentPosition()
Future<AMapPosition?> getCurrentPosition() {
  return LocationService().getCurrentPosition();
}
