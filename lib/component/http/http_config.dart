import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:imboy/config/init.dart';

/// dio 配置项
class HttpConfig {
  final String? baseUrl;
  final String? proxy;
  final String? cookiesPath;
  final List<Interceptor>? interceptors;
  final int connectTimeout;
  final int sendTimeout;
  final int receiveTimeout;
  final Map<String, dynamic>? headers;

  HttpConfig({
    this.baseUrl,
    this.headers,
    this.proxy,
    this.cookiesPath,
    this.interceptors,
    this.connectTimeout = Duration.millisecondsPerMinute,
    this.sendTimeout = Duration.millisecondsPerMinute,
    this.receiveTimeout = Duration.millisecondsPerMinute,
  });
}

// https://github.com/dart-lang/web_socket_channel/issues/134
class GlobalHttpOverrides extends io.HttpOverrides {
  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    // 安全的证书验证：仅开发环境允许自签名证书
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (io.X509Certificate cert, String host, int port) {
            // 仅在开发环境接受自签名证书
            if (currentEnv == 'dev' || currentEnv.startsWith('local')) {
              return true;
            }
            // 生产环境进行严格验证
            return false;
          };
  }
}
