import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/main_input.dart';
import 'package:imboy/config/enum.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// 群备注页面
class GroupRemarkPage extends ConsumerStatefulWidget {
  final GroupInfoType? groupInfoType;
  final String text;
  final String? groupId;

  const GroupRemarkPage({
    super.key,
    this.groupInfoType = GroupInfoType.remark,
    this.text = '',
    this.groupId,
  });

  @override
  ConsumerState<GroupRemarkPage> createState() => _GroupRemarkPageState();
}

class _GroupRemarkPageState extends ConsumerState<GroupRemarkPage> {
  final TextEditingController _textController = TextEditingController();

  void handle() {
    if (widget.groupInfoType == GroupInfoType.name) {
      if (!strNoEmpty(_textController.text)) {
        // TODO: 显示提示
        return;
      }
      context.pop(_textController.text);
    } else if (widget.groupInfoType == GroupInfoType.cardName) {
      // 允许为空，为空时显示昵称
      context.pop(_textController.text);
    } else {
      // TODO: 显示"即将推出"提示
    }
  }

  @override
  void initState() {
    super.initState();
    _textController.text = widget.text;
  }

  String get label {
    if (widget.groupInfoType == GroupInfoType.name) {
      return t.changeParam(param: t.groupName);
    } else if (widget.groupInfoType == GroupInfoType.cardName) {
      return t.groupAlias;
    } else {
      return t.remark;
    }
  }

  String get des {
    if (widget.groupInfoType == GroupInfoType.name) {
      return t.changeGroupChatName;
    } else if (widget.groupInfoType == GroupInfoType.cardName) {
      return t.nicknameChangeVisibility;
    } else {
      return t.groupRemarkVisibility;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return MainInputBody(
      child: Scaffold(
        backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF5F5F5),
        appBar: GlassAppBar(
          automaticallyImplyLeading: true,
          rightDMActions: [
            TextButton(
              onPressed: () => handle(),
              child: Text(
                t.buttonSave,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 30),
              Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 15),
                child: Text(
                  des,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest
                      : Colors.white,
                  borderRadius: AppRadius.borderRadiusMedium,
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.2)
                          : Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _textController,
                  style: TextStyle(color: colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: widget.groupInfoType == GroupInfoType.name
                        ? t.groupName
                        : (widget.groupInfoType == GroupInfoType.cardName
                              ? t.groupAlias
                              : t.remark),
                    hintStyle: TextStyle(
                      color: colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Visibility(
                visible: widget.groupInfoType == GroupInfoType.remark,
                child: Row(
                  children: <Widget>[
                    Text(
                      '群聊名称：wechat_flutter 106号群',
                      style: TextStyle(
                        color: colorScheme.outline,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          t.fillIn,
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                      onTap: () {
                        _textController.text = 'wechat_flutter 106号群';
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
