#!/usr/bin/env python3
"""Execute the real Android repository configuration against isolated Maven fixtures."""
import argparse
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import threading
import urllib.parse
import zipfile


ROOT = Path(__file__).resolve().parents[2]
PROPERTY = 'ORG_GRADLE_PROJECT_imboyUseMavenMirror'
LINT_PATH = 'com/android/tools/lint/lint-typedef-remover/31.5.1/'
INIT_SCRIPT = '''
import org.gradle.api.artifacts.repositories.MavenArtifactRepository
import groovy.json.JsonOutput

def observe = { repositories, scope ->
    repositories.all { repository ->
        if (!(repository instanceof MavenArtifactRepository)) {
            throw new GradleException("Unexpected repository type in " + scope)
        }
        def original = repository.url
        def record = [scope: scope, url: original.toString()]
        new File(System.getenv('IMBOY_PROBE_REPOSITORIES')).append(JsonOutput.toJson(record) + '\\n')
        if (original.scheme == 'file') return
        def host = original.host
        def kind = host == 'maven.aliyun.com' ? 'mirror' : 'official'
        if (!(host in ['maven.aliyun.com', 'dl.google.com', 'repo.maven.apache.org', 'plugins.gradle.org'])) {
            throw new GradleException("Unexpected external repository: " + original)
        }
        repository.url = uri(System.getenv('IMBOY_PROBE_ENDPOINT') + '/' + kind + '/')
        repository.allowInsecureProtocol = true // Synthetic loopback repositories only.
    }
}
gradle.beforeSettings { settings -> observe(settings.pluginManagement.repositories, 'settings') }
gradle.beforeProject { project ->
    observe(project.repositories, 'project:' + project.path)
    observe(project.buildscript.repositories, 'buildscript:' + project.path)
}
'''
CHILD_SCRIPT = '''
// Preserve jpush_flutter 3.5.9's failing AGP classpath dependency and repository order.
buildscript {
    repositories { mavenCentral(); google() }
    dependencies { classpath("com.android.tools.build:gradle:8.5.1") }
}
val probe = configurations.create("repositoryProbe")
dependencies.add(probe.name, "fixture:app-library:1")
tasks.register("checkRepositories") {
    doLast {
        check(probe.files.single().name == "app-library-1.jar")
        check(buildscript.configurations.getByName("classpath").files.any {
            it.name == "lint-typedef-remover-31.5.1.jar"
        })
        println("IMBOY_REPOSITORY_PROBE_OK")
    }
}
'''


def find_gradle(specified):
    properties = (ROOT / 'android/gradle/wrapper/gradle-wrapper.properties').read_text()
    version = re.search(r'/gradle-([0-9][\w.\-]*?)-(?:all|bin)\.zip', properties)
    if not version:
        raise RuntimeError('Cannot determine the pinned Gradle version')
    version = version.group(1)
    if specified:
        candidate = Path(shutil.which(specified) or specified).resolve()
        candidates = [candidate]
    else:
        homes = [Path(os.environ.get('GRADLE_USER_HOME', Path.home() / '.gradle')),
                 Path.home() / '.gradle']
        candidates = sorted({p for home in homes for p in home.glob(
            f'wrapper/dists/gradle-{version}-*/*/gradle-{version}/bin/gradle')})
    for binary in candidates:
        distribution = binary.resolve().parent.parent
        if binary.is_file() and (distribution / f'lib/gradle-core-api-{version}.jar').is_file():
            return binary.resolve(), distribution
    raise RuntimeError(f'Installed Gradle {version} is required; pass --gradle or populate the wrapper cache. No download or skip was attempted.')


def jar_bytes(entries):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, 'w', compression=zipfile.ZIP_DEFLATED) as jar:
        for name, content in entries.items():
            jar.writestr(name, content)
    return buffer.getvalue()


def maven_files(work, distribution, settings, build, logs):
    resources = {}

    def module(group, name, version, jar=None, dependencies=()):
        base = f'{group.replace(".", "/")}/{name}/{version}/{name}-{version}'
        deps = ''.join(f'<dependency><groupId>{g}</groupId><artifactId>{a}</artifactId><version>{v}</version></dependency>'
                       for g, a, v in dependencies)
        pom = (f'<project><modelVersion>4.0.0</modelVersion><groupId>{group}</groupId>'
               f'<artifactId>{name}</artifactId><version>{version}</version>'
               f'<packaging>{"pom" if jar is None else "jar"}</packaging>'
               f'<dependencies>{deps}</dependencies></project>').encode()
        resources[base + '.pom'] = pom
        if jar is not None:
            resources[base + '.jar'] = jar

    plugins = re.findall(r'id\("([^"]+)"\) version "([^"]+)"', settings)
    expected = {'dev.flutter.flutter-plugin-loader', 'com.android.application', 'org.jetbrains.kotlin.android'}
    if {name for name, _ in plugins} != expected:
        raise RuntimeError('Update fixture coverage for the actual settings plugin IDs')
    classes = work / 'plugin-classes'
    classes.mkdir()
    source = work / 'NoopPlugins.groovy'
    source.write_text('package fixture\n' + '\n'.join(
        f'class Noop{i} implements org.gradle.api.Plugin<Object> {{ void apply(Object target) {{}} }}'
        for i in range(len(plugins))))
    java = str(Path(os.environ['JAVA_HOME']) / 'bin/java') if os.environ.get('JAVA_HOME') else 'java'
    result = subprocess.run([java, '-cp', str(distribution / 'lib/*'),
                             'org.codehaus.groovy.tools.FileSystemCompiler', '-d', str(classes), str(source)],
                            capture_output=True, text=True, timeout=60)
    (logs / 'fixture-plugin-compilation.log').write_text(result.stdout + result.stderr)
    if result.returncode:
        raise RuntimeError('Synthetic plugin compilation failed; see fixture-plugin-compilation.log')
    for i, (plugin, version) in enumerate(plugins):
        entries = {str(p.relative_to(classes)): p.read_bytes() for p in classes.rglob('*.class')}
        entries[f'META-INF/gradle-plugins/{plugin}.properties'] = f'implementation-class=fixture.Noop{i}\n'.encode()
        module('fixture', f'plugin-{i}', '1', jar_bytes(entries))
        module(plugin, plugin + '.gradle.plugin', version,
               dependencies=[('fixture', f'plugin-{i}', '1')])
    empty = jar_bytes({'fixture.txt': b'Synthetic test artifact; no production code.\n'})
    firebase = re.search(r'classpath\("com\.google\.gms:google-services:([^"]+)"\)', build)
    if not firebase:
        raise RuntimeError('Firebase buildscript dependency was not found')
    module('com.google.gms', 'google-services', firebase.group(1), empty)
    module('com.android.tools.build', 'gradle', '8.5.1', empty,
           [('com.android.tools.lint', 'lint-typedef-remover', '31.5.1')])
    module('com.android.tools.lint', 'lint-typedef-remover', '31.5.1', empty)
    module('fixture', 'app-library', '1', empty)
    for name, data in list(resources.items()):
        for algorithm in ('sha1', 'sha256', 'md5'):
            resources[name + '.' + algorithm] = hashlib.new(algorithm, data).hexdigest().encode()
    return resources


def make_server(resources, requests, scenarios):
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def do_HEAD(self):
            self.respond(False)

        def do_GET(self):
            self.respond(True)

        def respond(self, body):
            parts = urllib.parse.urlsplit(self.path).path.lstrip('/').split('/', 2)
            scenario, kind, resource = parts if len(parts) == 3 else ('', '', '')
            failure = scenarios.get(scenario, {}).get('mirror_failure')
            if kind == 'mirror' and (failure == 'all' or (failure == 'lint' and resource.startswith(LINT_PATH))):
                status, data = 502, b'Synthetic Maven mirror outage\n'
            elif scenario in scenarios and kind in ('mirror', 'official') and resource in resources:
                status, data = 200, resources[resource]
            else:
                status, data = 404, b'Not found\n'
            requests.append({'scenario': scenario, 'kind': kind, 'resource': resource, 'status': status})
            self.send_response(status)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            if body:
                self.wfile.write(data)

    return ThreadingHTTPServer(('127.0.0.1', 0), Handler)


def run_scenario(name, options, work, logs, gradle, endpoint, settings, build, requests):
    directory = work / name / 'checkout/android'
    directory.mkdir(parents=True)
    sdk = work / name / 'flutter-sdk'
    included = sdk / 'packages/flutter_tools/gradle'
    included.mkdir(parents=True)
    (included / 'settings.gradle').write_text("rootProject.name = 'fixture-flutter-tools'\n")
    (directory / 'local.properties').write_text('flutter.sdk=' + sdk.as_posix() + '\n')
    (directory / 'settings.gradle.kts').write_text(settings + '\ninclude(":jpush_fixture")\n')
    (directory / 'build.gradle.kts').write_text(build)
    for child in ('app', 'jpush_fixture'):
        (directory / child).mkdir()
    (directory / 'app/build.gradle.kts').write_text('')
    (directory / 'app/google-services.json').write_text('{}\n')
    (directory / 'jpush_fixture/build.gradle.kts').write_text(CHILD_SCRIPT)
    init = directory / 'probe.init.gradle'
    init.write_text(INIT_SCRIPT)
    repositories = logs / (name + '-repositories.jsonl')
    repositories.write_text('')
    env = dict(os.environ, GRADLE_USER_HOME=str(work / name / 'gradle-home'),
               IMBOY_PROBE_REPOSITORIES=str(repositories), IMBOY_PROBE_ENDPOINT=endpoint + '/' + name)
    env.pop(PROPERTY, None)  # CI selects official mode; the default scenario must not inherit it.
    if options['mode'] is not None:
        env[PROPERTY] = options['mode']
    command = [str(gradle), '--no-daemon', '--max-workers=1', '--console=plain',
               '-Dorg.gradle.jvmargs=-Xmx512m -XX:MaxMetaspaceSize=384m',
               '-Dorg.gradle.internal.http.connectionTimeout=5000',
               '-Dorg.gradle.internal.http.socketTimeout=5000',
               '--init-script', str(init), ':jpush_fixture:checkRepositories']
    print(f'Checking {name} with an isolated Gradle home...', flush=True)
    log = logs / (name + '.log')
    with log.open('w') as output:
        result = subprocess.run(command, cwd=directory, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=300)
    text = log.read_text()
    seen = [r for r in requests if r['scenario'] == name]
    configured = [json.loads(line) for line in repositories.read_text().splitlines()]
    errors = []
    if options['success']:
        if result.returncode or 'IMBOY_REPOSITORY_PROBE_OK' not in text:
            errors.append('Gradle configuration or fixture dependency resolution failed')
        for scope in ('settings', 'buildscript::', 'project::', 'buildscript::jpush_fixture'):
            urls = [r['url'] for r in configured if r['scope'] == scope]
            if not urls:
                errors.append('Repository scope was not exercised: ' + scope)
            elif options['mode'] == 'false':
                if any('maven.aliyun.com' in url for url in urls):
                    errors.append('Official mode injected an Aliyun repository: ' + scope)
            elif 'maven.aliyun.com' not in urls[0]:
                errors.append('Default mirror priority was lost: ' + scope)
        if not any(r['resource'].startswith(LINT_PATH) and r['resource'].endswith('.jar')
                   and r['status'] == 200 for r in seen):
            errors.append('The historical lint dependency was not resolved')
        if options['mode'] == 'false' and any(r['kind'] == 'mirror' for r in seen):
            errors.append('Official mode contacted the failing mirror')
        if options['mode'] is None and not any(r['kind'] == 'mirror' for r in seen):
            errors.append('The default did not use mirrors')
    elif options['mirror_failure'] == 'lint':
        if result.returncode == 0 or 'lint-typedef-remover' not in text or '502' not in text:
            errors.append('The intentional jpush transitive mirror failure did not fail as expected')
        if not any(r['resource'].startswith(LINT_PATH) and r['status'] == 502 for r in seen):
            errors.append('The negative case did not reach the failing lint dependency')
    elif result.returncode == 0 or options['mode'] not in text or seen:
        errors.append('An invalid property did not fail before dependency resolution')
    summary = {'scenario': name, 'status': 'FAIL' if errors else 'PASS',
               'gradle_exit_code': result.returncode, 'request_count': len(seen),
               'mirror_requests': sum(r['kind'] == 'mirror' for r in seen),
               'errors': errors, 'log': str(log)}
    print(json.dumps(summary), flush=True)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--gradle', help='Installed binary matching android/gradle/wrapper/gradle-wrapper.properties')
    parser.add_argument('--artifact-dir', type=Path, help='Retain scenario logs, repository observations and HTTP requests')
    args = parser.parse_args()
    try:
        gradle, distribution = find_gradle(args.gradle)
        with tempfile.TemporaryDirectory(prefix='imboy-maven-policy-') as temporary:
            work = Path(temporary)
            logs = args.artifact_dir.resolve() if args.artifact_dir else work / 'logs'
            logs.mkdir(parents=True, exist_ok=True)
            settings = (ROOT / 'android/settings.gradle.kts').read_text()
            build = (ROOT / 'android/build.gradle.kts').read_text()
            resources = maven_files(work, distribution, settings, build, logs)
            scenarios = {
                'official': {'mode': 'false', 'mirror_failure': 'all', 'success': True},
                'default-mirror': {'mode': None, 'mirror_failure': None, 'success': True},
                'broken-mirror': {'mode': 'true', 'mirror_failure': 'lint', 'success': False},
                'invalid-mode': {'mode': 'invalid-fixture-value', 'mirror_failure': None, 'success': False},
            }
            requests, results = [], []
            server = make_server(resources, requests, scenarios)
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                endpoint = f'http://127.0.0.1:{server.server_port}'
                for name, options in scenarios.items():
                    results.append(run_scenario(name, options, work, logs, gradle, endpoint,
                                                settings, build, requests))
            finally:
                server.shutdown()
                server.server_close()
                thread.join()
                (logs / 'requests.json').write_text(json.dumps(requests, indent=2) + '\n')
                (logs / 'summary.json').write_text(json.dumps(results, indent=2) + '\n')
            return 0 if all(result['status'] == 'PASS' for result in results) else 1
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'ERROR: {error}', flush=True)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
