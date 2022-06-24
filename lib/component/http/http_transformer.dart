import 'package:dio/dio.dart';

import 'http_response.dart';

/// Response 解析
abstract class HttpTransformer {
  IMBoyHttpResponse parse(Response response);
}

class DefaultHttpTransformer extends HttpTransformer {
  @override
  IMBoyHttpResponse parse(Response response) {
    if (response.data["status"] == 100) {
      return IMBoyHttpResponse.success(response.data["payload"]);
    } else if (response.data["code"] == 0) {
      return IMBoyHttpResponse.success(response.data["payload"]);
    } else {
      return IMBoyHttpResponse.failure(
          errorMsg: response.data["msg"], errorCode: response.data["code"]);
    }
  }

  /// 单例对象
  static DefaultHttpTransformer _instance = DefaultHttpTransformer._internal();

  /// 内部构造方法，可避免外部暴露构造函数，进行实例化
  DefaultHttpTransformer._internal();

  /// 工厂构造方法，这里使用命名构造函数方式进行声明
  factory DefaultHttpTransformer.getInstance() => _instance;
}
