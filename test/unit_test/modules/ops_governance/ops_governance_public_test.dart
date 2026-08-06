import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/ops_governance/public.dart';
import 'package:imboy/store/model/feedback_model.dart';

void main() {
  test(
    'ops_governance public entry exposes current route and service shells',
    () {
      expect(AppVersionApi.new, isA<Function>());
      expect(FeedbackApi.new, isA<Function>());
      expect(NotificationService.new, isA<Function>());
      expect(FeedbackPage.new, isA<Function>());
      expect(UpgradePage.new, isA<Function>());

      final model = FeedbackModel(
        feedbackId: 1,
        appVsn: '0.0.1',
        type: 'bug_report',
        rating: '5.0',
        body: 'demo',
        attach: const <String>[],
        replyCount: 0,
        status: 1,
        createdAt: 0,
        updatedAt: 0,
      );
      expect(FeedbackDetailPage(model: model), isA<FeedbackDetailPage>());
    },
  );
}
