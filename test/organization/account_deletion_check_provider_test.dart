import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/account_deletion_check_provider.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';

class _Api extends OrganizationApi {
  final requests = <Completer<DeletionPreflightReport>>[];
  @override
  Future<DeletionPreflightReport> deletionPreflight() {
    final request = Completer<DeletionPreflightReport>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  test(
    'same UID reauthentication clears report and fences old errors',
    () async {
      final api = _Api();
      late void Function() auth;
      var transitioning = false;
      final container = ProviderContainer(
        overrides: [
          organizationApiProvider.overrideWithValue(api),
          accountCheckIdentityProvider.overrideWithValue('123'),
          accountCheckTransitionProvider.overrideWithValue(() => transitioning),
          accountCheckAuthSubscribeProvider.overrideWithValue((changed) {
            auth = changed;
            return () {};
          }),
        ],
      );
      addTearDown(container.dispose);
      container.listen(accountDeletionCheckProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);
      expect(api.requests, hasLength(1));
      transitioning = true;
      auth();
      await Future<void>.delayed(Duration.zero);
      expect(api.requests, hasLength(1));
      api.requests[0].completeError(StateError('old account response'));
      await Future<void>.delayed(Duration.zero);
      expect(container.read(accountDeletionCheckProvider).isLoading, isTrue);
      transitioning = false;
      auth();
      await Future<void>.delayed(Duration.zero);
      expect(api.requests, hasLength(2));
      api.requests[1].complete(
        const DeletionPreflightReport(subjectUserId: '123'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(accountDeletionCheckProvider).value?.subjectUserId,
        '123',
      );
      auth();
      expect(container.read(accountDeletionCheckProvider).value, isNull);
    },
  );

  test('wrong server subject is rejected', () async {
    final api = _Api();
    final container = ProviderContainer(
      overrides: [
        organizationApiProvider.overrideWithValue(api),
        accountCheckIdentityProvider.overrideWithValue('123'),
        accountCheckTransitionProvider.overrideWithValue(() => false),
        accountCheckAuthSubscribeProvider.overrideWithValue((_) => () {}),
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountDeletionCheckProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    api.requests.single.complete(
      const DeletionPreflightReport(subjectUserId: '456'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(accountDeletionCheckProvider).hasError, isTrue);
    expect(container.read(accountDeletionCheckProvider).value, isNull);
  });

  test('late success cannot overwrite refreshed same UID report', () async {
    final api = _Api();
    late void Function() auth;
    final container = ProviderContainer(
      overrides: [
        organizationApiProvider.overrideWithValue(api),
        accountCheckIdentityProvider.overrideWithValue('123'),
        accountCheckTransitionProvider.overrideWithValue(() => false),
        accountCheckAuthSubscribeProvider.overrideWithValue((changed) {
          auth = changed;
          return () {};
        }),
      ],
    );
    addTearDown(container.dispose);
    container.listen(accountDeletionCheckProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    auth();
    await Future<void>.delayed(Duration.zero);
    api.requests[1].complete(
      const DeletionPreflightReport(subjectUserId: '123', observedAt: 'new'),
    );
    await Future<void>.delayed(Duration.zero);
    api.requests[0].complete(
      const DeletionPreflightReport(subjectUserId: '123', observedAt: 'old'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(accountDeletionCheckProvider).value?.observedAt,
      'new',
    );
  });

  test('cleanup resources are typed bounded IDs without content', () {
    final report = DeletionPreflightReport.fromJson({
      'subject_user_id': 123,
      'facts': [
        {
          'domain': 'talk_record',
          'resources': List.generate(21, (i) => {'record_id': '${i + 1}'}),
        },
      ],
    });
    expect(report.cleanupResources, hasLength(20));
    expect(report.cleanupResources.first.recordId, '1');
    expect(report.cleanupResourcesTruncated, isTrue);
  });
}
