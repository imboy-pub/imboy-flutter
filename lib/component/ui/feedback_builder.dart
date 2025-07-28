import 'package:feedback/feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:get/get.dart';

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

  String get ratingDesc {
    if (double.parse(rating) == 5.0) {
      return 'great'.tr;
    } else if (double.parse(rating) >= 4.0) {
      return 'good'.tr;
    } else if (double.parse(rating) >= 3.0) {
      return 'not_bad'.tr;
    } else if (double.parse(rating) >= 2.0) {
      return 'need_continue_work_hard'.tr;
    } else {
      return 'too_bad'.tr;
    }
  }
}

enum FeedbackType { bugReport, featureRequest }

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
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (widget.scrollController != null)
                  const FeedbackSheetDragHandle(),
                ListView(
                  controller: widget.scrollController,
                  padding: EdgeInsets.fromLTRB(
                    16,
                    widget.scrollController != null ? 20 : 16,
                    16,
                    0,
                  ),
                  children: [
                    Text('leave_your_suggestions'.tr),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
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
                                    child: Text(
                                      type
                                          .toString()
                                          .split('.')
                                          .last
                                          .replaceAll('_', ' ')
                                          .tr,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (feedbackType) => setState(
                              () => _feedback.feedbackType = feedbackType,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: const Text(
                            '*',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        Text('what_your_feedback'.tr),
                      ],
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color.fromARGB(255, 247, 247, 247),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          borderSide: BorderSide(color: Colors.white, width: 1),
                        ),
                        contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                      ),
                      maxLines: 16,
                      minLines: 6,
                      focusNode: descFocusNode,
                      onChanged: (newFeedback) =>
                          _feedback.feedbackText = newFeedback,
                    ),
                    const SizedBox(height: 16),
                    Text('your_contact_information'.tr),
                    TextField(
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Color.fromARGB(255, 247, 247, 247),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                          borderSide: BorderSide(color: Colors.white, width: 1),
                        ),
                        contentPadding: EdgeInsets.fromLTRB(10, 10, 10, 10),
                      ),
                      focusNode: contactFocusNode,
                      onChanged: (val) => _feedback.contactDetail = val,
                    ),
                    const SizedBox(height: 16),
                    Text('your_feel'.tr),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('rating'.tr),
                          Text(': ${_feedback.rating}    '),
                          Text(_feedback.ratingDesc),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RatingBar.builder(
                          initialRating: 3,
                          minRating: 1,
                          itemCount: 5,
                          itemPadding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                          ),
                          itemBuilder: (context, _) =>
                              const Icon(Icons.star, color: Colors.amber),
                          onRatingUpdate: (rating) {
                            setState(
                              () => _feedback.rating = rating.toString(),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _feedback.feedbackType != null
                ? () {
                    widget.onSubmit(
                      _feedback.feedbackText,
                      extras: _feedback.toMap(),
                    );
                  }
                : null,
            child: Text('button_submit'.tr),
          ),
          const SizedBox(height: 4),
        ],
      ),
      onTap: () {
        descFocusNode.unfocus();
        contactFocusNode.unfocus();
      },
    );
  }
}
