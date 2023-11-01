import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/init.dart';

import 'group_bill_board_logic.dart';
import 'group_bill_board_state.dart';

class GroupBillBoardPage extends StatefulWidget {
  final String? groupOwner;
  final String? groupNotice;
  final String? groupId;
  final String? time;
  final Callback? callback;

  const GroupBillBoardPage(
    this.groupOwner,
    this.groupNotice, {
    super.key,
    this.groupId,
    this.time,
    this.callback,
  });

  @override
  // ignore: library_private_types_in_public_api
  _GroupBillBoardPageState createState() => _GroupBillBoardPageState();
}

class _GroupBillBoardPageState extends State<GroupBillBoardPage> {
  final logic = Get.find<GroupBillBoardLogic>();
  final GroupBillBoardState state = Get.find<GroupBillBoardLogic>().state;

  bool inputState = false;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  String? _publishTime;

  TextStyle styleLabel =
      TextStyle(fontSize: 12.0, color: Colors.black.withOpacity(0.8));

  @override
  void initState() {
    super.initState();
    _textController.text = widget.groupNotice!;
  }

  onChange() {
    if (inputState) {
      _publishTime =
          "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day} ${DateTime.now().hour}:${DateTime.now().minute}";
      widget.callback!(_publishTime);
      Navigator.pop(context, _textController.text);
      inputState = false;
    } else {
      inputState = true;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // var rWidget = ComMomButton(
    //   text: '确定',
    //   style: const TextStyle(color: Colors.white),
    //   width: 45.0,
    //   margin: const EdgeInsets.all(10.0),
    //   radius: 4.0,
    //   onTap: () => onChange(),
    // );

    return Scaffold(
      appBar: const PageAppBar(
        title: '群公告',
        // rightDMActions: <Widget>[rWidget],
      ),
      body: TextField(
        decoration: const InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: '请编辑群公告',
        ),
        autofocus: true,
        focusNode: _focusNode,
        maxLines: null,
        expands: true,
        controller: _textController,
        style: const TextStyle(fontSize: 15.0),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<GroupBillBoardLogic>();
    super.dispose();
  }
}
