"""Verify the existing multi-document SQLite probe preparation before Chrome."""
from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil

TARGETS = frozenset({
    'test/unit_test/service/browser_sqlite_storage_bridge_chrome_test.dart',
    'test/service/web_writer_startup_busy_chrome_test.dart',
})
SCRIPT = '.github/scripts/ci_prepare_chrome.sh'
PROBE = 'test/fixtures/browser_sqlite_bridge_probe.dart'
PROBE_LINK = 'test/fixtures/browser_sqlite_bridge_probe.js'
SERVED = '.dart_tool/browser_sqlite_bridge_probe.js'
COUNTER = 'test/fixtures/startup_busy_counter.js'
SOURCE_INPUTS = (
    SCRIPT,
    'scripts/auto_test_lib/browser_sqlite_fixture.py',
    'scripts/auto_test_lib/execution_runner.py',
    'scripts/auto_test_lib/execution_catalog.py',
    'scripts/auto_test_lib/execution_cli.py',
    'lib/service/browser_sqlite_storage_bridge_web.dart',
    'lib/service/sqflite_init_web.dart',
    'pubspec.lock',
    PROBE,
    'test/fixtures/browser_sqlite_bridge_probe.html',
    'test/fixtures/browser_sqlite_bridge_probe.htm',
    'test/fixtures/browser_sqlite_bridge_host.html',
    'test/fixtures/browser_sqlite_bridge_host.htm',
    PROBE_LINK,
    COUNTER,
    'test/fixtures/sqlite3.wasm',
    'web/sqlite3.wasm',
)
_RUNTIME_INPUTS = tuple(name for name in SOURCE_INPUTS
    if not name.startswith('scripts/auto_test_lib/') and name != PROBE_LINK) + (
        '.dart_tool/package_config.json',)
EVIDENCE_NAMES = frozenset({
    'defines.json', 'receipt.json', 'compile.log', 'browser_sqlite_bridge_probe.js',
    'process.json', 'prepare.log', 'execution-context.json',
})
DEFINE_NAMES = frozenset({
    'BROWSER_SQLITE_PROBE_SRI', 'BROWSER_SQLITE_PREPARATION_SHA256', 'STARTUP_BUSY_COUNTER_SRI',
})
_BINDING_ERROR = 'BROWSER_SQLITE_PREPARATION_EVIDENCE_MISSING_OR_INVALID'


class PreparationFailure(ValueError):
    pass


def _sha256(data):
    return hashlib.sha256(data).hexdigest()


def _sri(data):
    return 'sha256-' + base64.b64encode(hashlib.sha256(data).digest()).decode()


def source_fingerprints(root):
    """Plan inputs exclude generated JS and package_config, which need pub get."""
    result = {}
    for name in SOURCE_INPUTS:
        path = Path(root) / name
        try:
            if path.is_symlink():
                link = os.readlink(path)
                result[name] = {'sha256': _sha256(os.fsencode(link)), 'link_target': link}
            else:
                result[name] = {'sha256': _sha256(path.read_bytes())}
        except OSError as error:
            raise PreparationFailure('BROWSER_SQLITE_SOURCE_MISSING:' + name) from error
    return result


def _runtime_sources(root):
    result = {}
    for name in _RUNTIME_INPUTS:
        path = root / name
        result[name] = {'sha256': _sha256(path.read_bytes())}
        if path.is_symlink():
            result[name]['link_target'] = os.readlink(path)
    link = root / PROBE_LINK
    expected = '../../' + SERVED
    if not link.is_symlink() or os.readlink(link) != expected:
        raise PreparationFailure('BROWSER_SQLITE_PROBE_LINK_CHANGED')
    result[PROBE_LINK] = {'link_target': expected}
    return result


def _bytes(path):
    if path.is_symlink():
        raise PreparationFailure('BROWSER_SQLITE_EVIDENCE_SYMLINK:' + path.name)
    return path.read_bytes()


def _evidence(path, data=None):
    return {'path': str(path), 'sha256': _sha256(_bytes(path) if data is None else data)}


def _process_evidence(process, directory, command, resolve=Path):
    # Validate the runner's original pre-spawn measurement; never measure again.
    from .execution_runner import _validate_execution_context

    if (type(process.get('exit_code')) is not int or process['exit_code'] != 0 or
            process.get('error') is not None or process.get('command') != command):
        raise PreparationFailure('BROWSER_SQLITE_PREPARATION_PROCESS_FAILED:' + str(process.get('exit_code')))
    expected_paths = {'process_receipt': directory / 'process.json',
                      'log': directory / 'prepare.log', 'machine': directory / 'prepare.log'}
    evidence = {}
    for key, path in expected_paths.items():
        item = _evidence(path, _bytes(Path(resolve(str(path)))))
        if process.get(key) != str(path) or process.get(key + '_sha256') != item['sha256']:
            raise PreparationFailure('BROWSER_SQLITE_PROCESS_EVIDENCE_MISMATCH:' + key)
        evidence[str(path)] = item
    saved = json.loads(_bytes(Path(resolve(str(expected_paths['process_receipt'])))))
    for key in ('command', 'exit_code', 'error', 'log', 'machine', 'log_sha256',
                'machine_sha256', 'execution_context'):
        if saved.get(key) != process.get(key):
            raise PreparationFailure('BROWSER_SQLITE_PROCESS_RECEIPT_MISMATCH:' + key)
    context = process.get('execution_context')
    if not isinstance(context, dict) or set(context) != {'path', 'sha256', 'value'}:
        raise PreparationFailure('BROWSER_SQLITE_EXECUTION_CONTEXT_MISSING')
    path = directory / 'execution-context.json'
    data = _bytes(Path(resolve(str(path))))
    if context['path'] != str(path) or context['sha256'] != _sha256(data) or json.loads(data) != context['value']:
        raise PreparationFailure('BROWSER_SQLITE_EXECUTION_CONTEXT_MISMATCH')
    _validate_execution_context(context['value'])
    evidence[str(path)] = _evidence(path, data)
    return list(evidence.values())


def prepare(root, env, output, execute_process):
    """Compile via the existing script, then bind current sources and real bytes."""
    root = Path(root).resolve()
    directory = Path(output).resolve() / 'browser-sqlite/preparation'
    runtime_env = dict(env, CI='true', FLUTTER_SUPPRESS_ANALYTICS='true')
    try:
        before = source_fingerprints(root)
        runtime_before = _runtime_sources(root)
        command = ['bash', str(root / SCRIPT), '--browser-sqlite-probe', str(directory)]
        process = execute_process(command, runtime_env, directory, cwd=root, timeout=210,
                                  log_path=directory / 'prepare.log')
        evidence = _process_evidence(process, directory, command)
        raw = {name: _bytes(directory / name) for name in (
            'defines.json', 'receipt.json', 'compile.log', 'browser_sqlite_bridge_probe.js')}
        receipt, defines = json.loads(raw['receipt.json']), json.loads(raw['defines.json'])
        if (type(receipt.get('schema_version')) is not int or receipt['schema_version'] != 1 or
                receipt.get('status') != 'READY' or type(receipt.get('exit_code')) is not int or
                receipt['exit_code'] != 0 or receipt.get('served_path') != SERVED):
            raise PreparationFailure('BROWSER_SQLITE_PREPARATION_NOT_READY')
        if (before != source_fingerprints(root) or runtime_before != _runtime_sources(root) or
                receipt.get('sources') != runtime_before):
            raise PreparationFailure('BROWSER_SQLITE_PREPARATION_SOURCES_MISMATCH')
        compiler = receipt['compiler']
        dart = shutil.which('dart', path=runtime_env.get('PATH', os.defpath))
        if (not dart or compiler.get('executable') != dart or
                not isinstance(compiler.get('version'), str) or not compiler['version'].strip() or
                compiler.get('sha256') != _sha256((root / dart).read_bytes())):
            raise PreparationFailure('BROWSER_SQLITE_COMPILER_MISMATCH')
        compiled_command = receipt.get('command')
        if (not isinstance(compiled_command, list) or len(compiled_command) != 8 or
                compiled_command[:6] != [dart, 'compile', 'js', '--no-source-maps', '-O1', '-o'] or
                compiled_command[-1] != PROBE):
            raise PreparationFailure('BROWSER_SQLITE_COMPILE_COMMAND_MISMATCH')
        compiled = Path(compiled_command[6])
        if (not compiled.is_absolute() or compiled.name != 'browser_sqlite_bridge_probe.js' or
                not compiled.parent.name.startswith('browser-sqlite-') or
                compiled.parent.parent != root / '.dart_tool'):
            raise PreparationFailure('BROWSER_SQLITE_COMPILE_OUTPUT_MISMATCH')
        javascript = raw['browser_sqlite_bridge_probe.js']
        artifacts = {name: _sha256(raw[name]) for name in ('browser_sqlite_bridge_probe.js', 'compile.log')}
        if not javascript or receipt.get('artifacts') != artifacts or _bytes(root / SERVED) != javascript:
            raise PreparationFailure('BROWSER_SQLITE_COMPILED_BYTES_MISMATCH')
        expected = {'BROWSER_SQLITE_PROBE_SRI': _sri(javascript),
                    'BROWSER_SQLITE_PREPARATION_SHA256': _sha256(raw['receipt.json']),
                    'STARTUP_BUSY_COUNTER_SRI': _sri((root / COUNTER).read_bytes())}
        if (defines != expected or receipt.get('probe_sri') != expected['BROWSER_SQLITE_PROBE_SRI'] or
                receipt.get('counter_sri') != expected['STARTUP_BUSY_COUNTER_SRI']):
            raise PreparationFailure('BROWSER_SQLITE_DEFINES_OR_SRI_MISMATCH')
        evidence.extend(_evidence(directory / name, data) for name, data in raw.items())
        binding = {'schema_version': 1, 'files': {Path(item['path']).name: item for item in evidence},
                   'defines': defines, 'served_sha256': _sha256(javascript)}
        return {'defines': defines, 'evidence': evidence, 'served_sha256': _sha256(javascript),
                'binding': binding}
    except PreparationFailure:
        raise
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        raise PreparationFailure('BROWSER_SQLITE_PREPARATION_INVALID:' + str(error)) from error


def validate_preparation_binding(instance, meta, related, command, process_receipt):
    """Require the complete per-attempt preparation, even without file access."""
    if instance.get('target') not in TARGETS:
        if meta is not None:
            raise PreparationFailure(_BINDING_ERROR)
        return
    if (instance.get('platform') != 'web' or not isinstance(meta, dict) or
            set(meta) != {'schema_version', 'files', 'defines', 'served_sha256', 'served_unchanged'} or
            type(meta['schema_version']) is not int or meta['schema_version'] != 1 or
            not isinstance(meta['files'], dict) or set(meta['files']) != EVIDENCE_NAMES or
            not isinstance(meta['defines'], dict) or set(meta['defines']) != DEFINE_NAMES or
            not isinstance(related, list) or not isinstance(command, list) or
            not all(isinstance(arg, str) for arg in command) or
            not isinstance(process_receipt, str) or not Path(process_receipt).is_absolute()):
        raise PreparationFailure(_BINDING_ERROR)
    directory = Path(process_receipt).parent / 'browser-sqlite/preparation'
    for name, item in meta['files'].items():
        if (not isinstance(item, dict) or set(item) != {'path', 'sha256'} or
                item['path'] != str(directory / name) or not isinstance(item['sha256'], str) or
                not re.fullmatch(r'[0-9a-f]{64}', item['sha256']) or related.count(item) != 1):
            raise PreparationFailure(_BINDING_ERROR)
    defines, files = meta['defines'], meta['files']
    js_sha = files['browser_sqlite_bridge_probe.js']['sha256']
    if (meta['served_sha256'] != js_sha or
            defines['BROWSER_SQLITE_PREPARATION_SHA256'] != files['receipt.json']['sha256'] or
            defines['BROWSER_SQLITE_PROBE_SRI'] != 'sha256-' + base64.b64encode(bytes.fromhex(js_sha)).decode() or
            not isinstance(defines['STARTUP_BUSY_COUNTER_SRI'], str) or
            not re.fullmatch(r'sha256-[A-Za-z0-9+/]{43}=', defines['STARTUP_BUSY_COUNTER_SRI'])):
        raise PreparationFailure(_BINDING_ERROR)
    for name, value in defines.items():
        prefix = '--dart-define=' + name + '='
        if [arg for arg in command if arg.startswith(prefix)] != [prefix + value]:
            raise PreparationFailure(_BINDING_ERROR)
    if meta['served_unchanged'] is not True:
        raise PreparationFailure('BROWSER_SQLITE_PREPARED_BYTES_CHANGED')


def validate_preparation_evidence(instance, meta, related, command, process_receipt, resolve):
    """Replay downloaded preparation without reading the worker's SDK or sources."""
    validate_preparation_binding(instance, meta, related, command, process_receipt)
    if instance.get('target') not in TARGETS:
        return
    try:
        files = meta['files']
        raw = {name: _bytes(Path(resolve(item['path']))) for name, item in files.items()}
        if any(_sha256(raw[name]) != item['sha256'] for name, item in files.items()):
            raise PreparationFailure('BROWSER_SQLITE_PREPARATION_DIGEST_MISMATCH')
        receipt, defines = json.loads(raw['receipt.json']), json.loads(raw['defines.json'])
        if (not isinstance(receipt, dict) or type(receipt.get('schema_version')) is not int or
                receipt['schema_version'] != 1 or receipt.get('status') != 'READY' or
                type(receipt.get('exit_code')) is not int or receipt['exit_code'] != 0 or
                receipt.get('served_path') != SERVED):
            raise PreparationFailure('BROWSER_SQLITE_PREPARATION_NOT_READY')
        sources = receipt.get('sources')
        if not isinstance(sources, dict) or set(sources) != {*_RUNTIME_INPUTS, PROBE_LINK}:
            raise PreparationFailure('BROWSER_SQLITE_PREPARATION_SOURCES_MISMATCH')
        for name in _RUNTIME_INPUTS:
            item = sources[name]
            if (not isinstance(item, dict) or set(item) not in ({'sha256'}, {'sha256', 'link_target'}) or
                    not isinstance(item.get('sha256'), str) or not re.fullmatch(r'[0-9a-f]{64}', item['sha256']) or
                    ('link_target' in item and not isinstance(item['link_target'], str))):
                raise PreparationFailure('BROWSER_SQLITE_PREPARATION_SOURCES_MISMATCH')
        if sources[PROBE_LINK] != {'link_target': '../../' + SERVED}:
            raise PreparationFailure('BROWSER_SQLITE_PROBE_LINK_CHANGED')
        expected = {'BROWSER_SQLITE_PROBE_SRI': _sri(raw['browser_sqlite_bridge_probe.js']),
                    'BROWSER_SQLITE_PREPARATION_SHA256': _sha256(raw['receipt.json']),
                    'STARTUP_BUSY_COUNTER_SRI': 'sha256-' + base64.b64encode(
                        bytes.fromhex(sources[COUNTER]['sha256'])).decode()}
        if (not raw['browser_sqlite_bridge_probe.js'] or defines != expected or meta['defines'] != expected or
                receipt.get('probe_sri') != expected['BROWSER_SQLITE_PROBE_SRI'] or
                receipt.get('counter_sri') != expected['STARTUP_BUSY_COUNTER_SRI'] or
                receipt.get('artifacts') != {name: files[name]['sha256'] for name in
                    ('browser_sqlite_bridge_probe.js', 'compile.log')}):
            raise PreparationFailure('BROWSER_SQLITE_DEFINES_OR_SRI_MISMATCH')
        process = json.loads(raw['process.json'])
        directory = Path(files['process.json']['path']).parent
        prepare_command = process.get('command')
        if (not isinstance(prepare_command, list) or len(prepare_command) != 4 or
                not all(isinstance(arg, str) for arg in prepare_command) or
                not Path(prepare_command[1]).is_absolute() or
                not prepare_command[1].endswith('/' + SCRIPT)):
            raise PreparationFailure('BROWSER_SQLITE_PREPARATION_COMMAND_MISMATCH')
        source_root = Path(prepare_command[1]).parents[2]
        expected_command = ['bash', str(source_root / SCRIPT), '--browser-sqlite-probe', str(directory)]
        process.update(process_receipt=files['process.json']['path'],
                       process_receipt_sha256=files['process.json']['sha256'])
        _process_evidence(process, directory, expected_command, resolve)
        compiler, compiled_command = receipt.get('compiler'), receipt.get('command')
        if (not isinstance(compiler, dict) or not isinstance(compiler.get('executable'), str) or
                not compiler['executable'] or not isinstance(compiler.get('version'), str) or
                not compiler['version'].strip() or not isinstance(compiler.get('sha256'), str) or
                not re.fullmatch(r'[0-9a-f]{64}', compiler['sha256']) or
                not isinstance(compiled_command, list) or len(compiled_command) != 8 or
                not all(isinstance(arg, str) for arg in compiled_command) or
                compiled_command[:6] != [compiler['executable'], 'compile', 'js', '--no-source-maps', '-O1', '-o'] or
                compiled_command[-1] != PROBE):
            raise PreparationFailure('BROWSER_SQLITE_COMPILE_COMMAND_MISMATCH')
        compiled = Path(compiled_command[6])
        if (compiled.name != 'browser_sqlite_bridge_probe.js' or
                not compiled.parent.name.startswith('browser-sqlite-') or
                compiled.parent.parent != source_root / '.dart_tool'):
            raise PreparationFailure('BROWSER_SQLITE_COMPILE_OUTPUT_MISMATCH')
    except PreparationFailure:
        raise
    except (OSError, ValueError, KeyError, TypeError, AttributeError) as error:
        raise PreparationFailure(_BINDING_ERROR + ':' + str(error)) from error


def served_unchanged(root, prepared):
    try:
        root = Path(root)
        link = root / PROBE_LINK
        return (link.is_symlink() and os.readlink(link) == '../../' + SERVED and
                _sha256(_bytes(root / SERVED)) == prepared['served_sha256'])
    except (OSError, ValueError, KeyError, TypeError):
        return False
