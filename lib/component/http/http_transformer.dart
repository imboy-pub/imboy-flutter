import 'package:dio/dio.dart';

import 'http_response.dart';

/// `Response<dynamic>` 解析
abstract class HttpTransformer {
  IMBoyHttpResponse parse(Response<dynamic> response, String uri);
}

class DefaultHttpTransformer extends HttpTransformer {
  @override
  IMBoyHttpResponse parse(Response<dynamic> response, String uri) {
    // 安全日志：不输出完整响应数据
    if (response.data is! Map) {
      return IMBoyHttpResponse.failure();
    }
    final data = response.data as Map;
    final code = _normalizeCode(data['code']);
    final msg = '${data['msg'] ?? 'error'}';
    final payload = _enrichPayload(data);

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

  /// 服务端 elib_response 会把 extra options（如 field=人类可读错误消息，
  /// friend_handler 统一约定 msg=英文错误码、中文消息在 field）合并到顶层
  /// JSON 而非 payload 内。这里把非 envelope 键合入 payload，供上层统一读取。
  static dynamic _enrichPayload(Map<dynamic, dynamic> data) {
    final payload = data['payload'];
    final extras = Map.fromEntries(
      data.entries.where(
        (e) =>
            e.key != 'code' &&
            e.key != 'msg' &&
            e.key != 'sv_ts' &&
            e.key != 'payload',
      ),
    );
    if (extras.isEmpty) {
      return payload;
    }
    if (payload is Map) {
      return {...extras, ...Map<String, dynamic>.from(payload)};
    }
    return extras;
  }

  /// 单例对象
  static final DefaultHttpTransformer _instance =
      DefaultHttpTransformer._internal();

  /// 内部构造方法，可避免外部暴露构造函数，进行实例化
  DefaultHttpTransformer._internal();

  /// 工厂构造方法，这里使用命名构造函数方式进行声明
  factory DefaultHttpTransformer.getInstance() => _instance;
}
