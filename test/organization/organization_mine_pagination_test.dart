import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:imboy/modules/organization/domain/organization_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/organization_entry_provider.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/config/const.dart';

class _PagedApi extends OrganizationApi {
  final pages = <int>[];
  bool failSecond = false;
  Future<void> Function(int)? onPage;
  @override
  Future<OrganizationPage<Organization>> mine({
    int page = 1,
    int size = 10,
  }) async {
    pages.add(page);
    await onPage?.call(page);
    if (page == 2 && failSecond) {
      throw OrganizationApiException(503, 'synthetic page failure');
    }
    return OrganizationPage(
      list: page == 1
          ? List.generate(
              10,
              (i) => Organization(id: '${i + 1}', name: 'Synthetic ${i + 1}'),
            )
          : const [
              Organization(id: '10', name: 'Updated ten'),
              Organization(id: '11', name: 'Synthetic eleven'),
            ],
      page: page,
      size: 10,
      total: 11,
      totalPage: 2,
    );
  }
}

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });
  test(
    'enterprise entry includes later pages and deduplicates overlapping ids',
    () async {
      final api = _PagedApi();
      final container = ProviderContainer(
        overrides: [organizationApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      await container.read(organizationEntryProvider.notifier).fetch();
      final state = container.read(organizationEntryProvider);
      expect(api.pages, [1, 2]);
      expect(state.orgs, hasLength(11));
      expect(state.orgs.last.id, '11');
      expect(state.orgs.singleWhere((o) => o.id == '10').name, 'Updated ten');
      expect(state.error, isNull);
    },
  );
  test(
    'account change discards the batch before requesting another page',
    () async {
      final api = _PagedApi()
        ..onPage = (page) async {
          if (page == 1) {
            await StorageService.to.setString(
              Keys.currentUid,
              'synthetic-new-account',
            );
          }
        };
      await expectLater(api.allMine(), throwsStateError);
      expect(api.pages, [1]);
    },
  );
  test(
    'later page failure is a retryable error, not a partial enterprise list',
    () async {
      final api = _PagedApi()..failSecond = true;
      final container = ProviderContainer(
        overrides: [organizationApiProvider.overrideWithValue(api)],
      );
      addTearDown(container.dispose);
      await container.read(organizationEntryProvider.notifier).fetch();
      expect(container.read(organizationEntryProvider).orgs, isEmpty);
      expect(container.read(organizationEntryProvider).loaded, isFalse);
      expect(container.read(organizationEntryProvider).error, contains('503'));
      api.failSecond = false;
      await container.read(organizationEntryProvider.notifier).fetch();
      expect(container.read(organizationEntryProvider).orgs, hasLength(11));
      expect(container.read(organizationEntryProvider).error, isNull);
    },
  );
}
