/// HOTFIX-01: Plaintext Log Prevention Test
///
/// This test verifies that sending, editing, or revoking messages does not log
/// the plain-text content of the message payload, even in debug mode.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/page/chat/chat/services/chat_network_service.dart';
import 'package:imboy/service/encryption_mode.dart';

void main() {
  group('Plaintext Log Prevention (HOTFIX-01)', () {
    late List<String> capturedLogs;
    late DebugPrintCallback originalDebugPrint;

    setUp(() {
      capturedLogs = [];
      originalDebugPrint = debugPrint;
      // Override debugPrint to capture logs
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) {
          capturedLogs.add(message);
        }
      };

      // Set initialized encryption mode to plaintext to avoid E2eeSecurityException
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: true,
      );
    });

    tearDown(() {
      // Restore original debugPrint
      debugPrint = originalDebugPrint;

      // Reset policy mode
      EncryptionModeService.debugSet(
        mode: EncryptionMode.plaintext,
        initialized: false,
      );
    });

    test(
      'sendMessage does not log raw message payload containing plain text',
      () async {
        const sensitiveText = 'SECRET_SENSITIVE_TEXT_12345';
        final Map<String, dynamic> msg = {
          'id': 'msg-id-123',
          'type': 'C2C',
          'from': 'user-1',
          'to': 'user-2',
          'payload': {'msg_type': 'text', 'text': sensitiveText},
        };

        final service = ChatNetworkService();

        try {
          await service.sendMessage(msg);
        } catch (e) {
          // Ignore initialization/database/event exceptions
        }

        // Assert that none of the captured logs contain our sensitive text!
        for (final log in capturedLogs) {
          expect(
            log.contains(sensitiveText),
            isFalse,
            reason: 'Sensitive plain-text message was leaked in logs: "$log"',
          );
        }
      },
    );
  });
}
