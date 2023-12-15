import 'package:get/get.dart';

import 'http_exceptions.dart';

class IMBoyHttpResponse {
  late bool ok;
  late int code;
  late String msg;
  dynamic payload;

  HttpException? error;

  // IMBoyHttpResponse._internal({this.ok = false});

  IMBoyHttpResponse.success(this.payload) {
    ok = true;
    code = 0;
    msg = 'success';
  }

  IMBoyHttpResponse.failure({String? errMsg, int? errCode, dynamic payload}) {
    error = BadRequestException(message: errMsg, code: errCode);
    msg = errMsg ?? 'unknown error';
    code = errCode ?? 1;
    payload = payload ?? {};
    ok = false;
    // iPrint("IMBoyHttpResponse_failure code $code");
    // iPrint("IMBoyHttpResponse_failure msg $msg");
    // iPrint("IMBoyHttpResponse_failure payload ${payload.toString()}");
  }

  IMBoyHttpResponse.failureFormResponse({dynamic payload}) {
    error = BadResponseException(payload);
    ok = false;
  }

  IMBoyHttpResponse.failureFromError(
      {HttpException? error, int? errCode, String? errMsg}) {
    error = error ?? UnknownException();
    code = errCode ?? 1;
    msg = errMsg ?? 'error'.tr;
    ok = false;
  }
}
