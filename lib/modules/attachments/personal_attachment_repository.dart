import 'package:imboy/service/sqlite.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repo_local.dart';

class PersonalAttachment {
  const PersonalAttachment(this.message, this.name);
  final MessageModel message;
  final String name;

  static PersonalAttachment? fromMessage(MessageModel message) {
    if (IMBoyMessageStatus.isRevokedStatus(message.status)) return null;
    final data = message.payloadMap;
    if (data.isEmpty) {
      return null; // No ciphertext parsing or implicit key recovery.
    }
    final name = (data['filename'] ?? data['name'] ?? '').toString().trim();
    return PersonalAttachment(message, name);
  }
}

/// Read-only index over this account's local message database. No cloud calls.
class PersonalAttachmentRepository {
  static const types = [
    'file',
    'image',
    'imageMulti',
    'video',
    'voice',
    'audio',
  ];

  Future<List<PersonalAttachment>> page({
    int offset = 0,
    int limit = 40,
    String keyword = '',
  }) async {
    final account = UserRepoLocal.to.currentUid;
    if (account.isEmpty) throw Exception('No active account');
    final db = await SqliteService.to.db;
    if (db == null) throw Exception('Local message database unavailable');
    final placeholders = List.filled(types.length, '?').join(',');
    final rows = await db.rawQuery(
      '''
      SELECT * FROM (
        SELECT id,type,CAST(from_id AS TEXT) AS from_id,CAST(to_id AS TEXT) AS to_id,payload,created_at,conversation_uk3,
               is_author,topic_id,status,msg_type,auto_id FROM msg_c2c
        UNION ALL
        SELECT id,type,CAST(from_id AS TEXT) AS from_id,CAST(to_id AS TEXT) AS to_id,payload,created_at,conversation_uk3,
               is_author,topic_id,status,msg_type,auto_id FROM msg_c2g
      ) WHERE msg_type IN ($placeholders)
        AND COALESCE(status, 0) NOT BETWEEN 30 AND 39
        AND CASE WHEN json_valid(payload) THEN json_type(payload) = 'object' ELSE 0 END
        AND CASE WHEN json_valid(payload) THEN
          COALESCE(json_extract(payload, '\$.filename'), json_extract(payload, '\$.name'), '')
          ELSE '' END LIKE ? ESCAPE '!'
      ORDER BY created_at DESC, type ASC, auto_id DESC LIMIT ? OFFSET ?
    ''',
      [
        ...types,
        '%${keyword.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_')}%',
        limit.clamp(1, 100),
        offset < 0 ? 0 : offset,
      ],
    );
    if (account != UserRepoLocal.to.currentUid) {
      throw Exception('Account changed during attachment query');
    }
    // Only index locally readable metadata; ciphertext stays in the source chat.
    return rows
        .map(
          (row) => PersonalAttachment(
            MessageModel.fromJson(Map<String, dynamic>.from(row)),
            '',
          ),
        )
        .toList();
  }
}
