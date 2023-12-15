import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:niku/namespace.dart' as n;

import 'package:imboy/config/const.dart';

/// A data type holding user feedback consisting of a feedback type, free from
/// feedback text, and a sentiment rating.
class IMBoyFeedback {
  IMBoyFeedback({
    this.feedbackType,
    this.feedbackText = '',
    this.rating,
  });

  FeedbackType? feedbackType;
  String feedbackText;
  FeedbackRating? rating;

  @override
  String toString() {
    return {
      if (rating != null) 'rating': rating.toString(),
      'feedback_type': feedbackType.toString(),
      'feedback_text': feedbackText,
    }.toString();
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      if (rating != null) 'rating': rating.toString(),
      'feedback_type': feedbackType.toString(),
      'feedback_text': feedbackText,
    };
  }
}

/// What type of feedback the user wants to provide.
enum FeedbackType {
  bugReport,
  featureRequest,
}

/// A user-provided sentiment rating.
enum FeedbackRating {
  bad,
  neutral,
  good,
}

/// A form that prompts the user for the type of feedback they want to give,
/// free form text feedback, and a sentiment rating.
/// The submit button is disabled until the user provides the feedback type. All
/// other fields are optional.
class IMBoyFeedbackForm extends StatefulWidget {
  const IMBoyFeedbackForm({
    super.key,
    required this.onSubmit,
    required this.scrollController,
  });

  final OnSubmit onSubmit;
  final ScrollController? scrollController;

  @override
  State<IMBoyFeedbackForm> createState() => _IMBoyFeedbackFormState();
}

class _IMBoyFeedbackFormState extends State<IMBoyFeedbackForm> {
  final IMBoyFeedback _feedback = IMBoyFeedback();
  final FocusNode focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: n.Column([
        Expanded(
          child: n.Stack(
            [
              if (widget.scrollController != null)
                const FeedbackSheetDragHandle(),
              ListView(
                controller: widget.scrollController,
                // Pad the top by 20 to match the corner radius if drag enabled.
                padding: EdgeInsets.fromLTRB(
                  16,
                  widget.scrollController != null ? 20 : 16,
                  16,
                  0,
                ),
                children: [
                  Text('请留下您宝贵的意见和建议'.tr),
                  n.Row([
                    n.Padding(
                      right: 8,
                      child: const Text(
                        '*',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    Flexible(
                      child: DropdownButton<FeedbackType>(
                        value: _feedback.feedbackType,
                        items: FeedbackType.values
                            .map(
                              (type) => DropdownMenuItem<FeedbackType>(
                                value: type,
                                child: Text(type
                                    .toString()
                                    .split('.')
                                    .last
                                    .replaceAll('_', ' ')
                                    .tr),
                              ),
                            )
                            .toList(),
                        onChanged: (feedbackType) => setState(
                            () => _feedback.feedbackType = feedbackType),
                      ),
                    ),
                  ], mainAxisAlignment: MainAxisAlignment.start),
                  const SizedBox(height: 16),
                  n.Row([
                    n.Padding(
                      right: 8,
                      child: const Text(
                        '*',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                    // Text('What is your feedback?'),
                    Text('你的反馈是什么?'.tr),
                  ]),
                  TextField(
                    cursorColor: Colors.black54,
                    decoration: const InputDecoration(
                      labelText: "",
                      labelStyle: TextStyle(
                        fontSize: 14,
                        color: AppColors.MainTextColor,
                      ),
                      contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                      fillColor: Color.fromARGB(255, 247, 247, 247),
                      filled: true,
                      enabledBorder: OutlineInputBorder(
                        /*边角*/
                        borderRadius: BorderRadius.all(
                          Radius.circular(5), //边角为5
                        ),
                        borderSide: BorderSide(
                          color: Colors.white, //边线颜色为白色
                          width: 1, //边线宽度为2
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white, //边框颜色为白色
                          width: 1, //宽度为5
                        ),
                        borderRadius: BorderRadius.all(
                          Radius.circular(5), //边角为30
                        ),
                      ),
                    ),
                    // focusNode: _inputFocusNode,
                    maxLength: 400,
                    maxLines: 16,
                    minLines: 4,
                    // 长按是否展示【剪切/复制/粘贴菜单LengthLimitingTextInputFormatter】
                    enableInteractiveSelection: true,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    focusNode: focusNode,
                    onChanged: (newFeedback) =>
                        _feedback.feedbackText = newFeedback,
                  ),
                  const SizedBox(height: 16),
                  // const Text('How does this make you feel?'),
                  Text('这让你感觉如何?'.tr),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: FeedbackRating.values.map(_ratingToIcon).toList(),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton(
          // disable this button until the user has specified a feedback type
          onPressed: _feedback.feedbackType != null
              ? () {
                  widget.onSubmit(
                    _feedback.feedbackText,
                    extras: _feedback.toMap(),
                  );
                }
              : null,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryElement,
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            //取消圆角边框
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
          ),
          child: Text('button_submit'.tr),
        ),
        const SizedBox(height: 4),
      ]),
      onTap: () {
        focusNode.unfocus();
      },
    );
  }

  Widget _ratingToIcon(FeedbackRating rating) {
    final bool isSelected = _feedback.rating == rating;
    late IconData icon;
    switch (rating) {
      case FeedbackRating.bad:
        icon = Icons.mood_bad; // 情绪不满的
        break;
      case FeedbackRating.neutral:
        icon = Icons.sentiment_neutral; // 情绪中立的
        break;
      case FeedbackRating.good:
        icon = Icons.mood; // 满意的
        break;
    }
    return IconButton(
      color: isSelected ? AppColors.secondaryElementText : Colors.grey,
      onPressed: () => setState(() => _feedback.rating = rating),
      icon: Icon(icon),
      iconSize: 36,
    );
  }
}
