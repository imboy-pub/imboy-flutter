import 'http_exceptions.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/helper/ntp.dart';

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
    if (payload is Map && payload.containsKey('sv_ts') == true) {
      try {
        final serverTs = int.parse('${payload['sv_ts']}');
        NtpHelper.updateOffsetFromServer(serverTs);
      } catch (e) {
        // sv_ts 仅用于 NTP 时间偏移校正，解析失败不影响响应本身，
        // 但仍记录一下便于排查持续的时钟漂移问题。
        iPrint('[HttpResponse] parse sv_ts failed: $e');
      }
    }
  }

  IMBoyHttpResponse.failure({String? errMsg, int? errCode, dynamic payload}) {
    error = BadRequestException(message: errMsg, code: errCode);
    msg = errMsg ?? 'unknown error';
    code = errCode ?? 1;
    this.payload = payload ?? <String, dynamic>{};
    ok = false;
    // iPrint("IMBoyHttpResponse_failure code $code");
    // iPrint("IMBoyHttpResponse_failure msg $msg");
    // iPrint("IMBoyHttpResponse_failure payload ${payload.toString()}");
  }

  IMBoyHttpResponse.failureFormResponse({dynamic payload}) {
    error = BadResponseException(payload);
    code = 1;
    msg = 'bad response';
    this.payload = payload ?? <String, dynamic>{};
    ok = false;
  }

  IMBoyHttpResponse.failureFromError({
    HttpException? error,
    int? errCode,
    String? errMsg,
  }) {
    this.error = error ?? UnknownException();
    code = errCode ?? this.error!.code;
    msg = errMsg ?? this.error!.message;
    payload = <String, dynamic>{};
    ok = false;
  }
}
