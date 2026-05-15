import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/page/user_tag/contact_tag_list/contact_tag_list_provider.dart';
import 'package:imboy/page/user_tag/contact_tag_detail/contact_tag_detail_provider.dart';
import 'package:imboy/store/model/user_tag_model.dart';

import 'user_tag_save_provider.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 用户标签保存/编辑页面
class UserTagSavePage extends ConsumerStatefulWidget {
  final UserTagModel? tag;
  final String scene;

  const UserTagSavePage({super.key, this.tag, required this.scene});

  @override
  ConsumerState<UserTagSavePage> createState() => _UserTagSavePageState();
}

class _UserTagSavePageState extends ConsumerState<UserTagSavePage> {
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _valueChanged = false;

  // 防抖状态
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.tag?.name ?? '';
    _textController.addListener(() {
      setState(() {
        _valueChanged = _textController.text.trim() != (widget.tag?.name ?? '');
      });
    });
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 输入框(TextField)被键盘遮挡解决方案
      resizeToAvoidBottomInset: false,
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        leading: InkWell(
          onTap: () {
            Navigator.of(context).pop();
          },
          child: const Icon(Icons.close),
        ),
        title: widget.tag == null
            ? t.common.addTag
            : t.main.changeParam(param: t.contact.tags),
      ),
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: 120,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextFormField(
                autofocus: true,
                focusNode: _inputFocusNode,
                controller: _textController,
                keyboardType: TextInputType.text,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                  filled: true,
                  fillColor: isDark
                      ? const Color.fromRGBO(70, 70, 70, 1.0)
                      : Colors.white70,
                  focusedBorder: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusTiny,
                    borderSide: const BorderSide(width: 1.0),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusTiny,
                    borderSide: const BorderSide(width: 1.0),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusTiny,
                    borderSide: const BorderSide(width: 1.0, color: Colors.red),
                  ),
                  errorStyle: const TextStyle(),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusTiny,
                    borderSide: const BorderSide(width: 1.0, color: Colors.red),
                  ),
                  border: InputBorder.none,
                ),
                readOnly: false,
                onFieldSubmitted: (val) async {
                  FocusScope.of(context).requestFocus(FocusNode());
                  if (val == '') {
                    setState(() {
                      _valueChanged = false;
                    });
                  }
                },
                onChanged: (val) {
                  // 已经在 initState 中监听
                },
                onSaved: (value) {},
                validator: (value) {
                  return null;
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RoundedElevatedButton(
                  text: t.common.buttonAccomplish,
                  highlighted: _valueChanged && !_isSaving,
                  onPressed: _isSaving
                      ? null
                      : () async {
                          String trimmedText = _textController.text.trim();
                          if (trimmedText.isEmpty) {
                            setState(() {
                              _valueChanged = false;
                            });
                            return;
                          }

                          // 防抖：设置保存状态
                          setState(() => _isSaving = true);

                          try {
                            if (widget.tag == null && _valueChanged) {
                              // 添加新标签
                              final newTag = await ref
                                  .read(userTagSaveProvider.notifier)
                                  .addTag(
                                    scene: widget.scene,
                                    tagName: trimmedText,
                                  );
                              if (newTag != null) {
                                // 添加到列表
                                ref
                                    .read(contactTagListProvider.notifier)
                                    .updateTag(newTag);
                                Navigator.of(context).pop();
                              }
                            } else if (_valueChanged) {
                              // 修改标签名称
                              bool res = await ref
                                  .read(userTagSaveProvider.notifier)
                                  .changeName(
                                    scene: widget.scene,
                                    tagId: widget.tag?.tagId ?? 0,
                                    tagName: trimmedText,
                                  );
                              if (res) {
                                await ref
                                    .read(contactTagListProvider.notifier)
                                    .replaceObjectTag(
                                      scene: widget.scene,
                                      oldName: widget.tag?.name ?? '',
                                      newName: trimmedText,
                                    );

                                // 更新标签
                                UserTagModel updatedTag = UserTagModel(
                                  userId: widget.tag?.userId ?? 0,
                                  tagId: widget.tag?.tagId ?? 0,
                                  scene: widget.tag?.scene ?? 2,
                                  name: trimmedText,
                                  subtitle: widget.tag?.subtitle ?? '',
                                  refererTime: widget.tag?.refererTime ?? 0,
                                  updatedAt: widget.tag?.updatedAt ?? 0,
                                  createdAt: widget.tag?.createdAt ?? 0,
                                );
                                ref
                                    .read(contactTagListProvider.notifier)
                                    .updateTag(updatedTag);

                                // 如果详情页面已打开，更新标签名称
                                try {
                                  ref.read(contactTagDetailProvider).tagName;
                                } catch (e) {
                                  // 详情页面未打开，忽略
                                }

                                EasyLoading.showSuccess(t.common.tipSuccess);
                                Navigator.of(context).pop();
                              } else {
                                EasyLoading.showError(t.common.tipFailed);
                              }
                            }
                          } finally {
                            // 恢复保存状态
                            if (mounted) {
                              setState(() => _isSaving = false);
                            }
                          }
                        },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
