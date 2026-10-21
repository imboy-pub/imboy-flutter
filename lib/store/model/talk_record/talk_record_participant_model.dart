import 'package:imboy/store/model/model_parse_utils.dart';
import 'package:imboy/store/model/workspace_model.dart'
    show EntityId, entityIdOf;

/// A selected person is informational; it never creates a sharing grant.
class TalkRecordParticipantInput {
  const TalkRecordParticipantInput({this.userId = '', this.displayName = ''});
  final EntityId userId;
  final String displayName;

  Map<String, dynamic> toJson() {
    if (userId.isNotEmpty) {
      if (!RegExp(r'^[1-9][0-9]*$').hasMatch(userId)) {
        throw const FormatException('Invalid participant user id');
      }
      return {'user_id': int.parse(userId)};
    }
    final name = displayName.trim();
    if (name.isEmpty || name.runes.length > 120) {
      throw const FormatException('Invalid participant label');
    }
    return {'display_name': name};
  }

  factory TalkRecordParticipantInput.fromJson(Map<String, dynamic> json) {
    final input = TalkRecordParticipantInput(
      userId: entityIdOf(json['user_id']),
      displayName: parseModelString(json['display_name']),
    );
    input.toJson();
    return input;
  }

  String get identityKey =>
      userId.isNotEmpty ? 'user:$userId' : 'guest:${displayName.trim()}';
}

class TalkRecordParticipantModel {
  const TalkRecordParticipantModel({
    required this.id,
    required this.input,
    required this.displayName,
    required this.attendanceSource,
  });
  final EntityId id;
  final TalkRecordParticipantInput input;
  final String displayName, attendanceSource;

  factory TalkRecordParticipantModel.fromJson(Map<String, dynamic> json) =>
      TalkRecordParticipantModel(
        id: entityIdOf(json['id']),
        input: TalkRecordParticipantInput.fromJson(json),
        displayName: parseModelString(json['display_name']),
        attendanceSource: parseModelString(json['attendance_source']),
      );
}

class TalkRecordParticipants {
  TalkRecordParticipants.fromJson(Map<String, dynamic> json)
    : recordId = entityIdOf(json['record_id']),
      revision = json['revision'] is int ? json['revision'] as int : 0,
      list = List.unmodifiable(
        (json['list'] as List).map(
          (item) => TalkRecordParticipantModel.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        ),
      );
  final EntityId recordId;
  final int revision;
  final List<TalkRecordParticipantModel> list;

  bool matches(List<TalkRecordParticipantInput> desired) {
    final expected = desired.map((item) => item.identityKey).toSet();
    final actual = list.map((item) => item.input.identityKey).toSet();
    return expected.length == desired.length &&
        actual.length == list.length &&
        expected.length == actual.length &&
        expected.containsAll(actual);
  }
}
