import 'package:imboy/store/model/people_model.dart';

class JoinGroupModel {
  final String groupId;
  final String userId;
  final bool isFirst;
  final PeopleModel people;
  JoinGroupModel({
    required this.groupId,
    required this.userId,
    required this.isFirst,
    required this.people,
  });
}

class LeaveGroupModel {
  final String groupId;
  final String userId;
  final PeopleModel people;

  LeaveGroupModel({
    required this.groupId,
    required this.userId,
    required this.people,
  });
}