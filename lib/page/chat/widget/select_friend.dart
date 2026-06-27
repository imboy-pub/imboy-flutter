import 'package:azlistview/azlistview.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lpinyin/lpinyin.dart';

import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';

import 'package:imboy/service/assets.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/font_types.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 选择好友页面
/// 使用 Riverpod 进行状态管理
class SelectFriendPage extends ConsumerStatefulWidget {
  final Map<String, String> peer;
  final bool peerIsReceiver;

  const SelectFriendPage({
    super.key,
    required this.peer,
    this.peerIsReceiver = false,
  });

  @override
  ConsumerState<SelectFriendPage> createState() => _SelectFriendPageState();
}

class _SelectFriendPageState extends ConsumerState<SelectFriendPage> {
  // final int _suspensionHeight = 30;
  final int _itemHeight = 60;

  List<ContactModel> _contactList = [];

  // ignore: prefer_collection_literals
  final Set<String> _currIndexBarData = {};

  @override
  void initState() {
    super.initState();
    // 延迟加载数据，确保 ref 已准备好
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
    });
  }

  List<dynamic> selects = [];

  // 构建索引栏项目
  Widget _buildSusItem(BuildContext context, String tag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      height: 30,
      alignment: Alignment.centerLeft,
      color: Theme.of(context).colorScheme.surface,
      child: Text(
        tag,
        style: context.textStyle(
          FontSizeType.small,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  void loadData() async {
    // 加载联系人列表
    final contactList = await ContactRepo().findFriend();

    setState(() {
      _contactList = contactList;
    });

    _handleList(_contactList);
  }

  void _handleList(List<ContactModel> list) {
    for (int i = 0; i < list.length; i++) {
      String pinyin = PinyinHelper.getPinyinE(list[i].title);
      String tag = pinyin.substring(0, 1).toUpperCase();
      list[i].namePinyin = pinyin;
      if (RegExp("[A-Z]").hasMatch(tag)) {
        list[i].nameIndex = tag;
        _currIndexBarData.add(tag);
      } else {
        list[i].nameIndex = "#";
      }
    }
    _currIndexBarData.add('#');

    // A-Z sort.
    SuspensionUtil.sortListBySuspensionTag(_contactList);

    // show sus tag.
    SuspensionUtil.setShowSuspensionStatus(_contactList);

    setState(() {});
  }

  /*
  Widget _buildSusWidget(String susTag) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15.0),
      height: _suspensionHeight.toDouble(),
      width: double.infinity,
      alignment: Alignment.centerLeft,
      color: AppColors.AppBarColor,
      child: Text(
        susTag,
        textScaleFactor: 1.2,
        style:  TextStyle(
          color: AppColors.lightTextSecondary,
          fontSize: FontSizeType.small.size,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  */

  void sendToDialog(ContactModel model) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final peer = widget.peer;
    final peerIsReceiver = widget.peerIsReceiver;

    // 根据主题选择按钮文字颜色：暗色用 iOS 绿、亮色用 iOS 蓝（语义色）
    final brightness = Theme.of(context).brightness;
    final Color buttonTextColor = isDarkMode
        ? AppColors.getIosGreen(brightness)
        : AppColors.getIosBlue(brightness);

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.chat.sendTo),
        backgroundColor: isDarkMode
            ? AppColors.darkSurfaceGrouped
            : AppColors.lightSurfaceGrouped,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        content: SizedBox(
          height: 164,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              peerIsReceiver
                  ? Row(
                      children: [
                        Avatar(imgUri: model.avatar),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              model.title,
                              style: context.textStyle(
                                FontSizeType.medium,
                                fontWeight: FontWeight.normal,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Avatar(imgUri: peer['avatar']!),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: Text(
                              peer['title']!,
                              style: context.textStyle(
                                FontSizeType.medium,
                                fontWeight: FontWeight.normal,
                              ),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                    ),
              const Divider(),
              Expanded(
                child: Text(
                  // visitCard
                  peerIsReceiver
                      ? "[${t.common.personalCard}]${peer['nickname']}"
                      : "[${t.common.personalCard}]${model.nickname}",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              t.common.buttonCancel,
              textAlign: TextAlign.center,
              style: TextStyle(color: buttonTextColor),
            ),
          ),
          TextButton(
            onPressed: () async {
              var nav = Navigator.of(context);
              nav.pop();
              nav.pop(model);
            },
            child: Text(
              t.common.buttonSend,
              textAlign: TextAlign.center,
              style: TextStyle(color: buttonTextColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItem(ContactModel model) {
    // String susTag = model.getSuspensionTag();
    return Column(
      children: [
        SizedBox(
          height: _itemHeight.toDouble(),
          child: InkWell(
            onTap: () {
              sendToDialog(model);
              // model.selected = !model.selected;
              // if (model.selected) {
              //   selects.insert(0, model);
              // } else {
              //   selects.remove(model);
              // }
              // setState(() {});
            },
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Avatar(imgUri: model.avatar, width: 49, height: 49),
                ),
                const Space(),
                Expanded(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(right: 30),
                    height: _itemHeight.toDouble(),
                    decoration: const BoxDecoration(
                      border: Border(top: BorderSide(width: 0.5)),
                    ),
                    child: Text(
                      model.title,
                      style: context.textStyle(FontSizeType.normal),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: GlassAppBar(
        title: t.contact.selectFriends,
        leading: Padding(
          padding: AppSpacing.allSmall,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
            },
            child: const Icon(Icons.close),
          ),
        ),
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              // 检查网络状态
              var connectivityResult = await Connectivity().checkConnectivity();
              if (connectivityResult.contains(ConnectivityResult.none)) {
                String msg = t.common.tipConnectDesc;
                AppLoading.showInfo(' $msg');
                return;
              }
              List<ContactModel> contact = await ContactRepo().findFriend();
              if (contact.isNotEmpty) {
                setState(() {
                  _contactList = contact;
                  // contactIsEmpty.value = _contactList.isEmpty;
                });
                _handleList(_contactList);
              }
            },
            child: AzListView(
              data: _contactList,
              itemCount: _contactList.length,
              itemBuilder: (context, i) => _buildListItem(_contactList[i]),
              // 解决联系人数据量少的情况下无法刷新的问题
              // 在listview的physice属性赋值new AlwaysScrollableScrollPhysics()，保持listview任何情况都能滚动
              physics: const AlwaysScrollableScrollPhysics(),
              susItemBuilder: (BuildContext context, int index) {
                ContactModel model = _contactList[index];
                if ('↑' == model.getSuspensionTag()) {
                  return Container();
                }

                return _buildSusItem(context, model.getSuspensionTag());
              },
              // indexBarData: const ['↑', ...kIndexBarData],
              indexBarData: _contactList.isNotEmpty
                  ? ['↑', ..._currIndexBarData]
                  : [],
              indexBarOptions: IndexBarOptions(
                needRebuild: true,
                ignoreDragCancel: true,
                downTextStyle: context.textStyle(
                  FontSizeType.small,
                  color: AppColors.onPrimary,
                ),
                downItemDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                indexHintWidth: 128 / 2,
                indexHintHeight: 128 / 2,
                indexHintDecoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage(
                      AssetsService.getImgPath('index_bar_bubble_gray'),
                    ),
                    fit: BoxFit.contain,
                  ),
                ),
                indexHintAlignment: Alignment.centerRight,
                indexHintChildAlignment: const Alignment(-0.25, 0.0),
                indexHintOffset: const Offset(-20, 0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
