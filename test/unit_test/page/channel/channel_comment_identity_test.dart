import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/widgets/channel_comment_tile.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/channel_comment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      Keys.currentUid: '9007199254740993',
    });
    await StorageService.init();
  });
  testWidgets('comment owner uses exact decimal identity', (tester) async {
    Widget tile(String uid) => TranslationProvider(
      child: MaterialApp(
        home: Scaffold(
          body: ChannelCommentTile(
            comment: ChannelCommentModel.fromJson({
              'id': '1',
              'channel_id': '2',
              'message_id': '3',
              'user_id': uid,
              'content': 'synthetic',
            }),
            onReply: () {},
            onToggleLike: () {},
            onDelete: () {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(tile('9007199254740993'));
    expect(find.byIcon(CupertinoIcons.delete), findsOneWidget);
    await tester.pumpWidget(tile('9007199254740992'));
    expect(find.byIcon(CupertinoIcons.delete), findsNothing);
  });
}
