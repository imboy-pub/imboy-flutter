import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;

import 'cs_integration_fixture.dart';

class CsOwnedFileRefused implements Exception {
  const CsOwnedFileRefused();
  @override
  String toString() => 'CS_OWNED_FILE_REFUSED';
}

/// Fixed Android user-0 run custody, not an arbitrary filesystem allowlist.
/// Requires the separately leased single-writer device window. Dart has no
/// O_NOFOLLOW open: these checks do not prove kernel-level ABA exclusion.
class CsOwnedDeviceFiles {
  CsOwnedDeviceFiles(this.fixture) : _root = Directory(fixture.ownedDeviceRoot);
  @visibleForTesting
  CsOwnedDeviceFiles.forTest(Directory sandbox, this.fixture) : _root = sandbox;
  final CsIntegrationFixture fixture;
  final Directory _root;
  String get _input => '${_root.path}/input/${fixture.assetName}';
  String get _output => '${_root.path}/output/${fixture.assetName}';

  Future<void> _tree() async {
    for (final path in [
      _root.path,
      '${_root.path}/input',
      '${_root.path}/output',
    ]) {
      if (await FileSystemEntity.type(path, followLinks: false) !=
              FileSystemEntityType.directory ||
          await Directory(path).resolveSymbolicLinks() != path) {
        throw const CsOwnedFileRefused();
      }
    }
  }

  Future<FileStat> _regular(String path) async {
    if (await FileSystemEntity.type(path, followLinks: false) !=
            FileSystemEntityType.file ||
        await File(path).resolveSymbolicLinks() != path) {
      throw const CsOwnedFileRefused();
    }
    final stat = await File(path).stat();
    if (stat.size != fixture.assetSize) throw const CsOwnedFileRefused();
    return stat;
  }

  Future<void> assertOutputAbsent() => _safe(() async {
    await _tree();
    if (await FileSystemEntity.type(_output, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw const CsOwnedFileRefused();
    }
  });

  Future<Uint8List> readInput() => _safe(() async {
    await assertOutputAbsent();
    return _read(_input);
  });
  Future<Uint8List> readPicked(File selected) => _safe(() async {
    if (selected.path != _input) throw const CsOwnedFileRefused();
    return readInput();
  });
  Future<Uint8List> readSaved() => _safe(() => _read(_output));

  Future<void> verifySaveUri(Uri uri) => _safe(() async {
    if (uri != Uri.file(_output)) throw const CsOwnedFileRefused();
    await readSaved();
  });

  Future<Uint8List> _read(String path) async {
    await _tree();
    final before = await _regular(path);
    final handle = await File(path).open(mode: FileMode.read);
    late Uint8List bytes;
    try {
      if (await handle.length() != fixture.assetSize) {
        throw const CsOwnedFileRefused();
      }
      bytes = await handle.read(fixture.assetSize + 1);
    } finally {
      await handle.close();
    }
    await _tree();
    final after = await _regular(path);
    if (before.modified != after.modified ||
        before.changed != after.changed ||
        before.mode != after.mode ||
        bytes.length != fixture.assetSize ||
        sha256.convert(bytes).toString() != fixture.assetSha) {
      throw const CsOwnedFileRefused();
    }
    return bytes.asUnmodifiableView();
  }

  Future<T> _safe<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on Object {
      throw const CsOwnedFileRefused();
    }
  }
}
