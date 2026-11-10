import 'dart:typed_data';
import 'dart:io' as io;
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/http/http_exceptions.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
import 'package:imboy/service/group_file_service.dart';
import 'package:imboy/service/asset_url_resolver.dart';
import 'package:imboy/store/api/group_file_api.dart';

part 'group_file_controlled_open_checks.dart';
part 'group_file_load_race_checks.dart';

part 'group_file_page_fixtures.dart';

void main() {
  setUpAll(() {
    try {
      _originalFilePicker = FilePickerPlatform.instance;
      _hasOriginalFilePicker = true;
    } catch (_) {
      _hasOriginalFilePicker = false;
    }
    _pickTmp = io.Directory.systemTemp.createTempSync('gf-page-test');
  });

  tearDownAll(() {
    if (_hasOriginalFilePicker && _originalFilePicker != null) {
      FilePickerPlatform.instance = _originalFilePicker!;
    }
    if (_pickTmp.existsSync()) _pickTmp.deleteSync(recursive: true);
  });

  tearDown(() {
    AssetUrlResolver.instance.clear();
    AssetUrlResolver.instance.fetcherOverride = null;
    GroupFileService.instanceForTest = null;
    GroupFilePage.openWebPreviewForTest = null;
    GroupFilePage.openMediaPreviewForTest = null;
    GroupFilePage.openExternalForTest = null;
  });

  groupFileControlledOpenTests();
  groupFileLoadRaceTests();

  testWidgets('large category labels remain visible and announce selection', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    GroupFileService.instanceForTest = _FakeGroupFileService(
      files: const [
        {'file_id': 'f1', 'file_name': '图片B', 'file_category': 'image'},
      ],
      categoryStats: const [
        {'category': 'document', 'count': 1},
        {'category': 'image', 'count': 1},
      ],
      searchResult: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: TranslationProvider(
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(2),
              ),
              child: AppLoading.init()(context, child),
            ),
            home: const GroupFilePage(groupId: 'g1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final filters = find.byWidgetPredicate(
      (widget) => widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    expect(tester.getSize(filters).height, greaterThan(44));
    final label = '${t.chat.groupFileCategoryImage} (1)';
    await tester.ensureVisible(find.text(label));
    expect(tester.getSemantics(find.text(label)).getSemanticsData()
        .hasFlag(SemanticsFlag.isSelected), isFalse);
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
    final selected = tester.getSemantics(find.text(label)).getSemanticsData();
    expect(selected.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(selected.hasFlag(SemanticsFlag.isSelected), isTrue);
    expect(find.text('图片B'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category filter narrows list and forwards category', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {'file_id': 'f1', 'file_name': '文档A', 'file_category': 'document'},
        {'file_id': 'f2', 'file_name': '图片B', 'file_category': 'image'},
      ],
      categoryStats: [
        {'category': 'document', 'count': 1, 'total_size': 10},
        {'category': 'image', 'count': 1, 'total_size': 20},
      ],
      searchResult: const [],
    );
    GroupFileService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('文档A'), findsOneWidget);
    expect(find.text('图片B'), findsOneWidget);

    await tester.tap(find.text('图片 (1)'));
    await tester.pumpAndSettle();

    expect(find.text('文档A'), findsNothing);
    expect(find.text('图片B'), findsOneWidget);
    expect(fakeService.getFilesCategoryCalls.contains('image'), isTrue);
  });

  testWidgets('load failure renders retryable error view, not empty state', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {'file_id': 'f1', 'file_name': '会议纪要', 'file_category': 'document'},
      ],
      categoryStats: const [],
      searchResult: const [],
      getFilesFailures: 1, // 首次加载失败，重试成功
    );
    GroupFileService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    // 失败态：不能冒充"暂无群文件"空态，且必须给出重试入口
    expect(find.text(t.common.loadError), findsOneWidget);
    expect(find.text(t.chat.groupFileEmpty), findsNothing);
    expect(find.text(t.common.buttonRetry), findsOneWidget);

    // 点重试真的重新拉取并渲染出数据
    await tester.tap(find.text(t.common.buttonRetry));
    await tester.pumpAndSettle();

    expect(fakeService.getFilesCallCount, 2);
    expect(find.text('会议纪要'), findsOneWidget);
    expect(find.text(t.common.loadError), findsNothing);
  });

  testWidgets('search uses keyword and renders search result', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {'file_id': 'f1', 'file_name': '会议纪要', 'file_category': 'document'},
      ],
      categoryStats: const [],
      searchResult: [
        {'file_id': 'f2', 'file_name': '预算表.xlsx', 'file_category': 'document'},
      ],
    );
    GroupFileService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(CupertinoSearchTextField), '预算');
    // 页面在 onSubmitted 里触发搜索（CupertinoSearchTextField 无提交按钮）
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(fakeService.searchKeywordCalls, ['预算']);
    expect(find.text('预算表.xlsx'), findsOneWidget);
    expect(find.text('会议纪要'), findsNothing);
  });

  testWidgets('tap file with empty url shows snackbar', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {'file_id': 'f1', 'file_name': '无链接文件', 'file_category': 'document'},
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    GroupFileService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('无链接文件'));
    await tester.pump();

    expect(find.text('文件地址缺失，无法打开'), findsOneWidget);
  });

  testWidgets('tap file with invalid url shows snackbar', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '无效链接文件',
          'file_category': 'document',
          'file_url': 'http://[',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    GroupFileService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('无效链接文件'));
    await tester.pump();

    expect(find.text('文件地址无效'), findsOneWidget);
  });

  testWidgets('tap image file opens in-app full-screen preview', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '示例图片.jpg',
          'file_category': 'image',
          'file_url': 'https://example.com/a.jpg',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    GroupFileService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('示例图片.jpg'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('关闭'), findsOneWidget);
    expect(find.text('无法打开文件链接'), findsNothing);
  });

  testWidgets('tap document file opens in-app web preview', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '需求文档.pdf',
          'file_category': 'document',
          'file_url': 'https://example.com/doc.pdf',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    String? capturedUrl;
    String? capturedTitle;
    GroupFileService.instanceForTest = fakeService;
    GroupFilePage.openWebPreviewForTest = (context, url, title) async {
      capturedUrl = url;
      capturedTitle = title;
    };

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('需求文档.pdf'));
    await tester.pumpAndSettle();

    final authorized = Uri.parse(capturedUrl!);
    expect(authorized.origin, 'https://example.com');
    expect(authorized.path, '/doc.pdf');
    expect(authorized.queryParameters.keys, containsAll(['s', 'a', 'v']));
    expect(capturedTitle, '需求文档.pdf');
    expect(find.text('无法打开文件链接'), findsNothing);
  });

  testWidgets('web preview failure falls back to external open', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '预览失败文档.pdf',
          'file_category': 'document',
          'file_url': 'https://example.com/fallback-doc.pdf',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    String? fallbackUrl;
    int fallbackCalls = 0;
    GroupFileService.instanceForTest = fakeService;
    GroupFilePage.openWebPreviewForTest = (context, url, title) async {
      throw StateError('mock webview preview failed');
    };
    GroupFilePage.openExternalForTest = (context, url) async {
      fallbackCalls++;
      fallbackUrl = url;
      return true;
    };

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('预览失败文档.pdf'));
    await tester.pumpAndSettle();

    expect(fallbackCalls, 1);
    final authorized = Uri.parse(fallbackUrl!);
    expect(authorized.origin, 'https://example.com');
    expect(authorized.path, '/fallback-doc.pdf');
    expect(authorized.queryParameters.keys, containsAll(['s', 'a', 'v']));
    expect(find.text('无法打开文件链接'), findsNothing);
  });

  testWidgets('web preview fallback failure shows snackbar', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '回退失败文档.pdf',
          'file_category': 'document',
          'file_url': 'https://example.com/fallback-fail-doc.pdf',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    GroupFileService.instanceForTest = fakeService;
    GroupFilePage.openWebPreviewForTest = (context, url, title) async {
      throw StateError('mock webview preview failed');
    };
    GroupFilePage.openExternalForTest = (context, url) async => false;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('回退失败文档.pdf'));
    await tester.pumpAndSettle();

    expect(find.text('无法打开文件链接'), findsOneWidget);
  });

  testWidgets('tap video file opens in-app media preview', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '演示视频.mp4',
          'file_category': 'video',
          'file_url': 'https://example.com/demo.mp4',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    String? capturedUrl;
    String? capturedTitle;
    String? capturedKind;
    GroupFileService.instanceForTest = fakeService;
    GroupFilePage.openMediaPreviewForTest =
        (context, url, title, previewKind) async {
          capturedUrl = url;
          capturedTitle = title;
          capturedKind = previewKind;
        };

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('演示视频.mp4'));
    await tester.pumpAndSettle();

    final authorized = Uri.parse(capturedUrl!);
    expect(authorized.origin, 'https://example.com');
    expect(authorized.path, '/demo.mp4');
    expect(authorized.queryParameters.keys, containsAll(['s', 'a', 'v']));
    expect(capturedTitle, '演示视频.mp4');
    expect(capturedKind, 'video');
    expect(find.text('无法打开文件链接'), findsNothing);
  });

  testWidgets('tap audio file opens in-app media preview', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '语音播客.mp3',
          'file_category': 'audio',
          'file_url': 'https://example.com/podcast.mp3',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    String? capturedUrl;
    String? capturedTitle;
    String? capturedKind;
    GroupFileService.instanceForTest = fakeService;
    GroupFilePage.openMediaPreviewForTest =
        (context, url, title, previewKind) async {
          capturedUrl = url;
          capturedTitle = title;
          capturedKind = previewKind;
        };

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('语音播客.mp3'));
    await tester.pumpAndSettle();

    final authorized = Uri.parse(capturedUrl!);
    expect(authorized.origin, 'https://example.com');
    expect(authorized.path, '/podcast.mp3');
    expect(authorized.queryParameters.keys, containsAll(['s', 'a', 'v']));
    expect(capturedTitle, '语音播客.mp3');
    expect(capturedKind, 'audio');
    expect(find.text('无法打开文件链接'), findsNothing);
  });

  testWidgets('media preview failure falls back to external open', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '预览失败视频.mp4',
          'file_category': 'video',
          'file_url': 'https://example.com/fallback-video.mp4',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    String? fallbackUrl;
    int fallbackCalls = 0;
    GroupFileService.instanceForTest = fakeService;
    GroupFilePage.openMediaPreviewForTest =
        (context, url, title, previewKind) async {
          throw StateError('mock media preview failed');
        };
    GroupFilePage.openExternalForTest = (context, url) async {
      fallbackCalls++;
      fallbackUrl = url;
      return true;
    };

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('预览失败视频.mp4'));
    await tester.pumpAndSettle();

    expect(fallbackCalls, 1);
    final authorized = Uri.parse(fallbackUrl!);
    expect(authorized.origin, 'https://example.com');
    expect(authorized.path, '/fallback-video.mp4');
    expect(authorized.queryParameters.keys, containsAll(['s', 'a', 'v']));
    expect(find.text('无法打开文件链接'), findsNothing);
  });

  testWidgets('media preview fallback failure shows snackbar', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {
          'file_id': 'f1',
          'file_name': '回退失败视频.mp4',
          'file_category': 'video',
          'file_url': 'https://example.com/fallback-fail-video.mp4',
        },
      ],
      categoryStats: const [],
      searchResult: const [],
    );
    GroupFileService.instanceForTest = fakeService;
    GroupFilePage.openMediaPreviewForTest =
        (context, url, title, previewKind) async {
          throw StateError('mock media preview failed');
        };
    GroupFilePage.openExternalForTest = (context, url) async => false;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('回退失败视频.mp4'));
    await tester.pumpAndSettle();

    expect(find.text('无法打开文件链接'), findsOneWidget);
  });

  testWidgets('upload success triggers snackbar and refresh', (tester) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {'file_id': 'f1', 'file_name': '会议纪要', 'file_category': 'document'},
      ],
      categoryStats: const [
        {'category': 'document', 'count': 1, 'total_size': 10},
      ],
      searchResult: const [],
      uploadResult: {'file_id': 'f-new', 'file_name': 'upload.txt'},
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _singlePickResult(fileName: 'upload.txt', bytes: [1, 2, 3]),
    );
    GroupFileService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getFilesCallCount, 1);
    expect(fakeService.getCategoryStatsCallCount, 1);

    await tester.tap(
      find.widgetWithIcon(IconButton, CupertinoIcons.arrow_up_doc),
    );
    await tester.pumpAndSettle();

    expect(fakePicker.pickCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(fakeService.uploadCalls.single.groupId, 'g1');
    expect(fakeService.uploadCalls.single.fileName, 'upload.txt');
    expect(fakeService.uploadCalls.single.fileBytes, [1, 2, 3]);
    expect(fakeService.uploadCalls.single.mime, 'text/plain');
    // direct 会话幂等键必须随选件生成（kill 后重试恢复同一会话）
    expect(
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$')
          .hasMatch(fakeService.uploadCalls.single.clientUploadId),
      isTrue,
    );
    expect(find.text('文件上传成功'), findsOneWidget);
    expect(fakeService.getFilesCallCount, 2);
    expect(fakeService.getCategoryStatsCallCount, 2);
    // 成功后不残留重试条
    expect(find.textContaining('重试上传'), findsNothing);
  });

  testWidgets('upload failure shows failed snackbar without refresh', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {'file_id': 'f1', 'file_name': '会议纪要', 'file_category': 'document'},
      ],
      categoryStats: const [
        {'category': 'document', 'count': 1, 'total_size': 10},
      ],
      searchResult: const [],
      uploadResult: null,
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _singlePickResult(fileName: 'upload.txt', bytes: [9, 8, 7]),
    );
    GroupFileService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getFilesCallCount, 1);
    expect(fakeService.getCategoryStatsCallCount, 1);

    await tester.tap(
      find.widgetWithIcon(IconButton, CupertinoIcons.arrow_up_doc),
    );
    await tester.pumpAndSettle();

    expect(fakePicker.pickCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(find.text('文件上传失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getFilesCallCount, 1);
    expect(fakeService.getCategoryStatsCallCount, 1);
    // 失败保留本地重试条（同 clientUploadId 幂等恢复 direct 会话）
    expect(find.text('重试上传「upload.txt」'), findsOneWidget);
  });

  testWidgets('upload failure retry reuses same clientUploadId', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: const [],
      categoryStats: const [],
      searchResult: const [],
      uploadResult: null,
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _singlePickResult(fileName: 'retry.txt', bytes: [5]),
    );
    GroupFileService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithIcon(IconButton, CupertinoIcons.arrow_up_doc),
    );
    await tester.pumpAndSettle();
    expect(fakeService.uploadCalls.length, 1);

    // 点重试：不重新选件，同 clientUploadId 再走一次 direct
    fakeService.uploadResult = {'file_id': 'f-retry'};
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(fakePicker.pickCallCount, 1, reason: '重试不得重新拉起选件');
    expect(fakeService.uploadCalls.length, 2);
    expect(
      fakeService.uploadCalls[0].clientUploadId,
      fakeService.uploadCalls[1].clientUploadId,
    );
    expect(find.text('文件上传成功'), findsOneWidget);
    expect(find.textContaining('重试上传'), findsNothing);
  });

  testWidgets('upload with no local path shows read failed snackbar', (
    tester,
  ) async {
    final fakeService = _FakeGroupFileService(
      files: [
        {'file_id': 'f1', 'file_name': '会议纪要', 'file_category': 'document'},
      ],
      categoryStats: const [
        {'category': 'document', 'count': 1, 'total_size': 10},
      ],
      searchResult: const [],
      uploadResult: {'file_id': 'should-not-happen'},
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _singlePickResultWithoutBytes(fileName: 'empty.txt'),
    );
    GroupFileService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithIcon(IconButton, CupertinoIcons.arrow_up_doc),
    );
    await tester.pumpAndSettle();

    expect(fakePicker.pickCallCount, 1);
    expect(fakeService.uploadCalls, isEmpty);
    expect(find.text('文件读取失败，请重试'), findsOneWidget);
  });
}
