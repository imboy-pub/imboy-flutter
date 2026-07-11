import 'package:flutter/foundation.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 单项上传状态机：pending → uploading → done / failed。
enum UploadItemStatus { pending, uploading, done, failed }

/// 单项批量上传状态：稳定 id + 状态 + 原始资源（供失败重试复用）+ 成功结果 payload。
///
/// [id] 稳定不变，由控制器自增分配，用于在列表增删（[BatchUploadController.removeAt]）
/// 后仍能把异步上传结果回写到正确的项，规避「按数组下标回写」的错位竞态。
///
/// [asset] 可空：相册批量选中的项一律带 [AssetEntity]（失败可重传）；相机即拍
/// 等无 AssetEntity 的项以 null 追加为已完成态，不参与重试。
@immutable
class UploadItem<T> {
  const UploadItem({
    required this.id,
    this.asset,
    this.status = UploadItemStatus.pending,
    this.result,
  });

  final int id;
  final AssetEntity? asset;
  final UploadItemStatus status;
  final T? result;

  bool get isPending => status == UploadItemStatus.pending;
  bool get isUploading => status == UploadItemStatus.uploading;
  bool get isDone => status == UploadItemStatus.done;
  bool get isFailed => status == UploadItemStatus.failed;

  /// 仅带原始 AssetEntity 的失败项可重试。
  bool get canRetry => isFailed && asset != null;

  UploadItem<T> _to(UploadItemStatus status, {T? result}) =>
      UploadItem<T>(id: id, asset: asset, status: status, result: result);
}

/// 上传函数：成功返回结果 payload，失败返回 null（含文件读取失败）。
typedef AssetUploader<T> = Future<T?> Function(AssetEntity asset);

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
  BatchUploadController({required this.uploader, this.concurrency = 3})
    : assert(concurrency > 0);

  final AssetUploader<T> uploader;
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

  /// 追加一个已完成项（如相机即拍即传成功后回填），不参与重试。
  void addCompleted(T result) {
    _items.add(
      UploadItem<T>(
        id: _nextId++,
        status: UploadItemStatus.done,
        result: result,
      ),
    );
    notifyListeners();
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
    final asset = _itemById(id)?.asset;
    if (asset == null) return;
    _setById(id, (item) => item._to(UploadItemStatus.uploading));
    final result = await uploader(asset);
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
