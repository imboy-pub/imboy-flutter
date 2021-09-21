import 'http_exceptions.dart';

class HttpResponse {
  late bool ok;
  dynamic? payload;
  HttpException? error;

  HttpResponse._internal({this.ok = false});

  HttpResponse.success(this.payload) {
    this.ok = true;
  }

  HttpResponse.failure({String? errorMsg, int? errorCode}) {
    this.error = BadRequestException(message: errorMsg, code: errorCode);
    this.ok = false;
  }

  HttpResponse.failureFormResponse({dynamic? payload}) {
    this.error = BadResponseException(payload);
    this.ok = false;
  }

  HttpResponse.failureFromError([HttpException? error]) {
    this.error = error ?? UnknownException();
    this.ok = false;
  }
}
