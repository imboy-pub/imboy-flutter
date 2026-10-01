import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/organization/domain/human_directory_models.dart';
import 'package:imboy/modules/organization/infrastructure/organization_api.dart';
import 'package:imboy/modules/organization/presentation/human_directory_controller.dart';

import 'human_directory_controller_test.dart' as fixture;

const _dept = HumanDirectoryDepartment(
  id: '8001',
  name: 'Synthetic department',
);
const _member = HumanDirectoryMember(
  userId: '9001',
  displayName: 'Synthetic member',
);
HumanDirectoryPage<T> _page<T>(List<T> list, {String? cursor}) =>
    HumanDirectoryPage(list: list, cursor: cursor, hasMore: cursor != null);
Future<void> _tick() => Future<void>.delayed(Duration.zero);

Future<HumanDirectoryController> _loaded(fixture.FakeSource src) async {
  src.membersPage = _page([_member], cursor: 'members');
  src.meResult = HumanDirectoryMe(organizationId: fixture.orgA, list: [_dept]);
  final c = HumanDirectoryController(dataSource: src);
  c.configure(accountKey: 'synthetic', organizationId: fixture.orgA);
  src.pendingDepartments.last.complete(_page([_dept], cursor: 'departments'));
  await _tick();
  expect(c.phase, HumanDirectoryPhase.ready);
  return c;
}

void _denied(HumanDirectoryController c) {
  expect(c.phase, HumanDirectoryPhase.error);
  expect(c.pageError, isNotNull);
  expect(c.departments.items, isEmpty);
  expect(c.members.items, isEmpty);
  expect(c.search.items, isEmpty);
  expect(c.myDepartments, isEmpty);
  expect(c.departments.cursor, isNull);
  expect(c.members.cursor, isNull);
  expect(c.refreshing, isFalse);
  expect(c.meLoading, isFalse);
}

void main() {
  for (final endpoint in ['departments', 'members', 'search', 'me']) {
    for (final code in [403, 404]) {
      test('$endpoint $code 清空旧目录、屏蔽迟到结果、允许重试', () async {
        final src = fixture.FakeSource();
        final c = await _loaded(src);
        addTearDown(c.dispose);
        if (endpoint == 'search') {
          c.setQuery('ab');
          src.pendingSearch.last.complete(
            _page([
              const HumanDirectorySearchItem(type: 'member', member: _member),
            ]),
          );
          await _tick();
        }
        final error = OrganizationApiException(code, 'synthetic denied');
        if (endpoint == 'members') src.membersError = error;
        if (endpoint == 'me') src.meError = error;
        final refresh = c.refresh();
        if (endpoint == 'departments') {
          src.pendingDepartments.last.completeError(error);
        }
        if (endpoint == 'search') src.pendingSearch.last.completeError(error);
        await _tick();
        _denied(c);
        if (endpoint != 'search' && !src.pendingDepartments.last.isCompleted) {
          src.pendingDepartments.last.complete(_page([_dept]));
        }
        await refresh;
        _denied(c);
        src.membersError = null;
        src.meError = null;
        final retry = c.refresh();
        if (endpoint == 'search') {
          src.pendingSearch.last.complete(
            _page([
              const HumanDirectorySearchItem(type: 'member', member: _member),
            ]),
          );
        } else {
          src.pendingDepartments.last.complete(_page([_dept]));
        }
        await retry;
        expect(c.phase, HumanDirectoryPhase.ready);
      });
    }
  }
  test('旧企业迟到的403不能清空新企业目录', () async {
    final src = fixture.FakeSource();
    final c = await _loaded(src);
    addTearDown(c.dispose);
    final old = c.refresh();
    final pending = src.pendingDepartments.last;
    c.configure(accountKey: 'synthetic', organizationId: fixture.orgB);
    src.pendingDepartments.last.complete(_page([_dept]));
    await _tick();
    pending.completeError(const OrganizationApiException(403, 'old denied'));
    await old;
    expect(c.identity!.organizationId, fixture.orgB);
    expect(c.phase, HumanDirectoryPhase.ready);
    expect(c.departments.items, hasLength(1));
  });
  test('成员追加同页重复ID只保留一次', () async {
    final src = fixture.FakeSource();
    final c = await _loaded(src);
    addTearDown(c.dispose);
    const next = HumanDirectoryMember(
      userId: '9002',
      displayName: 'Synthetic next',
    );
    src.membersPage = _page([_member, next, next]);
    await c.loadMoreMembers();
    expect(c.members.items.map((m) => m.userId), ['9001', '9002']);
  });
}
