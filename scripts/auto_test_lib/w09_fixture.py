"""Owned, private lifecycle for the W09 synthetic slow-PUT fixture."""
from __future__ import annotations
import http.client
import json
import os
from pathlib import Path
import re
import selectors
import signal
import subprocess
import time
from urllib.parse import urlparse

TARGET = 'test/unit_test/api/w09_inflight_cancel_chrome_test.dart'
SQLITE_TARGET = 'test/unit_test/service/browser_attachment_materials_chrome_test.dart'
TARGETS = frozenset({TARGET, SQLITE_TARGET})
FIXTURE = 'test/fixtures/w09_cancel/slow-put.cjs'


class FixtureFailure(Exception):
    pass


class W09Fixture:
    def __init__(self, root, env):
        self.root, self.env, self.process = Path(root), env, None
        self.origin = self.nonce = None

    def start(self):
        try:
            self.process = subprocess.Popen(['node', str(self.root / FIXTURE)], cwd=self.root,
                env=self.env, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                start_new_session=True)
            with selectors.DefaultSelector() as selector:
                selector.register(self.process.stdout, selectors.EVENT_READ)
                deadline, data = time.monotonic() + 5, b''
                while b'\n' not in data:
                    wait = deadline - time.monotonic()
                    if wait <= 0 or not selector.select(wait):
                        raise FixtureFailure('fixture startup timeout')
                    chunk = os.read(self.process.stdout.fileno(), 4096)
                    if not chunk or len(data) + len(chunk) > 4096:
                        raise FixtureFailure('fixture startup invalid')
                    data += chunk
            payload = json.loads(data.split(b'\n', 1)[0])
            origin, nonce = payload['origin'], payload['nonce']
            uri = urlparse(origin)
            if (uri.scheme != 'http' or uri.hostname != '127.0.0.1' or
                    not uri.port or uri.path or uri.query or uri.fragment or uri.username or
                    not isinstance(nonce, str) or not re.fullmatch('[a-f0-9]{64}', nonce)):
                raise FixtureFailure('fixture identity invalid')
            conn = http.client.HTTPConnection('127.0.0.1', uri.port, timeout=3)
            try:
                conn.request('GET', '/identity?nonce=' + nonce)
                response = conn.getresponse()
                body = response.read(4097)
            finally:
                conn.close()
            if response.status != 200 or len(body) > 4096:
                raise FixtureFailure('fixture handshake rejected')
            identity = json.loads(body)
            if identity != {'fixture': 'w09-slow-put-v1', 'nonce': nonce} or self.process.poll() is not None:
                raise FixtureFailure('fixture handshake invalid')
            self.origin, self.nonce = origin, nonce
            return self
        except BaseException as error:
            if not self.stop():
                raise FixtureFailure('fixture startup cleanup failed') from None
            if isinstance(error, (KeyboardInterrupt, SystemExit)):
                raise
            raise FixtureFailure('fixture startup failed') from None

    def observer(self, _path):
        return 'W09_FIXTURE_EXITED' if self.process.poll() is not None else None

    def stop(self):
        if self.process is None:
            return True
        process = self.process
        if process.poll() is None:
            try:
                os.killpg(process.pid, signal.SIGTERM)
                process.wait(timeout=3)
            except ProcessLookupError:
                pass
            except subprocess.TimeoutExpired:
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait(timeout=3)
                except (ProcessLookupError, subprocess.TimeoutExpired):
                    return False
        if process.stdout:
            process.stdout.close()
        return process.poll() is not None
