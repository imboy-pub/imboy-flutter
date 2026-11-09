#!/usr/bin/env python3
"""DCO regressions using real temporary Git commits and an offline GitHub API.

The gh fixture runs the production --jq filter against controlled JSON. It
does not claim that GitHub has verified the synthetic fixture commits.
"""
import copy
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CHECKER = ROOT / 'scripts/check_pr_dco.sh'
BOT_NAME = 'dependabot[bot]'
BOT_EMAIL = '49699333+dependabot[bot]@users.noreply.github.com'
BOT_SIGNOFF = 'Signed-off-by: dependabot[bot] <support@github.com>'
HUMAN_SIGNOFF = 'Signed-off-by: DCO Fixture <fixture@example.invalid>'


class PrDcoTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='imboy-pr-dco-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / 'repo'
        self.repo.mkdir()
        self.env = {k: v for k, v in os.environ.items() if not k.startswith('GIT_')}
        self.env.update(GIT_CONFIG_NOSYSTEM='1', GIT_CONFIG_GLOBAL=os.devnull,
                        GITHUB_REPOSITORY='example/project')
        self.git('init', '-q')
        self.git('config', 'user.name', 'DCO Fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')
        hooks = self.root / 'hooks'
        hooks.mkdir()
        self.git('config', 'core.hooksPath', str(hooks))
        self.base = self.commit('Existing unsigned base')
        self.response = self.root / 'response.json'
        self.calls = self.root / 'calls'
        self.response.write_text('{}', encoding='utf-8')
        stub_dir = self.root / 'bin'
        stub_dir.mkdir()
        stub = stub_dir / 'gh'
        stub.write_text('''#!/usr/bin/env bash
set -euo pipefail
[[ "$#" == 6 && "$1" == api && "$2" == --hostname &&
   "$3" == github.com && "$5" == --jq ]] || exit 91
printf '%s\\n' "$4" >> "$DCO_TEST_CALLS"
[[ "${DCO_TEST_API_FAILURE:-0}" == 0 ]] || exit 92
jq -r "$6" "$DCO_TEST_RESPONSE"
''', encoding='utf-8')
        stub.chmod(0o755)
        self.env.update(PATH=str(stub_dir) + os.pathsep + self.env['PATH'],
                        DCO_TEST_RESPONSE=str(self.response),
                        DCO_TEST_CALLS=str(self.calls), DCO_TEST_API_FAILURE='0')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.repo,
                                       env=self.env, text=True).strip()

    def commit(self, subject, signoff=None, name='DCO Fixture',
               email='fixture@example.invalid'):
        args = ['-c', 'user.name=' + name, '-c', 'user.email=' + email,
                'commit', '-q', '--allow-empty', '-m', subject]
        if signoff is not None:
            args += ['-m', signoff]
        self.git(*args)
        return self.git('rev-parse', 'HEAD')

    def bot_commit(self, signoff=BOT_SIGNOFF, name=BOT_NAME, email=BOT_EMAIL):
        return self.commit('Dependency update', signoff, name, email)

    def trusted_response(self, sha):
        return {
            'sha': sha,
            'author': {'login': BOT_NAME, 'type': 'Bot', 'id': 49699333},
            'committer': {'login': 'web-flow'},
            'commit': {'author': {'name': BOT_NAME, 'email': BOT_EMAIL},
                       'verification': {'verified': True, 'reason': 'valid'}},
        }

    def check(self, head, expected, base=None, response=None, **env):
        if response is not None:
            self.response.write_text(json.dumps(response), encoding='utf-8')
        process = subprocess.run(
            ['bash', str(CHECKER)], cwd=self.repo,
            env={**self.env, 'PR_BASE_SHA': self.base if base is None else base,
                 'PR_HEAD_SHA': head, **env},
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
            timeout=15,
        )
        self.assertEqual(process.returncode, expected, process.stdout)
        return process.stdout

    def test_signed_human_needs_no_api(self):
        head = self.commit('Signed contribution', HUMAN_SIGNOFF)
        self.assertIn('DCO passed for 1 PR commits', self.check(head, 0))
        self.assertFalse(self.calls.exists())

    def test_unsigned_or_wrong_human_signoff_fails(self):
        for signoff in (None, 'Signed-off-by: Other <other@example.invalid>'):
            with self.subTest(signoff=signoff):
                self.git('reset', '--hard', self.base)
                self.check(self.commit('Unsigned contribution', signoff), 1)
        self.assertFalse(self.calls.exists())

    def test_email_metacharacters_remain_literal(self):
        email = 'fixture+ci[bot]@example.invalid'
        signed = self.commit('Signed CI fixture',
                             'Signed-off-by: Fixture <' + email + '>', email=email)
        self.check(signed, 0)
        wrong = self.commit('Wrong signoff',
                            'Signed-off-by: Fixture <fixture+cibot@exampleXinvalid>',
                            email=email)
        self.check(wrong, 1, base=signed)

    def test_official_signoff_requires_verified_repository_commit(self):
        self.assertIsNotNone(shutil.which('jq'), 'jq is required for the API filter regression')
        head = self.bot_commit()
        self.check(head, 0, response=self.trusted_response(head))
        self.assertEqual(self.calls.read_text().splitlines(),
                         ['repos/example/project/commits/' + head])

    def test_bot_signoff_is_exact_and_mandatory(self):
        for signoff in (None, HUMAN_SIGNOFF,
                        'Signed-off-by: dependabot[bot] <' + BOT_EMAIL + '>',
                        BOT_SIGNOFF + ' extra',
                        'Signed-off-by: Other <support@github.com>'):
            with self.subTest(signoff=signoff):
                self.git('reset', '--hard', self.base)
                head = self.bot_commit(signoff=signoff)
                self.check(head, 1, response=self.trusted_response(head))
        self.assertFalse(self.calls.exists())

    def test_partial_bot_identity_is_not_a_human_exception(self):
        for name, email in ((BOT_NAME, 'impostor@example.invalid'),
                            ('Impostor', BOT_EMAIL)):
            with self.subTest(name=name, email=email):
                self.git('reset', '--hard', self.base)
                head = self.bot_commit(BOT_SIGNOFF, name, email)
                self.check(head, 1, response=self.trusted_response(head))
        self.assertFalse(self.calls.exists())

    def test_api_identity_signature_and_sha_must_all_match(self):
        head = self.bot_commit()
        mutations = [
            (('sha',), '1' * 40),
            (('author', 'login'), 'impostor'),
            (('author', 'id'), 123),
            (('author', 'type'), 'User'),
            (('commit', 'author', 'name'), 'Impostor'),
            (('commit', 'author', 'email'), 'impostor@example.invalid'),
            (('committer', 'login'), 'impostor'),
            (('commit', 'verification', 'verified'), False),
            (('commit', 'verification', 'verified'), 'true'),
            (('commit', 'verification', 'reason'), 'unknown_key'),
        ]
        for keys, value in mutations:
            with self.subTest(field='.'.join(keys), value=value):
                response = copy.deepcopy(self.trusted_response(head))
                target = response
                for key in keys[:-1]:
                    target = target[key]
                target[keys[-1]] = value
                self.check(head, 1, response=response)

    def test_api_failure_missing_fields_and_invalid_json_fail_closed(self):
        head = self.bot_commit()
        self.check(head, 1, response=self.trusted_response(head), DCO_TEST_API_FAILURE='1')
        self.check(head, 1, response={})
        self.response.write_text('invalid JSON', encoding='utf-8')
        self.check(head, 1)

    def test_missing_or_invalid_repository_fails_before_api(self):
        head = self.bot_commit()
        for repository in ('', 'project', 'https://github.com/example/project'):
            with self.subTest(repository=repository):
                self.check(head, 1, response=self.trusted_response(head),
                           GITHUB_REPOSITORY=repository)
        self.assertFalse(self.calls.exists())

    def test_invalid_or_empty_commit_range_fails(self):
        head = self.commit('Signed contribution', HUMAN_SIGNOFF)
        for base, tip in (('', head), (self.base, ''), (self.base, 'HEAD'),
                          ('main', head), (self.base, '1' * 40),
                          ('1' * 40, head), (head, head)):
            with self.subTest(base=base, head=tip):
                self.check(tip, 1, base=base)

    def test_unsigned_ancestor_is_not_hidden_by_signed_tip(self):
        self.commit('Unsigned contribution')
        head = self.commit('Signed tip', HUMAN_SIGNOFF)
        self.check(head, 1)

    def test_synthetic_checkout_merge_excluded_but_real_merge_checked(self):
        self.git('checkout', '-qb', 'contribution')
        head = self.commit('Signed contribution', HUMAN_SIGNOFF)
        self.git('checkout', '-qb', 'target', self.base)
        target = self.commit('Target advanced', HUMAN_SIGNOFF)
        self.git('merge', '-q', '--no-ff', '--no-edit', 'contribution')
        synthetic = self.git('rev-parse', 'HEAD')
        self.check(head, 0, base=target)
        self.check(synthetic, 1, base=target)


if __name__ == '__main__':
    unittest.main()
