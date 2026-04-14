import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/file/group_file_page.dart';
import 'package:imboy/service/group_file_service.dart';
import 'package:imboy/store/api/group_file_api.dart';

class _UploadCall {
  const _UploadCall({
    required this.groupId,
    required this.fileName,
    required this.fileBytes,
    required this.fileType,
  });

  final String groupId;
  final String fileName;
  final List<int> fileBytes;
  final String? fileType;
}

class _FakeGroupFileService extends GroupFileService {
  _FakeGroupFileService({
    required this.files,
    required this.categoryStats,
    required this.searchResult,
    this.uploadResult,
  }) : super.withApi(GroupFileApi());

  final List<Map<String, dynamic>> files;
  final List<Map<String, dynamic>> categoryStats;
  final List<Map<String, dynamic>> searchResult;
  final Map<String, dynamic>? uploadResult;

  final List<String?> getFilesCategoryCalls = [];
  final List<String> searchKeywordCalls = [];
  final List<_UploadCall> uploadCalls = [];
  int getFilesCallCount = 0;
  int getCategoryStatsCallCount = 0;

  @override
  Future<Map<String, dynamic>> getFiles({
    required String groupId,
    int page = 1,
    int size = 20,
    String? category,
  }) async {
    getFilesCallCount++;
    getFilesCategoryCalls.add(category);
    return {'list': files, 'total': files.length, 'page': page, 'size': size};
  }

  @override
  Future<List<Map<String, dynamic>>> getCategoryStats({
    required String groupId,
  }) async {
    getCategoryStatsCallCount++;
    return categoryStats;
  }

  @override
  Future<Map<String, dynamic>> searchFiles({
    required String groupId,
    required String keyword,
    int page = 1,
    int size = 20,
  }) async {
    searchKeywordCalls.add(keyword);
    return {
      'list': searchResult,
      'total': searchResult.length,
      'page': page,
      'size': size,
    };
  }

  @override
  Future<Map<String, dynamic>?> uploadFile({
    required String groupId,
    required String fileName,
    required List<int> fileBytes,
    String? fileType,
  }) async {
    uploadCalls.add(
      _UploadCall(
        groupId: groupId,
        fileName: fileName,
        fileBytes: fileBytes,
        fileType: fileType,
      ),
    );
    return uploadResult;
  }
}

class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker({required this.pickResult});

  FilePickerResult? pickResult;
  int pickFilesCallCount = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async {
    pickFilesCallCount++;
    return pickResult;
  }
}

Widget _buildTestApp() {
  return const ProviderScope(
    child: MaterialApp(home: GroupFilePage(groupId: 'g1')),
  );
}

FilePickerPlatform? _originalFilePicker;
bool _hasOriginalFilePicker = false;

FilePickerResult _singlePickResult({
  required String fileName,
  required List<int> bytes,
}) {
  return FilePickerResult([
    PlatformFile(
      name: fileName,
      size: bytes.length,
      bytes: Uint8List.fromList(bytes),
    ),
  ]);
}

FilePickerResult _singlePickResultWithoutBytes({required String fileName}) {
  return FilePickerResult([PlatformFile(name: fileName, size: 0, bytes: null)]);
}

void main() {
  setUpAll(() {
    try {
      _originalFilePicker = FilePickerPlatform.instance;
      _hasOriginalFilePicker = true;
    } catch (_) {
      _hasOriginalFilePicker = false;
    }
  });

  tearDownAll(() {
    if (_hasOriginalFilePicker && _originalFilePicker != null) {
      FilePickerPlatform.instance = _originalFilePicker!;
    }
  });

  tearDown(() {
    GroupFileService.instanceForTest = null;
    GroupFilePage.openWebPreviewForTest = null;
    GroupFilePage.openMediaPreviewForTest = null;
    GroupFilePage.openExternalForTest = null;
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

    await tester.tap(find.widgetWithText(FilterChip, '图片 (1)'));
    await tester.pumpAndSettle();

    expect(find.text('文档A'), findsNothing);
    expect(find.text('图片B'), findsOneWidget);
    expect(fakeService.getFilesCategoryCalls.contains('image'), isTrue);
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

    await tester.enterText(find.byType(TextField), '预算');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_forward));
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

  testWidgets('tap image file opens in-app preview sheet', (tester) async {
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

    expect(find.byTooltip('关闭预览'), findsOneWidget);
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

    expect(capturedUrl, 'https://example.com/doc.pdf');
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
    expect(fallbackUrl, 'https://example.com/fallback-doc.pdf');
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

    expect(capturedUrl, 'https://example.com/demo.mp4');
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

    expect(capturedUrl, 'https://example.com/podcast.mp3');
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
    expect(fallbackUrl, 'https://example.com/fallback-video.mp4');
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
      find.widgetWithIcon(IconButton, Icons.upload_file_outlined),
    );
    await tester.pumpAndSettle();

    expect(fakePicker.pickFilesCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(fakeService.uploadCalls.single.groupId, 'g1');
    expect(fakeService.uploadCalls.single.fileName, 'upload.txt');
    expect(fakeService.uploadCalls.single.fileBytes, [1, 2, 3]);
    expect(fakeService.uploadCalls.single.fileType, 'text/plain');
    expect(find.text('文件上传成功'), findsOneWidget);
    expect(fakeService.getFilesCallCount, 2);
    expect(fakeService.getCategoryStatsCallCount, 2);
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
      find.widgetWithIcon(IconButton, Icons.upload_file_outlined),
    );
    await tester.pumpAndSettle();

    expect(fakePicker.pickFilesCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(find.text('文件上传失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getFilesCallCount, 1);
    expect(fakeService.getCategoryStatsCallCount, 1);
  });

  testWidgets('upload with empty bytes shows read failed snackbar', (
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
      find.widgetWithIcon(IconButton, Icons.upload_file_outlined),
    );
    await tester.pumpAndSettle();

    expect(fakePicker.pickFilesCallCount, 1);
    expect(fakeService.uploadCalls, isEmpty);
    expect(find.text('文件读取失败，请重试'), findsOneWidget);
  });
}
