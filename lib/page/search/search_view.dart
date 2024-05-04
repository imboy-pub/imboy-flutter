import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/config/theme.dart';

import 'search_logic.dart';
import 'search_state.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final logic = Get.put(SearchLogic());
  final SearchState state = Get.find<SearchLogic>().state;

  final TextEditingController _searchC = TextEditingController();

  List words = ['moment'.tr, '文章', '公众号', '小程序', '音乐', '表情'];

  Widget wordView(item) {
    return InkWell(
      child: Container(
        width: Get.width / 3,
        alignment: Alignment.center,
        margin: const EdgeInsets.symmetric(vertical: 15.0),
        child: Text(
          item,
          // style: const TextStyle(color: AppColors.TipColor),
        ),
      ),
      onTap: () => Get.snackbar("tips", "$item功能正在开发"),
    );
  }

  Widget body() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Text(
            'search_specific_content'.tr,
            // style: const TextStyle(color: AppColors.MainTextColor),
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
            style: AppStyle.navAppBarTitleStyle,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'search'.tr,
            ),
            onChanged: (text) {
              setState(() {});
            },
          ),
        ),
        strNoEmpty(_searchC.text)
            ? InkWell(
                child: const Icon(Icons.backspace),
                onTap: () {
                  _searchC.text = '';
                  setState(() {});
                },
              )
            : Container()
      ],
    );
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar:
          NavAppBar(automaticallyImplyLeading: true, titleWidget: searchView),
      body: SizedBox(width: Get.width, child: body()),
    );
  }

  @override
  void dispose() {
    Get.delete<SearchLogic>();
    super.dispose();
  }
}
