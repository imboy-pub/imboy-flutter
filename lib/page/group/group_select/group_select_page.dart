import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/avatar.dart' show SmartGroupAvatar;
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/ios_settings_ui.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/page/group/group_select/group_select_provider.dart';
import 'package:imboy/store/model/conversation_model.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_colors.dart';

class GroupSelectPage extends ConsumerStatefulWidget {
  const GroupSelectPage({super.key});

  @override
  ConsumerState<GroupSelectPage> createState() => _GroupSelectPageState();
}

class _GroupSelectPageState extends ConsumerState<GroupSelectPage> {
  @override
  void initState() {
    super.initState();
    // 初始化数据
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadData();
    });
  }

  /// 加载数据
  Future<void> loadData() async {
    final notifier = ref.read(groupSelectProvider.notifier);
    await notifier.loadData();
  }

  /// 计算群组头像
  Future<List<String>> computeAvatar(String gid) async {
    final service = ref.read(groupSelectServiceProvider);
    return await service.computeAvatar(gid);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(groupSelectProvider);

    return Scaffold(
      backgroundColor: isDark
          ? Theme.of(context).colorScheme.surface
          : AppColors.lightPageBackground,
      appBar: GlassAppBar(
        title: t.group.selectGroup,
        automaticallyImplyLeading: true,
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
          ? NoDataView(text: t.common.noData)
          : ListView.builder(
              shrinkWrap: true,
              itemCount: state.items.length,
              itemBuilder: (BuildContext context, int index) {
                ConversationModel model = state.items[index];
                return Column(
                  children: [
                    ImBoyListTile(
                      leading: SmartGroupAvatar(
                        avatar: model.avatar,
                        groupId: model.peerId.toString(),
                        avatarLoader: computeAvatar,
                        size: 48,
                      ),
                      title: Text(
                        strEmpty(model.title)
                            ? model.computeTitle
                            : model.title,
                      ),
                      trailing: const Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: AppColors.iosGray3,
                      ),
                      onTap: () {
                        context.push(
                          '/chat/${model.peerId}',
                          extra: {
                            'peerId': model.peerId,
                            'peerTitle': model.title,
                            'peerAvatar': model.avatar,
                            'peerSign': '',
                            'type': 'C2G',
                            'options': const {'popTime': 2, 'memberCount': 0},
                          },
                        );
                      },
                    ),
                    if (index < state.items.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 76),
                        child: Divider(
                          height: 0.33,
                          color: AppColors.getIosSeparator(
                            Theme.of(context).brightness,
                          ).withValues(alpha: 0.3),
                        ),
                      ),
                  ],
                );
              },
              physics: const AlwaysScrollableScrollPhysics(),
            ),
    );
  }
}
