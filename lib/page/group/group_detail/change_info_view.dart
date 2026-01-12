import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/group/group_list/group_list_logic.dart';
import 'package:imboy/store/model/group_model.dart';

import 'group_detail_logic.dart';
import 'package:imboy/i18n/strings.g.dart';

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
  final GroupListLogic groupListLogic = Get.find<GroupListLogic>();

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
      appBar: GlassAppBar(
        title: widget.title,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            if (widget.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.outline,
                  ),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  SmartGroupAvatar(
                    avatar: widget.group.avatar,
                    groupId: widget.group.groupId,
                    size: 44,
                    avatarLoader: groupListLogic.computeAvatar,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      focusNode: _inputFocusNode,
                      controller: _textController,
                      autofocus: true,
                      maxLines: 1,
                      maxLength: 80,
                      style: TextStyle(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        border: InputBorder.none,
                        hintText: widget.group.title.isEmpty ? t.unnamed : '',
                        hintStyle: TextStyle(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        valueChanged.value = value.trim() != widget.group.title;
                        onClose.value = value.isEmpty;
                      },
                    ),
                  ),
                  Obx(() => Visibility(
                        visible: onClose.isFalse,
                        child: GestureDetector(
                          onTap: () {
                            _textController.text = '';
                            valueChanged.value = true;
                            onClose.value = true;
                          },
                          child: Icon(
                            Icons.cancel,
                            color: colorScheme.outline.withValues(alpha: 0.5),
                            size: 20,
                          ),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Obx(
              () => RoundedElevatedButton(
                text: t.buttonAccomplish,
                highlighted: valueChanged.isTrue,
                onPressed: () async {
                  String trimmedText = _textController.text.trim();
                  if (valueChanged.isTrue) {
                    GroupModel? g = await logic.groupEdit(widget.group.groupId, {
                      'title': trimmedText,
                    });
                    if (g != null) {
                      EasyLoading.showSuccess(t.tipSuccess);
                      Get.back(result: g);
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
