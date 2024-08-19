class ChatExtendModel {
  final String type;
  final Map<String, dynamic> payload;

  ChatExtendModel({
    // join_group | leave_group | delete_msg | clean_msg
    required this.type,
    required this.payload,
  });
}
