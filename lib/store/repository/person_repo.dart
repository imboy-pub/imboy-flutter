import 'package:imboy/helper/database.dart';
import 'package:imboy/store/model/person_model.dart';
import 'package:sqflite/sqflite.dart';

class PersonRepo {
  static String tablename = 'im_person';

  static String uid = 'uid';
  static String account = 'account';
  static String nickname = 'nickname';
  static String avatar = 'avatar';
  static String birthday = 'birthday';
  static String role = 'role';
  static String gender = 'gender';
  static String levelId = 'level_id';
  static String language = 'language';
  static String sign = 'sign';
  static String allowType = 'allow_type';
  static String location = 'location';

  Database _db;

  PersonRepo() {
    _database();
  }

  _database() async {
    _db = await DatabaseHelper.instance.database;
  }

  // 插入一条数据
  Future<PersonModel> insert(PersonModel person) async {
    if (this._db == null) {
      await this._database();
    }
    person.uid =
        (await _db.insert(PersonRepo.tablename, person.toMap())) as String;
    return person;
  }

  // 查找所有信息
  Future<List<PersonModel>> all() async {
    if (this._db == null) {
      await this._database();
    }
    List<Map> maps = await _db.query(PersonRepo.tablename, columns: [
      PersonRepo.uid,
      PersonRepo.account,
      PersonRepo.nickname,
      PersonRepo.avatar,
      PersonRepo.birthday,
      PersonRepo.role,
      PersonRepo.gender,
      PersonRepo.levelId,
      PersonRepo.language,
      PersonRepo.sign,
      PersonRepo.allowType,
      PersonRepo.location
    ]);

    if (maps == null || maps.length == 0) {
      return null;
    }

    List<PersonModel> persons = [];
    for (int i = 0; i < maps.length; i++) {
      persons.add(PersonModel.fromMap(maps[i]));
    }
    return persons;
  }

  // 根据ID查找用户信息
  Future<PersonModel> find(String uid) async {
    if (this._db == null) {
      await this._database();
    }
    List<Map> maps = await _db.query(PersonRepo.tablename,
        columns: [
          PersonRepo.uid,
          PersonRepo.account,
          PersonRepo.nickname,
          PersonRepo.avatar,
          PersonRepo.birthday,
          PersonRepo.role,
          PersonRepo.gender,
          PersonRepo.levelId,
          PersonRepo.language,
          PersonRepo.sign,
          PersonRepo.allowType,
          PersonRepo.location
        ],
        where: '${PersonRepo.uid} = ?',
        whereArgs: [uid]);
    if (maps.length > 0) {
      return PersonModel.fromMap(maps.first);
    }
    return null;
  }

  // 根据ID删除信息
  Future<int> delete(String uid) async {
    if (this._db == null) {
      await this._database();
    }
    return await _db.delete(PersonRepo.tablename,
        where: '${PersonRepo.uid} = ?', whereArgs: [uid]);
  }

  // 更新信息
  Future<int> update(PersonModel person) async {
    if (this._db == null) {
      await this._database();
    }
    return await _db.update(PersonRepo.tablename, person.toMap(),
        where: '${PersonRepo.uid} = ?', whereArgs: [person.uid]);
  }

// 记得及时关闭数据库，防止内存泄漏
// close() async {
//   await _db.close();
// }
}
