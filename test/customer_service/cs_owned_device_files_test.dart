import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/customer_service/cs_owned_device_files.dart';
import '../../integration_test/customer_service/cs_integration_fixture.dart';
import 'cs_integration_admission_test.dart' show validFixture;

late Directory root;
late CsOwnedDeviceFiles custody;

void main() {
  _registerFilesystemFixture();
  _registerValidInput();
  _registerSymlinkInput();
  _registerDirectoryAlias();
  _registerExistingOutput();
  _registerChangedContent();
  _registerSavedBinding();
  _registerSafeError();
}

void _registerFilesystemFixture() {
  setUp(() async {
    final temp = Directory(await Directory.systemTemp.resolveSymbolicLinks());
    root = await temp.createTemp('cx-owned-files-');
    await Directory('${root.path}/input').create();
    await Directory('${root.path}/output').create();
    await File('${root.path}/input/owned.txt').writeAsString('owned-bytes!');
    final values = validFixture()
      ..['ASSET_SHA'] = sha256.convert('owned-bytes!'.codeUnits).toString();
    custody = CsOwnedDeviceFiles.forTest(
      root,
      CsIntegrationFixture.parse(values),
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
}

void _registerValidInput() {
  test(
    'canonical owned input is bounded, digest bound and immutable',
    () async {
      final bytes = await custody.readInput();
      expect(bytes, 'owned-bytes!'.codeUnits);
      expect(() => bytes[0] = 0, throwsUnsupportedError);
      await custody.assertOutputAbsent();
    },
  );
}

void _registerSymlinkInput() {
  test('symlink input is refused without reading its target', () async {
    final input = File('${root.path}/input/owned.txt');
    await input.delete();
    await Link(input.path).create('${root.path}/output/private-synthetic.txt');
    expect(custody.readInput(), throwsA(isA<CsOwnedFileRefused>()));
  });
}

void _registerDirectoryAlias() {
  test('symlink subdirectory and aliased selected input fail closed', () async {
    final input = Directory('${root.path}/input');
    await input.delete(recursive: true);
    await Link(input.path).create('${root.path}/output');
    expect(custody.readInput(), throwsA(isA<CsOwnedFileRefused>()));
    expect(
      custody.readPicked(File('${root.path}/input/../output/owned.txt')),
      throwsA(isA<CsOwnedFileRefused>()),
    );
  });
}

void _registerExistingOutput() {
  test('existing or symlink save output cannot be reused', () async {
    final output = File('${root.path}/output/owned.txt');
    await output.writeAsString('owned-bytes!');
    await expectLater(
      custody.assertOutputAbsent(),
      throwsA(isA<CsOwnedFileRefused>()),
    );
    await output.delete();
    await Link(output.path).create('${root.path}/input/owned.txt');
    await expectLater(
      custody.assertOutputAbsent(),
      throwsA(isA<CsOwnedFileRefused>()),
    );
    expect(custody.readSaved(), throwsA(isA<CsOwnedFileRefused>()));
  });
}

void _registerChangedContent() {
  test(
    'changed size and digest refuse rather than exposing upload bytes',
    () async {
      final input = File('${root.path}/input/owned.txt');
      await input.writeAsString('other-bytes!');
      expect(custody.readInput(), throwsA(isA<CsOwnedFileRefused>()));
      await input.writeAsString('too-short');
      expect(custody.readInput(), throwsA(isA<CsOwnedFileRefused>()));
    },
  );
}

void _registerSavedBinding() {
  test(
    'saved bytes need canonical target and matching complete digest',
    () async {
      final output = File('${root.path}/output/owned.txt');
      await output.writeAsString('owned-bytes!');
      expect(await custody.readSaved(), 'owned-bytes!'.codeUnits);
      expect(
        custody.verifySaveUri(Uri.file('${root.path}/input/owned.txt')),
        throwsA(isA<CsOwnedFileRefused>()),
      );
      expect(
        custody.verifySaveUri(
          Uri.parse('content://unbound-provider/document/unknown'),
        ),
        throwsA(isA<CsOwnedFileRefused>()),
      );
      await custody.verifySaveUri(Uri.file(output.path));
    },
  );
}

void _registerSafeError() {
  test(
    'filesystem refusal cannot disclose path or private exception',
    () async {
      try {
        await custody.readPicked(File('/private/synthetic-secret'));
      } on CsOwnedFileRefused catch (e) {
        expect(e.toString(), 'CS_OWNED_FILE_REFUSED');
      }
    },
  );
}
