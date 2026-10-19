"""Candidate checks use real isolated Git repositories, no product resources."""
import copy
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib import acceptance_contract


class CandidateBindingTests(unittest.TestCase):
    def git(self, root, *args):
        return subprocess.check_output(
            ['git', '-C', str(root), '-c', 'user.name=leeyi',
             '-c', 'user.email=leeyisoft@qq.com', *args], stderr=subprocess.DEVNULL,
            text=True).strip()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.roots, self.frozen = {}, {}
        for name in ('imboy', 'imboyapp', 'imboyadmin'):
            root = Path(self.temp.name) / name
            root.mkdir()
            self.git(root, 'init', '-q')
            self.git(root, 'commit', '--allow-empty', '-qm', 'ancestor')
            ancestor = self.git(root, 'rev-parse', 'HEAD')
            (root / 'tracked.txt').write_text('candidate bytes')
            self.git(root, 'add', 'tracked.txt')
            self.git(root, 'commit', '--allow-empty', '-qm', 'candidate')
            head = self.git(root, 'rev-parse', 'HEAD')
            self.roots[name] = root
            self.frozen[name] = {'head': head, 'required_ancestors': [ancestor]}

    def audit(self, observed=None, frozen=None, roots=None):
        return acceptance_contract.audit_candidate_repositories(
            self.roots if roots is None else roots,
            self.frozen if frozen is None else frozen,
            self.frozen if observed is None else observed)

    def test_three_real_candidates_and_ancestors(self):
        self.assertEqual(self.audit(), [])

    def test_claimed_head_changed(self):
        observed = copy.deepcopy(self.frozen)
        observed['imboyapp']['head'] = 'a' * 40
        self.assertTrue(self.audit(observed=observed))

    def test_same_repository_cannot_satisfy_three_roots(self):
        roots = {name: self.roots['imboy'] for name in self.roots}
        frozen = {name: self.frozen['imboy'] for name in self.roots}
        self.assertTrue(self.audit(roots=roots, frozen=frozen, observed=frozen))

    def test_live_head_changed(self):
        self.git(self.roots['imboy'], 'commit', '--allow-empty', '-qm', 'new head')
        self.assertTrue(self.audit())

    def test_missing_ancestor_commit_rejected(self):
        frozen = copy.deepcopy(self.frozen)
        frozen['imboy']['required_ancestors'] = ['a' * 40]
        self.assertTrue(self.audit(frozen=frozen, observed=frozen))

    def test_existing_nonancestor_rejected(self):
        root = self.roots['imboy']
        self.git(root, 'checkout', '--orphan', 'unrelated')
        self.git(root, 'commit', '--allow-empty', '-qm', 'unrelated')
        unrelated = self.git(root, 'rev-parse', 'HEAD')
        self.git(root, 'checkout', '--detach', self.frozen['imboy']['head'])
        frozen = copy.deepcopy(self.frozen)
        frozen['imboy']['required_ancestors'] = [unrelated]
        self.assertTrue(self.audit(frozen=frozen, observed=frozen))
        self.git(root, 'replace', '--graft', frozen['imboy']['head'], unrelated)
        self.assertTrue(self.audit(frozen=frozen, observed=frozen))
        self.git(root, 'replace', '-d', frozen['imboy']['head'])
        (root / '.git' / 'info').mkdir(exist_ok=True)
        (root / '.git' / 'info' / 'grafts').write_text(
            frozen['imboy']['head'] + ' ' + unrelated + '\n')
        self.assertTrue(self.audit(frozen=frozen, observed=frozen))

    def test_incomplete_roots_and_nested_directory_rejected(self):
        roots = dict(self.roots)
        del roots['imboyadmin']
        self.assertTrue(self.audit(roots=roots))
        roots = dict(self.roots)
        nested = roots['imboy'] / 'nested'
        nested.mkdir()
        roots['imboy'] = nested
        self.assertTrue(self.audit(roots=roots))

    def test_bad_schema_and_dropped_ancestry_rejected(self):
        for value in (None, [], {}, {'head': '--secret-value', 'required_ancestors': []}):
            frozen = copy.deepcopy(self.frozen)
            frozen['imboy'] = value
            errors = self.audit(frozen=frozen, observed=frozen)
            self.assertTrue(errors)
            self.assertNotIn('secret-value', str(errors))
        observed = copy.deepcopy(self.frozen)
        observed['imboy']['required_ancestors'] = []
        self.assertTrue(self.audit(observed=observed))

    def test_tracked_worktree_and_index_changes_cannot_reuse_head(self):
        root = self.roots['imboyapp']
        (root / 'tracked.txt').write_text('changed bytes')
        self.assertIn('CANDIDATE_TRACKED_SOURCE_DIRTY:imboyapp', self.audit())
        self.git(root, 'add', 'tracked.txt')
        self.assertIn('CANDIDATE_TRACKED_SOURCE_DIRTY:imboyapp', self.audit())
        (root / 'tracked.txt').write_text('candidate bytes')
        self.assertIn('CANDIDATE_TRACKED_SOURCE_DIRTY:imboyapp', self.audit())

    def test_index_flags_cannot_hide_changed_source(self):
        root = self.roots['imboyapp']
        for flag in ['assume-unchanged', 'skip-worktree']:
            self.git(root, 'update-index', '--' + flag, 'tracked.txt')
            (root / 'tracked.txt').write_text('hidden change')
            self.assertIn('CANDIDATE_INDEX_HIDES_SOURCE_CHANGES:imboyapp', self.audit())
            (root / 'tracked.txt').write_text('candidate bytes')
            self.git(root, 'update-index', '--no-' + flag, 'tracked.txt')


if __name__ == '__main__':
    unittest.main()
