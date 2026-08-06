import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/e2ee/otk_refill_policy.dart';
import 'package:imboy/store/api/olm_api.dart';

/// E2EE-062 第六刀：客户端接真实 OTK 余量（残留 ①）。
///
/// == 缺口 ==
///
/// 服务端第五刀已开出 `GET /api/v1/e2ee/olm/prekey_count`
/// （imboy `evidence/E2EE-062-prekey-count-endpoint.md`），但客户端
/// `OlmApi.countPrekeys` 仍是**恒返回 0 的桩实现**。后果不只是「补传信号缺失」：
///
/// `remaining` 恒为 0 → 恒判定低水位 → **每次**都全量重发。
/// 而 `report_one_time_keys` 是**全量替换式**（先删后插，见 imboy
/// `olm_identity_logic:report_one_time_keys/4` 文档注释），
/// 于是每次入站建会话都把整个 OTK 池推倒重来。
///
/// == 本文件守护 ==
///
/// 1. 余量充足 → 不补（今天恒补的行为必须消失）；
/// 2. 余量低于水位 → 补到目标值；
/// 3. 【安全 / fail-closed】余量**未知**（查询失败）→ **不补**。
///    在未知状态上执行全量替换是破坏性动作；池饿一会儿只会降级到 fallback
///    prekey（既定降级路径），下次查询成功即恢复；
/// 4. 【正向可用性】余量 = 0（真的空了）→ **必须补**。
///    把「未知」和「0」混为一谈的实现会在这两条里必错其一；
/// 5. 首次注册（seed）→ 不依赖查询，直接铺满。否则查询一失败，
///    新设备将永远没有 OTK；
/// 6. 解析层必须把「查询失败」表达为 `null` 而不是 0。
void main() {
  const low = 5;
  const target = 50;

  group('otkRefillCount 决策', () {
    test('对照组：余量为 0 时必须补满（这条今天就成立，改后仍须成立）', () {
      expect(
        otkRefillCount(remaining: 0, lowWaterMark: low, targetCount: target),
        target,
      );
    });

    test('余量充足 → 不补', () {
      expect(
        otkRefillCount(remaining: 50, lowWaterMark: low, targetCount: target),
        0,
      );
      expect(
        otkRefillCount(remaining: low, lowWaterMark: low, targetCount: target),
        0,
        reason: '恰好等于水位线不算低水位',
      );
    });

    test('余量低于水位 → 补到目标值', () {
      expect(
        otkRefillCount(remaining: 4, lowWaterMark: low, targetCount: target),
        target - 4,
      );
      expect(
        otkRefillCount(remaining: 1, lowWaterMark: low, targetCount: target),
        target - 1,
      );
    });

    test('fail-closed：余量未知 → 不补（不得在未知状态上做全量替换）', () {
      expect(
        otkRefillCount(remaining: null, lowWaterMark: low, targetCount: target),
        0,
        reason: 'report_one_time_keys 是全量替换式；未知即动手 = 破坏性动作',
      );
    });

    test('未知与 0 必须区分对待', () {
      final unknown = otkRefillCount(
        remaining: null,
        lowWaterMark: low,
        targetCount: target,
      );
      final empty = otkRefillCount(
        remaining: 0,
        lowWaterMark: low,
        targetCount: target,
      );
      expect(unknown, isNot(empty));
    });

    test('seed：首次注册不依赖查询，直接铺满', () {
      expect(
        otkRefillCount(
          remaining: null,
          lowWaterMark: low,
          targetCount: target,
          seed: true,
        ),
        target,
        reason: '否则一次查询失败就让新设备永远没有 OTK',
      );
    });
  });

  group('prekey_count 响应解析', () {
    test('正常载荷 → 取出 count', () {
      expect(OlmApi.parseCountPayload({'count': 17}), 17);
      expect(OlmApi.parseCountPayload({'count': 0}), 0);
    });

    test('缺字段 / 类型不对 / 非 Map → null（未知），不得当 0', () {
      expect(OlmApi.parseCountPayload(null), isNull);
      expect(OlmApi.parseCountPayload(<String, dynamic>{}), isNull);
      expect(OlmApi.parseCountPayload({'count': 'abc'}), isNull);
      expect(OlmApi.parseCountPayload('not a map'), isNull);
    });

    test('负数视为未知（服务端不会返回，收到即异常）', () {
      expect(OlmApi.parseCountPayload({'count': -1}), isNull);
    });
  });

  group('端点常量', () {
    test('必须指向服务端第五刀注册的路由', () {
      expect(API.olmPrekeyCount, '/api/v1/e2ee/olm/prekey_count');
    });
  });
}
