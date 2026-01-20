import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';

/// 群成员详情页面
class GroupMemberDetailPage extends ConsumerWidget {
  final String id;

  const GroupMemberDetailPage(this.id, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: GlassAppBar(
        automaticallyImplyLeading: true,
        title: t.featureComingSoon,
      ),
    );
  }
}
