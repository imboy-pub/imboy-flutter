/// RSA 加密服务 - Web 平台实现
///
/// 使用 Web Crypto API 进行 RSA-OAEP 加密和密钥生成
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:web/web.dart' as web;

/// 将 PEM 格式转换为 DER 格式（字节数组）
Uint8List _pemToDer(String pem) {
  // 移除 PEM 头尾和换行符
  String cleaned = pem
      .replaceAll('-----BEGIN PUBLIC KEY-----', '')
      .replaceAll('-----END PUBLIC KEY-----', '')
      .replaceAll('\n', '')
      .replaceAll('\r', '');

  // Base64 解码
  String base64Str = cleaned.trim();
  return base64Decode(base64Str);
}

/// 创建 JavaScript 字符串数组
JSArray<JSString> _createStringArray(List<String> strings) {
  final array = JSArray<JSString>();
  for (final s in strings) {
    // ignore: invalid_runtime_check_with_js_interop_types
    (array as JSObject).callMethodVarArgs('push'.toJS, [s.toJS]);
  }
  return array;
}

/// 创建 JavaScript Uint8Array
JSUint8Array _createUint8Array(List<int> data) {
  // 使用 Dart Uint8List 然后转换为 JS Uint8Array
  final dartBytes = Uint8List.fromList(data);
  return dartBytes.toJS;
}

/// 创建空的 JavaScript 对象
JSObject _createJSObject() {
  return JSObject();
}

/// 设置 JavaScript 对象属性
void _setProperty(JSObject obj, String key, JSAny value) {
  obj.setProperty(key.toJS, value);
}

/// 获取 JavaScript 对象属性
JSAny? _getProperty(JSObject obj, String key) {
  return obj.getProperty(key.toJS);
}

/// 将 ArrayBuffer 转换为 Base64
String _arrayBufferToBase64(JSArrayBuffer buffer) {
  final bytes = JSUint8Array(buffer);
  final length = (bytes as JSObject).getProperty('length'.toJS) as JSNumber;
  final len = length.toDartInt;
  final charCodes = <int>[];
  for (var i = 0; i < len; i++) {
    // ignore: invalid_runtime_check_with_js_interop_types
    final byte =
        (bytes as JSObject).callMethodVarArgs('at'.toJS, [i.toJS]) as JSNumber;
    charCodes.add(byte.toDartInt);
  }
  return base64.encode(charCodes);
}

/// 使用 Web Crypto API 生成 RSA-2048 密钥对
Future<Map<String, String>> generateRSAKeyPairWeb() async {
  if (!kIsWeb) {
    throw UnsupportedError('This function is only available on web platform');
  }

  try {
    iPrint('🔐 Web 平台 RSA 密钥对生成开始');

    // 创建算法参数对象
    final algorithm = _createJSObject();
    _setProperty(algorithm, 'name', 'RSA-OAEP'.toJS);
    _setProperty(algorithm, 'modulusLength', 2048.toJS);
    _setProperty(algorithm, 'publicExponent', _createUint8Array([1, 0, 1]));
    final hashObj = _createJSObject();
    _setProperty(hashObj, 'name', 'SHA-256'.toJS);
    _setProperty(algorithm, 'hash', hashObj);

    // 生成密钥对
    final keyPairPromise = web.window.crypto.subtle.generateKey(
      algorithm,
      true,
      _createStringArray(['encrypt', 'decrypt']),
    );

    final keyPairJs = await keyPairPromise.toDart as JSObject;

    // 导出公钥 (SPKI 格式)
    final publicKey = _getProperty(keyPairJs, 'publicKey');
    final publicKeyBuffer = await web.window.crypto.subtle
        .exportKey(
          'spki',
          // ignore: invalid_runtime_check_with_js_interop_types
          publicKey as web.CryptoKey,
        )
        .toDart;

    // 导出私钥 (PKCS8 格式)
    final privateKey = _getProperty(keyPairJs, 'privateKey');
    final privateKeyBuffer = await web.window.crypto.subtle
        .exportKey(
          'pkcs8',
          // ignore: invalid_runtime_check_with_js_interop_types
          privateKey as web.CryptoKey,
        )
        .toDart;

    // 转换为 Base64
    final publicKeyBase64 = _arrayBufferToBase64(
      publicKeyBuffer as JSArrayBuffer,
    );
    final privateKeyBase64 = _arrayBufferToBase64(
      privateKeyBuffer as JSArrayBuffer,
    );

    // 格式化为 PEM
    final publicKeyPem = _formatAsPem(
      publicKeyBase64,
      '-----BEGIN PUBLIC KEY-----',
      '-----END PUBLIC KEY-----',
    );
    final privateKeyPem = _formatAsPem(
      privateKeyBase64,
      '-----BEGIN PRIVATE KEY-----',
      '-----END PRIVATE KEY-----',
    );

    iPrint('✅ Web 平台 RSA 密钥对生成完成');
    return {'publicKey': publicKeyPem, 'privateKey': privateKeyPem};
  } catch (e, stackTrace) {
    iPrint('❌ Web 平台 RSA 密钥对生成失败: $e');
    iPrint('📚 堆栈: $stackTrace');
    throw Exception('Web 平台 RSA 密钥对生成失败: $e');
  }
}

/// 使用 Web Crypto API 进行 RSA-OAEP 加密
Future<String> rsaEncryptWeb(String plaintext, String pubKeyPem) async {
  if (!kIsWeb) {
    throw UnsupportedError('This function is only available on web platform');
  }

  try {
    iPrint('🔐 Web 平台 RSA 加密开始');

    // 转换 PEM 为 DER 格式
    final derBytes = _pemToDer(pubKeyPem);
    iPrint('📦 DER 数据长度: ${derBytes.length} bytes');
    iPrint(
      '📦 DER 前 20 字节: ${derBytes.sublist(0, derBytes.length > 20 ? 20 : derBytes.length)}',
    );

    // 创建算法参数对象
    final algorithm = _createJSObject();
    _setProperty(algorithm, 'name', 'RSA-OAEP'.toJS);
    final hashObj = _createJSObject();
    _setProperty(hashObj, 'name', 'SHA-256'.toJS);
    _setProperty(algorithm, 'hash', hashObj);
    iPrint('📦 算法参数创建完成: RSA-OAEP-SHA256');

    // 导入公钥
    iPrint('📦 开始导入公钥 (SPKI 格式)...');
    final publicKeyData = _createUint8Array(derBytes);
    final publicKey = await web.window.crypto.subtle
        .importKey(
          'spki',
          publicKeyData,
          algorithm,
          false,
          _createStringArray(['encrypt']),
        )
        .toDart;

    iPrint('📦 公钥导入成功');

    // 编码明文
    final textEncoder = web.TextEncoder();
    final plaintextData = textEncoder.encode(plaintext);
    final plaintextLength =
        (plaintextData as JSObject).getProperty('length'.toJS) as JSNumber;
    iPrint('📦 明文长度: ${plaintextLength.toDartInt}');

    // 加密（算法参数必须与导入密钥时完全匹配）
    final encryptAlgorithm = _createJSObject();
    _setProperty(encryptAlgorithm, 'name', 'RSA-OAEP'.toJS);
    final encryptHashObj = _createJSObject();
    _setProperty(encryptHashObj, 'name', 'SHA-256'.toJS);
    _setProperty(encryptAlgorithm, 'hash', encryptHashObj);

    final encryptedBuffer = await web.window.crypto.subtle
        .encrypt(
          encryptAlgorithm,
          // ignore: invalid_runtime_check_with_js_interop_types, unnecessary_cast
          publicKey as web.CryptoKey,
          plaintextData,
        )
        .toDart;

    iPrint('📦 加密完成');

    // 转换为 Base64
    final encryptedBase64 = _arrayBufferToBase64(
      encryptedBuffer as JSArrayBuffer,
    );
    iPrint('✅ Web 平台 RSA 加密完成, 结果长度: ${encryptedBase64.length}');

    return encryptedBase64;
  } catch (e, stackTrace) {
    iPrint('❌ Web 平台 RSA 加密失败: $e');
    iPrint('📚 堆栈: $stackTrace');
    if (strNoEmpty(plaintext)) {
      throw Exception('Web 平台 RSA 加密失败: $e');
    }
    rethrow;
  }
}

/// 将 Base64 编码的密钥格式化为 PEM 格式
String _formatAsPem(String base64Key, String header, String footer) {
  // 将 Base64 分割为 64 字符的行
  final lines = <String>[];
  for (int i = 0; i < base64Key.length; i += 64) {
    final end = i + 64 < base64Key.length ? i + 64 : base64Key.length;
    lines.add(base64Key.substring(i, end));
  }

  return '$header\n${lines.join('\n')}\n$footer';
}

/// Web 存储包装器
class WebStorageStub {
  final web.Storage _storage;

  WebStorageStub(this._storage);

  String? getItem(String key) {
    try {
      return _storage.getItem(key);
    } catch (e) {
      iPrint('WebStorageStub.getItem($key) failed: $e');
      return null;
    }
  }

  void setItem(String key, String value) {
    try {
      _storage.setItem(key, value);
    } catch (e) {
      iPrint('WebStorageStub.setItem($key) failed: $e');
    }
  }

  void removeItem(String key) {
    try {
      _storage.removeItem(key);
    } catch (e) {
      iPrint('WebStorageStub.removeItem($key) failed: $e');
    }
  }

  void clear() {
    try {
      _storage.clear();
    } catch (e) {
      iPrint('WebStorageStub.clear() failed: $e');
    }
  }
}

/// Web 窗口包装器
class WebWindowStub {
  WebWindowStub();

  WebStorageStub get localStorage {
    return WebStorageStub(web.window.localStorage);
  }
}

/// 获取 Web 窗口对象
WebWindowStub get webWindow {
  return WebWindowStub();
}
