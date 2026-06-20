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
  ///
  /// 平台策略：
  /// - iOS: 优先使用高德地图定位（提供地址信息）
  /// - Android: 优先使用高德地图，失败时降级到 geolocator
  /// - macOS/Web: 使用 geolocator 定位
  Future<AMapPosition?> getCurrentPosition() async {
    if (kIsWeb) {
      return _getCurrentPositionGeolocator();
    } else if (Platform.isMacOS) {
      return _getCurrentPositionGeolocator();
    } else if (Platform.isIOS || Platform.isAndroid) {
      // iOS/Android: 优先高德，失败时降级到 geolocator(系统定位)
      // iOS 此前只用高德、无兜底；高德 Key/Bundle 绑定或网络异常时彻底拿不到坐标。
      return await _getCurrentPositionWithFallback();
    }
    return null;
  }

  /// 移动端定位：高德优先，失败时降级到 geolocator（系统 CoreLocation/LocationManager）
  ///
  /// 降级触发条件：
  /// 1. 高德返回 null（定位失败/权限/超时）
  /// 2. 高德返回 (0.0, 0.0) 无效坐标（通常表示 Key 认证或 Bundle 绑定失败）
  Future<AMapPosition?> _getCurrentPositionWithFallback() async {
    // 尝试使用高德地图定位
    AMapPosition? amapResult = await AMapHelper().startLocation();

    // 检查高德定位结果是否有效
    if (amapResult != null &&
        _isValidCoordinate(
          amapResult.latLng.latitude,
          amapResult.latLng.longitude,
        )) {
      return amapResult;
    }

    // 降级到 geolocator
    debugPrint('[Location] 高德定位无效，降级到 geolocator(系统定位)');
    final geo = await _getCurrentPositionGeolocator();
    debugPrint(
      '[Location] geolocator 结果 = ${geo == null ? 'null' : '${geo.latLng.latitude},${geo.latLng.longitude}'}',
    );
    return geo;
  }

  /// 检查坐标是否有效
  ///
  /// 有效坐标条件：
  /// 1. 不是 (0.0, 0.0)
  /// 2. 经度在 [-180, 180] 范围内
  /// 3. 纬度在 [-90, 90] 范围内
  bool _isValidCoordinate(double latitude, double longitude) {
    if (latitude == 0.0 && longitude == 0.0) {
      return false; // (0, 0) 通常表示定位失败
    }
    if (longitude < -180 || longitude > 180) {
      return false; // 经度超出有效范围
    }
    if (latitude < -90 || latitude > 90) {
      return false; // 纬度超出有效范围
    }
    return true;
  }

  /// 获取位置变化流（持续监听）
  ///
  /// 平台策略：
  /// - iOS: 使用高德地图定位流
  /// - Android: 优先使用高德地图，首次无效时自动降级到 geolocator 流
  /// - macOS/Web: 使用 geolocator 定位流
  ///
  /// 返回 null 表示平台不支持流式定位
  Stream<AMapPosition>? getPositionStream() {
    if (kIsWeb || Platform.isMacOS) {
      return _getPositionStreamGeolocator();
    } else if (Platform.isIOS) {
      return _getPositionStreamAMap();
    } else if (Platform.isAndroid) {
      // Android: 使用带降级逻辑的高德定位流
      return _getPositionStreamAndroid();
    }
    return null;
  }

  /// iOS 平台：使用高德地图定位流
  Stream<AMapPosition> _getPositionStreamAMap() {
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

  /// Android 平台：高德优先，失败时降级到 geolocator 流
  ///
  /// 由于高德 Key 认证问题会导致整个流失效，
  /// Android 的持续定位直接使用 geolocator 以保证可靠性
  Stream<AMapPosition>? _getPositionStreamAndroid() {
    return _getPositionStreamGeolocator();
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
        debugPrint('[geolocator] 定位服务未开启(serviceEnabled=false)');
        return null;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('[geolocator] 权限被拒绝(denied)');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('[geolocator] 权限被永久拒绝(deniedForever)');
        return null;
      }

      // 获取当前位置
      // Android：强制用系统 LocationManager（华为/无 GMS 设备的 FusedLocation 不可用，
      // 否则 getCurrentPosition 会一直超时）。其余平台用通用 LocationSettings。
      final LocationSettings locationSettings = (!kIsWeb && Platform.isAndroid)
          ? AndroidSettings(
              forceLocationManager: true,
              accuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15),
            )
          : const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            );
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: locationSettings,
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
      debugPrint('[geolocator] 获取定位异常: ${e.runtimeType} $e');
      // 末位兜底：取最后一次已知位置（拿不到实时定位时总比无数据强）
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          debugPrint(
            '[geolocator] 使用 lastKnownPosition ${last.latitude},${last.longitude}',
          );
          return AMapPosition(
            latLng: LatLng(last.latitude, last.longitude),
            id: '',
            name: '',
            address: '',
            adCode: '',
            distance: last.accuracy.toString(),
          );
        }
      } catch (_) {}
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
      return null;
    }
  }
}
