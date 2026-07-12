import 'package:flutter_test/flutter_test.dart';

import 'package:imboy/page/mention/mention_list_page.dart';
import 'package:imboy/service/mention_service.dart'
    show NewMentionEvent, MentionAllReadEvent;

/// MentionListPage 可测范围说明（为何不做整页渲染）：
///
/// - 页面在 initState 中直接调用 MentionService.to（`static final` 单例，
///   无 testInstance/接口注入点）→ MentionApi → HttpClient；HttpClient
///   使用 dio Http2Adapter 建立真实 socket 连接，flutter_test 的
///   HttpOverrides 拦截不到，整页 pump 会发起真实网络请求（60s 超时挂起）。
/// - 页面内的数据解析逻辑（_toInt/_resolveGroupId/_resolveMessageId/
///   _formatTime 等）均为 library-private 方法，测试无法直接访问。
///
/// 因此本文件仅覆盖公开构造契约；整页交互留待 integration_test 真机验证。
/// 若后续为 MentionService 增加接口 + testInstance 注入点（参考
/// GroupTaskService / test/widget/group_task_page_test.dart 范式），
/// 即可补齐列表渲染/已读跳转的 widget 测试。
void main() {
  group('MentionListPage 构造契约', () {
    test('MC-1 默认构造 groupId 为 null（全部提及入口）', () {
      const page = MentionListPage();

      expect(page.groupId, isNull);
    });

    test('MC-2 传入 groupId 时按群过滤（群内提及入口）', () {
      const page = MentionListPage(groupId: 'g100');

      expect(page.groupId, 'g100');
    });

    test('MC-3 createState 可创建状态对象（页面可实例化）', () {
      const page = MentionListPage();

      expect(page.createState(), isNotNull);
    });
  });

  group('提及事件契约（页面刷新触发源）', () {
    test('ME-1 NewMentionEvent 携带原始 data 且按值相等', () {
      const data = {'id': 1, 'group_id': 'g100', 'msg_id': 'm1'};

      const event = NewMentionEvent(data: data);

      expect(event.data['group_id'], 'g100');
      // AppEvent 基于 props 的值相等语义（事件去重/比对依赖此契约）
      expect(event, const NewMentionEvent(data: data));
    });

    test('ME-2 MentionAllReadEvent 的 groupId 可为 null（全部群已读）', () {
      const event = MentionAllReadEvent();

      expect(event.groupId, isNull);
      expect(event, const MentionAllReadEvent());
    });
  });
}
