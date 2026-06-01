import 'package:imboy/modules/identity/domain/value/user_id.dart';

/// 用户身份充血实体 / User identity rich entity（T3.5）。
///
/// 资料字段校验（性别 / 允许搜索枚举、邮箱格式）内聚于实体，语义对齐后端
/// 权威 `user_agg`（gender∈{1,2,3}、allow_search∈{1,2}、email 正则与
/// `elib_type:is_email` 一致），供 FE 表单委托判定，替代散落硬编码。
///
/// 不可变：copyWith 返回新实例，校验为纯静态查询。纯 Dart——禁止
/// import flutter/* 与 repository/*。
class User {
  const User({
    required this.id,
    this.nickname = '',
    this.gender = genderSecret,
    this.sign = '',
    this.region = '',
  });

  final UserId id;
  final String nickname;

  /// 性别：1 男 / 2 女 / 3 保密（对齐后端）。
  final int gender;
  final String sign;
  final String region;

  /// 性别枚举（对齐后端 user_agg）。
  static const int genderMale = 1;
  static const int genderFemale = 2;
  static const int genderSecret = 3;

  /// 允许搜索枚举（对齐后端 user_agg）。
  static const int allowSearchOn = 1;
  static const int allowSearchOff = 2;

  /// 邮箱格式正则——逐字镜像后端 `elib_type:is_email`。
  static final RegExp _emailRe = RegExp(
    r'^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+)+$',
  );

  /// 性别值是否合法（1/2/3）。
  static bool isValidGender(int value) =>
      value == genderMale || value == genderFemale || value == genderSecret;

  /// 允许搜索值是否合法（1/2）。
  static bool isValidAllowSearch(int value) =>
      value == allowSearchOn || value == allowSearchOff;

  /// 邮箱格式是否合法（仅格式，占用查询属后端 I/O）。
  static bool isValidEmail(String email) => _emailRe.hasMatch(email);

  /// 返回更新资料后的新实例（不可变）。
  User copyWith({String? nickname, int? gender, String? sign, String? region}) {
    return User(
      id: id,
      nickname: nickname ?? this.nickname,
      gender: gender ?? this.gender,
      sign: sign ?? this.sign,
      region: region ?? this.region,
    );
  }
}
