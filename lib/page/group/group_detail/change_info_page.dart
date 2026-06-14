import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/store/model/group_model.dart';
import 'package:imboy/store/repository/group_member_repo_sqlite.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'change_info_provider.dart';

/// 修改群信息页面
class ChangeInfoPage extends ConsumerStatefulWidget {
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
  ConsumerState<ChangeInfoPage> createState() => ChangeInfoPageState();
}

class ChangeInfoPageState extends ConsumerState<ChangeInfoPage> {
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  @override
  void dispose() {
    _inputFocusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  /// 初始化数据
  void _initData() {
    final notifier = ref.read(changeInfoProvider.notifier);
    notifier.setGroup(widget.group);
    _setText(widget.group.title);

    // 给予一些延时，确保页面构建完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  /// 设置文本并保持光标位置
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
  Widget build(BuildContext context) {
    final state = ref.watch(changeInfoProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: isDark
          ? colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(automaticallyImplyLeading: true, title: widget.title),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.regular,
          vertical: AppSpacing.large,
        ),
        child: Column(
          children: [
            if (widget.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.large),
                child: Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: colorScheme.outline),
                ),
              ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.regular,
                vertical: AppSpacing.medium,
              ),
              decoration: BoxDecoration(
                color: isDark ? colorScheme.surface : Colors.white,
                borderRadius: AppRadius.borderRadiusMedium,
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
                    groupId: widget.group.groupId.toString(),
                    size: 44,
                    avatarLoader: (groupId) async {
                      // 从本地数据库获取群成员头像
                      final members = await GroupMemberRepo().page(
                        limit: 9,
                        where: "${GroupMemberRepo.groupId} = ?",
                        whereArgs: [groupId],
                        orderBy: "${GroupMemberRepo.role} DESC",
                      );
                      return members
                          .map((m) => m.avatar)
                          .where((a) => a.isNotEmpty)
                          .toList();
                    },
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
                        hintText: widget.group.title.isEmpty
                            ? t.main.unnamed
                            : '',
                        hintStyle: TextStyle(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (value) {
                        ref.read(changeInfoProvider.notifier).updateText(value);
                      },
                    ),
                  ),
                  Visibility(
                    visible: state.text.isNotEmpty,
                    child: GestureDetector(
                      onTap: () {
                        _textController.text = '';
                        ref.read(changeInfoProvider.notifier).clearText();
                      },
                      child: Icon(
                        Icons.cancel,
                        color: colorScheme.outline.withValues(alpha: 0.5),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            RoundedElevatedButton(
              text: t.common.buttonAccomplish,
              highlighted: state.valueChanged,
              onPressed: () async {
                // 提前保存 context 引用
                final navigator = Navigator.of(context);
                GroupModel? g = await ref
                    .read(changeInfoProvider.notifier)
                    .saveGroupInfo(widget.group.groupId.toString());
                if (g != null && mounted) {
                  EasyLoading.showSuccess(t.common.tipSuccess);
                  navigator.pop(g);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
