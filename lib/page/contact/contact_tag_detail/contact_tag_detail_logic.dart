import 'package:get/get.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/provider/user_tag_provider.dart';
import 'package:imboy/store/repository/user_tag_relation_repo_sqlite.dart';

import 'contact_tag_detail_state.dart';

class ContactTagDetailLogic extends GetxController {
  RxList<ContactModel> contactList = RxList<ContactModel>();

  final ContactTagDetailState state = ContactTagDetailState();

  pageRelation(bool onRefresh, String scene) async {
    List<ContactModel> contact = [];
    var repo = UserTagRelationRepo();
    if (onRefresh == false) {
      // contact = await repo.list();
    }
    if (contact.isNotEmpty) {
      return contact;
    }
    Map<String, dynamic>? resp = await (UserTagProvider())
        .pageRelation(page: 1, size: 1000, scene: scene);
    List<dynamic> items = resp?['list'] ?? [];
    for (var json in items) {
      ContactModel model = await repo.save(json);
      // debugPrint("> on findFriend2 item ${model.toJson().toString()} ");
      if (model.isFriend == 1) {
        contact.insert(0, model);
      }
    }
    return contact;
  }
}
