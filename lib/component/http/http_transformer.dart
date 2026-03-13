import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'http_response.dart';

/// Response 解析
abstract class HttpTransformer {
  IMBoyHttpResponse parse(Response response, String uri);
}

class DefaultHttpTransformer extends HttpTransformer {
  @override
  IMBoyHttpResponse parse(Response response, String uri) {
    // 安全日志：不输出完整响应数据
    debugPrint("uri $uri, statusCode: ${response.statusCode}");
    if (response.data is! Map) {
      return IMBoyHttpResponse.failure();
    }
    final data = response.data as Map;
    final code = _normalizeCode(data['code']);
    final msg = '${data['msg'] ?? 'error'}';
    final payload = data['payload'];

    if (code == 0) {
      return IMBoyHttpResponse.success(payload);
    }
    return IMBoyHttpResponse.failure(
      errMsg: msg,
      errCode: code,
      payload: payload,
    );
  }

  static int _normalizeCode(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse('$raw') ?? 1;
  }

  /// 单例对象
  static final DefaultHttpTransformer _instance =
      DefaultHttpTransformer._internal();

  /// 内部构造方法，可避免外部暴露构造函数，进行实例化
  DefaultHttpTransformer._internal();

  /// 工厂构造方法，这里使用命名构造函数方式进行声明
  factory DefaultHttpTransformer.getInstance() => _instance;
}
