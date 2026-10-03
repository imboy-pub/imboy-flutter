"""Read-only evidence-integrity gates for full-product acceptance F01.

Extends the existing evidence schema and Flutter machine-event parser. A clean
result proves artifact integrity and recorded test counts only. Coverage,
candidate ancestry, business oracles, independent review and user UX approval
remain separate required gates; this module cannot issue product PASS.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import re
import stat
from pathlib import Path
from typing import Any, Dict, List, Mapping, Optional, Sequence, Tuple

from auto_test_lib import evidence, machine_events

_HASH = re.compile(r'^[0-9a-f]{64}$')
_MAX_EVENT_BYTES = 32 * 1024 * 1024


def _parts(path: Any) -> List[str]:
    if not isinstance(path, str) or not path or '\x00' in path or '\\' in path:
        raise ValueError('ARTIFACT_PATH_REJECTED')
    parts = path.split('/')
    if Path(path).is_absolute() or any(p in ('', '.', '..') for p in parts):
        raise ValueError('ARTIFACT_PATH_REJECTED')
    return parts


def _open_artifact(root: Path, path: str) -> int:
    """Open each component relative to an owned descriptor; reject symlinks."""
    parts = _parts(path)
    directory_flags = os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW
    directory = os.open(root, directory_flags)
    try:
        for part in parts[:-1]:
            child = os.open(part, directory_flags, dir_fd=directory)
            os.close(directory)
            directory = child
        descriptor = os.open(
            parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
            dir_fd=directory,
        )
        if not stat.S_ISREG(os.fstat(descriptor).st_mode):
            os.close(descriptor)
            raise OSError('artifact is not a regular file')
        return descriptor
    finally:
        os.close(directory)


def _hash_artifact(root: Path, path: str) -> str:
    digest = hashlib.sha256()
    with os.fdopen(_open_artifact(root, path), 'rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def validate_artifact_files(
    root: Path, artifacts: Sequence[Mapping[str, Any]],
) -> List[str]:
    """Recompute every indexed artifact hash without following symlinks.

    Does not certify that an index contains the complete required artifact set.
    Paths and values from untrusted evidence are not echoed in errors.
    """
    if not isinstance(artifacts, list) or not artifacts:
        return ['EMPTY_ARTIFACT_SET']
    errors: List[str] = []
    seen = set()
    for index, artifact in enumerate(artifacts):
        if not isinstance(artifact, dict):
            errors.append('ARTIFACT_SCHEMA_INVALID:%d' % index)
            continue
        path, claimed = artifact.get('path'), artifact.get('sha256')
        try:
            _parts(path)
        except ValueError:
            errors.append('ARTIFACT_PATH_REJECTED:%d' % index)
            continue
        if path in seen:
            errors.append('DUPLICATE_ARTIFACT_PATH:%d' % index)
            continue
        seen.add(path)
        if not isinstance(claimed, str) or not _HASH.fullmatch(claimed):
            errors.append('ARTIFACT_HASH_INVALID:%d' % index)
            continue
        try:
            actual = _hash_artifact(Path(root), path)
        except OSError:
            errors.append('ARTIFACT_UNREADABLE:%d' % index)
            continue
        if actual != claimed:
            errors.append('ARTIFACT_HASH_MISMATCH:%d' % index)
    return errors


def _read_verified_artifact(root: Path, artifact: Dict[str, Any]) -> bytes:
    """Read bounded bytes and verify their hash on the same descriptor."""
    with os.fdopen(_open_artifact(root, artifact['path']), 'rb') as stream:
        content = stream.read(_MAX_EVENT_BYTES + 1)
    if len(content) > _MAX_EVENT_BYTES:
        raise ValueError('MACHINE_EVENT_ARTIFACT_TOO_LARGE')
    if hashlib.sha256(content).hexdigest() != artifact['sha256']:
        raise ValueError('ARTIFACT_CHANGED_DURING_AUDIT')
    return content


def _read_event_artifact(root: Path, artifact: Dict[str, Any]) -> List[str]:
    return _read_verified_artifact(root, artifact).decode('utf-8').splitlines()


def _unique_json_object(pairs: list) -> dict:
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('DUPLICATE_JSON_KEY')
        result[key] = value
    return result


def _reject_json_constant(value: str) -> None:
    raise ValueError('NONFINITE_JSON_NUMBER')


def _finite_json_float(value: str) -> float:
    number = float(value)
    if not math.isfinite(number):
        raise ValueError('NONFINITE_JSON_NUMBER')
    return number


def load_frozen_json(root: Path, artifact: Any) -> Tuple[Any, List[str]]:
    """Load bounded JSON from an independently pinned artifact descriptor.

    Caller supplies path/hash from a trusted frozen input index, never from
    the report under audit. This function proves bytes and parsing only;
    candidate ancestry and domain schemas remain separate mandatory gates.
    """
    if not isinstance(artifact, dict):
        return None, ['FROZEN_INPUT_DESCRIPTOR_INVALID']
    errors = validate_artifact_files(root, [artifact])
    if errors:
        return None, errors
    try:
        content = _read_verified_artifact(Path(root), artifact).decode('utf-8')
        value = json.loads(content, object_pairs_hook=_unique_json_object,
                           parse_constant=_reject_json_constant,
                           parse_float=_finite_json_float)
    except (OSError, UnicodeError, ValueError, RecursionError):
        return None, ['FROZEN_INPUT_UNREADABLE_OR_AMBIGUOUS']
    if not isinstance(value, (dict, list)):
        return None, ['FROZEN_INPUT_CONTAINER_REQUIRED']
    return value, []


def _raw_result_errors(root: Path, artifact: Dict[str, Any], result: dict) -> List[str]:
    try:
        lines = _read_event_artifact(root, artifact)
    except (OSError, UnicodeError, ValueError):
        return ['MACHINE_EVENT_ARTIFACT_UNREADABLE']
    if not _valid_event_protocol(lines):
        return ['RAW_EVENT_NOT_PASS', 'RAW_EVENT_PROTOCOL_INVALID']
    parsed = machine_events.parse_machine_events(lines, process_exit_code=0)
    errors = []
    if parsed.test_status != 'PASS' or parsed.malformed_lines:
        errors.append('RAW_EVENT_NOT_PASS')
    observed = {'executed': parsed.executed, 'failed': parsed.failed,
                'skipped': parsed.skipped}
    for key, value in observed.items():
        if type(result.get(key)) is not int or result[key] != value:
            errors.append('RAW_EVENT_RESULT_MISMATCH:%s' % key)
    return errors


def _valid_test_done(event: dict) -> bool:
    if event.get('result') not in ('success', 'skipped', 'failure', 'error'):
        return False
    if any(key in event and type(event[key]) is not bool
           for key in ('hidden', 'skipped')):
        return False
    # Hidden loading/setup failures must not disappear from final evidence.
    return event['result'] == 'success' and not event.get('skipped', False)


def _valid_event_protocol(lines: List[str]) -> bool:
    """Require one complete run and one completion for every started test."""
    try:
        events = [json.loads(line) for line in lines if line.strip()]
    except ValueError:
        return False
    if not events or any(not isinstance(event, dict) for event in events):
        return False
    if events[0].get('type') != 'start' or events[-1].get('type') != 'done':
        return False
    if sum(event.get('type') == 'start' for event in events) != 1:
        return False
    if sum(event.get('type') == 'done' for event in events) != 1:
        return False
    if events[-1].get('success') is not True:
        return False
    started, completed = set(), set()
    for event in events:
        if event.get('type') == 'error':
            return False
        if event.get('type') == 'testStart':
            test = event.get('test')
            identifier = test.get('id') if isinstance(test, dict) else None
            if type(identifier) is not int or identifier < 0 or identifier in started:
                return False
            started.add(identifier)
        elif event.get('type') == 'testDone':
            identifier = event.get('testID')
            if type(identifier) is not int or identifier not in started:
                return False
            if identifier in completed or not _valid_test_done(event):
                return False
            completed.add(identifier)
    return bool(started) and started == completed


def audit_evidence_artifacts(
    root: Path, manifest: Dict[str, Any],
    requirements: Optional[Sequence[str]] = None, risk: Optional[str] = None,
) -> List[str]:
    """Validate the existing manifest and independently reparse its event file.

    One event stream per manifest prevents multiple targets being merged into
    fabricated counts. The event stream is required even for a claimed exit=0.
    """
    if not isinstance(manifest, dict) or not isinstance(manifest.get('result'), dict):
        return ['EVIDENCE_SCHEMA_REJECTED']
    if not isinstance(manifest['result'].get('status'), str):
        return ['EVIDENCE_SCHEMA_REJECTED']
    if manifest.get('required_evidence_level') is not None and not isinstance(
        manifest['required_evidence_level'], str,
    ):
        return ['EVIDENCE_SCHEMA_REJECTED']
    errors = evidence.validate_evidence(manifest, requirements, risk)
    if errors:
        # Existing schema diagnostics can include input values; return codes
        # only so an invalid manifest cannot leak credentials through errors.
        return ['EVIDENCE_SCHEMA_REJECTED']
    result = manifest['result']
    if type(result.get('process_exit_code')) is not int or result['process_exit_code'] != 0:
        errors.append('PROCESS_EXIT_NOT_ZERO')
    if result.get('status') != 'PASS':
        errors.append('EVIDENCE_STATUS_NOT_PASS')
    artifacts = manifest['artifacts']
    errors.extend(validate_artifact_files(root, artifacts))
    streams = [item for item in artifacts if item.get('kind') == 'machine_events']
    if len(streams) != 1:
        errors.append('MACHINE_EVENT_ARTIFACT_REQUIRED')
    if errors:
        return errors
    return _raw_result_errors(Path(root), streams[0], result)
