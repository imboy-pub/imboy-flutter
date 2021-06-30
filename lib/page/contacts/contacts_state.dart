import 'dart:async';

import 'package:imboy/component/chat/contact_item.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/contact_model.dart';

class ContactsState {
  ContactsState() {
    List<Contact> _contacts = [];
    StreamSubscription<dynamic> _messageStreamSubscription;

    List<ContactItem> _functionButtons = [
      new ContactItem(
          identifier: 'new_friend',
          account: '',
          avatar: contactAssets + 'ic_new_friend.webp',
          title: '新的朋友'),
      new ContactItem(
          identifier: 'ic_group',
          account: '',
          avatar: contactAssets + 'ic_group.webp',
          title: '群聊'),
      new ContactItem(
          identifier: 'ic_tag',
          account: '',
          avatar: contactAssets + 'ic_tag.webp',
          title: '标签'),
      new ContactItem(
          identifier: 'ic_no_public',
          account: '',
          avatar: contactAssets + 'ic_no_public.webp',
          title: '公众号'),
    ];
    final Map _letterPosMap = {INDEX_BAR_WORDS[0]: 0.0};
  }
}
