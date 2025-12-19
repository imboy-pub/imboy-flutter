import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common.dart';

import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/model/group_model.dart';

import 'group_detail_logic.dart';

class ChangeInfoPage extends StatefulWidget {
  const ChangeInfoPage({
    super.key,
    required this.group,
    required this.title,
    required this.subtitle,
  });

  final GroupModel group;
  final String title;
  final String subtitle;

  @override
  ChangeInfoPageState createState() => ChangeInfoPageState();
}

class ChangeInfoPageState extends State<ChangeInfoPage> {
  final logic = Get.put(GroupDetailLogic());

  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

  final RxBool valueChanged = false.obs;
  final RxString val = "".obs;
  final RxBool onClose = false.obs;

  /// 加载好友申请数据
  void initData() async {
    _setText(widget.group.title);
    // 给予一些延时，确保页面构建完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  /// https://stackoverflow.com/questions/60057840/flutter-how-to-insert-text-in-middle-of-text-field-text
  void _setText(String val) {
    String text = _textController.text;
    TextSelection textSelection = _textController.selection;
    int start = textSelection.start > -1 ? textSelection.start : 0;
    String newText = text.replaceRange(
      start,
      textSelection.end > -1 ? textSelection.end : 0,
      val,
    );
    _textController.text = newText;
    int offset = start + val.length;
    _textController.selection = textSelection.copyWith(
      baseOffset: offset,
      extentOffset: offset,
    );
  }

  @override
  void initState() {
    super.initState();
    initData();
  }

  @override
  void dispose() {
    // 清理资源
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: NavAppBar(
        // backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(left: 10, right: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Space(height: 10, width: Get.width),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Expanded(
                child: Text(
              widget.title,
              textAlign: TextAlign.center, // 文本对齐方式为居中
              style: TextStyle(
                fontSize: 24.0,
                fontWeight: FontWeight.w600,
              ),
            ))
          ]),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Expanded(
                child: Text(
              widget.subtitle,
              textAlign: TextAlign.center, // 文本对齐方式为居中
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
              ),
            ))
          ]),
          SizedBox(height: 20, width: Get.width),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
            SmartGroupAvatar(
              avatar: widget.group.avatar,
              groupId: widget.group.groupId,
              // size: 44,
              // onTap: onTapAvatar,
            ),
            const Space(
              width: 8,
            ),
            SizedBox(
              height: 80,
              width: Get.width - 128,
              child: TextField(
                focusNode: _inputFocusNode,
                controller: _textController,
                autofocus: true,
                maxLines: 1,
                maxLength: 80,
                decoration: InputDecoration(
                  counterText: '', // 这行代码会隐藏字符计数器
                  hintText: widget.group.title.isEmpty ? 'unnamed'.tr : '',
                  contentPadding: const EdgeInsets.only(
                    top: 28,
                    bottom: 10,
                  ), // 增加填充来调整高度
                ),
                onChanged: (value) {
                  valueChanged.value = value.trim() != widget.group.title;
                  onClose.value = value.isEmpty ? true : false;
                },
              ),
            ),
            Obx(() => Visibility(
                  visible: onClose.isFalse,
                  child: IconButton(
                    onPressed: () {
                      _textController.text = '';
                      valueChanged.value = true;
                      onClose.value = true; // Since the text is now empty
                    },
                    icon: const Icon(Icons.cancel),
                  ),
                )),
            // Text(logic.themeTypeTips());
          ]),
          SizedBox(height: 20, width: Get.width),
          Obx(
            () => RoundedElevatedButton(
              text: 'buttonAccomplish'.tr,
              highlighted: valueChanged.isTrue,
              onPressed: () async {
                String trimmedText = _textController.text.trim();
                if (valueChanged.isTrue) {
                  GroupModel? g = await logic.groupEdit(widget.group.groupId, {
                    'title': trimmedText,
                  });
                  if (g != null) {
                    EasyLoading.showSuccess('tipSuccess'.tr);
                    Get.back(result: g);
                    //   peerRemark = trimmedText;
                    //   Get.back(result: trimmedText);
                  }
                }
              },
            ),
          ),
        ]),
      ),
    );
  }
}
