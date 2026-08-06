import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/helper/datetime.dart';

/// BUG#51 家族：后端 `created_at` 是毫秒时间戳，UI 直接 toString 就把
/// `1785806160783` 原样摆给用户看（相册副标题、相册照片详情页各一处）。
///
/// 约定：解析不出有效毫秒数一律返回空串 —— **宁可不显示，也不露原始值**。
void main() {
  group('DateTimeHelper.millisFmtOrEmpty', () {
    test('int 毫秒 → 可读时间，绝不出现原始数字', () {
      final out = DateTimeHelper.millisFmtOrEmpty(1785806160783);
      expect(out, isNotEmpty);
      expect(
        out.contains('1785806160783'),
        isFalse,
        reason: '这正是 BUG#51 的表现：原始毫秒数被摆给用户看',
      );
    });

    test('久远时间走绝对格式', () {
      // 近期时间会被 lastTimeFmt 渲染成「6小时前」这类相对表述，
      // 取一个足够久远的时刻来断言绝对格式那条分支。
      final out = DateTimeHelper.millisFmtOrEmpty(1600000000000);
      expect(out, matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')));
    });

    test('数字字符串同样被解析', () {
      expect(
        DateTimeHelper.millisFmtOrEmpty('1785806160783'),
        DateTimeHelper.millisFmtOrEmpty(1785806160783),
      );
    });

    test('null / 空串 / 非数字 / 0 / 负数 一律返回空串', () {
      for (final bad in [null, '', 'abc', 0, -1, <String, dynamic>{}]) {
        expect(
          DateTimeHelper.millisFmtOrEmpty(bad),
          '',
          reason: '输入 $bad 不该产出任何可见文本',
        );
      }
    });

    test('自定义 pattern 在绝对格式分支生效', () {
      final out = DateTimeHelper.millisFmtOrEmpty(
        1600000000000,
        pattern: 'y-MM-dd',
      );
      expect(out, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });
  });
}
