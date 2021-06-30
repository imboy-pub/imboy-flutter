import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'contacts_logic.dart';
import 'contacts_state.dart';

class ContactsPage extends StatelessWidget {
  final ContactsLogic logic = Get.put(ContactsLogic());
  final ContactsState state = Get.find<ContactsLogic>().state;

  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
