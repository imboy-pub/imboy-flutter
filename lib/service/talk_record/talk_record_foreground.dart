import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

/// Android foreground acknowledgement belongs to one engine, never global capture.
class TalkRecordForeground {
  TalkRecordForeground({MethodChannel? channel, bool? enabled})
    : _channel = channel ?? const MethodChannel('imboy/talk_record_foreground'),
      _enabled = enabled ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _enabled;
  static TalkRecordForeground? _owner;
  String? _token;
  Future<void>? _starting;
  void Function()? onLost;

  Future<void> start() {
    if (!_enabled) return Future<void>.value();
    if (_starting != null) return _starting!;
    return _starting = _start().whenComplete(() {
      _starting = null;
    });
  }

  Future<void> _start() async {
    if (_owner != null && _owner != this) throw StateError('已有录音前台服务');
    if (_token != null) return;
    _owner = this;
    final random = Random.secure();
    final token = List.generate(
      24,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    _token = token;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'lost' &&
          call.arguments is Map &&
          (call.arguments as Map)['token'] == _token) {
        onLost?.call();
      }
    });
    try {
      final acknowledged = await _channel.invokeMethod<bool>('start', {
        'token': token,
      });
      if (acknowledged != true) throw StateError('录音前台服务未确认启动');
    } catch (_) {
      // Keep ownership until the native side confirms cleanup (close retries it).
      await stop();
      rethrow;
    }
  }

  Future<void> update({required bool paused}) async {
    if (!_enabled) return;
    final token = _token;
    if (token == null) throw StateError('录音前台服务不可用');
    if (await _channel.invokeMethod<bool>('update', {
          'token': token,
          'paused': paused,
        }) !=
        true) {
      throw StateError('录音前台服务未确认');
    }
  }

  Future<void> stop() async {
    if (!_enabled || _token == null) return;
    if (await _channel.invokeMethod<bool>('stop', {'token': _token}) != true) {
      throw StateError('录音前台服务未确认停止');
    }
    _token = null;
    if (_owner == this) {
      _owner = null;
      _channel.setMethodCallHandler(null);
    }
  }
}
