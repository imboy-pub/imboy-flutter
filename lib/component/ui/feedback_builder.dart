import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:niku/namespace.dart' as n;

/// A data type holding user feedback consisting of a feedback type, free from
/// feedback text, and a sentiment rating.
class IMBoyFeedback {
  IMBoyFeedback({
    this.feedbackType,
    this.feedbackText = '',
    this.rating = '3.0',
    this.contactDetail = '',
  });

  FeedbackType? feedbackType;
  String feedbackText;
  String rating;
  String contactDetail;

  @override
  String toString() {
    return {
      'rating': rating,
      'feedback_type': feedbackType.toString(),
      'feedback_text': feedbackText,
      'contact_detail': contactDetail,
    }.toString();
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'rating': rating,
      'feedback_type': feedbackType.toString(),
      'feedback_text': feedbackText,
      'contact_detail': contactDetail,
    };
  }

  // 评级描述
  get ratingDesc {
    if (double.parse(rating) == 5.0) {
      return 'great'.tr;
    } else if (double.parse(rating) >= 4.0) {
      return 'good'.tr;
    } else if (double.parse(rating) >= 3.0) {
      return 'not_bad'.tr; // 还不错
    } else if (double.parse(rating) >= 2.0) {
      return 'need_continue_work_hard'.tr; // '需要继续加油';
    } else {
      return 'too_bad'.tr;
    }
  }
}

/// What type of feedback the user wants to provide.
enum FeedbackType {
  bugReport,
  featureRequest,
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
  final FocusNode descFocusNode = FocusNode();
  final FocusNode contactFocusNode = FocusNode();

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
                  // 请留下您宝贵的意见和建议
                  Text('leave_your_suggestions'.tr),
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
                    // 你的反馈是什么?
                    Text('what_your_feedback'.tr),
                  ]),
                  TextField(
                    cursorColor: Colors.black54,
                    decoration: const InputDecoration(
                      labelText: "",
                      labelStyle: TextStyle(
                        fontSize: 14,
                        // color: AppColors.MainTextColor,
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
                    maxLength: 400,
                    maxLines: 16,
                    minLines: 6,
                    // 长按是否展示【剪切/复制/粘贴菜单LengthLimitingTextInputFormatter】
                    enableInteractiveSelection: true,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    focusNode: descFocusNode,
                    onChanged: (newFeedback) =>
                        _feedback.feedbackText = newFeedback,
                  ),
                  const SizedBox(height: 16),
                  // 你的联系方式
                  Text('your_contact_information'.tr),
                  TextField(
                    cursorColor: Colors.black54,
                    decoration: const InputDecoration(
                      labelText: "",
                      labelStyle: TextStyle(
                        fontSize: 14,
                        // color: AppColors.MainTextColor,
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
                    // 长按是否展示【剪切/复制/粘贴菜单LengthLimitingTextInputFormatter】
                    enableInteractiveSelection: true,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    focusNode: contactFocusNode,
                    onChanged: (val) => _feedback.contactDetail = val,
                  ),
                  const SizedBox(height: 16),
                  // const Text('How does this make you feel?'),
                  // 这让你感觉如何
                  Text('your_feel'.tr),
                  n.Padding(
                    top: 12,
                    bottom: 12,
                    child: n.Row([
                      // 评级
                      Text('rating'.tr),
                      Text(': ${_feedback.rating}    '),
                      Text(_feedback.ratingDesc),
                    ])
                      // 内容居中
                      ..mainAxisAlignment = MainAxisAlignment.center,
                  ),
                  n.Row([
                    RatingBar.builder(
                      initialRating: 3,
                      minRating: 1,
                      direction: Axis.horizontal,
                      allowHalfRating: true,
                      itemCount: 5,
                      itemPadding: const EdgeInsets.symmetric(horizontal: 8.0),
                      itemBuilder: (context, _) => const Icon(
                        Icons.star,
                        color: Colors.amber,
                      ),
                      onRatingUpdate: (rating) {
                        iPrint(rating.toString());
                        setState(() => _feedback.rating = rating.toString());
                      },
                    ),
                  ])
                    // 内容居中
                    ..mainAxisAlignment = MainAxisAlignment.center,
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
            // foregroundColor: AppColors.primaryElement,
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
        descFocusNode.unfocus();
        contactFocusNode.unfocus();
      },
    );
  }
}
