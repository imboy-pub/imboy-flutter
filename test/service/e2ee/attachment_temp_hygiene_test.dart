/// E2EE-061 Slice 8 —— 解密临时明文的清扫（ATT-05）
///
/// ⚠️ 这条威胁是**本线自己造出来的**：设计 §1 给 ATT-05 标的原本是
/// 「不适用——今天没有解密临时文件这一步」。Slice 6 接线之后，
/// `IMBoyCacheManager` 写的 `<name>.tmp` 就是**解密后的明文**；
/// 被 kill / 磁盘满时它会留下，没人引用也没人删。
///
/// 本文件跑**真实文件系统**（`Directory.systemTemp`），不是 mock：
/// 清扫逻辑的失效方式（删错文件、删不掉就整轮中断）都发生在真实 FS 语义上。
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_temp_hygiene.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('imboy_hygiene_test_');
  });

  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  File write(String name, {Duration? ageBack}) {
    final f = File('${dir.path}/$name')..writeAsStringSync('plaintext-bytes');
    if (ageBack != null) {
      f.setLastModifiedSync(DateTime.now().subtract(ageBack));
    }
    return f;
  }

  group('1. isStaleArtifact 判据', () {
    test('够老的 .tmp → 是残留', () {
      expect(
        AttachmentTempHygiene.isStaleArtifact(
          fileName: 'imboy_cache_1.jpg.tmp',
          age: AttachmentTempHygiene.staleAfter + const Duration(seconds: 1),
        ),
        isTrue,
      );
    });

    test('⚠️ 新鲜的 .tmp → 不动（可能正有另一次写入在进行）', () {
      expect(
        AttachmentTempHygiene.isStaleArtifact(
          fileName: 'imboy_cache_1.jpg.tmp',
          age: const Duration(seconds: 5),
        ),
        isFalse,
        reason: '见到就删会把正在写的那份删掉，变成永远下载不出来',
      );
    });

    test('⚠️ 非 .tmp 的缓存文件，再老也不动', () {
      expect(
        AttachmentTempHygiene.isStaleArtifact(
          fileName: 'imboy_cache_1.jpg',
          age: const Duration(days: 30),
        ),
        isFalse,
        reason: '清缓存是缓存策略变更，不是安全修复；越界会把好文件删光',
      );
    });
  });

  group('2. sweep：真实文件系统', () {
    test('只删够老的 .tmp，其余原样留着', () async {
      final stale = write('a.jpg.tmp', ageBack: const Duration(hours: 2));
      final fresh = write('b.jpg.tmp');
      final cached = write('c.jpg', ageBack: const Duration(days: 30));

      final removed = await AttachmentTempHygiene.sweep(dir);

      expect(removed, 1);
      expect(stale.existsSync(), isFalse);
      expect(fresh.existsSync(), isTrue, reason: '正在写的那份不能删');
      expect(cached.existsSync(), isTrue, reason: '已完成的缓存不能删');
    });

    test('多个残留一起清', () async {
      write('a.jpg.tmp', ageBack: const Duration(hours: 2));
      write('b.mp4.tmp', ageBack: const Duration(days: 1));
      write('c.jpg', ageBack: const Duration(days: 1));
      expect(await AttachmentTempHygiene.sweep(dir), 2);
      expect(dir.listSync().length, 1);
    });

    test('目录不存在 → 返回 0，不抛', () async {
      final missing = Directory('${dir.path}/nope');
      expect(await AttachmentTempHygiene.sweep(missing), 0);
    });

    test('空目录 → 返回 0', () async {
      expect(await AttachmentTempHygiene.sweep(dir), 0);
    });

    test('子目录不受影响（只处理 File）', () async {
      Directory('${dir.path}/sub.tmp').createSync();
      write('a.jpg.tmp', ageBack: const Duration(hours: 2));
      expect(await AttachmentTempHygiene.sweep(dir), 1);
      expect(Directory('${dir.path}/sub.tmp').existsSync(), isTrue);
    });

    test('⚠️ 实证：`is! File` 守卫是**冗余**防线（保留作纵深防御）', () {
      // 空验证做不成——去掉 `entity is! File` 会让 `entity.lastModified()`
      // 编译不过，而编译失败的"红"没有信息量。改为直接实证它为何冗余：
      // 目录的 URI 以 `/` 结尾，末段是**空串**，名字判据本就跳过。
      final d = Directory('${dir.path}/sub.tmp')..createSync();
      expect(d.uri.pathSegments.last, equals(''));
      expect(
        AttachmentTempHygiene.isStaleArtifact(
          fileName: d.uri.pathSegments.last,
          age: const Duration(days: 30),
        ),
        isFalse,
        reason: '即便没有类型守卫，名字判据也不会把目录当成残留',
      );
    });

    test('注入 now：把"现在"往后拨，新鲜的也会变成残留', () async {
      final fresh = write('a.jpg.tmp');
      expect(await AttachmentTempHygiene.sweep(dir), 0);
      expect(
        await AttachmentTempHygiene.sweep(
          dir,
          now: DateTime.now().add(const Duration(hours: 1)),
        ),
        1,
      );
      expect(fresh.existsSync(), isFalse);
    });
  });
}
