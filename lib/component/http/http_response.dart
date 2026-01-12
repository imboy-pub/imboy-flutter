
import 'http_exceptions.dart';
import 'package:imboy/component/helper/ntp.dart';
import 'package:imboy/i18n/strings.g.dart';

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

    // 从服务器响应中提取时间戳并更新时间偏移
    if (payload is Map && payload.containsKey('sv_ts')) {
      try {
        final serverTs = int.parse('${payload['sv_ts']}');
        NtpHelper.updateOffsetFromServer(serverTs);
      } catch (e) {
        // 解析失败，忽略
      }
    }
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
    msg = errMsg ?? t.errorUnexpected;
    ok = false;
  }
}
