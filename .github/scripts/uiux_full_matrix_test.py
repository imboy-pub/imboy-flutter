"""Behavioral checks for the full/offline partition contract."""
import copy
import unittest

from uiux_full_matrix import matrix


def plan():
    rows = [dict(id=str(n), selected=True, platform='linux', suite='unit',
                 runner='flutter-machine', product_profile=product,
                 coverage_eligible=True)
            for n, product in enumerate(('phase1_delivery', 'full-selected'))]
    base = dict(commit='abc', source_fingerprint='fp', gates=['ownership'], instances=rows)
    return dict(base, full_regression=True), dict(copy.deepcopy(base), scope='scoped')


class MatrixTest(unittest.TestCase):
    def test_products_are_separate_and_plan_is_unmodified(self):
        full, offline = plan()
        original = copy.deepcopy(offline)
        workers = matrix(full, offline)['include']
        self.assertEqual({w['product'] for w in workers}, {'phase1_delivery', 'full-selected'})
        self.assertEqual(len(workers), 2)
        self.assertTrue(all('os' not in worker for worker in workers))
        self.assertTrue(all(w['coverage'] == '--coverage' for w in workers))
        self.assertEqual(offline, original)

    def test_mismatch_or_duplicate_is_rejected(self):
        full, offline = plan()
        offline['instances'][0]['suite'] = 'widget'
        with self.assertRaisesRegex(ValueError, 'OFFLINE_NOT_IDENTICAL'):
            matrix(full, offline)
        full, offline = plan()
        full['instances'].append(copy.deepcopy(full['instances'][0]))
        with self.assertRaisesRegex(ValueError, 'DUPLICATE_FULL'):
            matrix(full, offline)
        full, offline = plan()
        offline['instances'].append(copy.deepcopy(offline['instances'][0]))
        with self.assertRaisesRegex(ValueError, 'DUPLICATE'):
            matrix(full, offline)

    def test_missing_offline_obligation_is_rejected(self):
        full, offline = plan()
        offline['instances'][0]['selected'] = False
        with self.assertRaisesRegex(ValueError, 'OFFLINE_SELECTION_INCOMPLETE'):
            matrix(full, offline)

    def test_unsupported_runner_is_rejected(self):
        full, offline = plan()
        full['instances'][0]['runner'] = 'device'
        offline['instances'][0]['runner'] = 'device'
        with self.assertRaisesRegex(ValueError, 'HOST_WORKER_UNSUPPORTED'):
            matrix(full, offline)


if __name__ == '__main__':
    unittest.main()
