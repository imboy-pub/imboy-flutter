import unittest
from unittest.mock import Mock
import tempfile
import json
from pathlib import Path
from mc22_owned_coordinator import Coordinator, validate_context


class CoordinatorTest(unittest.TestCase):
    def make(self, mode):
        c = Coordinator({'negative_mode': mode, 'group_id': '9007199254740993',
                         'api_port': 12345, 'package': 'pub.imboy.app.gzcustomer'}, 'physical', Mock())
        c.adb, c.request = Mock(return_value=''), Mock()
        return c

    def phase(self, mode, stage, sequence):
        return dict(mode=mode, stage=stage, sequence=sequence, deadline_remaining_ms=1000,
                    before_id=f'mc22-{mode}-before', after_id=f'mc22-{mode}-after', offline_id=f'mc22-{mode}-offline')

    def test_live_os_intents_and_barriers(self):
        c = self.make('live')
        for i, stage in enumerate(['joined', 'warm', 'before_received', 'chat_denied', 'cache_denied', 'verified']):
            self.assertEqual(c.step(self.phase('live', stage, i)), stage == 'verified')
        views = [call for call in c.adb.call_args_list if call.args[:3] == ('shell', 'am', 'start')]
        self.assertEqual(len(views), 2)
        self.assertEqual(views[0], views[1])
        self.assertIn('imboy://imboy.pub/chat/9007199254740993?type=C2G', views[0].args)
        self.assertEqual([call.args[0] for call in c.request.call_args_list],
                         ['emit_before', 'revoke', 'emit_after', 'finish'])

    def test_reconnect_preserves_control_channel(self):
        c = self.make('reconnect')
        for i, stage in enumerate(['joined', 'warm', 'before_received', 'disconnected',
                                   'offline_queued', 'reconnected', 'queued_denied']):
            c.step(self.phase('reconnect', stage, i))
        self.assertFalse(c.dropped)
        self.assertEqual([call.args[0] for call in c.request.call_args_list],
                         ['emit_before', 'link_drop', 'prepare_before_offline', 'revoke',
                          'prepare_offline', 'link_restore', 'finish'])
        c.adb.assert_any_call('reverse', '--remove', 'tcp:12345')
        c.adb.assert_any_call('reverse', 'tcp:12345', 'tcp:12345')

    def test_duplicate_and_wrong_identity(self):
        c = self.make('live')
        phase = self.phase('live', 'joined', 1)
        c.step(phase)
        c.step(phase)
        self.assertEqual(c.adb.call_count, 1)
        for bad in [dict(phase, mode='reconnect'), dict(phase, sequence=0),
                    dict(phase, deadline_remaining_ms=0), dict(phase, before_id='foreign')]:
            with self.assertRaises(ValueError):
                c.step(bad)

    def test_error_restores_only_owned_reverse(self):
        c = self.make('reconnect')
        c.preflight = Mock()
        def fail(_):
            c.reverse(False)
            raise ValueError('fixture failed')
        c.step = fail
        with self.assertRaisesRegex(ValueError, 'fixture failed'):
            c.run()
        self.assertEqual([call.args for call in c.adb.call_args_list],
                         [('reverse', '--remove', 'tcp:12345'),
                          ('reverse', 'tcp:12345', 'tcp:12345')])
        self.assertFalse(c.dropped)

    def test_private_context_and_separate_control_port(self):
        context = dict(negative_mode='live', package='pub.imboy.app.gzcustomer',
                       api_port=12345, bootstrap_port=12346, group_id='123',
                       phase_path='/mc-owned/android/phase', control_path='/mc-owned/android/control',
                       phase_key='a'*64, control_key='b'*64)
        with tempfile.TemporaryDirectory() as td:
            p = Path(td) / 'context.json'
            p.write_text(json.dumps(context))
            p.chmod(0o600)
            self.assertEqual(validate_context(p), context)
            p.chmod(0o644)
            with self.assertRaises(ValueError): validate_context(p)
            p.chmod(0o600)
            alias = Path(td) / 'alias'
            alias.symlink_to(p)
            with self.assertRaises(ValueError): validate_context(alias)
            p.write_text(json.dumps(dict(context, bootstrap_port=12345)))
            with self.assertRaises(ValueError): validate_context(p)


if __name__ == '__main__':
    unittest.main()
