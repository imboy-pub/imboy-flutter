import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:imboy/service/account_local_files.dart';
import 'package:imboy/service/account_local_task_registry.dart';

const _a = AccountLocalTaskOwner(
  uid: 'synthetic-a',
  environment: 'pro',
  endpoint: 'https://example.invalid',
);
const _b = AccountLocalTaskOwner(
  uid: 'synthetic-b',
  environment: 'pro',
  endpoint: 'https://example.invalid',
);

class _DelayedTemporaryPath extends PathProviderPlatform {
  _DelayedTemporaryPath(this.root, this.pathReady);
  final Directory root;
  final Completer<void> pathReady;
  final entered = Completer<void>();

  @override
  Future<String?> getTemporaryPath() async {
    entered.complete();
    await pathReady.future;
    return root.path;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cleanup cancels A and waits for final writes without stopping B',
    () async {
      final registry = AccountLocalTaskRegistry();
      final stopped = Completer<void>();
      final finalWrite = Completer<void>();
      var bCancelled = false;
      final b = registry.register(_b, onCancel: () => bCancelled = true);
      final work = registry.run<void>(
        _a,
        onCancel: () => stopped.complete(),
        operation: (task) async {
          try {
            await stopped.future;
            task.throwIfCancelled();
          } finally {
            await finalWrite.future;
          }
        },
      );
      final workResult = expectLater(
        work,
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      final cleanup = registry.beginCleanup(_a);
      var drained = false;
      final drainedResult = cleanup.stopped.then((_) => drained = true);
      await stopped.future;
      await Future<void>.delayed(Duration.zero);
      expect(drained, isFalse);
      expect(bCancelled, isFalse);
      expect(b.isCancelled, isFalse);
      expect(
        () => registry.register(_a),
        throwsA(isA<AccountLocalTaskCancelledException>()),
      );
      expect(() => registry.beginCleanup(_a), throwsStateError);

      finalWrite.complete();
      await workResult;
      await drainedResult;
      expect(drained, isTrue);
      cleanup.release();
      cleanup.release();
      registry.register(_a).finish();
      b.finish();
    },
  );

  test(
    'a failed stop keeps the task available for an explicit retry',
    () async {
      final registry = AccountLocalTaskRegistry();
      var attempts = 0;
      late AccountLocalTask work;
      work = registry.register(
        _a,
        onCancel: () async {
          attempts++;
          if (attempts == 1) {
            throw StateError('synthetic transient device failure');
          }
          work.finish();
        },
      );
      final first = registry.beginCleanup(_a);
      await expectLater(first.stopped, throwsStateError);
      first.release();
      expect(work.isCancelled, isTrue);

      final retry = registry.beginCleanup(_a);
      await retry.stopped;
      retry.release();
      expect(attempts, 2);
    },
  );

  test(
    'late path lookup cannot recreate an account temporary directory',
    () async {
      final registry = AccountLocalTaskRegistry();
      final previousPaths = PathProviderPlatform.instance;
      final root = await Directory.systemTemp.createTemp('account-files-test-');
      final pathReady = Completer<void>();
      final paths = _DelayedTemporaryPath(root, pathReady);
      PathProviderPlatform.instance = paths;
      final other = File(
        p.join(AccountLocalFiles.folderFor(root.path, _b), 'b.enc'),
      );
      await other.parent.create(recursive: true);
      await other.writeAsString('synthetic B data');
      try {
        final operation = registry.run<Directory>(
          _a,
          operation: AccountLocalFiles.directory,
        );
        final outcome = expectLater(
          operation,
          throwsA(isA<AccountLocalTaskCancelledException>()),
        );
        await paths.entered.future;
        final cleanup = registry.beginCleanup(_a);
        pathReady.complete();
        await outcome;
        await cleanup.stopped;
        cleanup.release();
        expect(
          await Directory(AccountLocalFiles.folderFor(root.path, _a)).exists(),
          isFalse,
        );
        expect(await other.readAsString(), 'synthetic B data');
      } finally {
        PathProviderPlatform.instance = previousPaths;
        await root.delete(recursive: true);
      }
    },
  );

  test('scopes distinguish account, deployment and endpoint exactly', () {
    const otherEnvironment = AccountLocalTaskOwner(
      uid: 'synthetic-a',
      environment: 'dev',
      endpoint: 'https://example.invalid',
    );
    const otherEndpoint = AccountLocalTaskOwner(
      uid: 'synthetic-a',
      environment: 'pro',
      endpoint: 'https://example.invalid/',
    );
    expect({_a, _b, otherEnvironment, otherEndpoint}.length, 4);
    expect(
      {
        for (final owner in [_a, _b, otherEnvironment, otherEndpoint])
          owner.preferenceKey('history'),
      }.length,
      4,
    );
    expect(
      AccountLocalFiles.folderFor('/tmp', _a),
      startsWith('/tmp/account_local_data/'),
    );
  });
}
