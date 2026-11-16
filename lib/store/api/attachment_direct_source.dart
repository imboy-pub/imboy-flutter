part of 'attachment_direct_api.dart';

/// 可重开的同一材料。调用方保证每次打开内容一致，长度必须精确。
/// 不携 URL/账号/路径，不表示材料已持久化或可跨刷新恢复。
class DirectUploadSource {
  factory DirectUploadSource({
    required int length,
    required Stream<List<int>> Function() openRead,
    void Function()? beforeDispatch,
  }) {
    if (length < 0) throw ArgumentError.value(length, 'length');
    return DirectUploadSource._(length, openRead, beforeDispatch);
  }

  DirectUploadSource._(this.length, this._openRead, this._beforeDispatch);
  factory DirectUploadSource.bytes(
    Uint8List bytes, {
    void Function()? beforeDispatch,
  }) {
    final snapshot = Uint8List.fromList(bytes).asUnmodifiableView();
    return DirectUploadSource(
      length: snapshot.length,
      openRead: () => Stream<List<int>>.value(snapshot),
      beforeDispatch: beforeDispatch,
    );
  }
  final int length;
  final Stream<List<int>> Function() _openRead;
  final void Function()? _beforeDispatch;

  /// Retain the captured owner through buffering. A rejected admission is
  /// terminal locally, never a renewable PUT error.
  void _requireDispatch() {
    try {
      _beforeDispatch?.call();
    } catch (_) {
      throw const DirectUploadDispatchRejected();
    }
  }

  /// 转发背压/下游取消，且在没有下一个 chunk 时也能响应 CancelToken。
  Stream<List<int>> openRead({CancelToken? cancelToken}) {
    late StreamController<List<int>> controller;
    StreamSubscription<List<int>>? subscription;
    var done = false;
    var received = 0;
    void fail(Object error, StackTrace stack) {
      if (done) return;
      done = true;
      controller.addError(error, stack);
      unawaited(subscription?.cancel());
      unawaited(controller.close());
    }

    controller = StreamController<List<int>>(
      onListen: () {
        if (cancelToken?.isCancelled == true) {
          fail(const DirectUploadCancelled(''), StackTrace.current);
          return;
        }
        cancelToken?.whenCancel.then((_) {
          fail(const DirectUploadCancelled(''), StackTrace.current);
        });
        try {
          subscription = _openRead().listen(
            (chunk) {
              if (done) return;
              received += chunk.length;
              if (received > length) {
                fail(
                  StateError('direct source length changed'),
                  StackTrace.current,
                );
                return;
              }
              controller.add(chunk);
            },
            onError: (Object error, StackTrace stack) => fail(error, stack),
            onDone: () {
              if (done) return;
              if (received != length) {
                fail(
                  StateError('direct source length changed'),
                  StackTrace.current,
                );
                return;
              }
              done = true;
              unawaited(controller.close());
            },
          );
          if (done) unawaited(subscription?.cancel());
        } catch (error, stack) {
          fail(error, stack);
        }
      },
      onPause: () => subscription?.pause(),
      onResume: () => subscription?.resume(),
      onCancel: () {
        done = true;
        return subscription?.cancel();
      },
    );
    return controller.stream;
  }
}

DirectUploadSource _fileUploadSource(io.File file) =>
    DirectUploadSource(length: file.lengthSync(), openRead: file.openRead);

DirectSourcePutFn? _filePutAdapter(io.File file, DirectFilePutFn? putFn) =>
    putFn == null
    ? null
    : (url, source, length, headers, {cancelToken, onProgress}) =>
          putFn(url, file, length, headers);

Future<String> _sha256OfSource(
  DirectUploadSource source,
  CancelToken? cancel,
) async {
  final digest = await crypto.sha256
      .bind(source.openRead(cancelToken: cancel))
      .first;
  return digest.toString();
}

/// No request was admitted; retain original task/materials and do not renew.
class DirectUploadDispatchRejected implements Exception {
  const DirectUploadDispatchRejected();
}
