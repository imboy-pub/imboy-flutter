import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/moment/moment_utils.dart';

void main() {
  group('momentGridLayout', () {
    test('1 张图单列（单图由调用方按宽高比大图展示）', () {
      final layout = momentGridLayout(count: 1, maxWidth: 316, spacing: 8);
      expect(layout.columns, 1);
    });

    test('4 张图 2×2 排列，cell 尺寸与九宫格一致', () {
      final layout4 = momentGridLayout(count: 4, maxWidth: 316, spacing: 8);
      final layout9 = momentGridLayout(count: 9, maxWidth: 316, spacing: 8);
      expect(layout4.columns, 2);
      expect(layout4.cellSize, layout9.cellSize);
    });

    test('9 张图三列网格，cell 尺寸 = (maxWidth - 2*spacing) / 3 向下取整', () {
      final layout = momentGridLayout(count: 9, maxWidth: 316, spacing: 8);
      expect(layout.columns, 3);
      expect(layout.cellSize, 100); // (316 - 16) / 3 = 100
    });

    test('2/3/5 张图均为三列网格', () {
      for (final count in [2, 3, 5]) {
        expect(
          momentGridLayout(count: count, maxWidth: 316, spacing: 8).columns,
          3,
          reason: 'count=$count',
        );
      }
    });

    test('cell 尺寸 floor 取整，保证 3 cell + 2 spacing 不超过 maxWidth', () {
      final layout = momentGridLayout(count: 9, maxWidth: 310, spacing: 8);
      expect(layout.cellSize, 98); // floor((310 - 16) / 3) = 98
      expect(layout.cellSize * 3 + 8 * 2, lessThanOrEqualTo(310));
    });
  });

  group('momentVideoDisplaySize', () {
    test('无宽高元数据退化 16:9 letterbox', () {
      final size = momentVideoDisplaySize(maxWidth: 320, aspectRatio: null);
      expect(size.width, 320);
      expect(size.height, closeTo(180, 0.01));
    });

    test('竖屏视频高度封顶 maxWidth，宽度等比收缩', () {
      final size = momentVideoDisplaySize(maxWidth: 320, aspectRatio: 9 / 16);
      expect(size.height, 320);
      expect(size.width, closeTo(180, 0.01));
    });
  });

  group('mediaAspectRatio', () {
    test('有 width/height 元数据返回宽高比', () {
      expect(
        mediaAspectRatio({'width': 1920, 'height': 1080}),
        closeTo(16 / 9, 0.001),
      );
    });

    test('缺失或非法元数据返回 null', () {
      expect(mediaAspectRatio({}), isNull);
      expect(mediaAspectRatio({'width': 0, 'height': 1080}), isNull);
    });
  });
}
