"""Real Node lifecycle and shared browser-fixture compatibility regressions."""
import hashlib
import http.client
import json
import os
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'scripts'))
from auto_test_lib.web_control_fixture import FixtureFailure, WebControlFixture


class WebControlFixtureTest(unittest.TestCase):
    def start_fixture(self, env=None):
        fixture = WebControlFixture(ROOT, dict(os.environ) if env is None else env).start()
        self.addCleanup(fixture.stop)
        return fixture

    def request(self, fixture, method, path, body=None, headers=None):
        origin = urlparse(fixture.origin)
        conn = http.client.HTTPConnection(origin.hostname, origin.port, timeout=3)
        try:
            conn.request(method, path, body=body, headers=headers or {})
            response = conn.getresponse()
            return response.status, dict(response.getheaders()), response.read()
        finally:
            conn.close()

    def stats(self, fixture, case):
        status, _, body = self.request(fixture, 'GET', '/stats?case=' + case)
        self.assertEqual(status, 200)
        return json.loads(body)

    def test_identity_handshake_port_override_and_cleanup(self):
        env = dict(os.environ, IMBOY_CONTROL_FETCH_PORT='invalid')
        fixture = self.start_fixture(env)
        self.assertEqual(env['IMBOY_CONTROL_FETCH_PORT'], 'invalid')
        self.assertIsNone(fixture.observer(None))
        status, _, body = self.request(fixture, 'GET', '/identity?nonce=' + fixture.nonce)
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), {'fixture': 'web-control-fetch-v1', 'nonce': fixture.nonce})
        for query in ('', '?nonce=wrong', '?nonce=' + fixture.nonce + '&nonce=' + fixture.nonce):
            with self.subTest(query=query):
                self.assertEqual(self.request(fixture, 'GET', '/identity' + query)[0], 403)
        self.assertTrue(fixture.stop())
        self.assertEqual(fixture.observer(None), 'WEB_CONTROL_FIXTURE_EXITED')
        self.assertTrue(fixture.stop())

    def test_new_attempt_has_empty_records(self):
        first = self.start_fixture()
        self.assertEqual(self.request(first, 'POST', '/api/v1/probe?case=reused', b'first')[0], 200)
        self.assertEqual(len(self.stats(first, 'reused')), 1)
        self.assertTrue(first.stop())
        second = self.start_fixture()
        self.assertNotEqual(first.nonce, second.nonce)
        self.assertEqual(self.stats(second, 'reused'), [])

    def test_parallel_fixtures_do_not_share_listener_or_records(self):
        first, second = self.start_fixture(), self.start_fixture()
        self.assertNotEqual(first.origin, second.origin)
        self.assertNotEqual(first.nonce, second.nonce)
        self.assertEqual(self.request(first, 'POST', '/api/v1/probe?case=same-id', b'one')[0], 200)
        self.assertEqual(self.stats(second, 'same-id'), [])
        self.assertEqual(self.request(second, 'POST', '/api/v1/probe?case=same-id', b'two')[0], 200)
        self.assertEqual(self.stats(first, 'same-id')[0]['sha256'], hashlib.sha256(b'one').hexdigest())
        self.assertEqual(self.stats(second, 'same-id')[0]['sha256'], hashlib.sha256(b'two').hexdigest())
        self.assertEqual(self.request(second, 'GET', '/identity?nonce=' + first.nonce)[0], 403)

    def test_failed_handshake_reaps_actual_node_child(self):
        fixture = WebControlFixture(ROOT, dict(os.environ))
        self.addCleanup(fixture.stop)
        with patch('http.client.HTTPConnection.request', side_effect=OSError('private details')):
            with self.assertRaises(FixtureFailure) as error:
                fixture.start()
        self.assertNotIn('private details', str(error.exception))
        self.assertIsNotNone(fixture.process.poll())
        self.assertTrue(fixture.process.stdout.closed)

    def test_browser_resources_and_preflight_still_work_without_nonce(self):
        fixture = self.start_fixture()
        headers = {'Origin': 'http://localhost:12345'}
        status, response_headers, body = self.request(
            fixture, 'GET', '/resource/data?case=browser-resource', headers=headers)
        self.assertEqual((status, body), (200, bytes([0, 127, 255])))
        self.assertEqual(response_headers['Access-Control-Allow-Origin'], headers['Origin'])
        self.assertEqual(len(self.stats(fixture, 'browser-resource')), 1)
        self.assertEqual(self.request(fixture, 'OPTIONS', '/api/v1/probe?case=preflight', headers=headers)[0], 204)
        self.assertEqual(self.stats(fixture, 'preflight'), [])


if __name__ == '__main__':
    unittest.main()
