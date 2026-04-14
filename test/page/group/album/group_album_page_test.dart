import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    required this.photoName,
    required this.photoBytes,
  });

  final String groupId;
  final String albumId;
  final String photoName;
  final List<int> photoBytes;
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
    this.renameAlbumResult = true,
  }) : super.withApi(GroupAlbumApi());

  final List<Map<String, dynamic>> albums;
  final Map<String, dynamic>? createAlbumResult;
  final Map<String, dynamic>? uploadPhotoResult;
  final bool renameAlbumResult;

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
  Future<Map<String, dynamic>?> uploadPhoto({
    required String groupId,
    required String albumId,
    required String photoName,
    required List<int> photoBytes,
  }) async {
    uploadCalls.add(
      _UploadCall(
        groupId: groupId,
        albumId: albumId,
        photoName: photoName,
        photoBytes: photoBytes,
      ),
    );
    return uploadPhotoResult;
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
    child: MaterialApp(home: GroupAlbumPage(groupId: 'g1')),
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
    GroupAlbumService.instanceForTest = null;
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

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '研发资料',
    );
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

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

    await tester.tap(find.widgetWithIcon(IconButton, Icons.add));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '失败相册',
    );
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

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

    expect(fakePicker.pickFilesCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(fakeService.uploadCalls.single.groupId, 'g1');
    expect(fakeService.uploadCalls.single.albumId, 'a-real');
    expect(fakeService.uploadCalls.single.photoName, 'cover.png');
    expect(fakeService.uploadCalls.single.photoBytes, [1, 2, 3, 4]);
    expect(find.text('图片上传成功'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 2);
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

    expect(fakePicker.pickFilesCallCount, 1);
    expect(fakeService.uploadCalls.length, 1);
    expect(find.text('图片上传失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 1);
  });

  testWidgets('upload photo with empty bytes shows read failed snackbar', (
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

    expect(fakePicker.pickFilesCallCount, 1);
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
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '新相册名',
    );
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

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
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      '新相册名',
    );
    final actionButtons = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextButton),
    );
    await tester.tap(actionButtons.last);
    await tester.pumpAndSettle();

    expect(fakeService.renameCalls.length, 1);
    expect(find.text('更新失败，请稍后重试'), findsOneWidget);
    expect(fakeService.getAlbumsCallCount, 1);
  });
}
