part of '../web_chat_lifecycle_test.dart';

class _DifferentEndpoint implements Env {
  @override
  String get apiBaseUrl => 'http://127.0.0.1:19800';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Sessions extends ChangeNotifier implements AuthSessionReader {
  @override
  bool get transitionFailed => false;
  @override
  AuthSessionScope current = (uid: '1', generation: 1, transitioning: false);
  @override
  bool isCurrent(AuthSessionScope captured) =>
      captured == current && current.uid.isNotEmpty && !current.transitioning;
  void profileChanged() => notifyListeners();

  void change(String uid) {
    current = (
      uid: uid,
      generation: current.generation + 1,
      transitioning: false,
    );
    notifyListeners();
  }
}

class _Conversation extends ConversationModel {
  _Conversation(String peer, {this.owner = '1'})
    : super(
        id: 1,
        peerId: peer,
        avatar: '',
        title: '',
        subtitle: '',
        type: 'C2C',
        msgType: 'text',
        unreadNum: 0,
      );
  final String owner;
  @override
  String get uk3 => ConversationUk3Generator.generateSmart(
    type: type,
    currentUserId: owner,
    peerId: peerId,
  );
}
