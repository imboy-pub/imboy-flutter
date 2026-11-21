import 'package:flutter_test/flutter_test.dart';
import 'package:geo_regions/geo_regions.dart';

import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/service/user_profile_service.dart';

/// UserProfileService.updateField 单元测试
///
/// 统一 PersonalInfoPage 与 ProfilePage 重复的「PUT 更新字段 + 同步本地缓存」逻辑，
/// 消除 DRY 漂移。通过可选回调注入隔离 HttpClient / UserRepoLocal 单例依赖。
///
/// FL-09：账号保存围栏（切账号迟到/持久写失败/legacy冲突/稳定路径身份）
/// 与 geo_regions 结构化地区身份（regionSelection 协议）。
void main() {
  group('Web settings own projection', () {
    for (final value in [false, 0, 'false', '0', 'no', 'off', ' FALSE ']) {
      test('legacy explicit visibility false remains false: $value', () {
        final parsed = UserProfileService.parseWebSettings({
          'allow_search': 2,
          'enable_visibility_read': value,
          'visibility_read_fraction': '0.83',
          'visibility_read_delay_ms': '1350',
          'font_size': 'huge',
          'manual_pending': 'must-not-copy',
        });
        expect(parsed['allow_search'], isFalse);
        expect(parsed['enable_visibility_read'], isFalse);
        expect(parsed['visibility_read_fraction'], .83);
        expect(parsed['visibility_read_delay_ms'], 1350);
        expect(parsed['font_size'], 'huge');
        expect(parsed.length, 5);
      });
    }
    test('complete empty setting keeps existing model defaults', () {
      final parsed = UserProfileService.parseWebSettings(<String, dynamic>{});
      expect(parsed['enable_visibility_read'], isTrue);
      expect(parsed['font_size'], 'normal');
    });
    for (final bad in [
      null,
      {'enable_visibility_read': 'garbage'},
      {'allow_search': <Object?>[]},
      {'visibility_read_fraction': 'oops'},
      {'font_size': 'extra_large'},
    ]) {
      test('known bad settings never silently fall back: $bad', () {
        expect(
          () => UserProfileService.parseWebSettings(bad),
          throwsFormatException,
        );
      });
    }
  });
  group('UserProfileService.updateField', () {
    test('成功时返回 true，并以 {field,value} 发起 PUT', () async {
      Map<String, dynamic>? sentData;
      Map<String, dynamic>? savedPayload;

      final ok = await UserProfileService.updateField(
        'avatar',
        'u123/file_x/a.png',
        httpPut: (data) async {
          sentData = data;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readCurrent: () => <String, dynamic>{'avatar': 'old', 'nickname': 'n'},
        saveLocal: (p) async {
          savedPayload = p;
          return true;
        },
      );

      expect(ok, isTrue);
      expect(sentData, {'field': 'avatar', 'value': 'u123/file_x/a.png'});
      // 顶层字段写入本地 payload
      expect(savedPayload!['avatar'], 'u123/file_x/a.png');
      expect(savedPayload!['nickname'], 'n');
    });

    test('PUT 失败时返回 false，且不写本地缓存', () async {
      var savedCalled = false;

      final ok = await UserProfileService.updateField(
        'avatar',
        'u123/file_x/a.png',
        httpPut: (_) async =>
            IMBoyHttpResponse.failure(errMsg: 'boom', errCode: 1),
        readCurrent: () => <String, dynamic>{},
        saveLocal: (_) async {
          savedCalled = true;
          return true;
        },
      );

      expect(ok, isFalse);
      expect(savedCalled, isFalse);
    });

    test('隐私设置字段写入 payload[setting] 而非顶层', () async {
      Map<String, dynamic>? savedPayload;

      final ok = await UserProfileService.updateField(
        'allow_search',
        false,
        httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
        readCurrent: () => <String, dynamic>{'setting': <String, dynamic>{}},
        saveLocal: (p) async {
          savedPayload = p;
          return true;
        },
      );

      expect(ok, isTrue);
      expect(savedPayload!['setting'], isA<Map<String, dynamic>>());
      // QA#18: allow_search 后端权威值域 1|2，service 将 bool false 归一为 2 落缓存
      expect((savedPayload!['setting'] as Map)['allow_search'], 2);
      // 顶层不应混入该字段
      expect(savedPayload!.containsKey('allow_search'), isFalse);
    });

    test('setting 缺失或非 Map 时安全初始化为 Map', () async {
      Map<String, dynamic>? savedPayload;

      final ok = await UserProfileService.updateField(
        'show_online_status',
        true,
        httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
        // setting 字段缺失
        readCurrent: () => <String, dynamic>{'avatar': 'a'},
        saveLocal: (p) async {
          savedPayload = p;
          return true;
        },
      );

      expect(ok, isTrue);
      expect(savedPayload!['setting'], isA<Map<String, dynamic>>());
      expect((savedPayload!['setting'] as Map)['show_online_status'], true);
    });
  });

  // ===================================================================
  // FL-09 负例与合同组
  //
  // 依据：
  // - 后端 user_agg:validate_update 支持 `regionSelection` 字段，
  //   value 恰为 #{region => binary(<=80), selection => protocolMap}；
  //   读侧状态机 region_selection_status/2 → resolved/empty/unresolved；
  //   user_logic:authoritative_region/1 以 pinned 数据集重算权威展示并精确比对。
  // - UserRepoLocal.changeInfo 已有 expectedUid/expectedGeneration/
  //   expectedEnvironment/expectedEndpoint 围栏契约；updateField 在 PUT 前
  //   捕获同一来源的会话快照，迟到响应拒绝本地落盘。
  // ===================================================================

  /// geo_regions 协议合法 selection（PROTOCOL.md §8 / models.dart GeoSelection）。
  const validSelection = <String, dynamic>{
    'protocolVersion': '1.0',
    'datasetId': 'geo-regions-seed',
    'countryCode': 'JP',
    'dataRevision': 's-0000000000000000',
    'pathIds': <String>['cc:JP'],
  };

  /// 带权威展示快照的 selection（后端 authoritative_region 比对基准）。
  const displayedSelection = <String, dynamic>{
    'protocolVersion': '1.0',
    'datasetId': 'geo-regions-seed',
    'countryCode': 'JP',
    'dataRevision': 's-0000000000000000',
    'pathIds': <String>['cc:JP'],
    'displaySnapshot': <String>['日本', '東京'],
    'displayLocale': 'zh-Hans',
  };

  UserProfileSessionSnapshot session(
    String uid, {
    int generation = 7,
    String environment = 'dev',
    String endpoint = 'http://127.0.0.1:9800',
  }) => UserProfileSessionSnapshot(
    uid: uid,
    generation: generation,
    environment: environment,
    endpoint: endpoint,
  );

  group('FL-09 账号保存围栏负例（第一轮缺口证明，实现后须全绿）', () {
    test('N1 切账号迟到：PUT 后会话已切换，本地缓存不得被污染', () async {
      // 集成负例：真实 UserRepoLocal + StorageService（unit_test config 已初始化）。
      // 与 test/unit_test/service/geo_regions_host_test.dart 的账号切换模拟同款：
      // 直接改写 Keys.currentUid。
      await StorageService.setMap(Keys.currentUser, <String, dynamic>{
        'uid': '510001',
        'account': 'a@test',
        'nickname': 'A',
      });
      await StorageService.to.setString(Keys.currentUid, '510001');

      Map<String, dynamic>? sent;
      final ok = await UserProfileService.updateField(
        'nickname',
        'x',
        httpPut: (data) async {
          sent = data;
          // 模拟 PUT 在途时切到账号 B（迟到响应场景）。
          await StorageService.to.setString(Keys.currentUid, '510002');
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
      );

      expect(sent, {'field': 'nickname', 'value': 'x'});
      // 围栏拒绝：迟到写不得伪装成功（PLANNED: 切账号迟到）。
      expect(ok, isFalse);
      // 本地缓存不得被污染：仍是被切换前账号 A 的资料原值。
      expect(UserRepoLocal.to.current.nickname, 'A');
      expect(UserRepoLocal.to.current.uid, '510001');
    });

    test('N2 本地资料读取失败：收敛为 false，不得异常逃逸或伪装成功', () async {
      var threw = false;
      var ok = true;
      try {
        ok = await UserProfileService.updateField(
          'nickname',
          'x',
          httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
          readCurrent: () => throw StateError('local profile read failed'),
          saveLocal: (_) async => true,
        );
      } catch (_) {
        threw = true;
      }
      expect(threw, isFalse, reason: '持久链路失败必须收敛，不得异常逃逸');
      expect(ok, isFalse, reason: '本地缓存未同步时不得返回 true');
    });

    test('N3 结构化区域身份必须随资料模型往返保留（旧字符串并行兼容）', () {
      final model = UserModel.fromJson(<String, dynamic>{
        'uid': '510001',
        'region': '日本 东京',
        'regionSelection': validSelection,
      });
      final out = model.toMap();
      // 旧字符串合同不受影响。
      expect(out['region'], '日本 东京');
      // 结构化身份不得在 fromJson/toMap 往返中静默丢失。
      expect(
        out['regionSelection'],
        isNotNull,
        reason: '结构化身份往返丢失 → 刷新后降级为纯字符串，稳定路径身份不成立',
      );
    });

    test('N4 regionSelection 保存成功后本地 region 字符串与状态必须同步', () async {
      Map<String, dynamic>? sent;
      Map<String, dynamic>? saved;
      final ok = await UserProfileService.updateField(
        'regionSelection',
        <String, dynamic>{'region': '日本 東京', 'selection': displayedSelection},
        httpPut: (data) async {
          sent = data;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readCurrent: () => <String, dynamic>{'region': '旧串'},
        saveLocal: (p) async {
          saved = p;
          return true;
        },
      );

      expect(sent!['field'], 'regionSelection');
      expect(sent!['value'], {
        'region': '日本 東京',
        'selection': displayedSelection,
      });
      expect(ok, isTrue);
      // 本地 region 字符串必须与已提交的结构化身份一致（不猜测、不丢资料）。
      expect(saved!['region'], '日本 東京');
      expect(
        saved!['regionSelectionStatus'],
        'resolved',
        reason: '后端仅在权威校验通过后才接受 → 读侧状态为 resolved',
      );
    });
  });

  group('FL-09 会话围栏（readSession 注入，uid/世代/环境/端点四维度）', () {
    Future<bool> runUpdate({
      required UserProfileSessionSnapshot atEntry,
      UserProfileSessionSnapshot? atCommit,
      Future<bool> Function(Map<String, dynamic> payload)? saveLocal,
    }) {
      // readSession 语义 = 每次调用读当前会话：首次在 PUT 前（entry），
      // 提交本地缓存前再读（commit）。闭包按调用次序模拟会话迁移。
      var read = 0;
      return UserProfileService.updateField(
        'nickname',
        'x',
        httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
        readCurrent: () => <String, dynamic>{'nickname': 'old'},
        saveLocal: saveLocal ?? (_) async => true,
        readSession: () {
          read += 1;
          return read == 1 ? atEntry : (atCommit ?? atEntry);
        },
      );
    }

    test('会话未变：照常落本地缓存并返回 true', () async {
      Map<String, dynamic>? saved;
      final ok = await runUpdate(
        atEntry: session('510001'),
        saveLocal: (p) async {
          saved = p;
          return true;
        },
      );
      expect(ok, isTrue);
      expect(saved!['nickname'], 'x');
    });

    test('uid 变化（切账号迟到）：拒绝落盘', () async {
      var saveCalled = false;
      final ok = await runUpdate(
        atEntry: session('510001'),
        atCommit: session('510002'),
        saveLocal: (_) async {
          saveCalled = true;
          return true;
        },
      );
      expect(ok, isFalse);
      expect(saveCalled, isFalse);
    });

    test('世代变化（成员世代推进）：拒绝落盘', () async {
      var saveCalled = false;
      final ok = await runUpdate(
        atEntry: session('510001'),
        atCommit: session('510001', generation: 8),
        saveLocal: (_) async {
          saveCalled = true;
          return true;
        },
      );
      expect(ok, isFalse);
      expect(saveCalled, isFalse);
    });

    test('环境变化：拒绝落盘', () async {
      var saveCalled = false;
      final ok = await runUpdate(
        atEntry: session('510001'),
        atCommit: session('510001', environment: 'pro'),
        saveLocal: (_) async {
          saveCalled = true;
          return true;
        },
      );
      expect(ok, isFalse);
      expect(saveCalled, isFalse);
    });

    test('端点变化：拒绝落盘', () async {
      var saveCalled = false;
      final ok = await runUpdate(
        atEntry: session('510001'),
        atCommit: session('510001', endpoint: 'http://127.0.0.1:9801'),
        saveLocal: (_) async {
          saveCalled = true;
          return true;
        },
      );
      expect(ok, isFalse);
      expect(saveCalled, isFalse);
    });

    test('本地持久写返回 false：updateField 不伪装成功', () async {
      final ok = await runUpdate(
        atEntry: session('510001'),
        saveLocal: (_) async => false,
      );
      expect(ok, isFalse);
    });

    test('本地持久写抛异常：收敛为 false，不异常逃逸', () async {
      final ok = await runUpdate(
        atEntry: session('510001'),
        saveLocal: (_) => throw StateError('persist failed'),
      );
      expect(ok, isFalse);
    });
  });

  group('FL-09 regionSelection 结构化保存', () {
    GeoSelection selectionWithDisplay() => const GeoSelection(
      protocolVersion: '1.0',
      datasetId: 'geo-regions-seed',
      countryCode: 'JP',
      dataRevision: 's-0000000000000000',
      pathIds: ['cc:JP'],
      displaySnapshot: ['日本', '東京'],
      displayLocale: 'zh-Hans',
    );

    test('正常：PUT value 恰为 {region, selection}，本地三键一致同步', () async {
      Map<String, dynamic>? sent;
      Map<String, dynamic>? saved;
      final ok = await UserProfileService.updateRegionSelection(
        selectionWithDisplay(),
        httpPut: (data) async {
          sent = data;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readCurrent: () => <String, dynamic>{'region': '旧串'},
        saveLocal: (p) async {
          saved = p;
          return true;
        },
        readSession: () => session('510001'),
      );
      expect(ok, isTrue);
      expect(sent!['field'], 'regionSelection');
      expect(sent!['value'], {
        'region': '日本 東京',
        'selection': displayedSelection,
      }, reason: '后端要求恰好两键且展示串与权威路径一致');
      expect(saved!['region'], '日本 東京');
      expect(saved!['regionSelection'], displayedSelection);
      expect(saved!['regionSelectionStatus'], 'resolved');
    });

    test('无展示快照：本地拒绝，不猜测展示串、不发请求', () async {
      var putCalled = false;
      final ok = await UserProfileService.updateRegionSelection(
        const GeoSelection(
          protocolVersion: '1.0',
          datasetId: 'geo-regions-seed',
          countryCode: 'JP',
          dataRevision: 's-0000000000000000',
          pathIds: ['cc:JP'],
        ),
        httpPut: (_) async {
          putCalled = true;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readSession: () => session('510001'),
      );
      expect(ok, isFalse);
      expect(putCalled, isFalse);
    });

    test('快照含空白名：本地拒绝（镜像后端空名拒绝）', () async {
      var putCalled = false;
      final ok = await UserProfileService.updateRegionSelection(
        const GeoSelection(
          protocolVersion: '1.0',
          datasetId: 'geo-regions-seed',
          countryCode: 'JP',
          dataRevision: 's-0000000000000000',
          pathIds: ['cc:JP'],
          displaySnapshot: ['日本', ' '],
        ),
        httpPut: (_) async {
          putCalled = true;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readSession: () => session('510001'),
      );
      expect(ok, isFalse);
      expect(putCalled, isFalse);
    });

    test('展示串超长（>80 字符）：本地拒绝（镜像后端兼容长度）', () async {
      var putCalled = false;
      final ok = await UserProfileService.updateRegionSelection(
        GeoSelection(
          protocolVersion: '1.0',
          datasetId: 'geo-regions-seed',
          countryCode: 'JP',
          dataRevision: 's-0000000000000000',
          pathIds: const ['cc:JP'],
          displaySnapshot: ['あ' * 45, 'い' * 45],
        ),
        httpPut: (_) async {
          putCalled = true;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readSession: () => session('510001'),
      );
      expect(ok, isFalse);
      expect(putCalled, isFalse);
    });

    test('selection 协议版本不支持：本地拒绝，不发请求', () async {
      var putCalled = false;
      final ok = await UserProfileService.updateField(
        'regionSelection',
        <String, dynamic>{
          'region': '日本 東京',
          'selection': const <String, dynamic>{
            'protocolVersion': '2.0',
            'datasetId': 'geo-regions-seed',
            'countryCode': 'JP',
            'dataRevision': 's-0000000000000000',
            'pathIds': <String>['cc:JP'],
            'displaySnapshot': <String>['日本', '東京'],
          },
        },
        httpPut: (_) async {
          putCalled = true;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readSession: () => session('510001'),
      );
      expect(ok, isFalse);
      expect(putCalled, isFalse);
    });

    test('value 多于两键：本地拒绝（镜像后端 map_size=2）', () async {
      var putCalled = false;
      final ok = await UserProfileService.updateField(
        'regionSelection',
        <String, dynamic>{
          'region': '日本 東京',
          'selection': displayedSelection,
          'extra': 1,
        },
        httpPut: (_) async {
          putCalled = true;
          return IMBoyHttpResponse.success(<String, dynamic>{});
        },
        readSession: () => session('510001'),
      );
      expect(ok, isFalse);
      expect(putCalled, isFalse);
    });

    test('后端拒绝：返回 false 且不写本地缓存', () async {
      var saveCalled = false;
      final ok = await UserProfileService.updateRegionSelection(
        selectionWithDisplay(),
        httpPut: (_) async => IMBoyHttpResponse.failure(errMsg: '', errCode: 1),
        readCurrent: () => <String, dynamic>{},
        saveLocal: (_) async {
          saveCalled = true;
          return true;
        },
        readSession: () => session('510001'),
      );
      expect(ok, isFalse);
      expect(saveCalled, isFalse);
    });

    test('会话切换：拒绝落盘（服务端已按旧账号提交，本地不污染新账号）', () async {
      var saveCalled = false;
      var entryRead = false;
      final ok = await UserProfileService.updateRegionSelection(
        selectionWithDisplay(),
        httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
        readCurrent: () => <String, dynamic>{},
        saveLocal: (_) async {
          saveCalled = true;
          return true;
        },
        readSession: () {
          if (!entryRead) {
            entryRead = true;
            return session('510001');
          }
          return session('510002');
        },
      );
      expect(ok, isFalse);
      expect(saveCalled, isFalse);
    });

    test('legacy region 写不触碰已缓存的结构化身份（不丢资料）', () async {
      Map<String, dynamic>? saved;
      final ok = await UserProfileService.updateField(
        'region',
        '中国香港 中西区',
        httpPut: (_) async => IMBoyHttpResponse.success(<String, dynamic>{}),
        readCurrent: () => <String, dynamic>{
          'region': '中国香港',
          'regionSelection': displayedSelection,
          'regionSelectionStatus': 'unresolved',
        },
        saveLocal: (p) async {
          saved = p;
          return true;
        },
        readSession: () => session('510001'),
      );
      expect(ok, isTrue);
      expect(saved!['region'], '中国香港 中西区');
      // 结构化身份原值保留：同名/旧码/撤并歧义不由客户端猜测改写。
      expect(saved!['regionSelection'], displayedSelection);
      expect(saved!['regionSelectionStatus'], 'unresolved');
    });
  });

  group('FL-09 UserModel 结构化身份', () {
    test('协议 map 解析为类型化身份，往返保留', () {
      final model = UserModel.fromJson(<String, dynamic>{
        'uid': '510001',
        'region': '日本 東京',
        'regionSelection': displayedSelection,
        'regionSelectionStatus': 'resolved',
      });
      expect(model.regionSelection, isNotNull);
      expect(model.regionSelection!.countryCode, 'JP');
      expect(model.regionSelection!.pathIds, ['cc:JP']);
      expect(model.regionSelectionStatus, 'resolved');

      final out = model.toMap();
      expect(out['region'], '日本 東京', reason: '旧字符串并行兼容');
      expect(out['regionSelection'], displayedSelection);
      expect(out['regionSelectionStatus'], 'resolved');

      final reparsed = UserModel.fromJson(out);
      expect(
        reparsed.regionSelection,
        model.regionSelection,
        reason: '稳定路径身份：往返后身份字段不变',
      );
    });

    test('展示语言变化不改变身份（语言变化不触发保存的模型基础）', () {
      final zh = UserModel.fromJson(<String, dynamic>{
        'regionSelection': displayedSelection,
      }).regionSelection!;
      final en = UserModel.fromJson(<String, dynamic>{
        'regionSelection': const <String, dynamic>{
          'protocolVersion': '1.0',
          'datasetId': 'geo-regions-seed',
          'countryCode': 'JP',
          'dataRevision': 's-0000000000000000',
          'pathIds': <String>['cc:JP'],
          'displaySnapshot': <String>['Japan', 'Tokyo'],
          'displayLocale': 'en',
        },
      }).regionSelection!;
      // GeoSelection == 只覆盖身份字段（protocolVersion/datasetId/
      // countryCode/dataRevision/pathIds），displaySnapshot/locale 是展示便利。
      expect(zh == en, isTrue, reason: '展示语言变化不得造成身份差异 → 保存触发器不会因语言误触发');
    });

    test('后端未提供结构化字段：不假定存在，旧字符串照常工作', () {
      final model = UserModel.fromJson(<String, dynamic>{
        'uid': '510001',
        'region': '旧地区串',
      });
      expect(model.regionSelection, isNull);
      expect(model.regionSelectionStatus, '');
      expect(model.region, '旧地区串');
      final out = model.toMap();
      expect(out['regionSelection'], isNull);
      expect(out['regionSelectionStatus'], '');
    });

    test('无效/不支持版本：保留旧串原值并标 unresolved，不猜测不丢资料', () {
      final model = UserModel.fromJson(<String, dynamic>{
        'region': '旧地区串',
        'regionSelection': const <String, dynamic>{
          'protocolVersion': '2.0',
          'datasetId': 'geo-regions-seed',
          'countryCode': 'JP',
          'dataRevision': 's-0000000000000000',
          'pathIds': <String>['cc:JP'],
        },
      });
      expect(model.regionSelection, isNull);
      expect(model.regionSelectionStatus, 'unresolved');
      expect(model.region, '旧地区串');
      final out = model.toMap();
      expect(out['region'], '旧地区串');
      expect(out['regionSelectionStatus'], 'unresolved');
    });

    test('旧缓存 JSON 字符串形态（后端 decode_region_selection 兼容）', () {
      final model = UserModel.fromJson(<String, dynamic>{
        'regionSelection':
            '{"protocolVersion":"1.0","datasetId":"geo-regions-seed",'
            '"countryCode":"JP","dataRevision":"s-0000000000000000",'
            '"pathIds":["cc:JP"]}',
      });
      expect(model.regionSelection, isNotNull);
      expect(model.regionSelection!.countryCode, 'JP');
    });
  });
}
