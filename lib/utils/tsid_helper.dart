/// TSID (Time-Sorted ID) 兼容性工具类
///
/// 在 TSID 迁移过渡期，后端新 API 返回 TSID 数字 (int)，
/// 旧 API 可能返回字符串格式 ID (String)。
/// 本工具类统一 ID 解析，兼容两种格式。
///
/// TSID 规格:
/// - 64-bit BIGINT, 位布局: [sign:1][timestamp:42][node:10][sequence:11]
/// - 纪元: 2025-01-01 UTC (1735689600000)
/// - 数字最多 19 位
library;

/// TSID ID 帮助类
///
/// 用于在过渡期兼容 String 和 int 两种 ID 格式。
/// 新代码应优先使用 int 类型存储 TSID。
class TsidHelper {
  TsidHelper._();

  /// 从 JSON 值解析 ID 为 String
  ///
  /// 兼容 int (TSID) 和 String 两种格式
  /// - int → 转为 String
  /// - String → 直接返回
  /// - null → 返回空字符串
  static String parseIdAsString(dynamic value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value is String) return value;
    return value.toString();
  }

  /// 从 JSON 值解析 ID 为 int（可空）
  ///
  /// - int → 直接返回
  /// - String → 尝试 int.tryParse，失败返回 null（非数字 ID 格式）
  /// - null → 返回 null
  static int? parseIdAsInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// 判断 ID 值是否为 TSID 数字格式
  ///
  /// TSID 是纯数字的大整数（通常 15-19 位）
  /// 非 TSID 格式包含字母和数字的混合字符串
  static bool isTsid(dynamic value) {
    if (value is int) return true;
    if (value is String) {
      if (value.isEmpty) return false;
      return int.tryParse(value) != null;
    }
    return false;
  }

  /// 从 TSID 中提取时间戳（毫秒）
  ///
  /// TSID 位布局: [sign:1][timestamp:42][node:10][sequence:11]
  /// 纪元: 2025-01-01 UTC (1735689600000)
  static int? extractTimestamp(dynamic value) {
    final id = parseIdAsInt(value);
    if (id == null || id <= 0) return null;
    // 右移 21 位 (node:10 + sequence:11) 得到 timestamp
    final tsMs = (id >> 21) + _epoch;
    return tsMs;
  }

  /// 从 TSID 中提取 DateTime
  static DateTime? extractDateTime(dynamic value) {
    final ms = extractTimestamp(value);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  /// TSID 纪元: 2025-01-01 UTC
  static const int _epoch = 1735689600000;

  /// 安全比较两个 ID（兼容 int/String 混合比较）
  ///
  /// 当一个是 int、另一个是 String 时，统一转为 String 比较
  static bool idsEqual(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a == null || b == null) return false;
    return parseIdAsString(a) == parseIdAsString(b);
  }
}
