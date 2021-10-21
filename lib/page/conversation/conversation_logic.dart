import 'package:get/get.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:imboy/store/repository/user_repo_sp.dart';

import 'conversation_state.dart';

class ConversationLogic extends GetxController {
  final state = ConversationState();
  final UserRepoSP current = Get.put(UserRepoSP.user);

  @override
  void onReady() {
    // TODO: implement onReady
    super.onReady();
  }

  getConversationsList() async {
    Map<String, ConversationModel> items =
        await (ConversationRepo()).findByCuid(current.currentUid);
    print(">>>>> on getConversationsList cuid: " + current.currentUid);
    print(">>>>> on items.length: " + items.length.toString());
    return items;
  }

  @override
  void onClose() {
    // TODO: implement onClose
    super.onClose();
  }

  reciveMessage(e) {}
}
