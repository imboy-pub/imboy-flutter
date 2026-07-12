import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 单项上传状态机：pending → uploading → done / failed。
enum UploadItemStatus { pending, uploading, done, failed }

/// 单项批量上传状态：稳定 id + 状态 + 原始资源（供失败重试复用）+ 成功结果 payload。
///
/// [id] 稳定不变，由控制器自增分配，用于在列表增删（[BatchUploadController.removeAt]）
/// 后仍能把异步上传结果回写到正确的项，规避「按下标回写」的错位竞态。
///
/// 原始资源二选一：相册批量选中的项带 [asset]；相机即拍即传的项带 [file]
/// （[isVideoFile] 区分拍照/录像）。两者都保留在项上，失败可重传、UI 可渲染
/// 本地缩略图，不再有「无源不可重试」的孤儿项。
@immutable
class UploadItem<T> {
  const UploadItem({
    required this.id,
    this.asset,
    this.file,
    this.isVideoFile = false,
    this.status = UploadItemStatus.pending,
    this.result,
  });

  final int id;
  final AssetEntity? asset;
  final File? file;

  /// 仅 [file] 项有意义：true 表示录像文件（上传走视频管道，UI 无法直接
  /// Image.file 预览）。
  final bool isVideoFile;

  final UploadItemStatus status;
  final T? result;

  bool get isPending => status == UploadItemStatus.pending;
  bool get isUploading => status == UploadItemStatus.uploading;
  bool get isDone => status == UploadItemStatus.done;
  bool get isFailed => status == UploadItemStatus.failed;

  /// 带原始资源（AssetEntity 或 File）的失败项可重试。
  bool get canRetry => isFailed && (asset != null || file != null);

  UploadItem<T> _to(UploadItemStatus status, {T? result}) => UploadItem<T>(
    id: id,
    asset: asset,
    file: file,
    isVideoFile: isVideoFile,
    status: status,
    result: result,
  );
}

/// 上传函数：成功返回结果 payload，失败返回 null（含文件读取失败）。
typedef AssetUploader<T> = Future<T?> Function(AssetEntity asset);

/// File 项上传函数（相机即拍即传）：isVideo 区分拍照/录像管道。
typedef FileUploader<T> = Future<T?> Function(File file, bool isVideo);

/// 批量逐项上传控制器。
///
/// 每项独立状态流转，批内并行、批间串行限流（[concurrency]），任一项失败不影响
/// 其余成功项，且失败项可单独或整批重试。作为 [ChangeNotifier]，UI 监听后可逐项
/// 渲染占位/进度/重试角标，替代「全局 spinner + 整批失败」的弱反馈。
///
/// 回写按稳定 [UploadItem.id] 定位而非数组下标：上传进行中用户删除任意项（列表
/// 整体前移）也不会导致其余 in-flight 结果串位或丢失——被删项的回写因查不到 id
/// 而安全丢弃。
///
/// 朋友圈与频道两处批量上传复用同一控制器（DRY）。
class BatchUploadController<T> extends ChangeNotifier {
  BatchUploadController({
    required this.uploader,
    this.fileUploader,
    this.concurrency = 3,
  }) : assert(concurrency > 0);

  final AssetUploader<T> uploader;

  /// 仅使用 [addFileAndUpload]（相机路径）时必须提供。
  final FileUploader<T>? fileUploader;

  final int concurrency;

  final List<UploadItem<T>> _items = [];
  int _nextId = 0;

  List<UploadItem<T>> get items => List.unmodifiable(_items);
  int get length => _items.length;

  bool get isBusy => _items.any((i) => i.isUploading);
  bool get hasFailed => _items.any((i) => i.isFailed);

  /// 已成功项的结果 payload，按加入顺序返回。
  List<T> get results => [
    for (final i in _items)
      if (i.isDone && i.result != null) i.result as T,
  ];

  /// 追加一批资源并立即分批并行上传（保留 Future.wait 并行语义）。
  Future<void> addAndUpload(List<AssetEntity> assets) async {
    if (assets.isEmpty) return;
    final ids = <int>[];
    for (final a in assets) {
      final id = _nextId++;
      ids.add(id);
      _items.add(UploadItem<T>(id: id, asset: a));
    }
    notifyListeners();
    await _runBatches(ids);
  }

  /// 追加一个相机即拍的 File 项并立即上传：与相册项同样走逐项状态机，
  /// 上传中有本地缩略图、失败保留可重试，不再即拍即丢。
  Future<void> addFileAndUpload(File file, {bool isVideo = false}) async {
    assert(fileUploader != null, 'addFileAndUpload requires fileUploader');
    final id = _nextId++;
    _items.add(UploadItem<T>(id: id, file: file, isVideoFile: isVideo));
    notifyListeners();
    await _uploadById(id);
  }

  /// 移除指定项（用户手动删除网格缩略图）。上传进行中删除是安全的：其余项按 id
  /// 回写，被删项的 in-flight 结果查不到 id 后丢弃。
  void removeAt(int index) {
    if (index < 0 || index >= _items.length) return;
    _items.removeAt(index);
    notifyListeners();
  }

  /// 单独重试某一失败项（按当前显示下标定位其 id），成功后其余项不受影响。
  Future<void> retry(int index) async {
    if (index < 0 || index >= _items.length) return;
    final item = _items[index];
    if (!item.canRetry) return;
    await _uploadById(item.id);
  }

  /// 重试全部失败项（走同一分批限流管道）。
  Future<void> retryFailed() async {
    final ids = [
      for (final i in _items)
        if (i.canRetry) i.id,
    ];
    await _runBatches(ids);
  }

  Future<void> _runBatches(List<int> ids) async {
    for (var i = 0; i < ids.length; i += concurrency) {
      final batch = ids.skip(i).take(concurrency);
      await Future.wait(batch.map(_uploadById));
    }
  }

  Future<void> _uploadById(int id) async {
    final item = _itemById(id);
    if (item == null) return;
    final Future<T?> Function() run;
    if (item.asset != null) {
      run = () => uploader(item.asset!);
    } else if (item.file != null && fileUploader != null) {
      run = () => fileUploader!(item.file!, item.isVideoFile);
    } else {
      // 误用防线（release 下 assert 被剥离）：无可用上传管道的项显式置
      // failed，避免静默卡在 pending 转圈且不可重试。
      _setById(id, (item) => item._to(UploadItemStatus.failed));
      return;
    }
    _setById(id, (item) => item._to(UploadItemStatus.uploading));
    final result = await run();
    _setById(
      id,
      (item) => result == null
          ? item._to(UploadItemStatus.failed)
          : item._to(UploadItemStatus.done, result: result),
    );
  }

  UploadItem<T>? _itemById(int id) {
    final idx = _items.indexWhere((e) => e.id == id);
    return idx < 0 ? null : _items[idx];
  }

  /// 每次回写都按 id 重新定位当前下标；项已被移除则丢弃这次回写。
  void _setById(int id, UploadItem<T> Function(UploadItem<T>) update) {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _items[idx] = update(_items[idx]);
    notifyListeners();
  }
}
