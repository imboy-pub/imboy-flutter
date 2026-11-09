part of 'group_file_page_test.dart';

class _UploadCall {
  const _UploadCall({
    required this.groupId,
    required this.fileName,
    required this.mime,
    required this.clientUploadId,
    required this.filePath,
    required this.fileBytes,
  });

  final String groupId;
  final String fileName;
  final String mime;
  final String clientUploadId;
  final String filePath;
  final List<int> fileBytes;
}

class _FakeGroupFileService extends GroupFileService {
  _FakeGroupFileService({
    required this.files,
    required this.categoryStats,
    required this.searchResult,
    this.uploadResult,
    this.getFilesFailures = 0,
  }) : super.withApi(GroupFileApi());

  final List<Map<String, dynamic>> files;
  final List<Map<String, dynamic>> categoryStats;
  final List<Map<String, dynamic>> searchResult;
  Map<String, dynamic>? uploadResult;

  /// 前 N 次 getFiles 抛异常，用于验证失败态与重试（service 已改为 rethrow）。
  final int getFilesFailures;

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
    if (getFilesCallCount <= getFilesFailures) {
      throw Exception('mock network down');
    }
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
  Future<Map<String, dynamic>?> uploadFileDirect({
    required String groupId,
    required io.File file,
    required String fileName,
    required String mime,
    String? clientUploadId,
  }) async {
    uploadCalls.add(
      _UploadCall(
        groupId: groupId,
        fileName: fileName,
        mime: mime,
        clientUploadId: clientUploadId ?? '',
        filePath: file.path,
        fileBytes: file.existsSync() ? file.readAsBytesSync() : const <int>[],
      ),
    );
    return uploadResult;
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

Widget _buildTestApp({String groupId = 'g1'}) {
  // 群文件页用 AppLoading.showToast 反馈；未挂 builder 时 EasyLoading 会断言。
  return ProviderScope(
    child: TranslationProvider(
      child: MaterialApp(
        home: GroupFilePage(groupId: groupId),
        builder: AppLoading.init(),
      ),
    ),
  );
}

FilePickerPlatform? _originalFilePicker;
bool _hasOriginalFilePicker = false;

/// 测试临时目录（direct 直传需要磁盘上的真实文件）。
late io.Directory _pickTmp;
final List<String> _pickPaths = <String>[];

List<PlatformFile> _singlePickResult({
  required String fileName,
  required List<int> bytes,
}) {
  final io.File f = io.File('${_pickTmp.path}/$fileName-${_pickPaths.length}')
    ..writeAsBytesSync(bytes);
  _pickPaths.add(f.path);
  return [_FakePickedFile(name: fileName, realPath: f.path, bytes: bytes)];
}

List<PlatformFile> _singlePickResultWithoutBytes({required String fileName}) {
  // 模拟选件无本地路径（如 Web blob）：页面应按读取失败处理。
  return [_FakePickedFile(name: fileName)];
}
