import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:imboy/store/model/contact_model.dart';

class ContactTagDetailState {
  Rx<String> tagName = ''.obs;
  Rx<int> refererTime = 0.obs;

  RxList<ContactModel> contactList = RxList<ContactModel>();

  // ignore: prefer_collection_literals
  RxSet currIndexBarData = Set().obs;

  int page = 1;
  int size = 10;

  Rx<String> kwd = ''.obs;
  Rx<Widget>? searchLeading;
  Rx<Iterable<Widget>>? searchTrailing;

  TextEditingController searchController = TextEditingController();

  ContactTagDetailState() {
    ///Initialize variables
  }
}
