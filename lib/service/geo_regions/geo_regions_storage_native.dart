import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class GeoPlatformStorage {
  late final Future<Directory> _root = _openRoot();

  Future<Directory> _openRoot() async {
    final support = await getApplicationSupportDirectory();
    return Directory(path.join(support.path, 'geo-regions-v1'))
        .create(recursive: true);
  }

  Future<File> _file(String key) async =>
      File(path.join((await _root).path, base64Url.encode(utf8.encode(key))));

  Future<Uint8List?> read(String key) async {
    try {
      return await (await _file(key)).readAsBytes();
    } on PathNotFoundException {
      return null;
    }
  }

  Future<void> write(String key, Uint8List bytes) async {
    final destination = await _file(key);
    final staging = await (await _root).createTemp('write-');
    try {
      final file = await File(path.join(staging.path, 'bytes'))
          .writeAsBytes(bytes, flush: true);
      await file.rename(destination.path);
    } finally {
      await staging.delete(recursive: true);
    }
  }

  Future<void> remove(String key) async {
    try {
      await (await _file(key)).delete();
    } on PathNotFoundException {
      // A concurrent eviction can remove the same entry.
    }
  }

  Future<List<String>> keys() async {
    final keys = <String>[];
    await for (final entity in (await _root).list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        keys.add(utf8.decode(base64Url.decode(path.basename(entity.path))));
      } on FormatException {
        // Ignore foreign files rather than treating them as Geo cache entries.
      }
    }
    return keys;
  }

  Future<void> clear() async {
    for (final key in await keys()) {
      await remove(key);
    }
  }
}
