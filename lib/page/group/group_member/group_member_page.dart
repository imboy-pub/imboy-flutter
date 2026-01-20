import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';

/// 群组成员页面
class GroupMemberPage extends ConsumerWidget {
  final String groupId;

  const GroupMemberPage({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: const GlassAppBar(automaticallyImplyLeading: true),
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: const [
          // TODO: 实现群组成员列表
        ],
      ),
    );
  }
}
