import 'package:flutter/cupertino.dart';
import 'package:imboy/component/view/message/msg_avatar.dart';
import 'package:imboy/component/view/message/text_item_container.dart';
import 'package:imboy/store/model/message_model.dart';
import 'package:imboy/store/repository/user_repository.dart';

class TextMsg extends StatelessWidget {
  final String content;
  final MessageModel model;

  TextMsg(this.content, this.model);

  @override
  Widget build(BuildContext context) {
    // final global = Provider.of<CurrentUserModel>(context, listen: false);
    var currentUser = UserRepository.currentUser();
    var body = [
      new MsgAvatar(model: model),
      new TextItemContainer(
        text: content ?? '文字为空',
        action: '',
        itself: true, // itself: model.fromId == global.uid,
      ),
      new Spacer(),
    ];
    var alignment = Alignment.centerLeft;
    if (model.fromId == currentUser.uid) {
      alignment = Alignment.centerRight;
      body = body.reversed.toList();
    } else {
      body = body;
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 5.0),
      child: new Row(children: body, mainAxisAlignment: MainAxisAlignment.end),
      alignment: alignment,
    );
  }
}
