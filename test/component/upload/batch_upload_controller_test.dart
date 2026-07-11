import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/upload/batch_upload_controller.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 构造最小可用 AssetEntity（纯数据，不触发平台通道），供 stub 上传函数按 id 分流。
AssetEntity _asset(String id) =>
    AssetEntity(id: id, typeInt: 1, width: 100, height: 100);

void main() {
  group('BatchUploadController', () {
    test('all assets succeed: every item done and results ordered', () async {
      // Arrange
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'url_${a.id}',
        concurrency: 3,
      );

      // Act
      await controller.addAndUpload([_asset('a'), _asset('b'), _asset('c')]);

      // Assert
      expect(controller.items.every((i) => i.isDone), isTrue);
      expect(controller.hasFailed, isFalse);
      expect(controller.results, ['url_a', 'url_b', 'url_c']);
    });

    test('partial failure marks only failures, keeps successes', () async {
      // Arrange — asset 'b' fails (uploader returns null).
      final failing = {'b'};
      final controller = BatchUploadController<String>(
        uploader: (a) async => failing.contains(a.id) ? null : 'url_${a.id}',
      );

      // Act
      await controller.addAndUpload([_asset('a'), _asset('b'), _asset('c')]);

      // Assert
      expect(controller.hasFailed, isTrue);
      expect(controller.items[0].isDone, isTrue);
      expect(controller.items[1].isFailed, isTrue);
      expect(controller.items[2].isDone, isTrue);
      expect(controller.results, ['url_a', 'url_c']);
    });

    test(
      'retry re-uploads only the failed item, successes untouched',
      () async {
        // Arrange
        final failing = {'b'};
        final controller = BatchUploadController<String>(
          uploader: (a) async => failing.contains(a.id) ? null : 'url_${a.id}',
        );
        await controller.addAndUpload([_asset('a'), _asset('b'), _asset('c')]);
        expect(controller.items[1].isFailed, isTrue);
        final doneBefore = controller.items[0];

        // Act — make 'b' succeed, retry only its index.
        failing.clear();
        await controller.retry(1);

        // Assert
        expect(controller.items[1].isDone, isTrue);
        expect(controller.hasFailed, isFalse);
        expect(controller.results, ['url_a', 'url_b', 'url_c']);
        // 成功项对象未被重传触碰。
        expect(identical(controller.items[0], doneBefore), isTrue);
      },
    );

    test('retry on a non-failed item is a no-op', () async {
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'url_${a.id}',
      );
      await controller.addAndUpload([_asset('a')]);

      await controller.retry(0); // already done
      expect(controller.results, ['url_a']);
    });

    test('retryFailed retries all failed items', () async {
      // Arrange
      final failing = {'a', 'c'};
      final controller = BatchUploadController<String>(
        uploader: (a) async => failing.contains(a.id) ? null : 'url_${a.id}',
      );
      await controller.addAndUpload([_asset('a'), _asset('b'), _asset('c')]);
      expect(controller.items.where((i) => i.isFailed).length, 2);

      // Act
      failing.clear();
      await controller.retryFailed();

      // Assert
      expect(controller.hasFailed, isFalse);
      expect(controller.results, ['url_a', 'url_b', 'url_c']);
    });

    test('status flows pending -> uploading -> done', () async {
      // Arrange — gate the upload with a Completer to observe intermediate state.
      final completer = Completer<String?>();
      final controller = BatchUploadController<String>(
        uploader: (a) => completer.future,
      );
      final seen = <UploadItemStatus>[];
      controller.addListener(() {
        if (controller.items.isNotEmpty)
          seen.add(controller.items.first.status);
      });

      // Act
      final future = controller.addAndUpload([_asset('a')]);
      // 同步前缀已把该项推进到 uploading（await uploader 前）。
      expect(controller.items.first.isUploading, isTrue);
      completer.complete('url_a');
      await future;

      // Assert
      expect(controller.items.first.isDone, isTrue);
      expect(
        seen,
        containsAllInOrder([
          UploadItemStatus.pending,
          UploadItemStatus.uploading,
        ]),
      );
      expect(seen.last, UploadItemStatus.done);
    });

    test('addCompleted appends a done, non-retryable item', () {
      final controller = BatchUploadController<String>(
        uploader: (a) async => null,
      );

      controller.addCompleted('camera_url');

      expect(controller.items.single.isDone, isTrue);
      expect(controller.items.single.canRetry, isFalse);
      expect(controller.results, ['camera_url']);
    });

    test('removeAt drops the item from results', () async {
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'url_${a.id}',
      );
      await controller.addAndUpload([_asset('a'), _asset('b')]);

      controller.removeAt(0);

      expect(controller.results, ['url_b']);
    });

    test(
      'removeAt during in-flight upload does not misroute other items',
      () async {
        // Arrange — gate each upload so a/b/c stay in-flight concurrently.
        final gates = {
          'a': Completer<String?>(),
          'b': Completer<String?>(),
          'c': Completer<String?>(),
        };
        final controller = BatchUploadController<String>(
          uploader: (a) => gates[a.id]!.future,
          concurrency: 9, // 全并行，对齐朋友圈发布页（9）
        );

        // Act — 启动上传（不 await，阻塞在 gate），在 a/b/c 均 uploading 时删首项。
        final future = controller.addAndUpload([
          _asset('a'),
          _asset('b'),
          _asset('c'),
        ]);
        expect(controller.items.every((i) => i.isUploading), isTrue);
        controller.removeAt(0); // 删 'a' → 列表前移为 [b, c]
        gates['b']!.complete('url_b');
        gates['c']!.complete('url_c');
        gates['a']!.complete('url_a'); // 被删项最后 resolve
        await future;

        // Assert — b/c 结果落到正确项，无串位/丢失；被删项结果不出现。
        // 旧「按下标回写」实现在此会串位成 ['url_b'] 且 b 卡 uploading。
        expect(controller.items.length, 2);
        expect(controller.items[0].result, 'url_b');
        expect(controller.items[1].result, 'url_c');
        expect(controller.results, ['url_b', 'url_c']);
      },
    );
  });
}
