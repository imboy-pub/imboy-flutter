"""Pinned plan input bytes only; semantic agreement and live drift are separate."""
from pathlib import Path
from typing import Any, List

from auto_test_lib import acceptance

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
