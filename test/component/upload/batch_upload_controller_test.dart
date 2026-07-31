import 'dart:async';
import 'dart:io';

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
        if (controller.items.isNotEmpty) {
          seen.add(controller.items.first.status);
        }
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

    test('addFileAndUpload success: item done with local file kept', () async {
      final controller = BatchUploadController<String>(
        uploader: (a) async => null,
        fileUploader: (file, isVideo) async => 'file_${file.path}_$isVideo',
      );

      await controller.addFileAndUpload(File('p.jpg'));

      final item = controller.items.single;
      expect(item.isDone, isTrue);
      expect(item.file?.path, 'p.jpg');
      expect(controller.results, ['file_p.jpg_false']);
    });

    test('addFileAndUpload passes isVideo through to fileUploader', () async {
      final controller = BatchUploadController<String>(
        uploader: (a) async => null,
        fileUploader: (file, isVideo) async => isVideo ? 'video' : 'image',
      );

      await controller.addFileAndUpload(File('v.mp4'), isVideo: true);

      expect(controller.items.single.isVideoFile, isTrue);
      expect(controller.results, ['video']);
    });

    test(
      'failed file item is retryable and retry re-invokes fileUploader',
      () async {
        var fail = true;
        final controller = BatchUploadController<String>(
          uploader: (a) async => null,
          fileUploader: (file, isVideo) async => fail ? null : 'ok',
        );
        await controller.addFileAndUpload(File('p.jpg'));
        expect(controller.items.single.isFailed, isTrue);
        expect(controller.items.single.canRetry, isTrue);

        fail = false;
        await controller.retry(0);

        expect(controller.items.single.isDone, isTrue);
        expect(controller.results, ['ok']);
      },
    );

    test(
      'retryFailed covers failed file items alongside asset items',
      () async {
        var fail = true;
        final controller = BatchUploadController<String>(
          uploader: (a) async => fail ? null : 'url_${a.id}',
          fileUploader: (file, isVideo) async => fail ? null : 'file_ok',
        );
        await controller.addAndUpload([_asset('a')]);
        await controller.addFileAndUpload(File('p.jpg'));
        expect(controller.items.where((i) => i.isFailed).length, 2);

        fail = false;
        await controller.retryFailed();

        expect(controller.hasFailed, isFalse);
        expect(controller.results, ['url_a', 'file_ok']);
      },
    );

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

  // 草稿恢复用：朋友圈发布失败时把已传成功的 URL 存进草稿，重进页面必须能
  // 把这些图恢复回来。此前只回填文字，图片全丢，用户得重选重传一遍。
  group('BatchUploadController.adoptUploaded（草稿恢复）', () {
    test('注入的项直接是 done 态，并按顺序进 results', () {
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'never_called',
      );

      controller.adoptUploaded(['url_1', 'url_2']);

      expect(controller.length, 2);
      expect(controller.items.every((i) => i.isDone), isTrue);
      expect(controller.results, ['url_1', 'url_2']);
      expect(controller.isBusy, isFalse);
      expect(controller.hasFailed, isFalse);
    });

    test('注入项没有本地源，因此不可重试（它们本来就已在服务端）', () {
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'never_called',
      );

      controller.adoptUploaded(['url_1']);

      final item = controller.items.single;
      expect(item.asset, isNull);
      expect(item.file, isNull);
      expect(item.canRetry, isFalse, reason: '已完成项没有可重传的本地源，不该出现重试入口');
    });

    test('空列表是安全的 no-op，不通知监听者', () {
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'never_called',
      );
      var notified = 0;
      controller.addListener(() => notified++);

      controller.adoptUploaded([]);

      expect(controller.length, 0);
      expect(notified, 0);
    });

    test('注入后再追加上传，id 不冲突且顺序稳定', () async {
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'url_${a.id}',
        concurrency: 2,
      );

      controller.adoptUploaded(['draft_1']);
      await controller.addAndUpload([_asset('new')]);

      expect(controller.results, ['draft_1', 'url_new']);
      // id 稳定且互不相同——回写按 id 定位，冲突会导致结果串位
      final ids = controller.items.map((i) => i.id).toSet();
      expect(ids.length, 2);
    });

    test('注入项可被 removeAt 删除（用户恢复草稿后想删掉某张）', () {
      final controller = BatchUploadController<String>(
        uploader: (a) async => 'never_called',
      );

      controller.adoptUploaded(['url_1', 'url_2', 'url_3']);
      controller.removeAt(1);

      expect(controller.results, ['url_1', 'url_3']);
    });
  });
}
