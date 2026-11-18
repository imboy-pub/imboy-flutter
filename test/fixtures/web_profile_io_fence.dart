import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_client.dart' as product;
import 'package:web/web.dart' as web;

@JS('Object.prototype.toString.call')
external JSString _kind(JSAny? value);

class ProfileIoFence implements HttpClientAdapter {
  int adapterCalls = 0, fetchCalls = 0, xhrCalls = 0;
  late final JSFunction _fetch;
  late final JSObject _xhrPrototype;
  late final JSFunction _open;
  HttpClientAdapter? _previousAdapter;

  bool _asset(String input) {
    final uri = Uri.base.resolve(input);
    return uri.origin == Uri.base.origin &&
        (uri.path.endsWith('/sqlite3.wasm') ||
            [
              '/assets/',
              '/canvaskit/',
              '/fonts/',
              '/packages/',
            ].any(uri.path.startsWith));
  }

  void install() {
    _previousAdapter = product.HttpClient.adapterForTest;
    product.HttpClient.adapterForTest = this;
    _fetch = web.window.getProperty<JSFunction>('fetch'.toJS);
    web.window.setProperty(
      'fetch'.toJS,
      ((JSAny? input, JSAny? options) {
        final raw = switch (_kind(input).toDart) {
          '[object String]' => (input as JSString).toDart,
          '[object URL]' => (input as web.URL).href,
          '[object Request]' => (input as web.Request).url,
          _ => '',
        };
        final requestMethod = _kind(input).toDart == '[object Request]'
            ? (input as web.Request).method
            : 'GET';
        final optionMethod = options == null
            ? null
            : (options as JSObject)
                  .getProperty<JSString?>('method'.toJS)
                  ?.toDart;
        if ((optionMethod ?? requestMethod).toUpperCase() != 'GET' ||
            !_asset(raw)) {
          fetchCalls++;
          return Future<JSAny?>.error(StateError('Undeclared profile Fetch'))
              .toJS;
        }
        return _fetch.callAsFunction(web.window, input, options);
      }).toJS,
    );
    _xhrPrototype = web.window
        .getProperty<JSObject>('XMLHttpRequest'.toJS)
        .getProperty<JSObject>('prototype'.toJS);
    _open = _xhrPrototype.getProperty<JSFunction>('open'.toJS);
    _xhrPrototype.setProperty(
      'open'.toJS,
      ((JSObject receiver, JSString method, JSString url, JSAny? async) {
        if (method.toDart.toUpperCase() != 'GET' || !_asset(url.toDart)) {
          xhrCalls++;
          throw StateError('Undeclared profile XHR');
        }
        return _open.callAsFunction(receiver, method, url, async ?? true.toJS);
      }).toJSCaptureThis,
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    adapterCalls++;
    throw StateError('Undeclared profile HTTP');
  }

  @override
  void close({bool force = false}) {}

  void verifyAndRestore() {
    try {
      expect(
        [adapterCalls, fetchCalls, xhrCalls],
        [0, 0, 0],
        reason: 'Caught failures cannot conceal attempted product transport',
      );
    } finally {
      product.HttpClient.adapterForTest = _previousAdapter;
      web.window.setProperty('fetch'.toJS, _fetch);
      _xhrPrototype.setProperty('open'.toJS, _open);
    }
  }
}
