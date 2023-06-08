import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:imboy/component/search.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/store/model/user_collect_model.dart';
import 'package:imboy/store/repository/user_collect_repo_sqlite.dart';
import 'package:niku/namespace.dart' as n;

import 'user_collect_logic.dart';

// ignore: must_be_immutable
class UserCollectPage extends StatelessWidget {
  UserCollectPage({super.key});

  int page = 1;
  int size = 20;
  final logic = Get.put(UserCollectLogic());
  final state = Get.find<UserCollectLogic>().state;

  void initData() async {
    var list = await logic.page(page: page, size: size);
    state.items.value = list;
  }

  @override
  Widget build(BuildContext context) {
    initData();
    return Scaffold(
      backgroundColor: AppColors.ChatBg,
      appBar: PageAppBar(
        title: '我的收藏'.tr,
      ),
      body: SingleChildScrollView(
        child: Container(
          width: Get.width,
          height: Get.height,
          color: AppColors.primaryBackground,
          child: n.Column(
            [
              n.Padding(
                left: 8,
                top: 10,
                right: 8,
                bottom: 10,
                child: SearchBar(
                  hintText: '搜索'.tr,
                  // isBorder: true,
                  onTap: () {
                    showSearch(
                      context: context,
                      // useRootNavigator: true,
                      delegate: LocalSearchBarDelegate(
                        searchLabel: '搜索'.tr,
                        queryTips: '收藏人名、群名、标签等'.tr,
                        doSearch: ((query) {
                          // debugPrint(
                          //     "> on search doSearch ${query.toString()}");
                          return UserCollectRepo().search(kwd: query);
                        }),
                        onTapForItem: (value) {
                          // debugPrint(
                          //     "> on search value ${value is UserCollectModel}, ${value.toString()}");
                          if (value is UserCollectModel) {
                            // Get.to(
                            //   () => PeopleInfoPage(
                            //     id: value.deniedUid,
                            //     sence: 'denylist',
                            //   ),
                            //   transition: Transition.rightToLeft,
                            //   popGesture: true, // 右滑，返回上一页
                            // );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: SlidableAutoCloseBehavior(child: Obx(() {
                  return state.items.isEmpty
                      ? NoDataView(text: '暂无数据'.tr)
                      : n.Padding(
                          top: 16,
                          child: ListView(
                            children: <Widget>[
                              for (int i = 0; i < state.items.length; i++)
                                n.ListTile(
                                  // selected: true,
                                  onTap: () {
                                    // onTapForItem(state.items[i]);
                                  },
                                  leading: Avatar(
                                    imgUri: state.items[i].avatar,
                                    onTap: () {},
                                  ),
                                  title: n.Row([
                                    Expanded(
                                      child: Text(
                                        // 会话对象标题
                                        state.items[i].title,
                                        style: const TextStyle(
                                          fontSize: 16.0,
                                          fontWeight: FontWeight.normal,
                                        ),
                                        maxLines: 6,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )
                                  ]),
                                ),
                            ],
                          ),
                        );
                })),
              ),
            ],
            mainAxisSize: MainAxisSize.min,
          ),
        ),
      ),
    );
  }
}
