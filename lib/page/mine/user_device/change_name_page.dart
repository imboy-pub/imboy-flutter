import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

/// 修改名称页面
class ChangeNamePage extends ConsumerStatefulWidget {
  final String title;
  final Future<bool> Function(String) callback;

  final String value;
  final String field;

  const ChangeNamePage({
    super.key,
    this.title = "",
    required this.callback,
    this.value = "",
    this.field = "",
  });

  @override
  ConsumerState<ChangeNamePage> createState() => _ChangeNamePageState();
}

class _ChangeNamePageState extends ConsumerState<ChangeNamePage> {
  final FocusNode inputFocusNode = FocusNode();
  final TextEditingController textController = TextEditingController();
  bool valueChanged = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    textController.text = widget.value;
    // 监听输入变化
    textController.addListener(() {
      final changed = textController.text.trim() != widget.value;
      if (changed != valueChanged) {
        setState(() {
          valueChanged = changed;
        });
      }
    });
  }

  @override
  void dispose() {
    inputFocusNode.dispose();
    textController.dispose();
    super.dispose();
  }

  /// 提交新值：防止回调等待期间重复提交，失败时提示错误。
  Future<void> _submit(String value) async {
    if (widget.field != 'input') return;
    final trimmedText = value.trim();
    if (trimmedText.isEmpty) {
      setState(() => valueChanged = false);
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      // 注：成功/失败的提示由 callback 自行通过 AppLoading 处理；这里仅兜底捕获
      // callback 内部未处理的异常，避免页面卡死且无任何反馈。
      final res = await widget.callback(trimmedText);
      if (res && mounted) {
        Navigator.of(context).pop();
      }
    } on Exception {
      if (mounted) AppLoading.showError(t.common.tipFailed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getSurfaceGrouped(
        Theme.of(context).brightness,
      ),
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        titleWidget: Row(
          children: [
            Expanded(child: Text(widget.title, textAlign: TextAlign.center)),
            RoundedElevatedButton(
              text: t.common.buttonAccomplish,
              highlighted: valueChanged,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting
                  ? null
                  : () => _submit(textController.text),
            ),
          ],
        ),
      ),
      body: TextFormField(
        autofocus: true,
        focusNode: inputFocusNode,
        controller: textController,
        keyboardType: TextInputType.text,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.fromLTRB(14, 0, AppSpacing.small, 0),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusTiny,
            borderSide: BorderSide(
              width: 0.2,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusTiny,
            borderSide: BorderSide(
              width: 0.2,
              color: Theme.of(context).colorScheme.surface,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusTiny,
            borderSide: BorderSide(
              width: 1.0,
              color: AppColors.getIosRed(Theme.of(context).brightness),
            ),
          ),
          errorStyle: const TextStyle(),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: AppRadius.borderRadiusTiny,
            borderSide: BorderSide(
              width: 1.0,
              color: AppColors.getIosRed(Theme.of(context).brightness),
            ),
          ),
          border: InputBorder.none,
        ),
        readOnly: _isSubmitting,
        onFieldSubmitted: _submit,
        onSaved: (value) {},
        validator: (value) {
          return null;
        },
      ),
    );
  }
}
