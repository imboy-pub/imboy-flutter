import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/button.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

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
              text: t.buttonAccomplish,
              highlighted: valueChanged,
              onPressed: () async {
                if (widget.field == "input") {
                  String trimmedText = textController.text.trim();
                  if (trimmedText == '') {
                    setState(() {
                      valueChanged = false;
                    });
                  } else {
                    bool res = await widget.callback(trimmedText);
                    if (res && mounted) {
                      Navigator.of(context).pop();
                    }
                  }
                }
              },
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
          contentPadding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
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
        readOnly: false,
        onFieldSubmitted: (val) async {
          if (val == '') {
            setState(() {
              valueChanged = false;
            });
          } else {
            bool res = await widget.callback(val);
            if (res && mounted) {
              Navigator.of(context).pop();
            }
          }
        },
        onSaved: (value) {},
        validator: (value) {
          return null;
        },
      ),
    );
  }
}
