import 'package:amap_flutter_base_plus/amap_flutter_base_plus.dart';

import 'amap_helper.dart';

/// 高德 POI 检索数据源（自 MapLocationPicker 抽出的纯数据装配层，零 UI 依赖）。
class LocationPoiSource {
  LocationPoiSource._();

  /// 全品类搜索类型码（餐饮/购物/生活服务/交通/…），随关键词检索传入。
  static const String searchTypes =
      "010000|020000|030000|040000|050000|060000|070000|080000|090000|100000|110000|120201|120300|140000|150400|190600|190301";

  /// 单页条数（与历史行为一致：hasMore 以满页判定）。
  static const int pageSize = 10;

  /// 关键词/周边 POI 检索并解析为 [AMapPosition] 列表。
  /// 响应形状不合法抛 [FormatException]（fail-fast，UI 层归一为检索错误态）。
  static Future<List<AMapPosition>> fetchPoi(
    String keyword,
    LatLng center,
    String citycode,
    int page,
  ) async {
    final response = keyword.isNotEmpty
        ? await AMapApi.getMapByKeyword(
            keyword,
            searchTypes,
            citycode,
            true,
            pageSize,
            page,
          )
        : await AMapApi.getAmapPoi(
            '${center.longitude},${center.latitude}',
            searchTypes,
            pageSize,
            page,
          );
    final data = response.data;
    if (data is! Map ||
        data['status']?.toString() != '1' ||
        data['pois'] is! List) {
      throw const FormatException('Invalid location search response');
    }
    return (data['pois'] as List).map(parsePosition).toList();
  }

  /// 高德 POI 行 → [AMapPosition]（id/name/坐标合法性 fail-fast）。
  static AMapPosition parsePosition(dynamic raw) {
    if (raw is! Map || raw['id'] is! String || raw['name'] is! String) {
      throw const FormatException('Invalid location result');
    }
    final coordinates = raw['location']?.toString().split(',') ?? [];
    final lng = coordinates.length == 2
        ? double.tryParse(coordinates[0])
        : null;
    final lat = coordinates.length == 2
        ? double.tryParse(coordinates[1])
        : null;
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      throw const FormatException('Invalid location coordinate');
    }
    return AMapPosition(
      id: raw['id'] as String,
      name: raw['name'] as String,
      latLng: LatLng(lat, lng),
      address: raw['address']?.toString() ?? '',
      adCode: raw['adcode']?.toString() ?? '',
      distance: raw['distance']?.toString() ?? '',
    );
  }
}
