import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/modules/customer_service/domain/cs_seat_session_machine.dart';
import 'package:imboy/modules/customer_service/domain/cs_session_detail.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';

/// Only a current closed detail supplies evaluation facts. A local close result
/// cannot turn an older active snapshot into a visitor rating fact.
class CsSessionRatingBanner extends StatelessWidget {
  final CsSessionDetail? detail;
  final CsSeatSessionPhase phase;
  const CsSessionRatingBanner({
    super.key,
    required this.detail,
    required this.phase,
  });
  @override
  Widget build(BuildContext context) {
    final t = context.t.customerService;
    final value = detail;
    final closed =
        phase == CsSeatSessionPhase.closed || phase == CsSeatSessionPhase.rated;
    if (!closed) return const SizedBox.shrink();
    final fact = value?.isClosed == true
        ? value!.evaluationState
        : CsEvaluationState.unknown;
    if (fact == CsEvaluationState.rated && value?.ratingAt != null) {
      return _rated(context, value!);
    }
    return ListTile(
      dense: true,
      leading: const Icon(CupertinoIcons.hourglass, color: AppColors.iosGray),
      title: Text(
        fact == CsEvaluationState.unrated
            ? t.waitingRatingTitle
            : t.ratingUnknownTitle,
        style: context.textStyle(FontSizeType.footnote),
      ),
    );
  }

  Widget _rated(BuildContext context, CsSessionDetail value) {
    final t = context.t.customerService;
    return ListTile(
      dense: true,
      leading: const Icon(CupertinoIcons.star_fill, color: AppColors.iosOrange),
      title: Text(
        t.ratingScoreLabel(score: value.rating),
        style: context.textStyle(FontSizeType.footnote),
      ),
      subtitle: Text(
        '${t.ratedTitle}\n${t.ratingTimeLabel(time: _utc(value.ratingAt!))}',
        style: context.textStyle(
          FontSizeType.caption2,
          color: AppColors.iosGray,
        ),
      ),
    );
  }
}

String _utc(DateTime at) {
  final utc = at.toUtc();
  String two(int n) => '$n'.padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${two(utc.month)}-${two(utc.day)} ${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)} UTC';
}
