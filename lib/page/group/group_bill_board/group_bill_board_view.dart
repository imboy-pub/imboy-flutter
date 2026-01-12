import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/datetime.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'group_bill_board_logic.dart';
import 'group_bill_board_state.dart';
import 'package:imboy/i18n/strings.g.dart';

class GroupBillBoardPage extends StatefulWidget {
  final String? groupOwner;
  final String? groupNotice;
  final String? groupId;
  final String? time;
  final Function(String?)? callback;

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

  final FocusNode _focusNode = FocusNode();
  late final TextEditingController _textController;
  bool _canSave = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.groupNotice ?? '');
    _textController.addListener(() {
      final isModified = _textController.text != (widget.groupNotice ?? '');
      if (isModified != _canSave) {
        setState(() {
          _canSave = isModified;
        });
      }
    });
  }

  void _saveNotice() {
    if (!_canSave) return;
    final newNotice = _textController.text;
    final now = DateTime.fromMillisecondsSinceEpoch(DateTimeHelper.millisecond());
    final publishTime =
        "${now.year}-${now.month}-${now.day} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    widget.callback?.call(publishTime);
    Navigator.pop(context, newNotice);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: GlassAppBar(
        title: t.groupAnnouncement,
        rightDMActions: [
          TextButton(
            onPressed: _canSave ? _saveNotice : null,
            child: Text(t.buttonAccomplish),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: TextField(
          decoration: InputDecoration(
            hintText: t.hintEditGroupAnnouncement,
            border: InputBorder.none,
            filled: true,
            fillColor: theme.cardColor,
          ),
          autofocus: true,
          focusNode: _focusNode,
          maxLines: null,
          expands: true,
          controller: _textController,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  @override
  void dispose() {
    Get.delete<GroupBillBoardLogic>();
    super.dispose();
  }
}
