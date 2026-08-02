import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';

part 'people_info_provider.g.dart';

// 用户信息状态类
class PeopleInfoState {
  final String nickname;
  final String avatar;
  final String account;
  final String region;
  final String sign;
  final String source;
  final String title;
  final int gender;
  final String remark;
  final String tag;
  final int isFriend;
  final int isFrom;
  final String status;
  final int lastSeenAt;

  /// 账号类型 0=真人 1=AI 2=官方（透明 AI 徽章数据源）
  final int accountType;

  const PeopleInfoState({
    this.nickname = '',
    this.avatar = '',
    this.account = '',
    this.region = '',
    this.sign = '',
    this.source = '',
    this.title = '',
    this.gender = 0,
    this.remark = '',
    this.tag = '',
    this.isFriend = 0,
    this.isFrom = 0,
    this.status = '',
    this.lastSeenAt = 0,
    this.accountType = 0,
  });

  PeopleInfoState copyWith({
    String? nickname,
    String? avatar,
    String? account,
    String? region,
    String? sign,
    String? source,
    String? title,
    int? gender,
    String? remark,
    String? tag,
    int? isFriend,
    int? isFrom,
    String? status,
    int? lastSeenAt,
    int? accountType,
  }) {
    return PeopleInfoState(
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      account: account ?? this.account,
      region: region ?? this.region,
      sign: sign ?? this.sign,
      source: source ?? this.source,
      title: title ?? this.title,
      gender: gender ?? this.gender,
      remark: remark ?? this.remark,
      tag: tag ?? this.tag,
      isFriend: isFriend ?? this.isFriend,
      isFrom: isFrom ?? this.isFrom,
      status: status ?? this.status,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      accountType: accountType ?? this.accountType,
    );
  }
}

// 用户信息 Notifier
@riverpod
class PeopleInfoNotifier extends _$PeopleInfoNotifier {
  @override
  PeopleInfoState build() {
    return const PeopleInfoState();
  }

  // 初始化数据
  Future<void> initData(String id, String scene) async {
    final ct = await ContactRepo().findByUid(id);

    if (ct != null) {
      state = state.copyWith(
        title: ct.title,
        nickname: ct.nickname,
        avatar: ct.avatar,
        account: ct.account,
        region: ct.region,
        sign: ct.sign,
        source: ct.source,
        gender: ct.gender,
        remark: ct.remark,
        tag: ct.tag,
        isFriend: ct.isFriend,
        isFrom: ct.isFrom,
        status: ct.status ?? '',
        lastSeenAt: ct.lastSeenAt ?? 0,
        accountType: ct.accountType,
      );
    }

    if (state.isFriend != 1) {
      final newSource = _getSourceByScene(scene);
      if (newSource != null) {
        state = state.copyWith(source: newSource);
      }
    }
  }

  // 根据场景获取来源
  String? _getSourceByScene(String scene) {
    switch (scene) {
      case 'qrcode':
        return 'qrcode';
      case 'visitCard':
        return 'visitCard';
      case 'people_nearby':
        return 'people_nearby';
      case 'recently_user':
        return 'recently_user';
      case 'contact_page':
      case 'denylist':
        return '';
      case 'group_member':
        return null;
      case 'user_search':
        return t.common.search;
      case '':
        return 'qrcode';
      default:
        return null;
    }
  }

  // 更新备注
  void updateRemark(String newRemark) {
    state = state.copyWith(remark: newRemark);
  }

  // 更新标签
  void updateTag(String newTag) {
    state = state.copyWith(tag: newTag);
  }

  /// 应用实时在线状态变更（由 UI 层订阅 UserStatusChangeEvent 后调用）。
  ///
  /// UI 层（people_info_page）已按 widget.id 过滤，此处直接更新 state。
  /// 状态映射逻辑见 [mapStatusChange]（可单测的纯函数）。
  void applyStatusChange(String status, {int? eventTimestamp}) {
    final mapped = mapStatusChange(
      currentLastSeenAt: state.lastSeenAt,
      status: status,
      eventTimestamp: eventTimestamp,
    );
    state = state.copyWith(
      status: mapped.status,
      lastSeenAt: mapped.lastSeenAt,
    );
  }

  /// 状态变更 → (status, lastSeenAt) 的纯映射逻辑。
  ///
  /// 抽成静态方法便于单测。语义：
  /// - online → status='online'，lastSeenAt 不变（上线不改变"最后离线时间"）
  /// - offline → status='offline'，lastSeenAt=事件时间戳（记录最后在线时刻）
  /// - hide → 对观察者等效于 offline，lastSeenAt 不变（隐身不等于真的下线）
  /// - offline 缺 eventTimestamp 时用当前时间兜底，避免回退到 0 显示"从未上线"
  static ({String status, int lastSeenAt}) mapStatusChange({
    required int currentLastSeenAt,
    required String status,
    int? eventTimestamp,
  }) {
    switch (status) {
      case 'online':
        return (status: 'online', lastSeenAt: currentLastSeenAt);
      case 'hide':
        // 隐身对观察者等效于离线，但不更新 lastSeenAt
        return (status: 'offline', lastSeenAt: currentLastSeenAt);
      case 'offline':
      default:
        final ts = eventTimestamp ?? DateTime.now().millisecondsSinceEpoch;
        return (status: 'offline', lastSeenAt: ts);
    }
  }

  /// 标记：UI 层订阅事件的能力存在（用于运行时能力检测/测试钉死）
  static bool get hasStaticApplyStatusChange => true;
}

// 用户 ID Provider (用于刷新数据)
@riverpod
String userId(Ref ref) => '';
