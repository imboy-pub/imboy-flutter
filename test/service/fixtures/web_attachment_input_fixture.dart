part of '../web_attachment_input_restore_chrome_test.dart';

final class _NoNetwork implements HttpClientAdapter {
  int calls = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    throw StateError('Unexpected product HTTP');
  }

  @override
  void close({bool force = false}) {}
}

// The delegated query completes in the real database before its result is held.
final class _HeldQueryDb implements Database {
  _HeldQueryDb(this.delegate, this.whereToHold);
  final Database delegate;
  final String whereToHold;
  final entered = Completer<void>.sync();
  final release = Completer<void>.sync();
  final returned = Completer<void>.sync();
  bool armed = false;
  @override
  bool get isOpen => delegate.isOpen;

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    debugPrintSynchronously(
      'RACE_PROXY query start table=$table where=$where armed=$armed target=$whereToHold',
    );
    final result = await delegate.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
    debugPrintSynchronously(
      'RACE_PROXY query returned table=$table where=$where rows=${result.length}',
    );
    if (armed &&
        table == AttachmentUploadTaskRepo.tableName &&
        where == whereToHold &&
        !entered.isCompleted) {
      debugPrintSynchronously('RACE_PROXY query gated where=$where');
      entered.complete();
      await release.future;
      returned.complete();
      debugPrintSynchronously('RACE_PROXY query released where=$where');
    }
    return result;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'unexpected gated database operation: ${invocation.memberName}',
  );
}
