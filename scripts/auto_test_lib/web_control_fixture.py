"""Fresh, runner-owned loopback service for the four host Oracle cases."""
from .owned_node_fixture import FixtureFailure, OwnedNodeFixture

TARGET = 'test/service/web_control_fixture_oracle_test.dart'
TARGETS = frozenset({TARGET})
FIXTURE = 'test/fixtures/web_control_fetch_server.cjs'


class WebControlFixture(OwnedNodeFixture):
    fixture_path = FIXTURE
    identity_name = 'web-control-fetch-v1'
    exit_reason = 'WEB_CONTROL_FIXTURE_EXITED'

    def __init__(self, root, env):
        # Ignore caller port pins: each attempt owns a fresh, ephemeral listener.
        super().__init__(root, dict(env, IMBOY_CONTROL_FETCH_PORT='0'))
