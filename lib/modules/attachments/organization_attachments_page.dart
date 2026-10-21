import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/repository/user_repo_provider.dart';

import 'workspace_attachments_page.dart';

/// Organization metadata index includes records without a workspace.
class OrganizationAttachmentsPage extends ConsumerWidget {
  const OrganizationAttachmentsPage({super.key, required this.orgId});
  final String orgId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(currentUserProvider)?.uid ?? '';
    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text(context.t.attachmentManager.title),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => context.pop(),
          child: Icon(
            CupertinoIcons.back,
            semanticLabel: context.t.common.buttonBack,
          ),
        ),
      ),
      body: uid.isEmpty || orgId.isEmpty
          ? Center(child: Text(context.t.attachmentManager.unavailableSource))
          : EnterpriseAttachmentIndex(
              key: ValueKey('org:$orgId:$uid'),
              organizationId: orgId,
              owner: uid,
            ),
    );
  }
}
