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
        return t.search;
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
}

// 用户 ID Provider (用于刷新数据)
@riverpod
String userId(Ref ref) => '';
