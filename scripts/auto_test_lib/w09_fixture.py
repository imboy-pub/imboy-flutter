"""Owned, private lifecycle for the W09 synthetic slow-PUT fixture."""
from .owned_node_fixture import FixtureFailure, OwnedNodeFixture

TARGET = 'test/unit_test/api/w09_inflight_cancel_chrome_test.dart'
SQLITE_TARGET = 'test/unit_test/service/browser_attachment_materials_chrome_test.dart'
TARGETS = frozenset({TARGET, SQLITE_TARGET})
FIXTURE = 'test/fixtures/w09_cancel/slow-put.cjs'


class W09Fixture(OwnedNodeFixture):
    fixture_path = FIXTURE
    identity_name = 'w09-slow-put-v1'
    exit_reason = 'W09_FIXTURE_EXITED'
