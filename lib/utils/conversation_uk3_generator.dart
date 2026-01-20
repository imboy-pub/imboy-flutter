/// ConversationUk3 生成器
///
/// 用于生成标准化的会话唯一标识符，确保同一对话在不同方向下生成一致的UK3
class ConversationUk3Generator {
  /// 生成标准的 conversationUk3
  ///
  /// [type] 消息类型 (C2C, C2G, S2C 等)
  /// [currentUserId] 当前用户ID
  /// [peerId] 对方用户ID或群组ID
  static String generate({
    required String type,
    required String currentUserId,
    required String peerId,
  }) {
    // 标准化用户ID顺序，确保同一个对话有统一的UK3
    String normalizedIds = _normalizeUserIds(currentUserId, peerId);

    return '${type.toUpperCase()}_$normalizedIds';
  }

  /// 特殊处理：群组消息使用原始格式
  ///
  /// 群组消息需要保持 user_id 和 group_id 的原始顺序，
  /// 因为群组ID是唯一的，不需要排序
  static String generateForGroup({
    required String type,
    required String currentUserId,
    required String groupId,
  }) {
    return '${type.toUpperCase()}_${currentUserId}_$groupId';
  }

  /// 特殊处理：系统消息
  ///
  /// 系统消息使用特殊标识，避免与普通消息混淆
  static String generateForSystem({
    required String type,
    required String userId,
  }) {
    return '${type.toUpperCase()}_SYSTEM_$userId';
  }

  /// 兼容性方法：保持原有逻辑不变（用于向后兼容）
  ///
  /// 这个方法保持原有的生成逻辑，主要用于已有的数据处理
  static String generateLegacy({
    required String type,
    required String currentUserId,
    required String peerId,
  }) {
    return "${type}_${currentUserId}_$peerId".toLowerCase();
  }

  /// 标准化用户ID顺序 - 按字母排序
  ///
  /// 确保C2C对话的一致性，不论是谁发起对话
  /// 例如：用户A和用户B的对话，不论A发还是B发，都生成相同的UK3
  static String _normalizeUserIds(String id1, String id2) {
    final sortedIds = [id1, id2]..sort();
    return '${sortedIds.first}_${sortedIds.last}';
  }

  /// 检查两个conversationUk3是否指向同一个对话
  ///
  /// 用于处理历史数据的兼容性问题
  static bool isSameConversation(String uk3_1, String uk3_2) {
    if (uk3_1 == uk3_2) return true;

    // 尝试解析两个UK3
    final parts1 = uk3_1.split('_');
    final parts2 = uk3_2.split('_');

    if (parts1.length < 3 || parts2.length < 3) return false;

    // 检查消息类型是否相同
    final type1 = parts1[0].toUpperCase();
    final type2 = parts2[0].toUpperCase();
    if (type1 != type2) return false;

    // 提取用户ID进行比较
    if (type1 == 'C2G') {
      // 群组消息：比较user_id和group_id
      return _compareGroupConversation(parts1, parts2);
    } else {
      // C2C消息：比较标准化后的用户ID
      return _compareC2CConversation(parts1, parts2);
    }
  }

  /// 比较群组会话
  static bool _compareGroupConversation(
    List<String> parts1,
    List<String> parts2,
  ) {
    // 群组格式：C2G_userId_groupId
    return parts1[1] == parts2[1] && parts1[2] == parts2[2];
  }

  /// 比较C2C会话
  static bool _compareC2CConversation(
    List<String> parts1,
    List<String> parts2,
  ) {
    // 提取两个用户ID并标准化排序
    final users1 = [parts1[1], parts1[2]]..sort();
    final users2 = [parts2[1], parts2[2]]..sort();

    return users1[0] == users2[0] && users1[1] == users2[1];
  }

  /// 从conversationUk3中提取消息类型
  static String extractType(String uk3) {
    return uk3.split('_')[0].toUpperCase();
  }

  /// 从conversationUk3中提取用户ID（C2C消息）
  static List<String> extractUserIds(String uk3) {
    final parts = uk3.split('_');
    if (parts.length < 3) return [];

    final type = parts[0].toUpperCase();
    if (type == 'C2G') {
      // 群组消息返回 [userId, groupId]
      return [parts[1], parts[2]];
    } else {
      // C2C消息返回两个用户ID
      return [parts[1], parts[2]];
    }
  }

  /// 智能生成conversationUk3
  ///
  /// 根据消息类型自动选择合适的生成方法
  static String generateSmart({
    required String type,
    required String currentUserId,
    required String peerId,
    bool useNewLogic = true,
  }) {
    final upperType = type.toUpperCase();

    if (!useNewLogic) {
      return generateLegacy(
        type: type,
        currentUserId: currentUserId,
        peerId: peerId,
      );
    }

    switch (upperType) {
      case 'C2G':
        return generateForGroup(
          type: type,
          currentUserId: currentUserId,
          groupId: peerId,
        );
      case 'S2C':
      case 'C2S':
        return generateForSystem(type: type, userId: currentUserId);
      default:
        return generate(
          type: type,
          currentUserId: currentUserId,
          peerId: peerId,
        );
    }
  }

  /// 迁移历史数据：将旧格式的UK3转换为新格式
  ///
  /// [legacyUk3] 旧格式的conversationUk3
  /// [currentUserId] 当前用户ID
  static String migrateLegacyUk3(String legacyUk3, String currentUserId) {
    final parts = legacyUk3.split('_');
    if (parts.length < 3) return legacyUk3;

    final type = parts[0].toUpperCase();
    final peerId = parts[2];

    if (type == 'C2G') {
      // 群组消息不需要改变
      return legacyUk3;
    }

    // C2C消息需要重新排序
    return generate(type: type, currentUserId: currentUserId, peerId: peerId);
  }
}
