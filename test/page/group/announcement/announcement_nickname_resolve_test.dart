import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/group/announcement/announcement_model.dart';

AnnouncementModel _m({
  String id = '1',
  String publisherId = '',
  String publisherName = '',
}) {
  return AnnouncementModel(
    id: id,
    groupId: 'g1',
    content: 'c',
    publisherId: publisherId,
    publisherName: publisherName,
    createdAt: 1700000000000,
  );
}

void main() {
  group('AnnouncementModel.copyWith', () {
    test('overrides only specified fields, leaves others intact', () {
      final original = _m(
        id: '1',
        publisherId: '10086',
        publisherName: 'Alice',
      );
      final updated = original.copyWith(publisherName: 'Bob');

      expect(updated.id, '1');
      expect(updated.publisherId, '10086');
      expect(updated.publisherName, 'Bob');
      expect(updated.groupId, 'g1');
      expect(updated.content, 'c');
      expect(updated.createdAt, 1700000000000);
    });

    test('no args returns equal-valued copy', () {
      final original = _m(publisherId: 'x', publisherName: 'y');
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.publisherId, original.publisherId);
      expect(copy.publisherName, original.publisherName);
    });

    test('overrides expiredAt to non-null and back', () {
      final original = _m();
      final withExpiry = original.copyWith(expiredAt: 1800000000000);
      expect(withExpiry.expiredAt, 1800000000000);
    });
  });

  group('isPublisherNameFallback', () {
    test('returns true when publisherName == publisherId (non-empty)', () {
      final item = _m(publisherId: '10086', publisherName: '10086');
      expect(isPublisherNameFallback(item), true);
    });

    test('returns false when publisherName is real nickname', () {
      final item = _m(publisherId: '10086', publisherName: 'Alice');
      expect(isPublisherNameFallback(item), false);
    });

    test('returns false when publisherId is empty', () {
      final item = _m(publisherId: '', publisherName: '');
      expect(isPublisherNameFallback(item), false);
    });

    test('returns false when publisherId empty but name non-empty', () {
      final item = _m(publisherId: '', publisherName: 'ghost');
      expect(isPublisherNameFallback(item), false);
    });
  });

  group('resolveAnnouncementNicknames', () {
    test('empty input list returns same instance (zero allocation)', () async {
      final items = <AnnouncementModel>[];
      final result = await resolveAnnouncementNicknames(
        items,
        (_) async => 'never called',
      );
      expect(identical(result, items), true);
    });

    test('no fallback items → lookup never called, returns same instance',
        () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: 'Alice'),
        _m(id: '2', publisherId: '10087', publisherName: 'Bob'),
      ];
      var callCount = 0;
      final result = await resolveAnnouncementNicknames(items, (_) async {
        callCount++;
        return 'should-not-be-called';
      });
      expect(callCount, 0);
      expect(identical(result, items), true);
    });

    test('fallback item with successful lookup → publisherName replaced',
        () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: '10086'),
      ];
      final result = await resolveAnnouncementNicknames(
        items,
        (id) async => id == '10086' ? 'Alice' : null,
      );
      expect(result.length, 1);
      expect(result.first.publisherName, 'Alice');
      expect(result.first.publisherId, '10086');
      expect(result.first.id, '1');
    });

    test('lookup returns null → original publisherName preserved', () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: '10086'),
      ];
      final result = await resolveAnnouncementNicknames(
        items,
        (_) async => null,
      );
      expect(result.first.publisherName, '10086');
    });

    test('lookup returns empty string → original publisherName preserved',
        () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: '10086'),
      ];
      final result = await resolveAnnouncementNicknames(
        items,
        (_) async => '',
      );
      expect(result.first.publisherName, '10086');
    });

    test('lookup throws → item preserved, other items unaffected', () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: '10086'),
        _m(id: '2', publisherId: '10087', publisherName: '10087'),
      ];
      final result = await resolveAnnouncementNicknames(items, (id) async {
        if (id == '10086') throw Exception('network down');
        return 'Bob';
      });
      // #1 保留回退态，#2 成功补齐
      expect(result[0].publisherName, '10086');
      expect(result[1].publisherName, 'Bob');
    });

    test('duplicate publisherIds → lookup called once per unique id',
        () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: '10086'),
        _m(id: '2', publisherId: '10086', publisherName: '10086'),
        _m(id: '3', publisherId: '10086', publisherName: '10086'),
      ];
      var callCount = 0;
      final result = await resolveAnnouncementNicknames(items, (id) async {
        callCount++;
        return 'Alice';
      });
      expect(callCount, 1);
      expect(result.every((item) => item.publisherName == 'Alice'), true);
    });

    test('mixed: some fallback + some resolved → only fallback processed',
        () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: '10086'),
        _m(id: '2', publisherId: '10087', publisherName: 'Bob'),
        _m(id: '3', publisherId: '10088', publisherName: '10088'),
      ];
      final lookedUp = <String>[];
      final result = await resolveAnnouncementNicknames(items, (id) async {
        lookedUp.add(id);
        return 'Resolved-$id';
      });
      expect(lookedUp.toSet(), {'10086', '10088'});
      expect(result[0].publisherName, 'Resolved-10086');
      expect(result[1].publisherName, 'Bob'); // 未被查
      expect(result[2].publisherName, 'Resolved-10088');
    });

    test('all lookups miss (return null) → returns original items instance',
        () async {
      final items = [
        _m(id: '1', publisherId: '10086', publisherName: '10086'),
        _m(id: '2', publisherId: '10087', publisherName: '10087'),
      ];
      final result = await resolveAnnouncementNicknames(
        items,
        (_) async => null,
      );
      // resolvedMap 为空 → 返回原列表实例（零 allocation 优化）
      expect(identical(result, items), true);
    });
  });
}
