import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_link_target_page.dart';
import 'package:imboy/service/channel_service.dart';
import 'package:imboy/store/model/channel_model.dart';

class _Service extends Fake implements ChannelService {
  final requests = <String, Completer<ChannelModel?>>{};
  final guards = <String, bool Function()>{};
  @override
  Future<ChannelModel?> refreshChannel(
    String channelId, {
    bool Function()? isCurrent,
  }) {
    guards[channelId] = isCurrent!;
    return (requests[channelId] = Completer<ChannelModel?>()).future;
  }
}

void main() {
  testWidgets('链接页复用时旧请求失效并加载新目标', (tester) async {
    final service = _Service();
    var id = '41';
    late StateSetter change;
    await tester.pumpWidget(
      TranslationProvider(
        child: ProviderScope(
          overrides: [channelServiceProvider.overrideWithValue(service)],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                change = setState;
                return ChannelLinkTargetPage(channelId: id);
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(service.guards['41']!(), isTrue);
    change(() => id = '42');
    await tester.pump();
    expect(service.guards['41']!(), isFalse);
    expect(service.guards['42']!(), isTrue);
    service.requests['42']!.complete(null);
    await tester.pumpAndSettle();
    expect(find.text(t.common.loadError), findsOneWidget);
    service.requests['41']!.complete(
      ChannelModel(
        id: 41,
        name: 'old',
        creatorId: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('old'), findsNothing);
    expect(find.text(t.common.loadError), findsOneWidget);
  });
}
