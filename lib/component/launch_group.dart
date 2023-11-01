import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/page/group/group_select/group_select_view.dart';

class LaunchGroupItem extends StatelessWidget {
  final String item;

  const LaunchGroupItem(
    Key? key,
    this.item,
  ) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.LineColor, width: 0.3),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: TextButton(
        // color: Colors.white,
        // padding: const EdgeInsets.symmetric(vertical: 15.0),
        onPressed: () {
          if (item == '选择一个群') {
            Get.to(
              () => const GroupSelectPage(),
              transition: Transition.rightToLeft,
              popGesture: true, // 右滑，返回上一页
            );
          } else {
            Get.snackbar('', '敬请期待');
          }
        },
        child: Container(
          width: Get.width,
          padding: const EdgeInsets.only(left: 20.0),
          child: Text(item),
        ),
      ),
    );
  }
}

class LaunchSearch extends StatelessWidget {
  final FocusNode? searchF;
  final TextEditingController? searchC;
  final ValueChanged<String>? onChanged;
  final GestureTapCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final GestureTapCallback? delOnTap;

  const LaunchSearch({
    super.key,
    this.searchF,
    this.searchC,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.delOnTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(right: 10.0),
          child: Icon(Icons.search_outlined),
        ),
        Expanded(
          child: TextField(
            focusNode: searchF,
            controller: searchC,
            style: const TextStyle(textBaseline: TextBaseline.alphabetic),
            decoration: InputDecoration(
              hintText: '搜索',
              hintStyle: TextStyle(color: AppColors.LineColor.withOpacity(0.7)),
              border: InputBorder.none,
            ),
            onChanged: onChanged,
            onTap: onTap ?? () {},
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
          ),
        ),
        strNoEmpty(searchC!.text)
            ? InkWell(
                child: const Image(
                  image: AssetImage('assets/images/ic_delete.webp'),
                ),
                onTap: () {
                  searchC!.text = '';
                  delOnTap!();
                },
              )
            : Container()
      ],
    );
  }
}
