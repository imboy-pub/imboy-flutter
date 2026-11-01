import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/support/v5_checkpoint_store.dart';

bool publishContender(String path, String value) {
  try {
    V5CheckpointStore(Directory(path))
        .publish('race.json', Uint8List.fromList(utf8.encode(value)));
    return true;
  } on StateError {
    return false;
  }
}

Future<bool> runContender(String path, String value) =>
    Isolate.run(() => publishContender(path, value));

void main() {
  group('V5 immutable checkpoints', () {
    late Directory root;
    late V5CheckpointStore store;
    setUp(() async {
      root = await Directory.systemTemp.createTemp('v5-checkpoint-test-');
      store = V5CheckpointStore(root);
    });
    tearDown(() async => root.delete(recursive: true));

    Uint8List bytes(String value) => Uint8List.fromList(utf8.encode(value));

    test('publication and identical retry preserve the original', () {
      expect(store.read('case.json'), isNull);
      store.publish('case.json', bytes('first'));
      expect(
        root.listSync().where((entry) => entry.path.endsWith('.tmp')),
        isEmpty,
      );
      store.publish('case.json', bytes('first'));
      expect(utf8.decode(store.read('case.json')!), 'first');
      expect(
        () => store.publish('case.json', bytes('different')),
        throwsStateError,
      );
      expect(utf8.decode(store.read('case.json')!), 'first');
    });

    test(
      'retained retry temporaries cannot mutate the published checkpoint',
      () {
        store.publish('case.json', bytes('first'));
        expect(
          () => store.publish('case.json', bytes('different')),
          throwsStateError,
        );
        final temporaries = root.listSync().whereType<File>().where(
          (entry) => entry.path.endsWith('.tmp'),
        );
        expect(temporaries, isNotEmpty);
        for (final temporary in temporaries) {
          temporary.writeAsStringSync('tampered', flush: true);
        }
        expect(utf8.decode(store.read('case.json')!), 'first');
      },
    );

    test('symlink target is never followed or overwritten', () async {
      final sentinel = File('${root.path}/sentinel')..writeAsStringSync('keep');
      await Link('${root.path}/case.json').create(sentinel.path);
      expect(() => store.read('case.json'), throwsStateError);
      expect(() => store.publish('case.json', bytes('new')), throwsStateError);
      expect(sentinel.readAsStringSync(), 'keep');
      expect(
        FileSystemEntity.typeSync('${root.path}/case.json', followLinks: false),
        FileSystemEntityType.link,
      );
    });

    test('hard linked matching content is not accepted as a checkpoint', () {
      final source = File('${root.path}/foreign')..writeAsStringSync('first');
      expect(Process.runSync('chmod', ['600', source.path]).exitCode, 0);
      expect(utf8.decode(store.read('foreign')!), 'first');
      final result = Process.runSync('ln', [
        source.path,
        '${root.path}/case.json',
      ]);
      expect(result.exitCode, 0);
      expect(() => store.read('case.json'), throwsStateError);
      expect(
        () => store.publish('case.json', bytes('first')),
        throwsStateError,
      );
      expect(source.readAsStringSync(), 'first');
    });

    test('replacing target after open is detected by device and inode', () {
      store.publish('case.json', bytes('first'));
      expect(
        () => store.read(
          'case.json',
          afterReadForTest: () {
            File('${root.path}/case.json').renameSync('${root.path}/original');
            final replacement = File('${root.path}/case.json')
              ..writeAsStringSync('first');
            expect(
              Process.runSync('chmod', ['600', replacement.path]).exitCode,
              0,
            );
          },
        ),
        throwsStateError,
      );
      expect(File('${root.path}/original').readAsStringSync(), 'first');
      expect(File('${root.path}/case.json').readAsStringSync(), 'first');
    });

    test('old Android APIs are rejected before checkpoint use', () {
      expect(
        () => V5CheckpointStore.requireAndroidApi(24),
        throwsUnsupportedError,
      );
      expect(
        () => V5CheckpointStore.requireAndroidApi(29),
        throwsUnsupportedError,
      );
      expect(() => V5CheckpointStore.requireAndroidApi(30), returnsNormally);
    });

    test('first and verified checkpoints are immutable separate files', () {
      store.publish('case.json', bytes('await_kill'));
      store.publish('case.verified.json', bytes('verified'));
      expect(utf8.decode(store.read('case.json')!), 'await_kill');
      expect(utf8.decode(store.read('case.verified.json')!), 'verified');
    });

    test('concurrent different publishers cannot replace the winner', () async {
      final path = root.path;
      final outcomes = await Future.wait([
        runContender(path, 'one'),
        runContender(path, 'two'),
      ]);
      expect(outcomes.where((ok) => ok), hasLength(1));
      expect({'one', 'two'}, contains(utf8.decode(store.read('race.json')!)));
    });

    test('unsafe names and empty or oversized content are rejected', () {
      expect(
        () => store.publish('../outside', bytes('x')),
        throwsArgumentError,
      );
      expect(() => store.publish('case', Uint8List(0)), throwsArgumentError);
      expect(
        () => store.publish('case', Uint8List(65537)),
        throwsArgumentError,
      );
    });
  });
}
