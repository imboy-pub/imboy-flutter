/// Semver 版本比较工具 / Semver version comparison utility
///
/// 仅比较 major.minor.patch 三段，忽略 pre-release 和 build metadata。
/// Compares only major.minor.patch segments; pre-release and build metadata
/// are ignored.
///
/// 用法 / Usage:
/// ```dart
/// VersionComparator.compare('2.0.0', '1.9.9');  // 1
/// VersionComparator.compare('1.0.0', '1.0.0');  // 0
/// VersionComparator.compare('1.0.0', '2.0.0');  // -1
///
/// VersionComparator.isNewer('2.0.0', than: '1.9.9');  // true
/// VersionComparator.isOlder('1.0.0', than: '2.0.0');  // true
/// ```
class VersionComparator {
  const VersionComparator._();

  /// 比较两个版本字符串。
  /// Returns  1 when [a] > [b],  0 when equal,  -1 when [a] < [b].
  static int compare(String a, String b) {
    final pa = _parse(a);
    final pb = _parse(b);

    for (var i = 0; i < 3; i++) {
      final diff = pa[i] - pb[i];
      if (diff != 0) return diff > 0 ? 1 : -1;
    }
    return 0;
  }

  /// [version] 是否比 [than] 新（严格 >）。
  /// Whether [version] is strictly newer than [than].
  static bool isNewer(String version, {required String than}) =>
      compare(version, than) == 1;

  /// [version] 是否比 [than] 旧（严格 <）。
  /// Whether [version] is strictly older than [than].
  static bool isOlder(String version, {required String than}) =>
      compare(version, than) == -1;

  /// 解析 "major.minor.patch" 为 [major, minor, patch] 整数列表。
  /// 任何无法解析的段回退为 0。
  static List<int> _parse(String version) {
    if (version.isEmpty) return [0, 0, 0];

    // 去掉 pre-release / build metadata 后缀（如 "1.0.0-rc.1+1" → "1.0.0"）
    final cleaned = version.split(RegExp(r'[-+]')).first;
    final parts = cleaned.split('.');

    int segment(int index) =>
        index < parts.length ? (int.tryParse(parts[index]) ?? 0) : 0;

    return [segment(0), segment(1), segment(2)];
  }
}
