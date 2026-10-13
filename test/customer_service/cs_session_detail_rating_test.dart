import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/infrastructure/cs_api.dart';

void main() {
  CsSessionDetail parse(Map<String, Object?> facts) =>
      CsSessionDetail.fromJson({
        'id': '4',
        'organization_id': '1',
        'conversation_id': '3',
        'status': 'closed',
        'version': 2,
        ...facts,
      });
  test('only explicit pair of null facts means unrated', () {
    expect(
      parse({'rating': null, 'rating_at': null}).evaluationState,
      CsEvaluationState.unrated,
    );
    for (final facts in <Map<String, Object?>>[
      {},
      {'rating': null},
      {'rating_at': null},
    ]) {
      expect(parse(facts).evaluationState, CsEvaluationState.unknown);
    }
  });
  test('real score and epoch seconds produce UTC rating facts', () {
    for (var score = 1; score <= 5; score++) {
      final detail = parse({'rating': score, 'rating_at': 1700000000});
      expect(detail.evaluationState, CsEvaluationState.rated);
      expect(detail.rating, score);
      expect(detail.hasRating, isTrue);
      expect(detail.ratingAt, DateTime.utc(2023, 11, 14, 22, 13, 20));
    }
  });
  test(
    'malformed or incomplete server facts stay unknown without fabricated time',
    () {
      for (final facts in <Map<String, Object?>>[
        {'rating': 0, 'rating_at': 1700000000},
        {'rating': 6, 'rating_at': 1700000000},
        {'rating': true, 'rating_at': 1700000000},
        {'rating': 4.5, 'rating_at': 1700000000},
        {'rating': '4', 'rating_at': 1700000000},
        {'rating': 4, 'rating_at': null},
        {'rating': 4, 'rating_at': 0},
        {'rating': 4, 'rating_at': -1},
        {'rating': 4, 'rating_at': true},
        {'rating': 4, 'rating_at': 1.5},
        {'rating': 4, 'rating_at': 8640000000001},
        {'rating': 4},
      ]) {
        final detail = parse(facts);
        expect(detail.evaluationState, CsEvaluationState.unknown);
        expect(detail.ratingAt, isNull);
      }
    },
  );
  test(
    'legacy constructor remains compatible without inventing server truth',
    () {
      const detail = CsSessionDetail(
        sessionId: '4',
        rating: 4,
        status: 'closed',
      );
      expect(detail.rating, 4);
      expect(detail.hasRating, isTrue);
      expect(detail.isClosed, isTrue);
      expect(detail.evaluationState, CsEvaluationState.unknown);
      expect(detail.ratingAt, isNull);
    },
  );
}
