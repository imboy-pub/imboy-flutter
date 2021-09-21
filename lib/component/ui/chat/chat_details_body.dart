import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:imboy/component/ui/message/send_msg.dart';
import 'package:imboy/component/view/indicator_page_view.dart';
import 'package:imboy/store/model/message_model.dart';

class ChatDetailsBody extends StatelessWidget {
  final ScrollController sC;
  List<MessageModel> msgs = [];

  ChatDetailsBody({required this.sC, required this.msgs});

  @override
  Widget build(BuildContext context) {
    return new Flexible(
      child: new ScrollConfiguration(
        behavior: MyBehavior(),
        child: new ListView.builder(
          controller: sC,
          padding: EdgeInsets.all(8.0),
          reverse: true,
          itemBuilder: (context, int index) {
            MessageModel model = msgs[index];
            return new SendMessageView(model);
          },
          itemCount: msgs.length,
          dragStartBehavior: DragStartBehavior.down,
        ),
      ),
    );
  }
}
