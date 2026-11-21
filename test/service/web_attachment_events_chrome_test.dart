@TestOn('chrome')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/web_shell/web_attachment_input_events_web.dart';
import 'package:web/web.dart' as web;

// Real DOM File bytes/events, synthetic user input; no clipboard permission or upload.
web.DataTransfer _files(List<String> names) {
  final transfer = web.DataTransfer();
  for (final name in names) {
    transfer.items.add(
      web.File(
        <web.BlobPart>[
          Uint8List.fromList([0, 127, 255]).toJS,
        ].toJS,
        name,
      ),
    );
  }
  return transfer;
}

web.DragEvent _drop(web.DataTransfer files, {int x = 10}) => web.DragEvent(
  'drop',
  web.DragEventInit(
    cancelable: true,
    clientX: x,
    clientY: 10,
    dataTransfer: files,
  ),
);

web.ClipboardEvent _paste(web.DataTransfer files) => web.ClipboardEvent(
  'paste',
  web.ClipboardEventInit(cancelable: true, clipboardData: files),
);

void main() {
  test(
    'drop only accepts files inside composer and preserves actual bytes',
    () async {
      final received = Completer<({String name, int size, Uint8List bytes})>();
      var calls = 0;
      final remove = listenWebAttachmentInput(
        containsPoint: (x, y) => x < 20 && y < 20,
        acceptsPaste: () => false,
        captureInput: () =>
            () => true,
        onFile: (name, size, read) async {
          calls++;
          received.complete((name: name, size: size, bytes: await read()));
        },
      );
      try {
        final outside = _drop(_files(['outside.bin']), x: 30);
        web.document.dispatchEvent(outside);
        expect(outside.defaultPrevented, isFalse);
        expect(calls, 0);
        final inside = _drop(_files(['inside.bin']));
        web.document.dispatchEvent(inside);
        final value = await received.future.timeout(const Duration(seconds: 3));
        expect(inside.defaultPrevented, isTrue);
        expect(value.name, 'inside.bin');
        expect(value.size, 3);
        expect(value.bytes, [0, 127, 255]);
        expect(calls, 1);
      } finally {
        remove();
      }
    },
  );

  test(
    'paste requires focused permission and disposal removes document listener',
    () async {
      var focused = false;
      var calls = 0;
      final received = Completer<Uint8List>();
      final remove = listenWebAttachmentInput(
        containsPoint: (x, y) => true,
        acceptsPaste: () => focused,
        captureInput: () =>
            () => true,
        onFile: (name, size, read) async {
          calls++;
          received.complete(await read());
        },
      );
      try {
        final unfocused = _paste(_files(['unfocused.bin']));
        web.document.dispatchEvent(unfocused);
        expect(unfocused.defaultPrevented, isFalse);
        expect(calls, 0);
        focused = true;
        final paste = _paste(_files(['focused.bin']));
        web.document.dispatchEvent(paste);
        expect(await received.future.timeout(const Duration(seconds: 3)), [
          0,
          127,
          255,
        ]);
        expect(paste.defaultPrevented, isTrue);
        expect(calls, 1);
      } finally {
        remove();
      }
      final disposed = _paste(_files(['disposed.bin']));
      web.document.dispatchEvent(disposed);
      expect(disposed.defaultPrevented, isFalse);
      expect(calls, 1);
    },
  );

  for (final disposeListener in [false, true]) {
    test('${disposeListener ? 'listener disposal' : 'owner change'} '
        'between files rejects remaining files in same drop', () async {
      var generation = 1;
      final firstRead = Completer<void>();
      final release = Completer<void>();
      final finished = Completer<void>();
      final names = <String>[];
      final remove = listenWebAttachmentInput(
        containsPoint: (x, y) => true,
        acceptsPaste: () => true,
        captureInput: () {
          final captured = generation;
          return () => generation == captured;
        },
        onFile: (name, size, read) async {
          names.add(name);
          expect(await read(), [0, 127, 255]);
          firstRead.complete();
          await release.future;
          finished.complete();
        },
      );
      try {
        web.document.dispatchEvent(
          _drop(_files(['first.bin', 'old-second.bin'])),
        );
        await firstRead.future.timeout(const Duration(seconds: 3));
        if (disposeListener) {
          remove();
        } else {
          generation++;
        }
        release.complete();
        await finished.future.timeout(const Duration(seconds: 3));
        await Future<void>.delayed(Duration.zero);
        expect(names, ['first.bin']);
      } finally {
        if (!release.isCompleted) release.complete();
        remove();
      }
    });
  }
}
