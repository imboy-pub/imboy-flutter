import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

/// Memory-only verified content and its owned image providers, never URLs/tickets.
class CsVerifiedAssetCache {
  final Map<String, Future<CsVerifiedAssetContent?>> _entries = {};
  Future<CsVerifiedAssetContent?> get(
    String id,
    Future<CsVerifiedAssetContent?> Function() load,
  ) {
    final existing = _entries[id];
    if (existing != null) return existing;
    late final Future<CsVerifiedAssetContent?> future;
    future = Future<CsVerifiedAssetContent?>.sync(load).then(
      (content) {
        if (content == null && identical(_entries[id], future)) {
          _entries.remove(id);
        }
        return content;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[id], future)) _entries.remove(id);
        Error.throwWithStackTrace(error, stack);
      },
    );
    _entries[id] = future;
    return future;
  }

  void clear() {
    final old = _entries.values.toList();
    _entries.clear();
    for (final future in old) {
      unawaited(
        future.then<void>((content) async {
          if (content != null) await MemoryImage(content.bytes).evict();
        }, onError: (Object error, StackTrace stack) {}),
      );
    }
  }
}
