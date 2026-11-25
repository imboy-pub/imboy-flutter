part of 'chat_network_service.dart';

// =============================================================================
// 群组操作（ChatNetworkService 的 part 拆分）
//
// groupTitle 原为 ChatNetworkService 类内实例方法，按方法边界移入本 part 的
// extension；公共调用面不变（调用方仍以 service.groupTitle(...) 形式调用）。
// =============================================================================

extension ChatNetworkServiceGroupOps on ChatNetworkService {
  /// 获取群组标题
  ///
  /// BUG#4 家族：`prefix` 为空时原先直接落到通用词「群聊」，于是无名群的聊天页
  /// 标题一律是 `群聊(2)`，而同一个群在群列表里显示的是成员名 —— 同群两种叫法，
  /// 正是 `GroupModel.displayTitle` 文档注释里点名要消灭的情况。
  ///
  /// 群名其实查得到，只是原逻辑仅在 `num <= 0` 分支查群详情、且只取 memberCount。
  /// 这里是所有入口（会话列表 / 群列表 / 设置页回传 / **进程恢复**）的必经收口点，
  /// 补齐三级回退：传入名 → 群 title → 成员名（与群列表同一算法）。
  ///
  /// 批次 14 新证据：同一个群从**进程恢复**路径进来时，标题退化成
  /// `104603643803863040(2)` —— TSID 直接泄漏给用户。传进来的 `prefix`
  /// 本身就是 gid（存量脏 title / 恢复参数），非空回退接不住它。
  /// 因此先做一次「prefix 是不是 gid 本身」的判定，是则视同缺失 ——
  /// 与 §二十三 给 `conversation_item` 定的判据同一条：
  /// **TSID 在任何情况下都不进 UI**。
  Future<String> groupTitle(String gid, String prefix, int num) async {
    String name = prefix.trim();
    if (name == gid.trim()) {
      name = '';
    }
    int memberCount = num;

    if (name.isEmpty || memberCount <= 0) {
      final GroupModel? g = await GroupDetailService().detail(gid: gid);
      if (name.isEmpty) {
        name = g?.title.trim() ?? '';
      }
      if (memberCount <= 0) {
        memberCount = g?.memberCount ?? 0;
      }
    }
    if (name.isEmpty) {
      // 无名群：取前几位成员昵称，与群列表页 computeTitle 同源，保证两处一致
      name = (await GroupListService().computeTitle(gid)).trim();
    }
    if (name.isEmpty) {
      name = t.main.unnamed;
    }

    return memberCount > 0 ? "$name($memberCount)" : name;
  }
}
