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
    this.connectTimeout = 15000, // 15 秒连接超时
    this.sendTimeout = 30000, // 30 秒发送超时
    this.receiveTimeout = 30000, // 30 秒接收超时
  });
}

// https://github.com/dart-lang/web_socket_channel/issues/134
class GlobalHttpOverrides extends io.HttpOverrides {
  /// 开发环境允许自签名证书的主机白名单
  static const _devAllowedHosts = <String>{
    'localhost',
    '127.0.0.1',
    '10.0.2.2', // Android 模拟器 host
  };

  @override
  io.HttpClient createHttpClient(io.SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (io.X509Certificate cert, String host, int port) {
            // 仅在开发环境且主机在白名单内时接受自签名证书
            if (currentEnv == 'dev' || currentEnv.startsWith('local')) {
              return _devAllowedHosts.contains(host) ||
                  host.endsWith('.imboy.pub');
            }
            // 生产环境进行严格验证
            return false;
          };
  }
}
