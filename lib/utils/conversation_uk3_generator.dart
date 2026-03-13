/// ConversationUk3 generator.
///
/// Generate standardized conversation identifiers for the current message model.
class ConversationUk3Generator {
  /// Generate standard conversationUk3 for peer messages.
  static String generate({
    required String type,
    required String currentUserId,
    required String peerId,
  }) {
    final normalizedIds = _normalizeUserIds(currentUserId, peerId);
    return '${type.toUpperCase()}_$normalizedIds';
  }

  static String _normalizeUserIds(String id1, String id2) {
    final sortedIds = [id1, id2]..sort();
    return '${sortedIds.first}_${sortedIds.last}';
  }

  static String _generateGroupUk3({
    required String type,
    required String currentUserId,
    required String groupId,
  }) {
    return '${type.toUpperCase()}_${currentUserId}_$groupId';
  }

  static String _generateSystemUk3({
    required String type,
    required String userId,
  }) {
    return '${type.toUpperCase()}_SYSTEM_$userId';
  }

  /// Generate conversationUk3 by message type.
  static String generateSmart({
    required String type,
    required String currentUserId,
    required String peerId,
  }) {
    switch (type.toUpperCase()) {
      case 'C2G':
        return _generateGroupUk3(
          type: type,
          currentUserId: currentUserId,
          groupId: peerId,
        );
      case 'S2C':
      case 'C2S':
        return _generateSystemUk3(type: type, userId: currentUserId);
      default:
        return generate(
          type: type,
          currentUserId: currentUserId,
          peerId: peerId,
        );
    }
  }
}
