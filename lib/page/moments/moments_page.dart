import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/moments/moments_provider.dart';
import 'package:imboy/theme/default/app_colors.dart';

import 'widget/moments_header.dart';
import 'widget/post_item.dart';

class MomentsPage extends ConsumerStatefulWidget {
  const MomentsPage({super.key});

  @override
  ConsumerState<MomentsPage> createState() => _MomentsPageState();
}

class _MomentsPageState extends ConsumerState<MomentsPage> {
  @override
  void initState() {
    super.initState();
    // TODO: 根据滚动位置动态设置 showTitle
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(momentsProvider);
    final t = context.t;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300.0,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            title: Text(
              state.showTitle ? t.moments : '',
              style: const TextStyle(color: Colors.white),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.camera_alt, color: Colors.white),
                onPressed: () {
                  // TODO: Navigate to publish page
                },
              ),
            ],
            flexibleSpace: const FlexibleSpaceBar(background: MomentsHeader()),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return PostItem(index: index);
              },
              childCount: 10, // Dummy count
            ),
          ),
        ],
      ),
    );
  }
}
