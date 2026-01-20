import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/config/const.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/live_room/live_room_list/live_room_list_provider.dart';
import 'package:imboy/store/model/live_room_model.dart';

class LiveRoomListPage extends ConsumerStatefulWidget {
  const LiveRoomListPage({super.key});

  @override
  ConsumerState<LiveRoomListPage> createState() => _LiveRoomListPageState();
}

class _LiveRoomListPageState extends ConsumerState<LiveRoomListPage> {
  StreamSubscription? _localeSubscription;

  @override
  void initState() {
    super.initState();
    _localeSubscription = LocaleSettings.getLocaleStream().listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _localeSubscription?.cancel();
    super.dispose();
  }

  void initData() {
    var list = <LiveRoomModel>[];
    list.add(
      LiveRoomModel(
        userId: "1",
        tagId: 1,
        scene: 1,
        name: "name",
        subtitle: "subtitle",
        refererTime: 0,
        updatedAt: 0,
        createdAt: 0,
      ),
    );
    ref.read(liveRoomListProvider.notifier).setItems(list);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(liveRoomListProvider);

    // 初始化数据
    initData();

    return Scaffold(
      appBar: GlassAppBar(automaticallyImplyLeading: true, title: t.myLive),
      body: SingleChildScrollView(
        child: Container(
          width: MediaQuery.of(context).size.width,
          height: MediaQuery.of(context).size.height,
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 15, right: 10),
                  child: state.items.isEmpty
                      ? NoDataView(text: t.noData)
                      : ListView.builder(
                          itemCount: state.items.length,
                          itemBuilder: (BuildContext context, int index) {
                            return Column(
                              children: [
                                ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 0,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(t.liveBroadcast),
                                      const Space(width: 10),
                                    ],
                                  ),
                                  subtitle: Row(
                                    children: [Text(t.publisherPage)],
                                  ),
                                  trailing: navigateNextIcon,
                                  onTap: () {
                                    context.push('/live_room/publisher');
                                  },
                                ),
                                const Divider(
                                  height: 8.0,
                                  indent: 0.0,
                                  color: Colors.black26,
                                ),
                                ListTile(
                                  contentPadding: const EdgeInsets.only(
                                    left: 0,
                                  ),
                                  title: Row(
                                    children: [
                                      Text(t.liveBroadcast),
                                      const Space(width: 10),
                                    ],
                                  ),
                                  subtitle: Row(children: [Text(t.subscriber)]),
                                  trailing: navigateNextIcon,
                                  onTap: () {
                                    context.push('/live_room/subscriber');
                                  },
                                ),
                                const Divider(
                                  height: 8.0,
                                  indent: 0.0,
                                  color: Colors.black26,
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
