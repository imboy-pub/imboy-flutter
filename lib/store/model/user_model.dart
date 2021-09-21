///
class UserModel {
  int? role;
  String? uid;
  String? account;
  String? nickname;
  String? avatar;
  String? gender;
  String? token;
  String? refreshtoken;

  UserModel({
    this.role,
    this.uid,
    this.account,
    this.nickname,
    this.avatar,
    this.gender,
    this.token,
    this.refreshtoken,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return new UserModel(
      uid: json["uid"],
      nickname: json["nickname"]?.toString(),
      avatar: json["avatar"]?.toString(),
      account: json["account"]?.toString(),
      role: json["role"]?.toInt(),
      gender: json["gender"]?.toString(),
      token: json["token"]?.toString(),
      refreshtoken: json["refreshtoken"]?.toString(),
    );
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data["uid"] = uid;
    data["nickname"] = nickname;
    data["avatar"] = avatar;
    data["account"] = account;
    data["role"] = role;
    data["gender"] = gender;
    data["token"] = token;
    data["refreshtoken"] = refreshtoken;
    return data;
  }
}
