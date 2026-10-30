import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_action_confirmation.dart';
import 'package:imboy/modules/customer_service/presentation/cs_session_attachment_preparation.dart';

import 'cs_session_action_confirmation_test.dart' show ActionApi, flow, mount;

final class SyntheticPickedFile extends PlatformFile {
  @override
  String get name => 'synthetic.txt';
  @override
  Uri get uri => Uri.file('/synthetic.txt');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final delayedPicker in [true, false]) {
    testWidgets(
      'delayed ${delayedPicker ? 'picker' : 'head'} cannot resume upload while CAS intent is locked',
      (tester) async {
        final context = await mount(tester), api = ActionApi();
        final f = flow(api), actions = CsSessionActionConfirmation(api: api);
        final picker = Completer<List<PlatformFile>>(),
            head = Completer<Uint8List>();
        var headCalls = 0, byteCalls = 0;
        final preparation = CsSessionAttachmentPreparation(
          pickFiles: () => picker.future,
          readLength: (File _) async => 1,
          readHead: (File _) {
            headCalls++;
            return head.future;
          },
          readBytes: (File _) async {
            byteCalls++;
            return Uint8List(1);
          },
        );
        final pending = preparation.prepare(
          canWrite: () => !actions.busy && !f.readRevoked && f.machine.canSend,
        );
        if (!delayedPicker) {
          picker.complete([SyntheticPickedFile()]);
          await tester.pump();
        }
        final close = actions.close(
          context: context,
          flow: f,
          isCurrent: () => true,
          risks: () => const CsActionRisks(),
        );
        await tester.pumpAndSettle();
        if (delayedPicker) {
          picker.complete([SyntheticPickedFile()]);
        } else {
          head.complete(Uint8List.fromList([65]));
        }
        expect(await pending, isNull);
        expect(headCalls, delayedPicker ? 0 : 1);
        expect(byteCalls, 0);
        expect(api.writes, 0);
        actions.invalidate();
        await tester.pumpAndSettle();
        await close;
        actions.dispose();
        f.dispose();
      },
    );
  }
}
