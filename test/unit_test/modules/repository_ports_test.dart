import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/group_collab/infrastructure/group_repository.dart';
import 'package:imboy/modules/messaging/infrastructure/message_repository.dart';
import 'package:imboy/modules/social_graph/infrastructure/contact_repository.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/store/repository/group_repo_sqlite.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

/// 编译期子类型断言 / Compile-time subtype assertions（T4.4a）。
///
/// 下列函数仅当各 `*_repo_sqlite` 类的 `implements <Port>` 关系成立时才能通过类型
/// 检查——编译/`dart analyze` 通过即为契约验证。**无需实例化**，故不触 SQLite，
/// 规避无头测试的 DB 初始化依赖。
///
/// These coercions only type-check when each sqlite repo `implements` its port;
/// a successful compile is the verification. No instantiation → no DB coupling.
MessageRepository _coerceMessage(MessageRepo r) => r;
GroupRepository _coerceGroup(GroupRepo r) => r;
ContactRepository _coerceContact(ContactRepo r) => r;

void main() {
  group('repository ports (T4.4a)', () {
    test('sqlite repos are subtypes of their domain ports', () {
      expect(_coerceMessage, isA<MessageRepository Function(MessageRepo)>());
      expect(_coerceGroup, isA<GroupRepository Function(GroupRepo)>());
      expect(_coerceContact, isA<ContactRepository Function(ContactRepo)>());
    });
  });
}
