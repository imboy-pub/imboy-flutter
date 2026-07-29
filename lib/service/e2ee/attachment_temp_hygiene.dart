/// E2EE-061 Slice 8 —— 解密临时明文的生命周期（ATT-05）
///
/// ## 这条威胁是**本线自己造出来的**
///
/// 设计 §1 原本给 ATT-05（下载/解密中途 kill 或磁盘满）标的是
/// 「**不适用**——今天没有解密临时文件这一步」。Slice 6 接线之后就有了：
/// `IMBoyCacheManager` 先写 `<name>.tmp` 再 rename，写的是**解密后的明文**。
///
/// 正常路径上 `.tmp` 会被 rename 掉；被 kill / 磁盘满 / 进程崩溃时它会留下——
/// 那是一份**没人再引用、也没人再删**的明文碎片。
///
/// ## 取舍
///
/// 只清 `.tmp` **残留**，不动已完成的缓存文件：缓存里本来就是明文
/// （今天所有附件都如此），把它一并清掉是缓存策略变更，不是安全修复。
///
/// 「够老才清」而不是「见到就清」：同一目录下可能正有另一次写入在进行中，
/// 见到就删会把正在写的那份删掉，变成永远下载不出来。
library;

import 'dart:io';

class AttachmentTempHygiene {
  /// 原子写入用的中间后缀（与 `IMBoyCacheManager` 保持一致）。
  static const String tempSuffix = '.tmp';

  /// 超过这个年龄的 `.tmp` 视为残留。
  ///
  /// 取 10 分钟：单次下载 + 解密远达不到，而崩溃残留只会越来越老。
  // ponytail: 固定阈值而非可配——它没有第二个合理取值，
  // 真要调也该等有了实测数据再说。
  static const Duration staleAfter = Duration(minutes: 10);

  /// 该文件是否是应被清掉的残留。
  ///
  /// [age] 由调用方按「现在 - 最后修改时间」算出，便于测试注入时间。
  static bool isStaleArtifact({
    required String fileName,
    required Duration age,
  }) {
    if (!fileName.endsWith(tempSuffix)) return false;
    return age >= staleAfter;
  }

  /// 清扫 [dir] 下的残留临时明文，返回删掉的个数。
  ///
  /// - 目录不存在 → 返回 0，不抛（首次运行、或缓存刚被清空）；
  /// - 单个文件删不掉（占用/权限）→ **跳过继续**，不让一个失败带走整轮清扫；
  /// - **绝不**碰非 [tempSuffix] 结尾的文件。
  static Future<int> sweep(Directory dir, {DateTime? now}) async {
    if (!await dir.exists()) return 0;
    final DateTime at = now ?? DateTime.now();
    int removed = 0;
    final List<FileSystemEntity> entries;
    try {
      entries = await dir.list(followLinks: false).toList();
    } on FileSystemException {
      return 0;
    }
    for (final entity in entries) {
      if (entity is! File) continue;
      final String name = entity.uri.pathSegments.last;
      try {
        final DateTime modified = await entity.lastModified();
        if (!isStaleArtifact(fileName: name, age: at.difference(modified))) {
          continue;
        }
        await entity.delete();
        removed++;
      } on FileSystemException {
        // 删不掉就跳过：下一轮还会再试，而中断整轮会让其余残留一直留着
        continue;
      }
    }
    return removed;
  }
}
