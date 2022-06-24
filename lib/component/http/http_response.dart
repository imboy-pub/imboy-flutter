import 'http_exceptions.dart';

class IMBoyHttpResponse {
  late bool ok;
  dynamic? payload;
  HttpException? error;

  IMBoyHttpResponse._internal({this.ok = false});

  IMBoyHttpResponse.success(this.payload) {
    this.ok = true;
  }

  IMBoyHttpResponse.failure({String? errorMsg, int? errorCode}) {
    this.error = BadRequestException(message: errorMsg, code: errorCode);
    this.ok = false;
  }

  IMBoyHttpResponse.failureFormResponse({dynamic? payload}) {
    this.error = BadResponseException(payload);
    this.ok = false;
  }

  IMBoyHttpResponse.failureFromError([HttpException? error]) {
    this.error = error ?? UnknownException();
    this.ok = false;
  }
}
