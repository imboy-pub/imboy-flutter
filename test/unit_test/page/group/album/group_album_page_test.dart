import 'dart:typed_data';
import 'dart:io' as io;

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker_platform_interface/file_picker_platform_interface.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/page/group/album/group_album_page.dart';
import 'package:imboy/service/group_album_service.dart';
import 'package:imboy/store/api/group_album_api.dart';

class _CreateCall {
  const _CreateCall({required this.groupId, required this.albumName});

  final String groupId;
  final String albumName;
}

class _UploadCall {
  const _UploadCall({
    required this.groupId,
    required this.albumId,
    required this.photoNames,
    required this.clientUploadIds,
  });

  final String groupId;
  final String albumId;
  final List<String> photoNames;
  final List<String> clientUploadIds;
}

class _RenameCall {
  const _RenameCall({required this.albumId, required this.albumName});

  final String albumId;
  final String albumName;
}

class _FakeGroupAlbumService extends GroupAlbumService {
  _FakeGroupAlbumService({
    required this.albums,
    this.createAlbumResult,
    this.uploadPhotoResult,
    this.uploadFailItemIndices = const <int>{},
    this.renameAlbumResult = true,
    this.throwOnGetAlbums = false,
  }) : super.withApi(GroupAlbumApi());

  final List<Map<String, dynamic>> albums;
  final Map<String, dynamic>? createAlbumResult;
  final Map<String, dynamic>? uploadPhotoResult;

  /// 按 items 下标强制失败的项（模拟 direct/bind_batch 部分失败）。
  Set<int> uploadFailItemIndices;
  final bool renameAlbumResult;

  /// true 时 getAlbums 抛出，模拟网络失败（service 不再 fail-open）。
  bool throwOnGetAlbums;

  int getAlbumsCallCount = 0;
  final List<_CreateCall> createCalls = [];
  final List<_UploadCall> uploadCalls = [];
  final List<_RenameCall> renameCalls = [];

  @override
  Future<Map<String, dynamic>> getAlbums({
    required String groupId,
    int page = 1,
    int size = 20,
  }) async {
    getAlbumsCallCount++;
    if (throwOnGetAlbums) throw Exception('network error');
    return {'list': albums, 'total': albums.length, 'page': page, 'size': size};
  }

  @override
  Future<Map<String, dynamic>?> createAlbum({
    required String groupId,
    required String albumName,
    coverPhotoId,
  }) async {
    createCalls.add(_CreateCall(groupId: groupId, albumName: albumName));
    return createAlbumResult;
  }

  @override
  Future<List<GroupAlbumUploadOutcome>> uploadPhotosDirect({
    required String groupId,
    required String albumId,
    required List<GroupAlbumUploadItem> items,
  }) async {
    uploadCalls.add(
      _UploadCall(
        groupId: groupId,
        albumId: albumId,
        photoNames: [for (final i in items) i.photoName],
        clientUploadIds: [for (final i in items) i.clientUploadId],
      ),
    );
    return <GroupAlbumUploadOutcome>[
      for (int i = 0; i < items.length; i++)
        GroupAlbumUploadOutcome(
          item: items[i],
          ok: uploadPhotoResult != null && !uploadFailItemIndices.contains(i),
          reason: 'mock_failed',
          photo: uploadPhotoResult,
        ),
    ];
  }

  @override
  Future<bool> renameAlbum({
    required albumId,
    required String albumName,
  }) async {
    renameCalls.add(
      _RenameCall(albumId: albumId?.toString() ?? '', albumName: albumName),
    );
    return renameAlbumResult;
  }
}

class _FakeFilePicker extends FilePickerPlatform {
  _FakeFilePicker({required this.pickResult});

  List<PlatformFile>? pickResult;
  int pickCallCount = 0;

  @override
  Future<List<PlatformFile>> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
  }) async {
    pickCallCount++;
    return pickResult ?? const [];
  }

  @override
  Future<PlatformFile?> pickFile({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    dynamic Function(FilePickerStatus)? onFileLoading,
    int compressionQuality = 0,
    AndroidOptions androidOptions = const AndroidOptions(),
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
    DarwinOptions darwinOptions = const DarwinOptions(),
  }) async {
    pickCallCount++;
    final files = pickResult ?? const <PlatformFile>[];
    return files.isEmpty ? null : files.first;
  }
}

/// PlatformFile 是 abstract base class，测试只能 extends 模拟。
/// direct 直传按 path 读真实文件（页面不再 readAsBytes），fake 需指向
/// 真实临时文件。
final class _FakePickedFile extends PlatformFile {
  _FakePickedFile({required this.name, this.realPath, List<int>? bytes})
    : _bytes = bytes == null ? null : Uint8List.fromList(bytes);

  @override
  final String name;
  final String? realPath;
  final Uint8List? _bytes;

  @override
  Uri get uri => Uri.file(realPath ?? '/fake/$name');

  @override
  XFile get xFile => XFile.fromData(_bytes ?? Uint8List(0));

  @override
  Future<int> length() async => _bytes?.length ?? 0;

  @override
  int lengthSync() => _bytes?.length ?? 0;

  @override
  Future<Uint8List> readAsBytes() async => _bytes ?? Uint8List(0);

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes ?? Uint8List(0));
}

Widget _buildTestApp() {
  // 页面用 AppLoading.showToast 反馈成功/失败（不是 SnackBar），
  // 未挂 builder 时 EasyLoading 会断言 'overlayEntry != null'。
  // 走项目 facade AppLoading.init()，不直接 import flutter_easyloading
  // （边界门禁只允许 app_loading.dart 依赖该库）。
  return ProviderScope(
    child: MaterialApp(
      home: const GroupAlbumPage(groupId: 'g1'),
      builder: AppLoading.init(),
    ),
  );
}

FilePickerPlatform? _originalFilePicker;
bool _hasOriginalFilePicker = false;

/// 测试临时目录（direct 直传需要磁盘上的真实文件）。
late io.Directory _pickTmp;
int _pickSeq = 0;

List<PlatformFile> _pickResultOf(List<(String, List<int>)> files) {
  return <PlatformFile>[
    for (final (String name, List<int> bytes) in files)
      () {
        final io.File f = io.File('${_pickTmp.path}/$name-${_pickSeq++}')
          ..writeAsBytesSync(bytes);
        return _FakePickedFile(name: name, realPath: f.path, bytes: bytes);
      }(),
  ];
}

List<PlatformFile> _singlePickResult({
  required String fileName,
  required List<int> bytes,
}) {
  return _pickResultOf(<(String, List<int>)>[(fileName, bytes)]);
}

List<PlatformFile> _singlePickResultWithoutBytes({required String fileName}) {
  // 模拟选件无本地路径（如 Web blob）：页面应按读取失败处理。
  return [_FakePickedFile(name: fileName)];
}

void main() {
  setUpAll(() {
    try {
      _originalFilePicker = FilePickerPlatform.instance;
      _hasOriginalFilePicker = true;
    } catch (_) {
      _hasOriginalFilePicker = false;
    }
    _pickTmp = io.Directory.systemTemp.createTempSync('ga-page-test');
  });

  tearDownAll(() {
    if (_hasOriginalFilePicker && _originalFilePicker != null) {
      FilePickerPlatform.instance = _originalFilePicker!;
    }
    if (_pickTmp.existsSync()) _pickTmp.deleteSync(recursive: true);
  });

  tearDown(() async {
    GroupAlbumService.instanceForTest = null;
    // 取消 EasyLoading toast 的自动关闭计时器，否则 widget 树 dispose 后
    // 仍有 pending timer，测试框架会报错。
    await AppLoading.dismiss(animation: false);
  });

  testWidgets('create album success shows snackbar and refresh', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [],
      createAlbumResult: {'album_id': 'a-new'},
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getAlbumsCallCount, 1);

    await tester.tap(find.widgetWithIcon(IconButton, CupertinoIcons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      '研发资料',
    );
    final actionButtons = find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.byType(CupertinoDialogAction),
    );
    await tester.tap(actionButtons.last);
    // 不用 pumpAndSettle：AppLoading.showToast 会挂一个 2s 自动关闭计时器，
    // pumpAndSettle 会因该 pending timer 抛错。手动推进到 toast 可见即可，
    // 计时器由 tearDown 的 dismiss 清理。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeService.createCalls.length, 1);
    expect(fakeService.createCalls.single.groupId, 'g1');
    expect(fakeService.createCalls.single.albumName, '研发资料');
    expect(find.text('相册已创建'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 2);
  });

  testWidgets('create album failure shows failed snackbar', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [],
      createAlbumResult: null,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getAlbumsCallCount, 1);

    await tester.tap(find.widgetWithIcon(IconButton, CupertinoIcons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      '失败相册',
    );
    final actionButtons = find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.byType(CupertinoDialogAction),
    );
    await tester.tap(actionButtons.last);
    // 不用 pumpAndSettle：AppLoading.showToast 会挂一个 2s 自动关闭计时器，
    // pumpAndSettle 会因该 pending timer 抛错。手动推进到 toast 可见即可，
    // 计时器由 tearDown 的 dismiss 清理。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeService.createCalls.length, 1);
    expect(find.text('创建失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 1);
  });

  testWidgets('upload photo success uses album_id and refresh', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [
        {
          'album_id': 'a-real',
          'id': 'legacy-id',
          'album_name': '团队相册',
          'photo_count': 1,
        },
      ],
      uploadPhotoResult: {'photo_id': 'p-new'},
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _singlePickResult(fileName: 'cover.png', bytes: [1, 2, 3, 4]),
    );
    GroupAlbumService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getAlbumsCallCount, 1);

    await tester.tap(find.byTooltip('上传图片').first);
    await tester.pumpAndSettle();

    expect(fakePicker.pickCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(fakeService.uploadCalls.single.groupId, 'g1');
    expect(fakeService.uploadCalls.single.albumId, 'a-real');
    expect(fakeService.uploadCalls.single.photoNames, ['cover.png']);
    // 每项均有 direct 幂等键
    expect(
      fakeService.uploadCalls.single.clientUploadIds.single,
      matches(
        RegExp(
          '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\$',
        ),
      ),
    );
    expect(find.text('图片上传成功'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 2);
    expect(find.textContaining('重试上传'), findsNothing);
  });

  testWidgets('upload photo failure shows failed snackbar', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [
        {'album_id': 'a-real', 'album_name': '团队相册', 'photo_count': 1},
      ],
      uploadPhotoResult: null,
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _singlePickResult(fileName: 'cover.png', bytes: [9, 8, 7]),
    );
    GroupAlbumService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getAlbumsCallCount, 1);

    await tester.tap(find.byTooltip('上传图片').first);
    await tester.pumpAndSettle();

    expect(fakePicker.pickCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(find.text('图片上传失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 1);
    // 全部失败保留重试条（失败项有账，不整批回滚）
    expect(find.text('重试上传 1 张失败图片'), findsOneWidget);
  });

  testWidgets('partial failure keeps failed item for retry only', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [
        {'album_id': 'a-real', 'album_name': '团队相册', 'photo_count': 1},
      ],
      uploadPhotoResult: {'photo_id': 'p-ok'},
      uploadFailItemIndices: const <int>{1},
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _pickResultOf(<(String, List<int>)>[
        ('a.png', [1]),
        ('b.png', [2]),
      ]),
    );
    GroupAlbumService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('上传图片').first);
    await tester.pumpAndSettle();

    expect(fakeService.uploadCalls.single.photoNames, ['a.png', 'b.png']);
    expect(find.text('已上传1张，1张失败'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 2, reason: '部分成功也要刷新');
    expect(find.text('重试上传 1 张失败图片'), findsOneWidget);

    // 重试只带失败项（同 clientUploadId，不重传已成功项）
    fakeService.uploadFailItemIndices = const <int>{};
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(fakeService.uploadCalls.length, 2);
    expect(fakeService.uploadCalls.last.photoNames, ['b.png']);
    expect(
      fakeService.uploadCalls.last.clientUploadIds.single,
      fakeService.uploadCalls.first.clientUploadIds[1],
    );
    expect(find.text('图片上传成功'), findsOneWidget);
    expect(find.textContaining('重试上传'), findsNothing);
  });

  testWidgets('upload photo with no local path shows read failed snackbar', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [
        {'album_id': 'a-real', 'album_name': '团队相册', 'photo_count': 1},
      ],
      uploadPhotoResult: {'photo_id': 'should-not-happen'},
    );
    final fakePicker = _FakeFilePicker(
      pickResult: _singlePickResultWithoutBytes(fileName: 'broken.png'),
    );
    GroupAlbumService.instanceForTest = fakeService;
    FilePickerPlatform.instance = fakePicker;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('上传图片').first);
    await tester.pumpAndSettle();

    expect(fakePicker.pickCallCount, 1);
    expect(fakeService.uploadCalls, isEmpty);
    expect(find.text('图片读取失败，请重试'), findsOneWidget);
  });

  testWidgets('rename album success shows snackbar and refresh', (
    tester,
  ) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [
        {'album_id': 'a-real', 'album_name': '旧相册名', 'photo_count': 1},
      ],
      renameAlbumResult: true,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getAlbumsCallCount, 1);

    await tester.tap(find.byTooltip('重命名相册').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      '新相册名',
    );
    final actionButtons = find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.byType(CupertinoDialogAction),
    );
    await tester.tap(actionButtons.last);
    // 不用 pumpAndSettle：AppLoading.showToast 会挂一个 2s 自动关闭计时器，
    // pumpAndSettle 会因该 pending timer 抛错。手动推进到 toast 可见即可，
    // 计时器由 tearDown 的 dismiss 清理。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeService.renameCalls.length, 1);
    expect(fakeService.renameCalls.single.albumId, 'a-real');
    expect(fakeService.renameCalls.single.albumName, '新相册名');
    expect(find.text('相册名称已更新'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 2);
  });

  testWidgets('rename album failure shows failed snackbar', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [
        {'album_id': 'a-real', 'album_name': '旧相册名', 'photo_count': 1},
      ],
      renameAlbumResult: false,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getAlbumsCallCount, 1);

    await tester.tap(find.byTooltip('重命名相册').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(CupertinoAlertDialog),
        matching: find.byType(CupertinoTextField),
      ),
      '新相册名',
    );
    final actionButtons = find.descendant(
      of: find.byType(CupertinoAlertDialog),
      matching: find.byType(CupertinoDialogAction),
    );
    await tester.tap(actionButtons.last);
    // 不用 pumpAndSettle：AppLoading.showToast 会挂一个 2s 自动关闭计时器，
    // pumpAndSettle 会因该 pending timer 抛错。手动推进到 toast 可见即可，
    // 计时器由 tearDown 的 dismiss 清理。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(fakeService.renameCalls.length, 1);
    expect(find.text('更新失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 1);
  });

  // 失败态回归：service 改 rethrow 之前，getAlbums 吞异常返回空分页，
  // 页面只能渲染"暂无群相册"，下面两个用例必然失败。
  testWidgets('加载失败渲染失败态 + 重试，而不是"暂无群相册"', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      albums: const [],
      throwOnGetAlbums: true,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('加载失败，请重试'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('暂无群相册'), findsNothing);
  });

  testWidgets('点失败态重试真的重新拉取；成功后回到正常列表', (tester) async {
    final fakeService = _FakeGroupAlbumService(
      albums: [
        {'album_id': 'a1', 'album_name': '相册一'},
      ],
      throwOnGetAlbums: true,
    );
    GroupAlbumService.instanceForTest = fakeService;

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();
    expect(fakeService.getAlbumsCallCount, 1);

    fakeService.throwOnGetAlbums = false;
    await tester.tap(find.text('重试'));
    await tester.pumpAndSettle();

    expect(fakeService.getAlbumsCallCount, 2);
    expect(find.text('加载失败，请重试'), findsNothing);
    expect(find.text('相册一'), findsOneWidget);
  });
}
