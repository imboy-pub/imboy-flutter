"""Pinned plan input bytes only; semantic agreement and live drift are separate."""
from pathlib import Path
from typing import Any, List
import re

from auto_test_lib import acceptance, acceptance_contract

_ROLES = {'product_plan', 'e2ee_plan', 'execution_contract', 'dispatch_cards',
          'acceptance_set', 'coverage_seed', 'input_manifest'}


def audit_version_inputs(root: Path, frozen: Any, observed: Any) -> List[str]:
    """Require every contract component explicitly and verify actual bytes.

    Descriptors must be frozen independently of the report. This gate cannot
    prove that these bytes are the authoritative latest approved plan or that
    their contents agree with the required case and acceptance collections.
    """
    if (not isinstance(frozen, dict) or set(frozen) != _ROLES
            or not isinstance(observed, dict) or set(observed) != _ROLES):
        return ['VERSION_INPUT_ROLE_SET_INVALID']
    if observed != frozen:
        return ['VERSION_INPUT_BINDING_CHANGED']
    errors, paths, hashes = [], set(), set()
    for descriptor in frozen.values():
        if not isinstance(descriptor, dict) or set(descriptor) != {'path', 'sha256'}:
            errors.append('VERSION_INPUT_DESCRIPTOR_INVALID')
            continue
        path, digest = descriptor['path'], descriptor['sha256']
        if not isinstance(path, str) or not isinstance(digest, str):
            errors.append('VERSION_INPUT_DESCRIPTOR_INVALID')
            continue
        if path in paths or digest in hashes:
            errors.append('VERSION_INPUT_ARTIFACT_REUSED')
        paths.add(path)
        hashes.add(digest)
        errors.extend(acceptance.validate_artifact_files(root, [descriptor]))
    return errors


def audit_version_document_links(root: Path, frozen: Any) -> List[str]:
    """Bind the document's component references to independently pinned bytes."""
    if not isinstance(frozen, dict) or not isinstance(frozen.get('version_inputs'), dict):
        return ['VERSION_DOCUMENT_LINKS_INVALID']
    inputs = frozen['version_inputs']
    document, errors = acceptance.load_frozen_json(root, inputs.get('acceptance_set'))
    if errors:
        return errors
    if not isinstance(document, dict):
        return ['VERSION_DOCUMENT_LINKS_INVALID']
    links = {'product_plan': 'plan_sha256', 'execution_contract': 'execution_contract_sha256',
             'dispatch_cards': 'dispatch_cards_sha256', 'coverage_seed': 'seed_sha256',
             'input_manifest': 'input_manifest_sha256'}
    for role, field in links.items():
        descriptor = inputs.get(role)
        digest = descriptor.get('sha256') if isinstance(descriptor, dict) else None
        if (not isinstance(digest, str) or not re.fullmatch(r'[0-9a-f]{64}', digest)
                or document.get(field) != digest):
            errors.append('VERSION_DOCUMENT_COMPONENT_MISMATCH:' + role)
    upstream, descriptor = document.get('upstream'), inputs.get('e2ee_plan')
    digest = descriptor.get('sha256') if isinstance(descriptor, dict) else None
    if (not isinstance(upstream, dict) or not isinstance(digest, str)
            or not re.fullmatch(r'[0-9a-f]{64}', digest) or upstream.get('sha256') != digest):
        errors.append('VERSION_DOCUMENT_UPSTREAM_MISMATCH')
    return errors


def audit_version_acceptance_set(root: Path, frozen: Any) -> List[str]:
    """Require runtime IDs to equal the independently pinned version document.

    This binds the explicit product Acceptance-ID set, not the upstream E2EE
    qualification ledger or the semantics of its business requirements.
    """
    if not isinstance(frozen, dict) or not isinstance(frozen.get('version_inputs'), dict):
        return ['VERSION_ACCEPTANCE_SET_INVALID']
    document, errors = acceptance.load_frozen_json(
        root, frozen['version_inputs'].get('acceptance_set'))
    if errors:
        return errors
    if not isinstance(document, dict):
        return ['VERSION_ACCEPTANCE_SET_INVALID']
    approved, runtime = document.get('acceptance_ids'), frozen.get('acceptance_ids')
    for identifiers in (approved, runtime):
        if (not isinstance(identifiers, list) or not identifiers
                or any(not isinstance(i, str) or not i.strip() for i in identifiers)
                or len(set(identifiers)) != len(identifiers)):
            return ['VERSION_ACCEPTANCE_SET_INVALID']
    if set(approved) != set(runtime):
        return ['VERSION_ACCEPTANCE_SET_MISMATCH']
    return []


def audit_dispatch_acceptance_set(root: Path, frozen: Any) -> List[str]:
    """Reject implicit card-to-parent mappings; coverage is not execution."""
    if not isinstance(frozen, dict) or not isinstance(frozen.get('version_inputs'), dict):
        return ['DISPATCH_INPUT_INVALID']
    document, errors = acceptance.load_frozen_json(
        root, frozen['version_inputs'].get('dispatch_cards'))
    if errors:
        return errors
    cards = document.get('cards') if isinstance(document, dict) else None
    identifiers = frozen.get('acceptance_ids')
    if (not isinstance(cards, list) or not cards or not isinstance(identifiers, list)
            or not identifiers or any(not isinstance(i, str) or not i.strip() for i in identifiers)
            or len(set(identifiers)) != len(identifiers)):
        return ['DISPATCH_INPUT_INVALID']
    owners, covered, errors = set(), set(), []
    for card in cards:
        if not isinstance(card, dict):
            return ['DISPATCH_CARD_INVALID']
        key, parents = card.get('id'), card.get('acceptance_ids')
        if not isinstance(key, str) or not key.strip() or key in owners:
            return ['DISPATCH_CARD_ID_INVALID']
        owners.add(key)
        if (not isinstance(parents, list) or not parents
                or any(not isinstance(i, str) or not i.strip() for i in parents)
                or len(set(parents)) != len(parents)):
            errors.append('DISPATCH_CARD_ACCEPTANCE_SET_INVALID')
            continue
        covered.update(parents)
    if covered != set(identifiers):
        errors.append('DISPATCH_ACCEPTANCE_COVERAGE_MISMATCH')
    return errors


def audit_case_dispatch_links(root: Path, frozen: Any) -> List[str]:
    """Every card needs frozen cases; case parents must match assigned cards.

    Declaration coverage is not proof of a card's business oracles or owner.
    """
    errors = audit_dispatch_acceptance_set(root, frozen)
    if errors:
        return errors
    document, errors = acceptance.load_frozen_json(
        root, frozen['version_inputs']['dispatch_cards'])
    if errors:
        return errors
    cases = frozen.get('required_cases')
    if acceptance_contract._case_index(cases) is None:
        return ['DISPATCH_REQUIRED_CASE_SET_INVALID']
    cards = {card['id']: set(card['acceptance_ids']) for card in document['cards']}
    used, errors = {}, []
    for case in cases:
        assignments = case.get('dispatch_card_ids')
        if (not isinstance(assignments, list) or not assignments
                or any(not isinstance(i, str) or not i.strip() for i in assignments)
                or len(set(assignments)) != len(assignments)):
            errors.append('CASE_DISPATCH_DECLARATION_INVALID')
            continue
        if any(identifier not in cards for identifier in assignments):
            errors.append('CASE_DISPATCH_CARD_UNKNOWN')
            continue
        parents, covered = set(case['parent_acceptance_ids']), set()
        for identifier in assignments:
            if not parents & cards[identifier]:
                errors.append('CASE_DISPATCH_UNRELATED_CARD')
            covered.update(cards[identifier])
            used.setdefault(identifier, set()).update(parents & cards[identifier])
        if not parents <= covered:
            errors.append('CASE_DISPATCH_PARENT_NOT_COVERED')
    if set(used) != set(cards):
        errors.append('DISPATCH_CARD_WITHOUT_REQUIRED_CASE')
    if any(used.get(identifier, set()) != parents for identifier, parents in cards.items()):
        errors.append('DISPATCH_CARD_PARENT_CASE_COVERAGE_MISMATCH')
    return errors
