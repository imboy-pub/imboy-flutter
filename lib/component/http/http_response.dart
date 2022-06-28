import 'http_exceptions.dart';

class IMBoyHttpResponse {
  late bool ok;
  dynamic payload;
  HttpException? error;

  // IMBoyHttpResponse._internal({this.ok = false});

  IMBoyHttpResponse.success(this.payload) {
    ok = true;
  }

  IMBoyHttpResponse.failure({String? errorMsg, int? errorCode}) {
    error = BadRequestException(message: errorMsg, code: errorCode);
    ok = false;
  }

  IMBoyHttpResponse.failureFormResponse({dynamic payload}) {
    error = BadResponseException(payload);
    ok = false;
  }

  IMBoyHttpResponse.failureFromError([HttpException? error]) {
    error = error ?? UnknownException();
    ok = false;
  }
}
