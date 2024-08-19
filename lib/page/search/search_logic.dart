import 'package:get/get.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/message_repo_sqlite.dart';

import 'search_state.dart';

class SearchLogic extends GetxController {
  final state = SearchState();

  Future<List<types.Message>> search({
    required String type,
    int page = 1,
    int size = 100,
    String? kwd,
    String? conversationUk3,
  }) async {

    var repo = MessageRepo(tableName: MessageRepo.getTableName(type));


    String? orderBy;

    List<MessageModel> list2 = await repo.page(
      page: page,
      size: size,
      kwd:kwd,
      conversationUk3:conversationUk3,
      orderBy: orderBy,
    );
    if (list2.isEmpty) {
      return [];
    }
    List<types.Message> list = [];
    for (int i = 0; i < list2.length; i++) {
      MessageModel msg = list2[i];
      list.add(await msg.toTypeMessage());
    }
    return list;
  }
}
