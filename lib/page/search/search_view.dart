import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/const.dart';

import 'search_logic.dart';
import 'search_state.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final logic = Get.put(SearchLogic());
  final SearchState state = Get.find<SearchLogic>().state;

  final TextEditingController _searchC = TextEditingController();

  List words = ['朋友圈', '文章', '公众号', '小程序', '音乐', '表情'];

  Widget wordView(item) {
    return InkWell(
      child: Container(
        width: Get.width / 3,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 15.0),
        child: Text(
          item,
          style: const TextStyle(color: AppColors.TipColor),
        ),
      ),
      onTap: () => Get.snackbar("tips", "$item功能小编正在开发"),
    );
  }

  Widget body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            '搜索指定内容'.tr,
            style: const TextStyle(color: AppColors.MainTextColor),
          ),
        ),
        Wrap(
          children: words.map(wordView).toList(),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var searchView = Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _searchC,
            style: const TextStyle(textBaseline: TextBaseline.alphabetic),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: '搜索'.tr,
            ),
            onChanged: (text) {
              setState(() {});
            },
          ),
        ),
        strNoEmpty(_searchC.text)
            ? InkWell(
                child: const Image(
                  image: AssetImage('assets/images/ic_delete.webp'),
                ),
                onTap: () {
                  _searchC.text = '';
                  setState(() {});
                },
              )
            : Container()
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.AppBarColor,
      appBar: PageAppBar(titleWidget: searchView),
      body: SizedBox(width: Get.width, child: body()),
    );
  }

  @override
  void dispose() {
    Get.delete<SearchLogic>();
    super.dispose();
  }
}
