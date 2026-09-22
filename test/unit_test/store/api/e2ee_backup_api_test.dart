import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/store/api/e2ee_backup_api.dart';

/// E2EE 备份 API 的取消语义。
///
/// 页面侧「上传总超时」与「稍后再说」都依赖 cancelToken 一路透传到 HTTP 层
/// 才能真正掐断在途请求；否则页面已经离开，请求仍在后台空转到重试耗尽。
/// 这里用 fake 子类记录透传参数（项目 API 层测试惯例，见
/// conversation_api_test.dart），不发真实请求。
class _RecordingBackupApi extends E2EEBackupApi {
  _RecordingBackupApi({required this.postResponse});

  IMBoyHttpResponse postResponse;
  dynamic getPayload = const <String, dynamic>{};

  final List<Map<String, dynamic>> postCalls = <Map<String, dynamic>>[];
  final List<Map<String, dynamic>> getCalls = <Map<String, dynamic>>[];

  @override
  Future<IMBoyHttpResponse> post(
    String uri, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    postCalls.add(<String, dynamic>{
      'uri': uri,
      'cancelToken': cancelToken,
      'data': data,
    });
    return postResponse;
  }

  @override
  Future<IMBoyHttpResponse> get(
    String uri, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    httpTransformer,
  }) async {
    getCalls.add(<String, dynamic>{'uri': uri, 'cancelToken': cancelToken});
    return IMBoyHttpResponse.success(getPayload);
  }
}

void main() {
  Future<E2EEBackupPutResult> callPutBackup(
    E2EEBackupApi api, {
    CancelToken? cancelToken,
  }) {
    return api.putBackup(
      backupVersion: 1,
      kdfSalt: 'c2FsdA==',
      kdfIterations: 310000,
      encryptedPayload: 'cGF5bG9hZA==',
      payloadHash: 'hash',
      cancelToken: cancelToken,
    );
  }

  test('info 把 cancelToken 透传给 HTTP 层', () async {
    final api = _RecordingBackupApi(
      postResponse: IMBoyHttpResponse.success(const <String, dynamic>{}),
    )..getPayload = <String, dynamic>{'has_backup': false, 'backup_version': 0};
    final cancelToken = CancelToken();

    await api.info(cancelToken: cancelToken);

    expect(api.getCalls.single['cancelToken'], same(cancelToken));
  });

  test('putBackup 把 cancelToken 透传给 HTTP 层', () async {
    final api = _RecordingBackupApi(
      postResponse: IMBoyHttpResponse.success(<String, dynamic>{
        'backup_version': 2,
      }),
    );
    final cancelToken = CancelToken();

    final result = await callPutBackup(api, cancelToken: cancelToken);

    expect(result.ok, isTrue);
    expect(api.postCalls.single['cancelToken'], same(cancelToken));
  });

  test('未取消时服务端 409 正常上报 versionConflict（对照组）', () async {
    final api = _RecordingBackupApi(
      postResponse: IMBoyHttpResponse.failure(errMsg: '版本冲突', errCode: 409),
    );

    final result = await callPutBackup(api);

    expect(result.ok, isFalse);
    expect(result.versionConflict, isTrue);
  });

  test('已取消时即使服务端 409 也不上报 versionConflict（提前返回）', () async {
    final api = _RecordingBackupApi(
      postResponse: IMBoyHttpResponse.failure(errMsg: '版本冲突', errCode: 409),
    );
    final cancelToken = CancelToken();
    cancelToken.cancel('user_postponed');

    final result = await callPutBackup(api, cancelToken: cancelToken);

    // 取消分支必须提前返回：走到末尾会把 409 标成 versionConflict，既误导
    // 调用方，也会让 E2EEServerBackupService.upload 白跑一轮 409 重试。
    // 这一条同时守住了页面侧「已取消不弹后端错误提示」的前提。
    expect(result.ok, isFalse);
    expect(result.versionConflict, isFalse);
  });
}
