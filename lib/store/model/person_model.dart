import 'package:imboy/store/repository/person_repo.dart';

class PersonModel {
  String? uid;
  String? account;
  String? nickname;
  String? avatar;
  String? area;

  int? birthday;
  int? role;
  int? gender;
  int? levelId;
  int? language;
  String? sign;
  dynamic allowType;
  String? location;

  PersonModel({
    this.uid,
    this.account,
    this.nickname,
    this.avatar,
    this.area,
    this.birthday,
    this.role,
    this.gender,
    this.levelId,
    this.language,
    this.sign,
    this.allowType,
    this.location,
  });

  PersonModel.fromMap(Map<String, dynamic> data) {
    uid = data['uid'];
    account = data['account'];
    nickname = data['nickname'];
    avatar = data['avatar'];
    area = data['area'];
    birthday = data['birthday'];
    role = data['role'];
    gender = data['gender'];
    levelId = data['level_id'];
    language = data['language'];
    sign = data['sign'];
    allowType = data['allow_type'];
    location = data['location'];
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['uid'] = this.uid;
    data['account'] = this.account;
    data['nickname'] = this.nickname;
    data['avatar'] = this.avatar;
    data['area'] = this.area;
    data['birthday'] = this.birthday;
    data['role'] = this.role;
    data['gender'] = this.gender;
    data['level_id'] = this.levelId;
    data['language'] = this.language;
    data['sign'] = this.sign;
    data['allow_type'] = this.allowType;
    data['location'] = this.location;
    return data;
  }

  static Future<PersonModel?> find(String uid) async {
    return (new PersonRepo()).find(uid);
  }
}
