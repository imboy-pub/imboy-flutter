import 'dart:convert';

import 'package:geo_regions/geo_regions.dart';
import 'package:imboy/component/http/http_client.dart';
import 'package:imboy/component/http/http_response.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/config/env.dart';
import 'package:imboy/config/init.dart' show currentEnv;
import 'package:imboy/store/repository/user_repo_local.dart';
import 'package:imboy/store/model/user_model.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/modules/messaging/domain/policy/visibility_read_rules.dart';

/// PUT 前捕获的会话身份快照。
///
/// 与 [UserRepoLocal.changeInfo] 的 expectedUid/expectedGeneration/
/// expectedEnvironment/expectedEndpoint 围栏同源：资料更新在发起 PUT 前
/// 捕获归属，响应迟到时本地缓存不得落入已切换的新账号。
class UserProfileSessionSnapshot {
  const UserProfileSessionSnapshot({
    required this.uid,
    required this.generation,
    required this.environment,
    required this.endpoint,
  });

  final String uid;
  final int generation;
  final String environment;
  final String endpoint;

  @override
  bool operator ==(Object other) =>
      other is UserProfileSessionSnapshot &&
      other.uid == uid &&
      other.generation == generation &&
      other.environment == environment &&
      other.endpoint == endpoint;

  @override
  int get hashCode => Object.hash(uid, generation, environment, endpoint);
}

/// 用户资料更新服务。
///
/// 统一封装「PUT /api/v1/user/update 更新单个字段 + 同步本地 UserRepoLocal 缓存」逻辑，
/// 消除 PersonalInfoPage 与 ProfilePage 各自手写、且行为不一致的重复实现（DRY）。
///
/// 隐私设置类字段写入 `payload['setting']`，其余字段写顶层，与后端数据结构对齐。
/// 通过可选回调注入 HttpClient / UserRepoLocal 单例，便于纯单元测试。
///
/// 账号保存围栏（FL-09）：
/// - 发起 PUT 前捕获 [UserProfileSessionSnapshot]；响应返回后会话已变化
///   （uid/世代/环境/端点任一变化）时拒绝本地落盘并返回 false；
/// - 默认本地写透传同一快照给 `UserRepoLocal.changeInfo` 的 expected* 参数，
///   与登录/退出写队列共享第二层围栏；
/// - 本地读/写任何失败收敛为 false，不异常逃逸、不伪装成功；
/// - `regionSelection` 走结构化协议（geo_regions §8），成功后本地
///   region/regionSelection/regionSelectionStatus 一致同步；legacy `region`
///   字符串写入不触碰已缓存的结构化身份（不猜测、不丢资料）。
class UserProfileService {
  const UserProfileService._();

  /// Preserve supported legacy encodings, never turn malformed privacy into a default.
  static Map<String, dynamic> parseWebSettings(dynamic raw) {
    if (raw is! Map) throw const FormatException('Missing profile settings');
    final settings = Map<String, dynamic>.from(raw);
    bool booleanValue(dynamic v) =>
        v is bool ||
        (v is num && v.isFinite) ||
        (v is String &&
            const [
              'true',
              'false',
              '1',
              '0',
              'yes',
              'no',
              'on',
              'off',
            ].contains(v.trim().toLowerCase()));
    bool numericValue(dynamic v) =>
        v is bool ||
        (v is num && v.isFinite) ||
        (v is String &&
            (num.tryParse(v)?.isFinite == true ||
                const ['true', 'false'].contains(v.toLowerCase())));
    for (final key in ['allow_search', 'enable_visibility_read']) {
      if (settings.containsKey(key) &&
          !booleanValue(settings[key]) &&
          !(key == 'allow_search' &&
              settings[key] is String &&
              (settings[key] as String).trim() == '2')) {
        throw FormatException('Invalid setting: $key');
      }
    }
    for (final key in [
      'visibility_read_fraction',
      'visibility_read_delay_ms',
    ]) {
      if (settings.containsKey(key) && !numericValue(settings[key])) {
        throw FormatException('Invalid setting: $key');
      }
    }
    if (settings.containsKey('font_size') &&
        (settings['font_size'] is! String ||
            FontSizeOption.fromValue(settings['font_size'] as String) ==
                null)) {
      throw const FormatException('Invalid font setting');
    }
    final model = UserSettingModel.fromJson(settings);
    return {
      'allow_search': model.allowSearch,
      'enable_visibility_read': model.enableVisibilityRead,
      'visibility_read_fraction': normalizeVisibilityFraction(
        model.visibilityReadFraction,
      ),
      'visibility_read_delay_ms': normalizeVisibilityDelayMs(
        model.visibilityReadDelayMs,
      ),
      'font_size': model.fontSize,
    };
  }

  /// 隐私设置字段集合：这些字段在本地缓存中归属 `setting` 子对象。
  static const Set<String> settingFields = {
    'allow_search',
    'allow_add_by_phone',
    'allow_add_by_qr',
    'show_online_status',
    'allow_nearby_visible',
  };

  /// 默认会话快照：uid/世代/环境/端点，与 changeInfo 围栏同源。
  static UserProfileSessionSnapshot readSessionSnapshot() {
    return UserProfileSessionSnapshot(
      uid: UserRepoLocal.to.currentUid,
      generation: UserRepoLocal.to.sessionGeneration,
      environment: currentEnv,
      endpoint: Env().apiBaseUrl,
    );
  }

  static bool _sameSession(
    UserProfileSessionSnapshot a,
    UserProfileSessionSnapshot b,
  ) => a == b;

  /// regionSelection 后端合同镜像（user_agg:validate_update/2 +
  /// user_logic:authoritative_region/1）：value 恰为 {region, selection} 两键；
  /// 展示串必须与后端 pinned 数据集重算的权威路径一致。
  ///
  /// 返回 (region, selection)；结构上不可能被后端接受的输入返回 null
  /// （本地拒绝，不发必败请求，不猜测展示串）。
  static (String, GeoSelection)? normalizeRegionSelectionValue(
    dynamic value, {
    bool serverCanonicalizesDisplay = false,
  }) {
    String? region;
    GeoSelection? selection;
    if (value is GeoSelection) {
      selection = value;
    } else if (value is Map &&
        value.length == 2 &&
        value.containsKey('region') &&
        value.containsKey('selection')) {
      final r = value['region'];
      if (r is! String) return null;
      region = r;
      final raw = value['selection'];
      if (raw is GeoSelection) {
        selection = raw;
      } else {
        try {
          final decoded = raw is String ? jsonDecode(raw) : raw;
          if (decoded is! Map) return null;
          selection = parseSelection(Map<String, dynamic>.from(decoded));
        } on Exception {
          return null;
        } on Error {
          return null;
        }
      }
    } else {
      return null;
    }
    final snapshot = selection.displaySnapshot;
    // 客户端没有数据集：无权威展示快照时不得猜测 region 展示串。
    if (snapshot == null || snapshot.any((name) => name.trim().isEmpty)) {
      return null;
    }
    final derived = snapshot.join(' ');
    final sent = region ?? derived;
    // 后端以数据集重算展示并精确比对，与快照不一致的 region 必败。
    if (sent != derived) return null;
    if (sent.contains('\u0000') ||
        (!serverCanonicalizesDisplay && sent.runes.length > 80)) {
      return null;
    }
    return (sent, selection);
  }

  /// 更新用户单个字段：PUT 后端，成功后同步本地缓存。
  ///
  /// 返回是否成功。PUT 失败、会话已切换（迟到响应）或本地读/写失败时
  /// 均不写本地缓存并返回 false。
  ///
  /// [httpPut]/[readCurrent]/[saveLocal]/[readSession] 仅用于测试注入，
  /// 生产环境使用默认实现。
  ///
  /// `field = 'regionSelection'` 时 [value] 为
  /// `{region: String, selection: GeoSelection|Map|String}` 或 [GeoSelection]，
  /// 本地缓存同步 region + regionSelection + regionSelectionStatus。
  /// 专用 Web 预览传入 POST transport 和 requireAuthoritativeRegion，只发送
  /// 结构化 selection，等服务端返回同一身份与权威展示后才提交本地。
  static Future<bool> updateField(
    String field,
    dynamic value, {
    Future<IMBoyHttpResponse> Function(Map<String, dynamic> data)? httpPut,
    Map<String, dynamic> Function()? readCurrent,
    Future<bool> Function(Map<String, dynamic> payload)? saveLocal,
    UserProfileSessionSnapshot Function()? readSession,
    bool requireAuthoritativeRegion = false,
  }) async {
    if (requireAuthoritativeRegion &&
        (field != 'regionSelection' || httpPut == null)) {
      return false;
    }
    final readSes = readSession ?? readSessionSnapshot;
    final put =
        httpPut ?? (data) => HttpClient.client.put(API.userUpdate, data: data);
    final readCur = readCurrent ?? () => UserRepoLocal.to.current.toMap();

    // 发起 PUT 前捕获归属；默认本地写透传同一快照给 changeInfo 围栏。
    final session = readSes();
    final save =
        saveLocal ??
        (p) => UserRepoLocal.to.changeInfo(
          p,
          expectedUid: session.uid,
          expectedGeneration: session.generation,
          expectedEnvironment: session.environment,
          expectedEndpoint: session.endpoint,
        );

    (String, GeoSelection)? normalizedRegion;
    if (field == 'regionSelection') {
      normalizedRegion = normalizeRegionSelectionValue(
        value,
        serverCanonicalizesDisplay: requireAuthoritativeRegion,
      );
      if (normalizedRegion == null) {
        // 结构上必败：本地拒绝，不猜测、不发请求、不落缓存。
        return false;
      }
    }

    // allow_search 后端权威值域为 int 1|2（user_agg:validate_allow_search），
    // bool 直传会被后端拒绝导致写入无效——这曾造成设置页与隐私页
    // 两处同义开关状态长期矛盾（QA#18）。
    if (field == 'allow_search' && value is bool) {
      value = value ? 1 : 2;
    }

    final request = requireAuthoritativeRegion
        ? <String, dynamic>{'selection': normalizedRegion!.$2.toMap()}
        : <String, dynamic>{'field': field, 'value': value};
    final resp = await put(request);
    if (!resp.ok) {
      // 透出后端中文原因（隐私开关链路：privacy_settings_page 只拿到 bool，
      // 不在这里弹出，用户只能看到与原因无关的兜底文案）。
      // showBackendError 内部已做空串与单测无 host 保护。
      AppLoading.showBackendError(resp.msg);
      return false;
    }

    // 迟到响应围栏：会话已切换时本地缓存属于新账号，拒绝落盘。
    if (!_sameSession(session, readSes())) {
      return false;
    }

    try {
      final payload = readCur();
      if (field == 'regionSelection') {
        final confirmed = requireAuthoritativeRegion
            ? _authoritativeRegionReply(resp.payload, normalizedRegion!.$2)
            : normalizedRegion;
        if (confirmed == null) return false;
        final (region, selection) = confirmed;
        // 后端仅在权威校验通过后才接受 → 读侧状态为 resolved；
        // 本地 region 字符串与结构化身份一致同步（不猜测、不丢资料）。
        payload['region'] = region;
        payload['regionSelection'] = selection.toMap();
        payload['regionSelectionStatus'] = 'resolved';
      } else if (settingFields.contains(field)) {
        final existing = payload['setting'];
        final setting = existing is Map<String, dynamic>
            ? Map<String, dynamic>.from(existing)
            : <String, dynamic>{};
        setting[field] = value;
        payload['setting'] = setting;
      } else {
        payload[field] = value;
      }
      return await save(payload);
    } on Exception {
      return false;
    } on Error {
      return false;
    }
  }

  static (String, GeoSelection)? _authoritativeRegionReply(
    dynamic response,
    GeoSelection submitted,
  ) {
    if (response is! Map || response['regionSelectionStatus'] != 'resolved') {
      return null;
    }
    final region = response['region'];
    final rawSelection = response['regionSelection'];
    if (region is! String ||
        region.trim().isEmpty ||
        region.runes.length > 80 ||
        region.contains('\u0000') ||
        rawSelection is! Map) {
      return null;
    }
    final selection = parseSelection(Map<String, dynamic>.from(rawSelection));
    // GeoSelection equality is the protocol, dataset, country, revision and ID path.
    return selection == submitted ? (region, selection) : null;
  }

  /// 结构化地区身份保存（geo_regions 协议 §8）。
  ///
  /// [selection] 必须携带 [GeoSelection.displaySnapshot]（后端以 pinned
  /// 数据集重算权威展示并精确比对，客户端无数据集时不得猜测展示串）。
  /// 成功后本地 region/regionSelection/regionSelectionStatus 一致同步。
  static Future<bool> updateRegionSelection(
    GeoSelection selection, {
    Future<IMBoyHttpResponse> Function(Map<String, dynamic> data)? httpPut,
    Map<String, dynamic> Function()? readCurrent,
    Future<bool> Function(Map<String, dynamic> payload)? saveLocal,
    UserProfileSessionSnapshot Function()? readSession,
    bool requireAuthoritativeRegion = false,
  }) {
    return updateField(
      'regionSelection',
      <String, dynamic>{
        'region': selection.displaySnapshot?.join(' '),
        // 必须传协议 map 而非 GeoSelection 实例：toJson() 返回 JSON 字符串，
        // 实例直传 HTTP 层会被二次编码，破坏 {region, selection} 线格式。
        'selection': selection.toMap(),
      },
      httpPut: httpPut,
      readCurrent: readCurrent,
      saveLocal: saveLocal,
      readSession: readSession,
      requireAuthoritativeRegion: requireAuthoritativeRegion,
    );
  }
}
