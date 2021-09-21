import 'dart:async';

import 'contacts_model.dart';

class ContactsState {
  ContactsState() {
    List<ContactModel> _contacts = [];
    StreamSubscription<dynamic> _messageStreamSubscription;
  }
}
