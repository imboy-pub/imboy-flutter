import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/capabilities/capability_locator.dart';
import 'package:imboy/capabilities/contracts/media_picker_capability.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/channel/channel_di_provider.dart';
import 'package:imboy/page/channel/channel_edit_page.dart';
import 'package:imboy/page/channel/channel_edit_avatar.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';

class _Api extends Mock implements ChannelApi {}

class _Picker extends Mock implements MediaPickerCapability {}

class _Context extends Fake implements BuildContext {}

ChannelModel _channel(String name, {int id = 1001}) => ChannelModel(
  id: id,
  name: name,
  description: '已有简介',
  creatorId: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  userRole: ChannelUserRole.creator,
);

Future<void> _pump(
  WidgetTester tester,
  ChannelApi api, {
  ChannelModel? channel,
  String channelId = '1001',
  Future<String?> Function(File, String)? upload,
  double width = 390,
  double textScale = 1,
  Brightness brightness = Brightness.light,
  ValueNotifier<String>? target,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    TranslationProvider(
      child: ProviderScope(
        overrides: [
          channelApiProvider.overrideWithValue(api),
          if (upload != null)
            channelEditAvatarUploadProvider.overrideWithValue(upload),
        ],
        child: MaterialApp(
          theme: ThemeData(brightness: brightness),
          builder: AppLoading.init(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => target == null
                        ? ChannelEditPage(
                            channelId: channelId,
                            channel: channel ?? _channel('缓存名称'),
                          )
                        : ValueListenableBuilder<String>(
                            valueListenable: target,
                            builder: (_, id, _) => ChannelEditPage(
                              channelId: id,
                              channel: _channel('频道$id', id: int.parse(id)),
                            ),
                          ),
                  ),
                ),
                child: const Text('进入编辑'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('进入编辑'));
  await tester.pumpAndSettle();
}

void main() {
  late _Api api;
  late _Picker picker;
  late Directory temp;

  setUpAll(() => registerFallbackValue(_Context()));

  setUp(() async {
    api = _Api();
    picker = _Picker();
    CapabilityLocator.I.register<MediaPickerCapability>(picker);
    temp = Directory.systemTemp.createTempSync('channel-avatar-recovery-');
    final file = File('${temp.path}/avatar.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
        ),
      );
    when(() => picker.pickSingle(any(), MediaType.image)).thenAnswer(
      (_) async => PickedMedia(path: file.path, type: MediaType.image),
    );
    await StorageService.to.setString(Keys.currentUid, 'uiux-channel-owner');
  });

  tearDown(() async {
    await AppLoading.dismiss(animation: false);
    await StorageService.to.remove(Keys.currentUid);
    temp.deleteSync(recursive: true);
  });

  testWidgets('缓存表单编辑后迟到的加载不能覆盖草稿', (tester) async {
    final response = Completer<ChannelModel?>();
    when(() => api.getChannel(any())).thenAnswer((_) => response.future);
    await _pump(tester, api);
    await tester.enterText(find.byType(TextFormField).first, '未保存名称 😀');
    response.complete(_channel('服务器名称'));
    await tester.pumpAndSettle();
    expect(find.text('未保存名称 😀'), findsOneWidget);
    expect(find.text('服务器名称'), findsNothing);
  });

  testWidgets('头像上传使用已解析真实ID而不是路由alias', (tester) async {
    final ids = <String>[];
    when(() => api.getChannel('owned-alias')).thenAnswer((_) async => null);
    when(() => api.getChannelByCustomId('owned-alias'))
        .thenAnswer((_) async => _channel('真实频道'));
    await _pump(
      tester,
      api,
      channelId: 'owned-alias',
      channel: _channel('旧缓存频道', id: 2002),
      upload: (_, id) async {
        ids.add(id);
        return null;
      },
    );
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.main.selectFromAlbum));
    await tester.pumpAndSettle();
    expect(ids, ['1001']);
    verify(() => api.getChannelByCustomId('owned-alias')).called(1);
    expect(find.text(t.channel.avatarNotUploaded), findsOneWidget);
  });

  testWidgets('旧账号迟到响应不能显示在当前编辑页', (tester) async {
    final response = Completer<ChannelModel?>();
    when(() => api.getChannel(any())).thenAnswer((_) => response.future);
    await _pump(tester, api);
    await StorageService.to.setString(Keys.currentUid, 'uiux-other-owner');
    response.complete(_channel('旧账号私有频道'));
    await tester.pumpAndSettle();
    expect(find.text('旧账号私有频道'), findsNothing);
  });

  testWidgets('同一帧连续保存只有一次命令且失败保留草稿', (tester) async {
    final response = Completer<ChannelModel?>();
    var writes = 0;
    when(() => api.getChannel(any())).thenAnswer((_) async => _channel('缓存名称'));
    when(
      () => api.updateChannel(
        any(),
        name: any(named: 'name'),
        description: any(named: 'description'),
        avatar: any(named: 'avatar'),
        tags: any(named: 'tags'),
        customId: any(named: 'customId'),
      ),
    ).thenAnswer((_) {
      writes++;
      return response.future;
    });
    await _pump(tester, api);
    await tester.enterText(find.byType(TextFormField).first, '失败仍保留的草稿');
    await tester.tap(find.text(t.common.save));
    await tester.tap(find.text(t.common.save));
    final observedWrites = writes;
    response.complete(null);
    await tester.pumpAndSettle();
    expect(observedWrites, 1);
    expect(find.text('失败仍保留的草稿'), findsOneWidget);
  });

  testWidgets('系统返回保护未保存修改，取消后留在编辑页', (tester) async {
    when(() => api.getChannel(any())).thenAnswer((_) async => _channel('缓存名称'));
    await _pump(tester, api);
    await tester.enterText(find.byType(TextFormField).first, '未保存草稿');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text(t.common.cancel));
    await tester.pumpAndSettle();
    expect(find.text('未保存草稿'), findsOneWidget);
  });
  testWidgets('头像上传失败禁用保存，重试成功后保存新地址', (tester) async {
    var attempts = 0;
    String? savedAvatar;
    when(() => api.getChannel(any())).thenAnswer((_) async => _channel('缓存名称'));
    when(
      () => api.updateChannel(
        any(),
        name: any(named: 'name'),
        description: any(named: 'description'),
        avatar: any(named: 'avatar'),
        tags: any(named: 'tags'),
        customId: any(named: 'customId'),
      ),
    ).thenAnswer((call) async {
      savedAvatar = call.namedArguments[#avatar] as String?;
      return null;
    });
    await _pump(
      tester,
      api,
      upload: (_, _) async => ++attempts == 1 ? null : 'avatar/new.png',
    );
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.main.selectFromAlbum));
    await tester.pumpAndSettle();
    expect(find.text(t.channel.avatarNotUploaded), findsOneWidget);
    final save = find.ancestor(
      of: find.text(t.common.save),
      matching: find.byType(CupertinoButton),
    );
    expect(tester.widget<CupertinoButton>(save.first).onPressed, isNull);
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-retry')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text(t.channel.avatarNotUploaded), findsNothing);
    await tester.tap(find.text(t.common.save));
    await tester.pumpAndSettle();
    expect(savedAvatar, 'avatar/new.png');
  });

  testWidgets('同一帧重复重试头像只发起一次上传', (tester) async {
    var attempts = 0;
    final retry = Completer<String?>();
    when(() => api.getChannel(any())).thenAnswer((_) async => _channel('缓存名称'));
    await _pump(
      tester,
      api,
      upload: (_, _) {
        attempts++;
        return attempts == 1 ? Future.value(null) : retry.future;
      },
    );
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.main.selectFromAlbum));
    await tester.pumpAndSettle();
    final action = tester
        .widget<CupertinoButton>(
          find.byKey(const ValueKey('channel-edit-avatar-retry')),
        )
        .onPressed!;
    action();
    action();
    final observed = attempts;
    retry.complete(null);
    await tester.pumpAndSettle();
    expect(observed, 2, reason: '一次初次上传与一次重试');
  });

  testWidgets('上传失败可还原预览并取消未同步状态', (tester) async {
    when(() => api.getChannel(any())).thenAnswer((_) async => _channel('缓存名称'));
    await _pump(tester, api, upload: (_, _) async => null);
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.main.selectFromAlbum));
    await tester.pumpAndSettle();
    expect(find.text(t.channel.avatarNotUploaded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-restore')));
    await tester.pumpAndSettle();
    expect(find.text(t.channel.avatarNotUploaded), findsNothing);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isNull,
    );
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ChannelEditPage), findsNothing);
  });

  testWidgets('未保存修改的返回手势也必须确认，确认后离开', (tester) async {
    when(() => api.getChannel(any())).thenAnswer((_) async => _channel('缓存名称'));
    await _pump(tester, api);
    await tester.enterText(find.byType(TextFormField).first, '手势保护草稿');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.dragFrom(const Offset(1, 400), const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoAlertDialog), findsOneWidget);
    await tester.tap(find.text(t.common.confirm));
    await tester.pumpAndSettle();
    expect(find.byType(ChannelEditPage), findsNothing);
  });
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5, 2.0]) {
      for (final brightness in Brightness.values) {
        testWidgets(
          '${width.toInt()}宽${(scale * 100).toInt()}%字体 ${brightness.name} 头像失败动作可见可点',
          (tester) async {
            final semantics = tester.ensureSemantics();
            try {
              when(() => api.getChannel(any()))
                  .thenAnswer((_) async => _channel('缓存名称'));
              await _pump(
                tester,
                api,
                upload: (_, _) async => null,
                width: width,
                textScale: scale,
                brightness: brightness,
              );
              await tester.tap(
                find.byKey(const ValueKey('channel-edit-avatar-picker')),
              );
              await tester.pumpAndSettle();
              await tester.tap(find.text(t.main.selectFromAlbum));
              await tester.pumpAndSettle();
              expect(find.text(t.channel.avatarNotUploaded), findsOneWidget);
              for (final key in [
                'channel-edit-avatar-retry',
                'channel-edit-avatar-restore',
              ]) {
                final button = find.byKey(ValueKey(key));
                await tester.ensureVisible(button);
                await tester.pumpAndSettle();
                expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
                expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
                final label = key.endsWith('retry')
                    ? t.common.buttonRetry
                    : t.channel.restoreAvatar;
                final buttonText = find.descendant(
                  of: button,
                  matching: find.text(label),
                );
                expect(
                  tester.getSemantics(buttonText).getSemanticsData().label,
                  contains(label),
                );
              }
              expect(tester.takeException(), isNull);
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
  testWidgets('切换编辑对象时旧上传不锁住新对象也不污染其头像', (tester) async {
    final target = ValueNotifier('1001');
    addTearDown(target.dispose);
    final upload = Completer<String?>();
    when(() => api.getChannel(any())).thenAnswer((call) async {
      final id = call.positionalArguments.first as String;
      return _channel('频道$id', id: int.parse(id));
    });
    await _pump(tester, api, target: target, upload: (_, _) => upload.future);
    await tester.tap(find.byKey(const ValueKey('channel-edit-avatar-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.main.selectFromAlbum));
    await tester.pump(const Duration(seconds: 1));
    target.value = '1002';
    await tester.pump();
    final canPick = tester
        .widget<CupertinoButton>(
          find.byKey(const ValueKey('channel-edit-avatar-picker')),
        )
        .onPressed;
    upload.complete('avatar/old-target.png');
    await tester.pumpAndSettle();
    expect(find.text('频道1002'), findsOneWidget);
    expect(canPick, isNotNull);
    expect(
      tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundImage,
      isNull,
    );
  });
}
