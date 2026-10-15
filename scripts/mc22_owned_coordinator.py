#!/usr/bin/env python3
"""Drive existing MC22 fixture barriers and real Android VIEW intents.

Start beside the owned Flutter negative test. This does not install/uninstall an
app, create a fixture, acquire a device, or prove the Flutter/DB assertions passed.
The caller must already own the context, physical device and adb reverse mapping.
"""
import argparse
import http.client
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import time


def validate_context(path):
    info = path.stat()
    if path.is_symlink() or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise ValueError('context must be owned private file, mode 0600')
    context = json.loads(path.read_text())
    if context['package'] != 'pub.imboy.app.gzcustomer' or context['negative_mode'] not in ('live', 'reconnect'):
        raise ValueError('wrong owned package/mode')
    for key in ('api_port', 'bootstrap_port'):
        if type(context[key]) is not int or not 1024 <= context[key] <= 65535:
            raise ValueError('invalid owned port')
    if context['api_port'] == context['bootstrap_port']:
        raise ValueError('phase control must remain reachable during API disconnect')
    if not re.fullmatch(r'[1-9][0-9]{0,18}', context['group_id']):
        raise ValueError('invalid group id')
    for role in ('phase', 'control'):
        if context[f'{role}_path'] != f'/mc-owned/android/{role}' or not re.fullmatch(r'[0-9A-Fa-f]{64}', context[f'{role}_key']):
            raise ValueError('invalid fixture control endpoint/key')
    return context


class Coordinator:
    def __init__(self, context, device, emit):
        self.context, self.device, self.emit = context, device, emit
        self.handled = set()
        self.sequence = -1
        self.dropped = False

    def adb(self, *args):
        result = subprocess.run(['adb', '-s', self.device, *args], capture_output=True,
                                text=True, timeout=20, check=True)
        if re.search(r'(?im)^\s*(Error|Exception):', result.stdout + result.stderr):
            raise ValueError('adb reported an operation error')
        return result.stdout.strip()

    def preflight(self):
        if not self.device or self.device.startswith('emulator-') or self.adb('get-state') != 'device':
            raise ValueError('explicit connected physical Android required')
        if self.adb('shell', 'getprop', 'ro.kernel.qemu') == '1':
            raise ValueError('emulator forbidden')
        port = self.context['api_port']
        if not any(line.split()[-2:] == [f'tcp:{port}', f'tcp:{port}']
                   for line in self.adb('reverse', '--list').splitlines()):
            raise ValueError('owned API reverse mapping missing')

    def request(self, action=None):
        role = 'control' if action else 'phase'
        connection = http.client.HTTPConnection('127.0.0.1', self.context['bootstrap_port'], timeout=95)
        try:
            headers = {f'x-mc-owned-{role}': self.context[f'{role}_key'], 'Content-Type': 'application/json'}
            body = json.dumps({'action': action}) if action else None
            connection.request('POST' if action else 'GET', self.context[f'{role}_path'], body, headers)
            response = connection.getresponse()
            raw = response.read(65537)
            if response.status != 200 or len(raw) > 65536:
                raise ValueError('fixture rejected phase request')
            decoded = json.loads(raw)
            if decoded.get('code') != 0 or not isinstance(decoded.get('payload'), dict):
                raise ValueError('invalid phase response')
            return decoded['payload']
        finally:
            connection.close()

    def view(self):
        # Same pre-revocation URI is replayed after revocation, via the actual OS.
        uri = f"imboy://imboy.pub/chat/{self.context['group_id']}?type=C2G"
        self.adb('shell', 'am', 'start', '-W', '-a', 'android.intent.action.VIEW',
                 '-d', uri, '-p', self.context['package'])
        self.emit('view_sent')

    def reverse(self, restore):
        port = f"tcp:{self.context['api_port']}"
        self.adb('reverse', *([port, port] if restore else ['--remove', port]))
        self.dropped = not restore
        self.emit('link_restored' if restore else 'link_removed')

    def step(self, phase):
        mode = self.context['negative_mode']
        sequence = phase['sequence']
        if phase['mode'] != mode or type(sequence) is not int or sequence < self.sequence or phase['deadline_remaining_ms'] <= 0:
            raise ValueError('phase identity/sequence/deadline mismatch')
        for key, suffix in [('before_id', 'before'), ('after_id', 'after'), ('offline_id', 'offline')]:
            if phase[key] != f'mc22-{mode}-{suffix}':
                raise ValueError('wrong fixture message identity')
        self.sequence = sequence
        stage = phase['stage']
        if stage == 'verified':
            return True
        if stage in self.handled:
            return False
        if stage in ('joined', 'chat_denied', 'reconnected'):
            self.view()
        elif stage == 'warm':
            self.request('emit_before')
        elif stage == 'before_received':
            if mode == 'live':
                self.request('revoke')
                self.request('emit_after')
            else:
                self.reverse(False)
                self.request('link_drop')
        elif mode == 'reconnect' and stage == 'disconnected':
            self.request('prepare_before_offline')
            self.request('revoke')
            self.request('prepare_offline')
        elif mode == 'reconnect' and stage == 'offline_queued':
            self.reverse(True)
            self.request('link_restore')
        elif stage == ('cache_denied' if mode == 'live' else 'queued_denied'):
            self.request('finish')
        else:
            return False
        self.handled.add(stage)
        self.emit(f'handled:{stage}')
        return False

    def run(self):
        self.preflight()
        deadline = time.monotonic() + 600
        try:
            while time.monotonic() < deadline:
                if self.step(self.request()):
                    self.emit('coordinator_verified')
                    return
                time.sleep(0.25)
            raise TimeoutError('MC22 lease deadline exceeded')
        finally:
            if self.dropped:
                self.reverse(True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--context', type=Path, required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--events', type=Path, required=True)
    args = parser.parse_args()
    def interrupted(_signal, _frame):
        raise SystemExit('coordinator interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    context = validate_context(args.context)
    # Exclusive creation preserves each attempt; never overwrite prior evidence.
    with args.events.open('x') as output:
        def emit(event):
            output.write(json.dumps({'event': event, 'monotonic': time.monotonic()}) + '\n')
            output.flush()
        Coordinator(context, args.device, emit).run()


if __name__ == '__main__':
    main()
