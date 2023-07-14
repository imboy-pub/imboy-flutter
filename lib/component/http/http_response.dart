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

  IMBoyHttpResponse.failure({String? errMsg, int? errCode}) {
    error = BadRequestException(message: errMsg, code: errCode);
    msg = errMsg ?? '';
    code = errCode ?? 1;
    ok = false;
  }

  IMBoyHttpResponse.failureFormResponse({dynamic payload}) {
    error = BadResponseException(payload);
    ok = false;
  }

  IMBoyHttpResponse.failureFromError({HttpException? error, int? errCode, String? errMsg}) {
    error = error ?? UnknownException();
    code = errCode ?? 1;
    msg = errMsg ?? 'error'.tr;
    ok = false;
  }
}
