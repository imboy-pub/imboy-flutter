import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

@JS('Object.prototype.toString.call')
external JSString _inputJsType(JSAny? input);

class ChatInputPlatformFence {
  final original = web.window.getProperty<JSFunction>('fetch'.toJS);
  int denied = 0;
  void install() => web.window.setProperty(
    'fetch'.toJS,
    ((JSAny? input, JSAny? options) {
      final raw = switch (_inputJsType(input).toDart) {
        '[object String]' => (input as JSString).toDart,
        '[object URL]' => (input as web.URL).href,
        '[object Request]' => (input as web.Request).url,
        _ => null,
      };
      final uri = raw == null ? null : Uri.base.resolve(raw);
      final asset =
          uri != null &&
          uri.origin == Uri.base.origin &&
          (uri == Uri.base.resolve('sqlite3.wasm') ||
              [
                '/assets/',
                '/canvaskit/',
                '/fonts/',
                '/packages/',
              ].any(uri.path.startsWith));
      if (!asset) {
        denied++;
        return Future<JSAny?>.error(
          StateError('Composer test forbids product Fetch'),
        ).toJS;
      }
      return original.callAsFunction(web.window, input, options);
    }).toJS,
  );
  void restore() => web.window.setProperty('fetch'.toJS, original);
}

Future<T> runInChatInputIoZone<T>(Future<T> Function() body) => body();
