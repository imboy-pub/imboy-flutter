import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class UserCollectState {
  RxBool kindActive = false.obs;

  RxList items = [].obs;

  int page = 1;
  int size = 10;

  // 被收藏的资源种类： 1 文本  2 图片  3 语音  4 视频  5 文件  6 位置消息
  String kind = 'all'; // all 1-10 recent_use
  final String recentUse = 'recent_use';
  Rx<String> kwd = ''.obs;
  Rx<Widget>? searchLeading;
  Rx<Iterable<Widget>>? searchTrailing;

  TextEditingController searchController = TextEditingController();

  UserCollectState() {
    ///Initialize variables
  }
}
