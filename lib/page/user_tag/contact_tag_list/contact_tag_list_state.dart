import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class ContactTagListState {
  RxList items = [].obs;

  int page = 1;
  int size = 10;

  Rx<String> kwd = ''.obs;
  Rx<Widget>? searchLeading;
  Rx<Iterable<Widget>>? searchTrailing;

  TextEditingController searchController = TextEditingController();

  ContactTagListState() {
    ///Initialize variables
  }
}
