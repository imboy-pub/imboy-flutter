import 'package:get/get.dart';
import 'package:imboy/store/model/conversation_model.dart';

class SendToState {
  SendToState() {
    ///Initialize variables
  }

//  多选
  RxBool multipleChoice = false.obs;

  // 会话列表
  RxList<ConversationModel> conversations = RxList<ConversationModel>([]);
}
