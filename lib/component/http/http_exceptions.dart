// 异常处理
class HttpException implements Exception {
  final String? _message;

  String get message => _message ?? runtimeType.toString();

  final int? _code;

  int get code => _code ?? -1;

  HttpException([this._message, this._code]);

  /// 直接展示 message（人话文案）；未覆写时 UI 若插值异常对象会显示
  /// "Instance of 'BadRequestException'" 这类调试文案（BUG：申诉页偶现）。
  @override
  String toString() => message;
}

/// 客户端请求错误
class BadRequestException extends HttpException {
  BadRequestException({String? message, int? code}) : super(message, code);
}

/// 服务端响应错误
class BadServiceException extends HttpException {
  BadServiceException({String? message, int? code}) : super(message, code);
}

class UnknownException extends HttpException {
  UnknownException([super.message]);
}

class CancelException extends HttpException {
  CancelException([super.message]);
}

class NetworkException extends HttpException {
  NetworkException({String? message, int? code}) : super(message, code);
}

/// 401
class UnauthorisedException extends HttpException {
  UnauthorisedException({String? message, int? code = 401})
    : super(message, code);
}

class BadResponseException extends HttpException {
  dynamic data;

  BadResponseException([this.data]) : super();
}
