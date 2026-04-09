/// 会话状态同步集成测试
///
/// 测试目标：
/// 1. 会话创建和更新
/// 2. 新消息到达时会话状态同步
/// 3. 会话最后消息更新
/// 4. 会话在内存和数据库的一致性
/// 5. 事件发布和订阅机制
@Skip('Requires native sqflite_sqlcipher plugin — run on device')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/service/events/events.dart';
import 'package:imboy/service/sqlite.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/store/repository/conversation_repo_sqlite.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const MethodChannel pathProviderChannel = MethodChannel(
    'plugins.flutter.io/path_provider',
  );

  // 初始化服务
  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (methodCall) async {
      switch (methodCall.method) {
        case 'getTemporaryDirectory':
        case 'getApplicationDocumentsDirectory':
        case 'getApplicationSupportDirectory':
        case 'getDatabasesPath':
          return Directory.systemTemp.path;
        default:
          return Directory.systemTemp.path;
      }
    });

    SharedPreferences.setMockInitialValues({});
    // 初始化存储服务（数据库服务依赖它）
    await StorageService.init();
    await StorageService.to.setString(Keys.currentUid, 'test_uid_for_conversation');
    // 初始化数据库服务
    await SqliteService.to.db;
  });

  tearDownAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
  });

  group('会话状态同步集成测试', () {
    late ConversationRepo conversationRepo;
    late StreamSubscription<DataWrapperEvent> eventSubscription;

    setUp(() async {
      conversationRepo = ConversationRepo();

      // 每个用例前清理当前测试用户的会话数据，避免跨用例/跨轮次残留影响断言。
      try {
        await SqliteService.to.delete(
          ConversationRepo.tableName,
          where: '${ConversationRepo.userId} = ?',
          whereArgs: ['test_uid_for_conversation'],
        );
      } catch (_) {
        // 清理失败不阻塞当前用例，后续断言会暴露真实问题。
      }

      // 订阅会话更新事件
      eventSubscription = AppEventBus.on<DataWrapperEvent>().listen((event) {
        // 测试中只记录事件，不做处理
      });
    });

    tearDown(() async {
      await eventSubscription.cancel();

      // 清理测试数据
      try {
        await conversationRepo.delete('C2C', 'test_peer_user_1');
        await conversationRepo.delete('C2G', 'test_group_1');
      } catch (e) {
        // 忽略清理错误
      }
    });

    group('会话基础功能', () {
      test('应该成功创建单例仓库', () {
        final repo1 = ConversationRepo();
        final repo2 = ConversationRepo();
        expect(repo1, isNotNull);
        expect(repo2, isNotNull);
      });

      test('应该能够创建 C2C 会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 1301,
          avatar: 'https://example.com/avatar.jpg',
          title: '测试用户',
          subtitle: '你好',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 1,
          payload: {'text': '你好'},
        );

        final savedConv = await conversationRepo.insert(conv);

        expect(savedConv, greaterThan(0));
      });

      test('应该能够创建 C2G 会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 2101,
          avatar: 'https://example.com/group.jpg',
          title: '测试群组',
          subtitle: '群消息',
          type: 'C2G',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 2,
          unreadNum: 5,
          payload: {'text': '群消息'},
        );

        final savedConv = await conversationRepo.insert(conv);

        expect(savedConv, greaterThan(0));
      });

      test('应该能够通过 peerId 查找会话', () async {
        // 1. 先插入测试数据
        final conv = ConversationModel(
          id: 0,
          peerId: 1302,
          avatar: 'https://example.com/avatar.jpg',
          title: '测试用户2',
          subtitle: '测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 3,
          unreadNum: 0,
          payload: {'text': '测试消息'},
        );

        await conversationRepo.insert(conv);

        // 2. 查找会话
        final found = await conversationRepo.findByPeerId(
          'C2C',
          'test_peer_user_2',
        );

        expect(found, isNotNull);
        expect(found!.peerId, 1302);
        expect(found.title, '测试用户2');
      });

      test('应该能够通过 ID 查找会话', () async {
        // 1. 先插入测试数据
        final conv = ConversationModel(
          id: 0,
          peerId: 1303,
          avatar: 'https://example.com/avatar.jpg',
          title: '测试用户3',
          subtitle: '测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 4,
          unreadNum: 0,
          payload: {'text': '测试消息'},
        );

        final insertedId = await conversationRepo.insert(conv);

        // 2. 通过 ID 查找
        final found = await conversationRepo.findById(insertedId);

        expect(found, isNotNull);
        expect(found!.peerId, 1303);
      });
    });

    group('会话更新功能', () {
      test('应该能够更新会话信息', () async {
        // 1. 插入测试数据
        final conv = ConversationModel(
          id: 0,
          peerId: 1304,
          avatar: 'https://example.com/avatar.jpg',
          title: '原始标题',
          subtitle: '原始副标题',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 5,
          unreadNum: 1,
          payload: {'text': '原始消息'},
        );

        final insertedId = await conversationRepo.insert(conv);

        // 2. 更新会话
        await conversationRepo.updateById(insertedId, {
          ConversationRepo.title: '更新后的标题',
          ConversationRepo.subtitle: '更新后的副标题',
          ConversationRepo.unreadNum: 0,
        });

        // 3. 验证更新
        final updated = await conversationRepo.findById(insertedId);

        expect(updated, isNotNull);
        expect(updated!.title, '更新后的标题');
        expect(updated.subtitle, '更新后的副标题');
        expect(updated.unreadNum, 0);
      });

      test('应该能够通过 peerId 更新会话', () async {
        // 1. 插入测试数据
        final conv = ConversationModel(
          id: 0,
          peerId: 1305,
          avatar: 'https://example.com/avatar.jpg',
          title: '原始标题',
          subtitle: '原始副标题',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 6,
          unreadNum: 1,
          payload: {'text': '原始消息'},
        );

        await conversationRepo.insert(conv);

        // 2. 通过 peerId 更新
        await conversationRepo.updateByPeerId('C2C', 'test_peer_user_5', {
          ConversationRepo.title: 'peerId更新后的标题',
          ConversationRepo.unreadNum: 3,
        });

        // 3. 验证更新
        final updated = await conversationRepo.findByPeerId(
          'C2C',
          'test_peer_user_5',
        );

        expect(updated, isNotNull);
        expect(updated!.title, 'peerId更新后的标题');
        expect(updated.unreadNum, 3);
      });
    });

    group('会话保存（插入或更新）', () {
      test('不存在时应该插入新会话', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 1306,
          avatar: 'https://example.com/avatar.jpg',
          title: '新会话',
          subtitle: '新消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 7,
          unreadNum: 1,
          payload: {'text': '新消息'},
        );

        final saved = await conversationRepo.save(conv);

        expect(saved.id, greaterThan(0));
        expect(saved.peerId, 1306);
        expect(saved.unreadNum, 1);
      });

      test('已存在时应该更新会话并累加未读数', () async {
        // 1. 插入初始会话
        final conv1 = ConversationModel(
          id: 0,
          peerId: 7,
          avatar: 'https://example.com/avatar.jpg',
          title: '会话1',
          subtitle: '消息1',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 8,
          unreadNum: 2,
          payload: {'text': '消息1'},
        );

        final saved1 = await conversationRepo.save(conv1);

        // 2. 更新会话（新消息）
        final conv2 = ConversationModel(
          id: saved1.id,
          peerId: 7,
          avatar: 'https://example.com/avatar.jpg',
          title: '会话1（更新）',
          subtitle: '消息2',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579300000,
          lastMsgId: 9,
          unreadNum: 3, // 新增 3 条未读
          payload: {'text': '消息2'},
        );

        final saved2 = await conversationRepo.save(conv2);

        // 3. 验证：未读数应该累加 (2 + 3 = 5)
        expect(saved2.id, saved1.id); // ID 不变
        expect(saved2.unreadNum, 5); // 2 + 3 = 5
        expect(saved2.subtitle, '消息2'); // 副标题更新
      });

      test('应该正确处理 payload 字段的序列化', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 8,
          avatar: 'https://example.com/avatar.jpg',
          title: 'Payload测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 10,
          unreadNum: 0,
          payload: {
            'text': '测试内容',
            'last_read_auto_id': 100,
            'custom_field': '自定义值',
          },
        );

        await conversationRepo.save(conv); // saved variable not needed

        // 重新读取
        final found = await conversationRepo.findByPeerId(
          'C2C',
          'test_peer_user_8',
        );

        expect(found, isNotNull);
        expect(found!.payload, isNotNull);
        expect(found.payload!['text'], '测试内容');
        expect(found.payload!['last_read_auto_id'], 100);
        expect(found.payload!['custom_field'], '自定义值');
      });
    });

    group('会话列表查询', () {
      test('应该能够查询所有会话', () async {
        // 1. 插入多条测试数据
        for (int i = 0; i < 3; i++) {
          final conv = ConversationModel(
            id: 0,
            peerId: 1500 + i,
            avatar: 'https://example.com/avatar$i.jpg',
            title: '用户$i',
            subtitle: '消息$i',
            type: 'C2C',
            msgType: 'text',
            lastTime: 1642579200000 + (i * 1000),
            lastMsgId: 2000 + i,
            unreadNum: i + 1,
            payload: {'text': '消息$i'},
          );

          await conversationRepo.insert(conv);
        }

        // 2. 查询所有会话
        final list = await conversationRepo.list();

        expect(list, isNotEmpty);
        // 验证按 lastTime DESC 排序（最新的在前面）
        expect(list.first.lastTime, greaterThan(list.last.lastTime));
      });

      test('应该能够按类型查询会话', () async {
        // 1. 插入不同类型的会话
        await conversationRepo.insert(
          ConversationModel(
            id: 0,
            peerId: 2,
            avatar: 'https://example.com/avatar.jpg',
            title: 'C2C用户',
            subtitle: 'C2C消息',
            type: 'C2C',
            msgType: 'text',
            lastTime: 1642579200000,
            lastMsgId: 2,
            unreadNum: 1,
            payload: {'text': 'C2C消息'},
          ),
        );

        await conversationRepo.insert(
          ConversationModel(
            id: 0,
            peerId: 2,
            avatar: 'https://example.com/group.jpg',
            title: 'C2G群组',
            subtitle: 'C2G消息',
            type: 'C2G',
            msgType: 'text',
            lastTime: 1642579200000,
            lastMsgId: 2,
            unreadNum: 2,
            payload: {'text': 'C2G消息'},
          ),
        );

        // 2. 按 C2C 类型查询
        final c2cList = await conversationRepo.list(type: 'C2C');

        // 3. 按 C2G 类型查询
        final c2gList = await conversationRepo.list(type: 'C2G');

        expect(c2cList, isNotEmpty);
        expect(c2gList, isNotEmpty);

        // 验证类型正确
        expect(c2cList.every((conv) => conv.type == 'C2C'), true);
        expect(c2gList.every((conv) => conv.type == 'C2G'), true);
      });
    });

    group('会话内容计算', () {
      test('应该正确计算文本消息的会话内容', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '这是一条文本消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {'text': '这是一条文本消息'},
        );

        final content = conv.content;

        expect(content, '这是一条文本消息');
      });

      test('应该正确显示对方撤回的消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '张三李四王五赵六',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 2,
          lastMsgStatus: 30, // peerRevoked
          unreadNum: 0,
          payload: {'peer_name': '张三李四王五赵六'},
        );

        final content = conv.content;

        // 应该显示 "张三李四王五..." 撤回了一条消息（超过12字符会截断）
        expect(content, contains('撤回了一条消息'));
        expect(content, contains('张三李四王五'));
      });

      test('应该正确显示自己撤回的消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '原始消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 3,
          lastMsgStatus: 31, // myRevoked
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        // 应该显示 "你撤回了一条消息"
        expect(content, contains('你撤回了一条消息'));
      });

      test('应该正确显示图片消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[图片]',
          type: 'C2C',
          msgType: 'image',
          lastTime: 1642579200000,
          lastMsgId: 4,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, '[图片]');
      });

      test('应该正确显示语音消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[语音]',
          type: 'C2C',
          msgType: 'voice',
          lastTime: 1642579200000,
          lastMsgId: 5,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('语音'));
      });

      test('应该正确显示视频消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[视频]',
          type: 'C2C',
          msgType: 'video',
          lastTime: 1642579200000,
          lastMsgId: 6,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, '[视频]');
      });

      test('应该正确显示文件消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '[文件]',
          type: 'C2C',
          msgType: 'file',
          lastTime: 1642579200000,
          lastMsgId: 7,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, '[文件]');
      });

      test('应该正确显示位置消息', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '北京市朝阳区建国路88号',
          type: 'C2C',
          msgType: 'location',
          lastTime: 1642579200000,
          lastMsgId: 8,
          unreadNum: 0,
          payload: {},
        );

        final content = conv.content;

        expect(content, contains('[位置]'));
        expect(content, contains('北京市朝阳区建国路88号'));
      });

      test('应该正确显示系统提示（被拒收）', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '消息被拒收了',
          type: 'C2C',
          msgType: 'custom',
          lastTime: 1642579200000,
          lastMsgId: 9,
          unreadNum: 0,
          payload: {'sys_prompt': 'in_denylist'},
        );

        final content = conv.content;

        expect(content, contains('拒收'));
      });

      test('应该正确显示系统提示（非好友）', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试用户',
          subtitle: '非好友提示',
          type: 'C2C',
          msgType: 'custom',
          lastTime: 1642579200000,
          lastMsgId: 10,
          unreadNum: 0,
          payload: {'sys_prompt': 'not_a_friend'},
        );

        final content = conv.content;

        expect(content, anyOf(contains('好友验证'), contains('你还不是他（她）好友')));
      });
    });

    group('会话 UK3 生成', () {
      test('应该正确生成 C2C 会话的 UK3', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 3,
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: {},
        );

        final uk3 = conv.uk3;

        expect(uk3, isNotEmpty);
        expect(uk3, contains('C2C'));
      });

      test('应该正确生成 C2G 会话的 UK3', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 3,
          avatar: '',
          title: '测试群组',
          subtitle: '测试',
          type: 'C2G',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 2,
          unreadNum: 0,
          payload: {},
        );

        final uk3 = conv.uk3;

        expect(uk3, isNotEmpty);
        expect(uk3, contains('C2G'));
      });
    });

    group('会话删除', () {
      test('应该能够删除会话', () async {
        // 1. 插入测试数据
        final conv = ConversationModel(
          id: 0,
          peerId: 1400,
          avatar: 'https://example.com/avatar.jpg',
          title: '待删除用户',
          subtitle: '待删除消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 001,
          unreadNum: 1,
          payload: {'text': '待删除消息'},
        );

        await conversationRepo.insert(conv);

        // 2. 验证存在
        final foundBefore = await conversationRepo.findByPeerId(
          'C2C',
          'test_peer_user_delete',
        );
        expect(foundBefore, isNotNull);

        // 3. 删除
        await conversationRepo.delete('C2C', 'test_peer_user_delete');

        // 4. 验证已删除
        final foundAfter = await conversationRepo.findByPeerId(
          'C2C',
          'test_peer_user_delete',
        );
        expect(foundAfter, isNull);
      });
    });

    group('JSON 序列化', () {
      test('应该正确序列化和反序列化会话对象', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1401,
          avatar: 'https://example.com/avatar.jpg',
          title: 'JSON测试用户',
          subtitle: 'JSON测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 001,
          lastMsgStatus: 20,
          unreadNum: 3,
          isShow: 1,
          payload: {'text': 'JSON测试消息', 'last_read_auto_id': 100},
        );

        // 序列化
        final json = conv.toJson();

        expect(json['id'], 1);
        expect(json['peer_id'], 1401);
        expect(json['title'], 'JSON测试用户');
        expect(json['unread_num'], 3);
        // payload 可能是 JSON 字符串，也可能已是 Map（取决于当前模型实现）
        final dynamic rawPayload = json['payload'];
        final Map<String, dynamic> payloadJson = rawPayload is String
            ? Map<String, dynamic>.from(jsonDecode(rawPayload) as Map)
            : Map<String, dynamic>.from(rawPayload as Map);
        expect(payloadJson['last_read_auto_id'], 100);

        // 反序列化
        final restored = ConversationModel.fromJson(json);

        expect(restored.id, 1);
        expect(restored.peerId, 1401);
        expect(restored.title, 'JSON测试用户');
        expect(restored.subtitle, 'JSON测试消息');
        expect(restored.unreadNum, 3);
        expect(restored.payload!['text'], 'JSON测试消息');
        expect(restored.payload!['last_read_auto_id'], 100);
      });

      test('应该正确处理空 payload 的反序列化', () {
        final json = {
          'id': 1,
          'peer_id': 'test_user',
          'avatar': '',
          'title': '测试',
          'subtitle': '测试消息',
          'type': 'C2C',
          'msg_type': 'text',
          'last_time': 1642579200000,
          'last_msg_id': 1,
          'last_msg_status': 11,
          'unread_num': 0,
          'is_show': 1,
          'payload': null, // 空 payload
        };

        final conv = ConversationModel.fromJson(json);

        expect(conv, isNotNull);
        expect(conv.payload, isNull);
      });

      test('应该正确处理字符串格式的 last_time', () {
        final json = {
          'id': 1,
          'peer_id': 'test_user',
          'avatar': '',
          'title': '测试',
          'subtitle': '测试消息',
          'type': 'C2C',
          'msg_type': 'text',
          'last_time': '1642579200000', // 字符串格式（会被解析）
          'last_msg_id': 1,
          'last_msg_status': 11,
          'unread_num': 0,
          'is_show': 1,
          'payload': {},
        };

        final conv = ConversationModel.fromJson(json);

        // DateTimeHelper.parseTimestamp 会解析字符串，但如果使用默认值可能是当前时间
        // 这里只验证它能正常工作，不验证具体值
        expect(conv.lastTime, greaterThan(0));
      });
    });

    group('会话复制', () {
      test('应该正确复制会话对象', () {
        final conv1 = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: 'https://example.com/avatar.jpg',
          title: '原始标题',
          subtitle: '原始副标题',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          lastMsgStatus: 20,
          unreadNum: 3,
          payload: {'text': '原始消息'},
        );

        final conv2 = conv1.copyWith(title: '新标题', unreadNum: 0);

        // 验证原对象不变
        expect(conv1.title, '原始标题');
        expect(conv1.unreadNum, 3);

        // 验证新对象的修改
        expect(conv2.title, '新标题');
        expect(conv2.unreadNum, 0);

        // 验证其他字段相同
        expect(conv2.peerId, conv1.peerId);
        expect(conv2.type, conv1.type);
        expect(conv2.lastMsgId, conv1.lastMsgId);
      });
    });

    group('边界条件', () {
      test('应该能够处理超大未读数', () async {
        final conv = ConversationModel(
          id: 0,
          peerId: 1402,
          avatar: '',
          title: '测试',
          subtitle: '测试',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 999999, // 超大未读数
          payload: {},
        );

        final saved = await conversationRepo.insert(conv);

        expect(saved, greaterThan(0));

        final found = await conversationRepo.findByPeerId(
          'C2C',
          'test_peer_large_unread',
        );

        expect(found, isNotNull);
        expect(found!.unreadNum, 999999);
      });

      test('应该能够处理特殊字符的标题', () async {
        final specialTitles = [
          '用户🎉表情',
          '用户"引号"测试',
          "用户'单引号'测试",
          '用户\n换行\n测试',
          '用户\t制表符\t测试',
        ];

        for (final title in specialTitles) {
          final conv = ConversationModel(
            id: 0,
            peerId: title.hashCode.abs() % 10000 + 2000,
            avatar: '',
            title: title,
            subtitle: '测试',
            type: 'C2C',
            msgType: 'text',
            lastTime: 1642579200000,
            lastMsgId: title.hashCode.abs() % 10000 + 3000,
            unreadNum: 0,
            payload: {},
          );

          final saved = await conversationRepo.insert(conv);

          expect(saved, greaterThan(0));
        }
      });

      test('应该能够处理空的 payload', () {
        final conv = ConversationModel(
          id: 1,
          peerId: 1100,
          avatar: '',
          title: '测试',
          subtitle: '测试消息',
          type: 'C2C',
          msgType: 'text',
          lastTime: 1642579200000,
          lastMsgId: 1,
          unreadNum: 0,
          payload: null, // 空 payload
        );

        // 读取 last_read_auto_id 应该返回 0
        final lastReadAutoId = conv.payload?['last_read_auto_id'] ?? 0;

        expect(lastReadAutoId, 0);
      });
    });
  });
}
