import 'package:dio/dio.dart';
import 'package:imboy/component/ui/app_loading.dart';

import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';

class UserCollectApi extends HttpClient {
  Future<Map<String, dynamic>?> page(Map<String, dynamic> args) async {
    IMBoyHttpResponse resp = await get(
      API.userCollectPage,
      queryParameters: args,
    );
    // BUG#128：HttpClient 从不抛异常（fail-open），网络失败只体现为
    // resp.ok == false。必须显式抛出，provider.page() 的 on Exception
    // 分支才能置 loadFailed 标记，页面才会渲染错误横幅而不是静默空态。
    resp.throwIfFailed();
    return resp.payload is Map<String, dynamic>
        ? resp.payload as Map<String, dynamic>
        : null;
  }

  /// 删除收藏
  Future<bool> remove({required String kindId}) async {
    IMBoyHttpResponse resp = await post(
      API.userCollectRemove,
      data: {'kind_id': kindId},
    );
    return resp.ok ? true : false;
  }

  ///
  Future<bool> change(Map<String, dynamic> data) async {
    IMBoyHttpResponse resp = await post(API.userCollectChange, data: data);
    // debugPrint("user_collect_api/change resp: ${resp.payload.toString()}");
    return resp.ok ? true : false;
  }

  /// Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  Future<bool> add(
    int kind,
    String kindId,
    String source,
    Map<String, dynamic> info,
  ) async {
    IMBoyHttpResponse resp = await post(
      API.userCollectAdd,
      data: {'kind': kind, 'kind_id': kindId, 'source': source, 'info': info},
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    // 如果请求失败，显示详细错误信息
    if (!resp.ok) {
      AppLoading.showError(resp.msg.isNotEmpty ? resp.msg : t.common.tipFailed);
    }
    AppLoading.dismiss();
    return resp.ok ? true : false;
  }

  // ------------------------------------------------------------------
  // E2EE 收藏 v1（迁移 227 / PLAN 2026-10-24-e2ee-collect §7）
  // 能力协商：manifest features["e2ee_collect"] != true 时不允许创建
  // sealed 收藏（旧后端组合拒绝，A7）；错误码精确保留供上层分流
  // （5501 升级提示 / 5502 冲突重读 / 5504 密钥同步 / 5505 参数 / 5506 legacy）。
  // ------------------------------------------------------------------

  /// v1 创建/重新收藏（含墓碑复活：服务端复用原行，客户端重新 seal）。
  /// 返回 (ok, generation)：ok=false 时 code 为服务端错误码。
  Future<CollectV1Result> addV1({
    required int kind,
    required String kindId,
    required String infoSealed,
    required int keyVersion,
    required List<String> attachHashes,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userCollectAdd,
      data: {
        'kind': kind,
        'kind_id': kindId,
        'info_sealed': infoSealed,
        'key_version': keyVersion,
        'attach_file_hash256': attachHashes,
      },
      options: Options(
        sendTimeout: const Duration(minutes: 5),
        receiveTimeout: const Duration(minutes: 5),
      ),
    );
    return _v1Result(resp);
  }

  /// v1 编辑（CAS）：expected_generation 匹配才更新。
  Future<CollectV1Result> updateV1({
    required String kindId,
    required int expectedGeneration,
    required int newGeneration,
    required String infoSealed,
    required int keyVersion,
    required List<String> attachHashes,
  }) async {
    IMBoyHttpResponse resp = await post(
      API.userCollectChange,
      data: {
        'action': 'update',
        'kind_id': kindId,
        'expected_generation': expectedGeneration,
        'generation': newGeneration,
        'info_sealed': infoSealed,
        'key_version': keyVersion,
        'attach_file_hash256': attachHashes,
      },
    );
    return _v1Result(resp);
  }

  CollectV1Result _v1Result(IMBoyHttpResponse resp) {
    int? gen;
    if (resp.payload is Map) {
      final raw = (resp.payload as Map)['generation'];
      gen = raw is int
          ? raw
          : raw is num
          ? raw.toInt()
          : null;
    }
    return CollectV1Result(
      ok: resp.ok,
      code: resp.code,
      msg: resp.msg,
      generation: gen,
      idempotent:
          resp.payload is Map && (resp.payload as Map)['idempotent'] == true,
    );
  }
}

/// v1 调用结果：错误码语义见 PLAN §9/错误码 5501-5506。
class CollectV1Result {
  const CollectV1Result({
    required this.ok,
    required this.code,
    required this.msg,
    this.generation,
    this.idempotent = false,
  });

  final bool ok;
  final int code;
  final String msg;
  final int? generation;

  /// 幂等重放成功（同请求字节，服务端已持久化相同状态）。
  final bool idempotent;
}
