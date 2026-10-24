import 'package:imboy/component/helper/datetime.dart';
import 'package:imboy/store/model/model_parse_utils.dart';

class UserCollectModel {
  int userId;

  // Kind 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息  7 个人名片
  int kind;

  // kind_id 是被收藏资源的 id（消息 id 为 String Xid base32hex），
  // 曾是 int 导致 parseModelInt 把 Xid 静默归零（QA#31，v22 迁移改 TEXT）
  String kindId;
  String source;
  String remark;

  // 朋友标签，半角逗号分割，单个表情不超过14字符
  String tag;

  int updatedAt;
  int createdAt;

  Map<String, dynamic> info;

  /// E2EE 收藏 v1（本地库 v34/服务端迁移 227）：记录修订号（0=legacy 行）。
  int generation;

  /// E2EE 收藏 v1：>0 = sealed 行（info 为客户端密文 base64 原文，未解密）。
  int keyVersion;

  UserCollectModel({
    required this.userId,
    required this.kind,
    required this.kindId,
    required this.source,
    required this.remark,
    required this.tag,
    required this.updatedAt,
    required this.createdAt,
    required this.info,
    this.generation = 0,
    this.keyVersion = 0,
    this.infoSealed,
    this.attachFileHash256 = '',
  });

  /// sealed 行判据（与服务端 key_version IS NOT NULL 对齐；本地以 0 表 legacy）。
  bool get sealed => keyVersion > 0;

  /// sealed 行原始密文（服务端/本地缓存的 info 列 base64，未经解密）；
  /// 解密材料由 [sealed] 行的 keychain open 使用，legacy 行为 null。
  final String? infoSealed;

  /// 行可见引用列表（逗号串原样；sealed 解密 AAD 参数与 §8.2 双核对源）。
  final String attachFileHash256;

  factory UserCollectModel.fromJson(Map<String, dynamic> data) {
    return UserCollectModel(
      userId: parseModelInt(data['user_id']),
      kind: parseModelInt(data['kind']),
      kindId: parseModelString(data['kind_id']),
      source: parseModelString(data['source']),
      remark: parseModelString(data['remark']),
      tag: parseModelString(data['tag']),
      updatedAt: DateTimeHelper.parseTimestamp(data['updated_at']),
      createdAt: DateTimeHelper.parseTimestamp(data['created_at']),
      // parseModelJsonMap 容忍 String/Map/null，避免手写 json.decode 的静默 catch
      info: parseModelJsonMap(data['info']) ?? <String, dynamic>{},
      generation: parseModelInt(data['generation']),
      keyVersion: parseModelInt(data['key_version']),
      infoSealed:
          data['info'] is String && parseModelInt(data['key_version']) > 0
          ? data['info'] as String
          : null,
      attachFileHash256: parseModelString(data['attach_file_hash256']),
    );
  }

  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['user_id'] = userId;
    data['kind'] = kind;
    data['kind_id'] = kindId;
    data['source'] = source;
    data['remark'] = remark;
    data['tag'] = tag;
    data['updated_at'] = updatedAt;
    data['created_at'] = createdAt;
    // sealed 行 toMap 携带密文原文（本地缓存/回写源），解密后 payload
    // 仅存在于内存 model（不落明文表）
    data['info'] = sealed && infoSealed != null && infoSealed!.isNotEmpty
        ? infoSealed
        : info;
    data['generation'] = generation;
    data['key_version'] = keyVersion;
    data['attach_file_hash256'] = attachFileHash256;
    return data;
  }
}
