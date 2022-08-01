// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'contact.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, unused_local_variable

extension GetContactCollection on Isar {
  IsarCollection<Contact> get contacts => getCollection();
}

const ContactSchema = CollectionSchema(
  name: 'Contact',
  schema:
      '{"name":"Contact","idName":"id","properties":[{"name":"account","type":"String"},{"name":"avatar","type":"String"},{"name":"firstletter","type":"String"},{"name":"gender","type":"Long"},{"name":"isfriend","type":"Long"},{"name":"isfrom","type":"Long"},{"name":"nameIndex","type":"String"},{"name":"namePinyin","type":"String"},{"name":"nickname","type":"String"},{"name":"region","type":"String"},{"name":"remark","type":"String"},{"name":"sign","type":"String"},{"name":"source","type":"String"},{"name":"sourceTr","type":"String"},{"name":"status","type":"String"},{"name":"title","type":"String"},{"name":"uid","type":"String"},{"name":"updateTime","type":"Long"}],"indexes":[{"name":"uid","unique":true,"properties":[{"name":"uid","type":"Hash","caseSensitive":true}]}],"links":[]}',
  idName: 'id',
  propertyIds: {
    'account': 0,
    'avatar': 1,
    'firstletter': 2,
    'gender': 3,
    'isfriend': 4,
    'isfrom': 5,
    'nameIndex': 6,
    'namePinyin': 7,
    'nickname': 8,
    'region': 9,
    'remark': 10,
    'sign': 11,
    'source': 12,
    'sourceTr': 13,
    'status': 14,
    'title': 15,
    'uid': 16,
    'updateTime': 17
  },
  listProperties: {},
  indexIds: {'uid': 0},
  indexValueTypes: {
    'uid': [
      IndexValueType.stringHash,
    ]
  },
  linkIds: {},
  backlinkLinkNames: {},
  getId: _contactGetId,
  setId: _contactSetId,
  getLinks: _contactGetLinks,
  attachLinks: _contactAttachLinks,
  serializeNative: _contactSerializeNative,
  deserializeNative: _contactDeserializeNative,
  deserializePropNative: _contactDeserializePropNative,
  serializeWeb: _contactSerializeWeb,
  deserializeWeb: _contactDeserializeWeb,
  deserializePropWeb: _contactDeserializePropWeb,
  version: 3,
);

int? _contactGetId(Contact object) {
  if (object.id == Isar.autoIncrement) {
    return null;
  } else {
    return object.id;
  }
}

void _contactSetId(Contact object, int id) {
  object.id = id;
}

List<IsarLinkBase> _contactGetLinks(Contact object) {
  return [];
}

void _contactSerializeNative(
    IsarCollection<Contact> collection,
    IsarRawObject rawObj,
    Contact object,
    int staticSize,
    List<int> offsets,
    AdapterAlloc alloc) {
  var dynamicSize = 0;
  final value0 = object.account;
  final _account = IsarBinaryWriter.utf8Encoder.convert(value0);
  dynamicSize += (_account.length) as int;
  final value1 = object.avatar;
  final _avatar = IsarBinaryWriter.utf8Encoder.convert(value1);
  dynamicSize += (_avatar.length) as int;
  final value2 = object.firstletter;
  IsarUint8List? _firstletter;
  if (value2 != null) {
    _firstletter = IsarBinaryWriter.utf8Encoder.convert(value2);
  }
  dynamicSize += (_firstletter?.length ?? 0) as int;
  final value3 = object.gender;
  final _gender = value3;
  final value4 = object.isfriend;
  final _isfriend = value4;
  final value5 = object.isfrom;
  final _isfrom = value5;
  final value6 = object.nameIndex;
  IsarUint8List? _nameIndex;
  if (value6 != null) {
    _nameIndex = IsarBinaryWriter.utf8Encoder.convert(value6);
  }
  dynamicSize += (_nameIndex?.length ?? 0) as int;
  final value7 = object.namePinyin;
  IsarUint8List? _namePinyin;
  if (value7 != null) {
    _namePinyin = IsarBinaryWriter.utf8Encoder.convert(value7);
  }
  dynamicSize += (_namePinyin?.length ?? 0) as int;
  final value8 = object.nickname;
  final _nickname = IsarBinaryWriter.utf8Encoder.convert(value8);
  dynamicSize += (_nickname.length) as int;
  final value9 = object.region;
  final _region = IsarBinaryWriter.utf8Encoder.convert(value9);
  dynamicSize += (_region.length) as int;
  final value10 = object.remark;
  final _remark = IsarBinaryWriter.utf8Encoder.convert(value10);
  dynamicSize += (_remark.length) as int;
  final value11 = object.sign;
  final _sign = IsarBinaryWriter.utf8Encoder.convert(value11);
  dynamicSize += (_sign.length) as int;
  final value12 = object.source;
  final _source = IsarBinaryWriter.utf8Encoder.convert(value12);
  dynamicSize += (_source.length) as int;
  final value13 = object.sourceTr;
  final _sourceTr = IsarBinaryWriter.utf8Encoder.convert(value13);
  dynamicSize += (_sourceTr.length) as int;
  final value14 = object.status;
  IsarUint8List? _status;
  if (value14 != null) {
    _status = IsarBinaryWriter.utf8Encoder.convert(value14);
  }
  dynamicSize += (_status?.length ?? 0) as int;
  final value15 = object.title;
  final _title = IsarBinaryWriter.utf8Encoder.convert(value15);
  dynamicSize += (_title.length) as int;
  final value16 = object.uid;
  IsarUint8List? _uid;
  if (value16 != null) {
    _uid = IsarBinaryWriter.utf8Encoder.convert(value16);
  }
  dynamicSize += (_uid?.length ?? 0) as int;
  final value17 = object.updateTime;
  final _updateTime = value17;
  final size = staticSize + dynamicSize;

  rawObj.buffer = alloc(size);
  rawObj.buffer_length = size;
  final buffer = IsarNative.bufAsBytes(rawObj.buffer, size);
  final writer = IsarBinaryWriter(buffer, staticSize);
  writer.writeBytes(offsets[0], _account);
  writer.writeBytes(offsets[1], _avatar);
  writer.writeBytes(offsets[2], _firstletter);
  writer.writeLong(offsets[3], _gender);
  writer.writeLong(offsets[4], _isfriend);
  writer.writeLong(offsets[5], _isfrom);
  writer.writeBytes(offsets[6], _nameIndex);
  writer.writeBytes(offsets[7], _namePinyin);
  writer.writeBytes(offsets[8], _nickname);
  writer.writeBytes(offsets[9], _region);
  writer.writeBytes(offsets[10], _remark);
  writer.writeBytes(offsets[11], _sign);
  writer.writeBytes(offsets[12], _source);
  writer.writeBytes(offsets[13], _sourceTr);
  writer.writeBytes(offsets[14], _status);
  writer.writeBytes(offsets[15], _title);
  writer.writeBytes(offsets[16], _uid);
  writer.writeLong(offsets[17], _updateTime);
}

Contact _contactDeserializeNative(IsarCollection<Contact> collection, int id,
    IsarBinaryReader reader, List<int> offsets) {
  final object = Contact();
  object.account = reader.readString(offsets[0]);
  object.avatar = reader.readString(offsets[1]);
  object.firstletter = reader.readStringOrNull(offsets[2]);
  object.gender = reader.readLong(offsets[3]);
  object.id = id;
  object.isfriend = reader.readLong(offsets[4]);
  object.isfrom = reader.readLong(offsets[5]);
  object.nameIndex = reader.readStringOrNull(offsets[6]);
  object.namePinyin = reader.readStringOrNull(offsets[7]);
  object.nickname = reader.readString(offsets[8]);
  object.region = reader.readString(offsets[9]);
  object.remark = reader.readString(offsets[10]);
  object.sign = reader.readString(offsets[11]);
  object.source = reader.readString(offsets[12]);
  object.status = reader.readStringOrNull(offsets[14]);
  object.uid = reader.readStringOrNull(offsets[16]);
  object.updateTime = reader.readLongOrNull(offsets[17]);
  return object;
}

P _contactDeserializePropNative<P>(
    int id, IsarBinaryReader reader, int propertyIndex, int offset) {
  switch (propertyIndex) {
    case -1:
      return id as P;
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readLong(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readLong(offset)) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readString(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readStringOrNull(offset)) as P;
    case 15:
      return (reader.readString(offset)) as P;
    case 16:
      return (reader.readStringOrNull(offset)) as P;
    case 17:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw 'Illegal propertyIndex';
  }
}

dynamic _contactSerializeWeb(
    IsarCollection<Contact> collection, Contact object) {
  final jsObj = IsarNative.newJsObject();
  IsarNative.jsObjectSet(jsObj, 'account', object.account);
  IsarNative.jsObjectSet(jsObj, 'avatar', object.avatar);
  IsarNative.jsObjectSet(jsObj, 'firstletter', object.firstletter);
  IsarNative.jsObjectSet(jsObj, 'gender', object.gender);
  IsarNative.jsObjectSet(jsObj, 'id', object.id);
  IsarNative.jsObjectSet(jsObj, 'isfriend', object.isfriend);
  IsarNative.jsObjectSet(jsObj, 'isfrom', object.isfrom);
  IsarNative.jsObjectSet(jsObj, 'nameIndex', object.nameIndex);
  IsarNative.jsObjectSet(jsObj, 'namePinyin', object.namePinyin);
  IsarNative.jsObjectSet(jsObj, 'nickname', object.nickname);
  IsarNative.jsObjectSet(jsObj, 'region', object.region);
  IsarNative.jsObjectSet(jsObj, 'remark', object.remark);
  IsarNative.jsObjectSet(jsObj, 'sign', object.sign);
  IsarNative.jsObjectSet(jsObj, 'source', object.source);
  IsarNative.jsObjectSet(jsObj, 'sourceTr', object.sourceTr);
  IsarNative.jsObjectSet(jsObj, 'status', object.status);
  IsarNative.jsObjectSet(jsObj, 'title', object.title);
  IsarNative.jsObjectSet(jsObj, 'uid', object.uid);
  IsarNative.jsObjectSet(jsObj, 'updateTime', object.updateTime);
  return jsObj;
}

Contact _contactDeserializeWeb(
    IsarCollection<Contact> collection, dynamic jsObj) {
  final object = Contact();
  object.account = IsarNative.jsObjectGet(jsObj, 'account') ?? '';
  object.avatar = IsarNative.jsObjectGet(jsObj, 'avatar') ?? '';
  object.firstletter = IsarNative.jsObjectGet(jsObj, 'firstletter');
  object.gender =
      IsarNative.jsObjectGet(jsObj, 'gender') ?? double.negativeInfinity;
  object.id = IsarNative.jsObjectGet(jsObj, 'id');
  object.isfriend =
      IsarNative.jsObjectGet(jsObj, 'isfriend') ?? double.negativeInfinity;
  object.isfrom =
      IsarNative.jsObjectGet(jsObj, 'isfrom') ?? double.negativeInfinity;
  object.nameIndex = IsarNative.jsObjectGet(jsObj, 'nameIndex');
  object.namePinyin = IsarNative.jsObjectGet(jsObj, 'namePinyin');
  object.nickname = IsarNative.jsObjectGet(jsObj, 'nickname') ?? '';
  object.region = IsarNative.jsObjectGet(jsObj, 'region') ?? '';
  object.remark = IsarNative.jsObjectGet(jsObj, 'remark') ?? '';
  object.sign = IsarNative.jsObjectGet(jsObj, 'sign') ?? '';
  object.source = IsarNative.jsObjectGet(jsObj, 'source') ?? '';
  object.status = IsarNative.jsObjectGet(jsObj, 'status');
  object.uid = IsarNative.jsObjectGet(jsObj, 'uid');
  object.updateTime = IsarNative.jsObjectGet(jsObj, 'updateTime');
  return object;
}

P _contactDeserializePropWeb<P>(Object jsObj, String propertyName) {
  switch (propertyName) {
    case 'account':
      return (IsarNative.jsObjectGet(jsObj, 'account') ?? '') as P;
    case 'avatar':
      return (IsarNative.jsObjectGet(jsObj, 'avatar') ?? '') as P;
    case 'firstletter':
      return (IsarNative.jsObjectGet(jsObj, 'firstletter')) as P;
    case 'gender':
      return (IsarNative.jsObjectGet(jsObj, 'gender') ??
          double.negativeInfinity) as P;
    case 'id':
      return (IsarNative.jsObjectGet(jsObj, 'id')) as P;
    case 'isfriend':
      return (IsarNative.jsObjectGet(jsObj, 'isfriend') ??
          double.negativeInfinity) as P;
    case 'isfrom':
      return (IsarNative.jsObjectGet(jsObj, 'isfrom') ??
          double.negativeInfinity) as P;
    case 'nameIndex':
      return (IsarNative.jsObjectGet(jsObj, 'nameIndex')) as P;
    case 'namePinyin':
      return (IsarNative.jsObjectGet(jsObj, 'namePinyin')) as P;
    case 'nickname':
      return (IsarNative.jsObjectGet(jsObj, 'nickname') ?? '') as P;
    case 'region':
      return (IsarNative.jsObjectGet(jsObj, 'region') ?? '') as P;
    case 'remark':
      return (IsarNative.jsObjectGet(jsObj, 'remark') ?? '') as P;
    case 'sign':
      return (IsarNative.jsObjectGet(jsObj, 'sign') ?? '') as P;
    case 'source':
      return (IsarNative.jsObjectGet(jsObj, 'source') ?? '') as P;
    case 'sourceTr':
      return (IsarNative.jsObjectGet(jsObj, 'sourceTr') ?? '') as P;
    case 'status':
      return (IsarNative.jsObjectGet(jsObj, 'status')) as P;
    case 'title':
      return (IsarNative.jsObjectGet(jsObj, 'title') ?? '') as P;
    case 'uid':
      return (IsarNative.jsObjectGet(jsObj, 'uid')) as P;
    case 'updateTime':
      return (IsarNative.jsObjectGet(jsObj, 'updateTime')) as P;
    default:
      throw 'Illegal propertyName';
  }
}

void _contactAttachLinks(IsarCollection col, int id, Contact object) {}

extension ContactByIndex on IsarCollection<Contact> {
  Future<Contact?> getByUid(String? uid) {
    return getByIndex('uid', [uid]);
  }

  Contact? getByUidSync(String? uid) {
    return getByIndexSync('uid', [uid]);
  }

  Future<bool> deleteByUid(String? uid) {
    return deleteByIndex('uid', [uid]);
  }

  bool deleteByUidSync(String? uid) {
    return deleteByIndexSync('uid', [uid]);
  }

  Future<List<Contact?>> getAllByUid(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndex('uid', values);
  }

  List<Contact?> getAllByUidSync(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return getAllByIndexSync('uid', values);
  }

  Future<int> deleteAllByUid(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return deleteAllByIndex('uid', values);
  }

  int deleteAllByUidSync(List<String?> uidValues) {
    final values = uidValues.map((e) => [e]).toList();
    return deleteAllByIndexSync('uid', values);
  }
}

extension ContactQueryWhereSort on QueryBuilder<Contact, Contact, QWhere> {
  QueryBuilder<Contact, Contact, QAfterWhere> anyId() {
    return addWhereClauseInternal(const IdWhereClause.any());
  }

  QueryBuilder<Contact, Contact, QAfterWhere> anyUid() {
    return addWhereClauseInternal(const IndexWhereClause.any(indexName: 'uid'));
  }
}

extension ContactQueryWhere on QueryBuilder<Contact, Contact, QWhereClause> {
  QueryBuilder<Contact, Contact, QAfterWhereClause> idEqualTo(int id) {
    return addWhereClauseInternal(IdWhereClause.between(
      lower: id,
      includeLower: true,
      upper: id,
      includeUpper: true,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> idNotEqualTo(int id) {
    if (whereSortInternal == Sort.asc) {
      return addWhereClauseInternal(
        IdWhereClause.lessThan(upper: id, includeUpper: false),
      ).addWhereClauseInternal(
        IdWhereClause.greaterThan(lower: id, includeLower: false),
      );
    } else {
      return addWhereClauseInternal(
        IdWhereClause.greaterThan(lower: id, includeLower: false),
      ).addWhereClauseInternal(
        IdWhereClause.lessThan(upper: id, includeUpper: false),
      );
    }
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> idGreaterThan(int id,
      {bool include = false}) {
    return addWhereClauseInternal(
      IdWhereClause.greaterThan(lower: id, includeLower: include),
    );
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> idLessThan(int id,
      {bool include = false}) {
    return addWhereClauseInternal(
      IdWhereClause.lessThan(upper: id, includeUpper: include),
    );
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> idBetween(
    int lowerId,
    int upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addWhereClauseInternal(IdWhereClause.between(
      lower: lowerId,
      includeLower: includeLower,
      upper: upperId,
      includeUpper: includeUpper,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> uidEqualTo(String? uid) {
    return addWhereClauseInternal(IndexWhereClause.equalTo(
      indexName: 'uid',
      value: [uid],
    ));
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> uidNotEqualTo(String? uid) {
    if (whereSortInternal == Sort.asc) {
      return addWhereClauseInternal(IndexWhereClause.lessThan(
        indexName: 'uid',
        upper: [uid],
        includeUpper: false,
      )).addWhereClauseInternal(IndexWhereClause.greaterThan(
        indexName: 'uid',
        lower: [uid],
        includeLower: false,
      ));
    } else {
      return addWhereClauseInternal(IndexWhereClause.greaterThan(
        indexName: 'uid',
        lower: [uid],
        includeLower: false,
      )).addWhereClauseInternal(IndexWhereClause.lessThan(
        indexName: 'uid',
        upper: [uid],
        includeUpper: false,
      ));
    }
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> uidIsNull() {
    return addWhereClauseInternal(const IndexWhereClause.equalTo(
      indexName: 'uid',
      value: [null],
    ));
  }

  QueryBuilder<Contact, Contact, QAfterWhereClause> uidIsNotNull() {
    return addWhereClauseInternal(const IndexWhereClause.greaterThan(
      indexName: 'uid',
      lower: [null],
      includeLower: false,
    ));
  }
}

extension ContactQueryFilter
    on QueryBuilder<Contact, Contact, QFilterCondition> {
  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'account',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'account',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'account',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'account',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'account',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'account',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'account',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> accountMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'account',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'avatar',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'avatar',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'avatar',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'avatar',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'avatar',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'avatar',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'avatar',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> avatarMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'avatar',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterIsNull() {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.isNull,
      property: 'firstletter',
      value: null,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'firstletter',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterGreaterThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'firstletter',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterLessThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'firstletter',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'firstletter',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'firstletter',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'firstletter',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'firstletter',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> firstletterMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'firstletter',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> genderEqualTo(
      int value) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'gender',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> genderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'gender',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> genderLessThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'gender',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> genderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'gender',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idIsNull() {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.isNull,
      property: 'id',
      value: null,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idEqualTo(int value) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'id',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idGreaterThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'id',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idLessThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'id',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> idBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'id',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfriendEqualTo(
      int value) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'isfriend',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfriendGreaterThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'isfriend',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfriendLessThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'isfriend',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfriendBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'isfriend',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfromEqualTo(
      int value) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'isfrom',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfromGreaterThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'isfrom',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfromLessThan(
    int value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'isfrom',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> isfromBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'isfrom',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexIsNull() {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.isNull,
      property: 'nameIndex',
      value: null,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'nameIndex',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexGreaterThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'nameIndex',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexLessThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'nameIndex',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'nameIndex',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'nameIndex',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'nameIndex',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'nameIndex',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nameIndexMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'nameIndex',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinIsNull() {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.isNull,
      property: 'namePinyin',
      value: null,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'namePinyin',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinGreaterThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'namePinyin',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinLessThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'namePinyin',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'namePinyin',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'namePinyin',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'namePinyin',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'namePinyin',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> namePinyinMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'namePinyin',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'nickname',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'nickname',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'nickname',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'nickname',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'nickname',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'nickname',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'nickname',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> nicknameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'nickname',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'region',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'region',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'region',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'region',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'region',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'region',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'region',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> regionMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'region',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'remark',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'remark',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'remark',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'remark',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'remark',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'remark',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'remark',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> remarkMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'remark',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'sign',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'sign',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'sign',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'sign',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'sign',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'sign',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'sign',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> signMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'sign',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'source',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'source',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'source',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'source',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'source',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'source',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'source',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'source',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'sourceTr',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'sourceTr',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'sourceTr',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'sourceTr',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'sourceTr',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'sourceTr',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'sourceTr',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> sourceTrMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'sourceTr',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusIsNull() {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.isNull,
      property: 'status',
      value: null,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'status',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusGreaterThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'status',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusLessThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'status',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'status',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'status',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'status',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'status',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> statusMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'status',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'title',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleGreaterThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'title',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleLessThan(
    String value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'title',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleBetween(
    String lower,
    String upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'title',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'title',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'title',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'title',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> titleMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'title',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidIsNull() {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.isNull,
      property: 'uid',
      value: null,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'uid',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidGreaterThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'uid',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidLessThan(
    String? value, {
    bool caseSensitive = true,
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'uid',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidBetween(
    String? lower,
    String? upper, {
    bool caseSensitive = true,
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'uid',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.startsWith,
      property: 'uid',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.endsWith,
      property: 'uid',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidContains(
      String value,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.contains,
      property: 'uid',
      value: value,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> uidMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.matches,
      property: 'uid',
      value: pattern,
      caseSensitive: caseSensitive,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updateTimeIsNull() {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.isNull,
      property: 'updateTime',
      value: null,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updateTimeEqualTo(
      int? value) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.eq,
      property: 'updateTime',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updateTimeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.gt,
      include: include,
      property: 'updateTime',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updateTimeLessThan(
    int? value, {
    bool include = false,
  }) {
    return addFilterConditionInternal(FilterCondition(
      type: ConditionType.lt,
      include: include,
      property: 'updateTime',
      value: value,
    ));
  }

  QueryBuilder<Contact, Contact, QAfterFilterCondition> updateTimeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return addFilterConditionInternal(FilterCondition.between(
      property: 'updateTime',
      lower: lower,
      includeLower: includeLower,
      upper: upper,
      includeUpper: includeUpper,
    ));
  }
}

extension ContactQueryLinks
    on QueryBuilder<Contact, Contact, QFilterCondition> {}

extension ContactQueryWhereSortBy on QueryBuilder<Contact, Contact, QSortBy> {
  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAccount() {
    return addSortByInternal('account', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAccountDesc() {
    return addSortByInternal('account', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatar() {
    return addSortByInternal('avatar', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByAvatarDesc() {
    return addSortByInternal('avatar', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByFirstletter() {
    return addSortByInternal('firstletter', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByFirstletterDesc() {
    return addSortByInternal('firstletter', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByGender() {
    return addSortByInternal('gender', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByGenderDesc() {
    return addSortByInternal('gender', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortById() {
    return addSortByInternal('id', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByIdDesc() {
    return addSortByInternal('id', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByIsfriend() {
    return addSortByInternal('isfriend', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByIsfriendDesc() {
    return addSortByInternal('isfriend', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByIsfrom() {
    return addSortByInternal('isfrom', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByIsfromDesc() {
    return addSortByInternal('isfrom', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNameIndex() {
    return addSortByInternal('nameIndex', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNameIndexDesc() {
    return addSortByInternal('nameIndex', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNamePinyin() {
    return addSortByInternal('namePinyin', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNamePinyinDesc() {
    return addSortByInternal('namePinyin', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNickname() {
    return addSortByInternal('nickname', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByNicknameDesc() {
    return addSortByInternal('nickname', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByRegion() {
    return addSortByInternal('region', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByRegionDesc() {
    return addSortByInternal('region', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByRemark() {
    return addSortByInternal('remark', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByRemarkDesc() {
    return addSortByInternal('remark', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortBySign() {
    return addSortByInternal('sign', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortBySignDesc() {
    return addSortByInternal('sign', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortBySource() {
    return addSortByInternal('source', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortBySourceDesc() {
    return addSortByInternal('source', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortBySourceTr() {
    return addSortByInternal('sourceTr', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortBySourceTrDesc() {
    return addSortByInternal('sourceTr', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStatus() {
    return addSortByInternal('status', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByStatusDesc() {
    return addSortByInternal('status', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByTitle() {
    return addSortByInternal('title', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByTitleDesc() {
    return addSortByInternal('title', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByUid() {
    return addSortByInternal('uid', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByUidDesc() {
    return addSortByInternal('uid', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByUpdateTime() {
    return addSortByInternal('updateTime', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> sortByUpdateTimeDesc() {
    return addSortByInternal('updateTime', Sort.desc);
  }
}

extension ContactQueryWhereSortThenBy
    on QueryBuilder<Contact, Contact, QSortThenBy> {
  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAccount() {
    return addSortByInternal('account', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAccountDesc() {
    return addSortByInternal('account', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatar() {
    return addSortByInternal('avatar', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByAvatarDesc() {
    return addSortByInternal('avatar', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByFirstletter() {
    return addSortByInternal('firstletter', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByFirstletterDesc() {
    return addSortByInternal('firstletter', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByGender() {
    return addSortByInternal('gender', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByGenderDesc() {
    return addSortByInternal('gender', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenById() {
    return addSortByInternal('id', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIdDesc() {
    return addSortByInternal('id', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIsfriend() {
    return addSortByInternal('isfriend', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIsfriendDesc() {
    return addSortByInternal('isfriend', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIsfrom() {
    return addSortByInternal('isfrom', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByIsfromDesc() {
    return addSortByInternal('isfrom', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNameIndex() {
    return addSortByInternal('nameIndex', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNameIndexDesc() {
    return addSortByInternal('nameIndex', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNamePinyin() {
    return addSortByInternal('namePinyin', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNamePinyinDesc() {
    return addSortByInternal('namePinyin', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNickname() {
    return addSortByInternal('nickname', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByNicknameDesc() {
    return addSortByInternal('nickname', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRegion() {
    return addSortByInternal('region', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRegionDesc() {
    return addSortByInternal('region', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRemark() {
    return addSortByInternal('remark', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByRemarkDesc() {
    return addSortByInternal('remark', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenBySign() {
    return addSortByInternal('sign', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenBySignDesc() {
    return addSortByInternal('sign', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenBySource() {
    return addSortByInternal('source', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenBySourceDesc() {
    return addSortByInternal('source', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenBySourceTr() {
    return addSortByInternal('sourceTr', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenBySourceTrDesc() {
    return addSortByInternal('sourceTr', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStatus() {
    return addSortByInternal('status', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByStatusDesc() {
    return addSortByInternal('status', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByTitle() {
    return addSortByInternal('title', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByTitleDesc() {
    return addSortByInternal('title', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByUid() {
    return addSortByInternal('uid', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByUidDesc() {
    return addSortByInternal('uid', Sort.desc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByUpdateTime() {
    return addSortByInternal('updateTime', Sort.asc);
  }

  QueryBuilder<Contact, Contact, QAfterSortBy> thenByUpdateTimeDesc() {
    return addSortByInternal('updateTime', Sort.desc);
  }
}

extension ContactQueryWhereDistinct
    on QueryBuilder<Contact, Contact, QDistinct> {
  QueryBuilder<Contact, Contact, QDistinct> distinctByAccount(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('account', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByAvatar(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('avatar', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByFirstletter(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('firstletter', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByGender() {
    return addDistinctByInternal('gender');
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctById() {
    return addDistinctByInternal('id');
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByIsfriend() {
    return addDistinctByInternal('isfriend');
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByIsfrom() {
    return addDistinctByInternal('isfrom');
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByNameIndex(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('nameIndex', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByNamePinyin(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('namePinyin', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByNickname(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('nickname', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByRegion(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('region', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByRemark(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('remark', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctBySign(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('sign', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctBySource(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('source', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctBySourceTr(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('sourceTr', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByStatus(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('status', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByTitle(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('title', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByUid(
      {bool caseSensitive = true}) {
    return addDistinctByInternal('uid', caseSensitive: caseSensitive);
  }

  QueryBuilder<Contact, Contact, QDistinct> distinctByUpdateTime() {
    return addDistinctByInternal('updateTime');
  }
}

extension ContactQueryProperty
    on QueryBuilder<Contact, Contact, QQueryProperty> {
  QueryBuilder<Contact, String, QQueryOperations> accountProperty() {
    return addPropertyNameInternal('account');
  }

  QueryBuilder<Contact, String, QQueryOperations> avatarProperty() {
    return addPropertyNameInternal('avatar');
  }

  QueryBuilder<Contact, String?, QQueryOperations> firstletterProperty() {
    return addPropertyNameInternal('firstletter');
  }

  QueryBuilder<Contact, int, QQueryOperations> genderProperty() {
    return addPropertyNameInternal('gender');
  }

  QueryBuilder<Contact, int?, QQueryOperations> idProperty() {
    return addPropertyNameInternal('id');
  }

  QueryBuilder<Contact, int, QQueryOperations> isfriendProperty() {
    return addPropertyNameInternal('isfriend');
  }

  QueryBuilder<Contact, int, QQueryOperations> isfromProperty() {
    return addPropertyNameInternal('isfrom');
  }

  QueryBuilder<Contact, String?, QQueryOperations> nameIndexProperty() {
    return addPropertyNameInternal('nameIndex');
  }

  QueryBuilder<Contact, String?, QQueryOperations> namePinyinProperty() {
    return addPropertyNameInternal('namePinyin');
  }

  QueryBuilder<Contact, String, QQueryOperations> nicknameProperty() {
    return addPropertyNameInternal('nickname');
  }

  QueryBuilder<Contact, String, QQueryOperations> regionProperty() {
    return addPropertyNameInternal('region');
  }

  QueryBuilder<Contact, String, QQueryOperations> remarkProperty() {
    return addPropertyNameInternal('remark');
  }

  QueryBuilder<Contact, String, QQueryOperations> signProperty() {
    return addPropertyNameInternal('sign');
  }

  QueryBuilder<Contact, String, QQueryOperations> sourceProperty() {
    return addPropertyNameInternal('source');
  }

  QueryBuilder<Contact, String, QQueryOperations> sourceTrProperty() {
    return addPropertyNameInternal('sourceTr');
  }

  QueryBuilder<Contact, String?, QQueryOperations> statusProperty() {
    return addPropertyNameInternal('status');
  }

  QueryBuilder<Contact, String, QQueryOperations> titleProperty() {
    return addPropertyNameInternal('title');
  }

  QueryBuilder<Contact, String?, QQueryOperations> uidProperty() {
    return addPropertyNameInternal('uid');
  }

  QueryBuilder<Contact, int?, QQueryOperations> updateTimeProperty() {
    return addPropertyNameInternal('updateTime');
  }
}
