import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/infrastructure/human_directory_api.dart';

/// One explicitly armed directory response is changed; all requests use real IO.
class A04DirectoryFaultAdapter implements HttpClientAdapter {
  A04DirectoryFaultAdapter({HttpClientAdapter? delegate})
    : _delegate = delegate ?? IOHttpClientAdapter();

  final HttpClientAdapter _delegate;
  String? _path;
  bool _fail = false;
  Completer<void>? _release;
  Completer<void>? _observed;
  int injectedFailures = 0;
  int heldResponses = 0;
  int forwardedRequests = 0;

  Future<void> get observed => _observed!.future;

  void failOnce(String organizationId) => _arm(organizationId, fail: true);

  void holdOnce(String organizationId) => _arm(organizationId, fail: false);

  void _arm(String organizationId, {required bool fail}) {
    if (_path != null || _release != null) {
      throw StateError('fault already armed');
    }
    _path = '/api/v1/organizations/$organizationId/directory/departments';
    _fail = fail;
    _observed = Completer<void>();
    if (!fail) _release = Completer<void>();
  }

  void release() {
    final pending = _release;
    _release = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final selected =
        options.method == 'GET' &&
        options.uri.path == _path &&
        !options.queryParameters.containsKey('cursor') &&
        !options.queryParameters.containsKey('parent_id');
    if (selected) _path = null;
    final response = await _delegate.fetch(
      options,
      requestStream,
      cancelFuture,
    );
    forwardedRequests++;
    if (!selected) return response;
    final bytes = await response.stream.fold<List<int>>(
      [],
      (a, b) => a..addAll(b),
    );
    if (response.statusCode != 200 ||
        (jsonDecode(utf8.decode(bytes)) as Map)['code'] != 0) {
      throw StateError(
        'fault requires an actual successful owned backend response',
      );
    }
    _observed!.complete();
    if (_fail) {
      injectedFailures++;
      // API-envelope failure avoids changing the production transport retry policy.
      return ResponseBody.fromString(
        jsonEncode({
          'code': 503,
          'msg': 'A04_SYNTHETIC_UNAVAILABLE',
          'payload': <String, Object?>{},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    }
    heldResponses++;
    await _release!.future.timeout(const Duration(seconds: 60));
    return ResponseBody.fromBytes(
      bytes,
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close({bool force = false}) {
    release();
    _delegate.close(force: force);
  }
}

/// Observes the real API Future, then signals after its chart consumer resumes.
class A04ObservedDirectorySource implements HumanDirectoryDataSource {
  A04ObservedDirectorySource(this._source);
  final HumanDirectoryDataSource _source;
  bool _next = false;
  Completer<void>? _consumed;
  Future<void> get consumed => _consumed!.future;

  void observeNextRoot() {
    if (_next || (_consumed != null && !_consumed!.isCompleted)) {
      throw StateError('observer already armed');
    }
    _next = true;
    _consumed = Completer<void>();
  }

  @override
  Future<HumanDirectoryPage<HumanDirectoryDepartment>> directoryDepartments({
    required EntityId organizationId,
    EntityId? parentId,
    String? cursor,
    int? limit,
  }) {
    final future = _source.directoryDepartments(
      organizationId: organizationId,
      parentId: parentId,
      cursor: cursor,
      limit: limit,
    );
    if (!_next || parentId != null || cursor != null) return future;
    _next = false;
    final caller = Completer<HumanDirectoryPage<HumanDirectoryDepartment>>();
    final consumed = _consumed!;
    future.then(
      (page) {
        caller.complete(page);
        scheduleMicrotask(consumed.complete);
      },
      onError: (Object error, StackTrace stack) {
        caller.completeError(error, stack);
        scheduleMicrotask(consumed.complete);
      },
    );
    return caller.future;
  }

  @override
  Future<HumanDirectoryPage<HumanDirectoryMember>> directoryMembers({
    required EntityId organizationId,
    EntityId? departmentId,
    String? cursor,
    int? limit,
  }) => _source.directoryMembers(
    organizationId: organizationId,
    departmentId: departmentId,
    cursor: cursor,
    limit: limit,
  );

  @override
  Future<HumanDirectoryMe> directoryMe({required EntityId organizationId}) =>
      _source.directoryMe(organizationId: organizationId);

  @override
  Future<HumanDirectoryPage<HumanDirectorySearchItem>> directorySearch({
    required EntityId organizationId,
    required String q,
    String? cursor,
    int? limit,
  }) => _source.directorySearch(
    organizationId: organizationId,
    q: q,
    cursor: cursor,
    limit: limit,
  );
}
