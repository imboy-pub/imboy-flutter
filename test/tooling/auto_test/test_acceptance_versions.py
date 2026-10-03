import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / 'scripts'))
from auto_test_lib.acceptance_versions import (
    audit_version_inputs, audit_version_acceptance_set, audit_dispatch_acceptance_set,
    audit_version_document_links,
    audit_case_dispatch_links,
)


class VersionInputsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.frozen = {}
        for role in ('product_plan', 'e2ee_plan', 'execution_contract', 'dispatch_cards',
                     'acceptance_set', 'coverage_seed', 'input_manifest'):
            raw = ('synthetic only: ' + role).encode()
            (self.root / role).write_bytes(raw)
            self.frozen[role] = dict(path=role, sha256=hashlib.sha256(raw).hexdigest())
        self.report = copy.deepcopy(self.frozen)

    def audit(self):
        return audit_version_inputs(self.root, self.frozen, self.report)

    def test_complete_synthetic_component_bytes(self):
        self.assertEqual([], self.audit())

    def test_missing_and_unknown_components_rejected(self):
        for role in tuple(self.frozen):
            descriptor = self.frozen.pop(role)
            self.assertIn('VERSION_INPUT_ROLE_SET_INVALID', self.audit())
            self.frozen[role] = descriptor
        self.report['unknown'] = {}
        self.assertIn('VERSION_INPUT_ROLE_SET_INVALID', self.audit())

    def test_report_cannot_replace_frozen_binding(self):
        self.report['product_plan']['sha256'] = '0' * 64
        self.assertIn('VERSION_INPUT_BINDING_CHANGED', self.audit())

    def test_tampered_bytes_rejected(self):
        (self.root / 'execution_contract').write_text('changed')
        self.assertTrue(any('ARTIFACT_HASH_MISMATCH' in e for e in self.audit()))

    def test_reusing_one_file_for_two_roles_rejected(self):
        self.frozen['e2ee_plan'] = self.frozen['product_plan']
        self.report = copy.deepcopy(self.frozen)
        self.assertIn('VERSION_INPUT_ARTIFACT_REUSED', self.audit())

    def test_escape_symlink_and_malformed_descriptor_rejected(self):
        for descriptor in (dict(path='../outside', sha256='a' * 64),
                           dict(path=[], sha256='a' * 64), None):
            self.frozen['product_plan'] = descriptor
            self.report = copy.deepcopy(self.frozen)
            self.assertTrue(self.audit())
        (self.root / 'alias').symlink_to('e2ee_plan')
        self.frozen['product_plan'] = dict(path='alias', sha256=self.frozen['e2ee_plan']['sha256'])
        self.report = copy.deepcopy(self.frozen)
        self.assertTrue(any('ARTIFACT_UNREADABLE' in e for e in self.audit()))

    def semantic_input(self, identifiers):
        raw = json.dumps({'acceptance_ids': identifiers}).encode()
        (self.root / 'acceptance_set').write_bytes(raw)
        artifact = dict(path='acceptance_set', sha256=hashlib.sha256(raw).hexdigest())
        return dict(version_inputs={'acceptance_set': artifact}, acceptance_ids=['F01-A01', 'F02-A01'])

    def test_version_ids_exact_equal_runtime_ids(self):
        frozen = self.semantic_input(['F02-A01', 'F01-A01'])
        self.assertEqual([], audit_version_acceptance_set(self.root, frozen))
        for identifiers in (['F01-A01'], ['F01-A01', 'F02-A01', 'unknown']):
            self.assertIn('VERSION_ACCEPTANCE_SET_MISMATCH',
                          audit_version_acceptance_set(self.root, self.semantic_input(identifiers)))

    def test_invalid_or_duplicate_document_ids_rejected(self):
        for identifiers in (None, [], ['F01-A01', 'F01-A01'], [''], [123]):
            self.assertIn('VERSION_ACCEPTANCE_SET_INVALID',
                          audit_version_acceptance_set(self.root, self.semantic_input(identifiers)))

    def test_runtime_duplicates_and_missing_descriptor_rejected(self):
        frozen = self.semantic_input(['F01-A01', 'F02-A01'])
        frozen['acceptance_ids'].append('F01-A01')
        self.assertIn('VERSION_ACCEPTANCE_SET_INVALID', audit_version_acceptance_set(self.root, frozen))
        frozen['version_inputs'] = {}
        self.assertTrue(audit_version_acceptance_set(self.root, frozen))

    def dispatch_input(self, cards):
        raw = json.dumps({'cards': cards}).encode()
        (self.root / 'dispatch_cards').write_bytes(raw)
        descriptor = dict(path='dispatch_cards', sha256=hashlib.sha256(raw).hexdigest())
        return dict(version_inputs={'dispatch_cards': descriptor}, acceptance_ids=['F01-A01'])

    def test_dispatch_exact_coverage_and_missing_mapping(self):
        card = {'id': 'card', 'acceptance_ids': ['F01-A01']}
        self.assertEqual([], audit_dispatch_acceptance_set(self.root, self.dispatch_input([card])))
        for parents in (None, [], ['F01-A01', 'F01-A01'], ['unknown']):
            card['acceptance_ids'] = parents
            self.assertTrue(audit_dispatch_acceptance_set(self.root, self.dispatch_input([card])))

    def test_duplicate_cards_and_empty_dispatch_rejected(self):
        card = {'id': 'card', 'acceptance_ids': ['F01-A01']}
        self.assertIn('DISPATCH_CARD_ID_INVALID', audit_dispatch_acceptance_set(
            self.root, self.dispatch_input([card, card])))
        self.assertIn('DISPATCH_INPUT_INVALID', audit_dispatch_acceptance_set(
            self.root, self.dispatch_input([])))

    def linked_document(self, document):
        raw = json.dumps(document).encode()
        (self.root / 'acceptance_set').write_bytes(raw)
        self.frozen['acceptance_set'] = dict(path='acceptance_set', sha256=hashlib.sha256(raw).hexdigest())
        return {'version_inputs': self.frozen}

    def test_document_component_references_match_pinned_artifacts(self):
        links = {'product_plan': 'plan_sha256', 'execution_contract': 'execution_contract_sha256',
                 'dispatch_cards': 'dispatch_cards_sha256', 'coverage_seed': 'seed_sha256',
                 'input_manifest': 'input_manifest_sha256'}
        document = {field: self.frozen[role]['sha256'] for role, field in links.items()}
        document['upstream'] = {'sha256': self.frozen['e2ee_plan']['sha256']}
        self.assertEqual([], audit_version_document_links(self.root, self.linked_document(document)))
        for role, field in links.items():
            old = document[field]
            document[field] = '0' * 64
            self.assertIn('VERSION_DOCUMENT_COMPONENT_MISMATCH:' + role,
                          audit_version_document_links(self.root, self.linked_document(document)))
            document[field] = old
        document['upstream'] = None
        self.assertIn('VERSION_DOCUMENT_UPSTREAM_MISMATCH',
                      audit_version_document_links(self.root, self.linked_document(document)))

    def case_dispatch_input(self):
        frozen = self.dispatch_input([{'id': 'card', 'acceptance_ids': ['F01-A01']}])
        case = dict(case_id='case', platform='android', profile='enabled', role_variant='sender',
                    parent_acceptance_ids=['F01-A01'], seed_ids=['seed'], oracle='synthetic',
                    applicability='REQUIRED', dispatch_card_ids=['card'])
        frozen['required_cases'] = [case]
        return frozen

    def test_case_dispatch_exact_valid_and_missing_assignments(self):
        frozen = self.case_dispatch_input()
        self.assertEqual([], audit_case_dispatch_links(self.root, frozen))
        for assignment in (None, [], ['unknown'], ['card', 'card']):
            frozen['required_cases'][0]['dispatch_card_ids'] = assignment
            self.assertTrue(audit_case_dispatch_links(self.root, frozen))

    def test_case_parent_must_belong_to_assigned_card(self):
        frozen = self.case_dispatch_input()
        frozen['required_cases'][0]['parent_acceptance_ids'] = ['other']
        errors = audit_case_dispatch_links(self.root, frozen)
        self.assertIn('CASE_DISPATCH_UNRELATED_CARD', errors)
        self.assertIn('CASE_DISPATCH_PARENT_NOT_COVERED', errors)

    def test_unassigned_card_cannot_be_hidden_by_another_card(self):
        cases = self.case_dispatch_input()['required_cases']
        frozen = self.dispatch_input([
            {'id': 'card', 'acceptance_ids': ['F01-A01']},
            {'id': 'unused', 'acceptance_ids': ['F01-A01']}])
        frozen['required_cases'] = cases
        self.assertIn('DISPATCH_CARD_WITHOUT_REQUIRED_CASE', audit_case_dispatch_links(self.root, frozen))

    def test_each_card_requires_cases_for_all_its_parents(self):
        cases = self.case_dispatch_input()['required_cases']
        other = copy.deepcopy(cases[0])
        other.update(case_id='other', parent_acceptance_ids=['F02-A01'], dispatch_card_ids=['second'])
        cases.append(other)
        frozen = self.dispatch_input([
            {'id': 'card', 'acceptance_ids': ['F01-A01', 'F02-A01']},
            {'id': 'second', 'acceptance_ids': ['F02-A01']}])
        frozen.update(acceptance_ids=['F01-A01', 'F02-A01'], required_cases=cases)
        self.assertIn('DISPATCH_CARD_PARENT_CASE_COVERAGE_MISMATCH',
                      audit_case_dispatch_links(self.root, frozen))


if __name__ == '__main__':
    unittest.main()
