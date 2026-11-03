import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/service/e2ee/attachment_encryptor.dart';

class _ObservedFile implements File {
  _ObservedFile(this.file);
  final File file;
  int reads = 0;
  final entered = Completer<void>();
  final resume = Completer<void>();
  bool rejectWrite = false;
  int closes = 0;

  @override
  String get path => file.path;
  @override
  int lengthSync() => file.lengthSync();
  @override
  bool existsSync() => file.existsSync();
  @override
  void deleteSync({bool recursive = false}) =>
      file.deleteSync(recursive: recursive);
  @override
  File renameSync(String newPath) => file.renameSync(newPath);
  @override
  Future<File> rename(String newPath) => file.rename(newPath);
  @override
  Stream<List<int>> openRead([int? start, int? end]) =>
      file.openRead(start, end);
  @override
  RandomAccessFile openSync({FileMode mode = FileMode.read}) =>
      _ObservedHandle(file.openSync(mode: mode), this, false);
  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      _ObservedHandle(await file.open(mode: mode), this, mode != FileMode.read);
  @override
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8}) {
    entered.complete();
    return file.openWrite(mode: mode, encoding: encoding);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ObservedHandle implements RandomAccessFile {
  _ObservedHandle(this.handle, this.owner, this.gateWrites);
  final RandomAccessFile handle;
  final _ObservedFile owner;
  final bool gateWrites;
  @override
  Uint8List readSync(int count) {
    owner.reads++;
    return handle.readSync(count);
  }

  @override
  Future<Uint8List> read(int count) => handle.read(count);

  @override
  void setPositionSync(int position) => handle.setPositionSync(position);
  @override
  void closeSync() => handle.closeSync();
  @override
  Future<void> close() async {
    if (gateWrites) owner.closes++;
    await handle.close();
  }

  @override
  Future<RandomAccessFile> flush() async {
    await handle.flush();
    return this;
  }

  @override
  Future<RandomAccessFile> writeFrom(
    List<int> buffer, [
    int start = 0,
    int? end,
  ]) async {
    if (gateWrites) {
      if (!owner.entered.isCompleted) owner.entered.complete();
      await owner.resume.future;
      if (owner.rejectWrite) {
        throw const FileSystemException('synthetic disk failure');
      }
    }
    await handle.writeFrom(buffer, start, end);
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final opening in [false, true]) {
    for (final rejectWrite in [false, true]) {
      test(
        '${opening ? 'open' : 'seal'} awaits each file write; failure=$rejectWrite',
        () async {
          final directory = await Directory.systemTemp.createTemp(
            'c06-backpressure-',
          );
          final plain = File('${directory.path}/plain')
            ..writeAsBytesSync(
              List<int>.generate(12500, (index) => index % 251),
            );
          final cipher = File('${directory.path}/cipher');
          final destination = File('${directory.path}/result');
          final key = Uint8List(32);
          final nonce = Uint8List(12);
          final binding = Uint8List(32);
          final sealed = AttachmentEncryptor.seal(
            plaintext: plain.readAsBytesSync(),
            bindingHash: binding,
            attachmentId: 'synthetic',
            objectKey: 'synthetic/object',
            mime: 'application/octet-stream',
            name: 'synthetic',
            contentKey: key,
            baseNonce: nonce,
            chunkSize: 4096,
          );
          cipher.writeAsBytesSync(sealed.ciphertext);
          final input = _ObservedFile(opening ? cipher : plain);
          final output = _ObservedFile(File('${destination.path}.part'))
            ..rejectWrite = rejectWrite;
          final operation = IOOverrides.runZoned(
            () => opening
                ? AttachmentEncryptor.openToFile(
                    cipherFile: input,
                    plaintextOut: destination,
                    descriptor: sealed.descriptor,
                    bindingHash: binding,
                  )
                : AttachmentEncryptor.sealToFile(
                    plaintextFile: input,
                    cipherFile: destination,
                    bindingHash: binding,
                    attachmentId: 'synthetic',
                    objectKey: 'synthetic/object',
                    mime: 'application/octet-stream',
                    name: 'synthetic',
                    contentKey: key,
                    baseNonce: nonce,
                    chunkSize: 4096,
                  ),
            createFile: (path) {
              if (path == input.path) return input;
              if (path == destination.path) return destination;
              if (path != output.path) {
                throw StateError('Unexpected file $path');
              }
              return output;
            },
          );
          final result = expectLater(
            operation,
            rejectWrite ? throwsA(isA<FileSystemException>()) : completes,
          );
          int? blockedReads;
          bool? publishedWhileBlocked;
          try {
            await output.entered.future.timeout(const Duration(seconds: 5));
            blockedReads = input.reads;
            publishedWhileBlocked = destination.existsSync();
          } finally {
            output.resume.complete();
            try {
              await result;
              expect(
                blockedReads,
                1,
                reason: 'a blocked write must stop reading/encrypting subsequent chunks',
              );
              expect(
                publishedWhileBlocked,
                isFalse,
                reason: 'no final file before all writes/authentication',
              );
              expect(File('${destination.path}.part').existsSync(), isFalse);
              expect(destination.existsSync(), !rejectWrite);
              expect(
                output.closes,
                1,
                reason:
                    'close the file handle exactly once even on write failure',
              );
              if (!rejectWrite) {
                expect(
                  destination.readAsBytesSync(),
                  opening ? plain.readAsBytesSync() : sealed.ciphertext,
                );
              }
            } finally {
              await directory.delete(recursive: true);
            }
          }
        },
      );
    }
  }
}
