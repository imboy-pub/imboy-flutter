import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';

import 'send_to_provider.dart';

/// 发送给 页面
class SendToPage extends ConsumerStatefulWidget {
  final Message msg;

  const SendToPage({super.key, required this.msg});

  @override
  ConsumerState<SendToPage> createState() => _SendToPageState();
}

class _SendToPageState extends ConsumerState<SendToPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final logic = ref.read(sendToProvider);
      await logic.conversationsList();
      setState(() {}); // 触发重建以更新 UI
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text(
          t.chat.forwardTo,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: textTheme.titleMedium?.fontSize ?? 16,
          ),
        ),
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.primary),
          onPressed: () => context.pop(),
        ),
        rightDMActions: [
          TextButton(
            onPressed: _send,
            child: Text(
              t.common.buttonSend,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: textTheme.bodyMedium?.fontSize ?? 14,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: colorScheme.surface,
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(AppSpacing.regular),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: t.common.search,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: textTheme.bodyMedium?.fontSize ?? 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant,
                    size: textTheme.bodyMedium?.fontSize ?? 14,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.borderRadiusXLarge,
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: textTheme.bodyMedium?.fontSize ?? 14,
                ),
                onChanged: (query) {
                  ref.read(sendToProvider).search(query);
                },
              ),
            ),
            // 联系人列表
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final logic = ref.watch(sendToProvider);
                  final searchResults = logic.searchResults;
                  final selectedContacts = logic.selectedContacts;

                  if (searchResults.isEmpty) {
                    return Center(
                      child: Text(
                        t.common.noContacts,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: textTheme.bodyMedium?.fontSize ?? 14,
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final contact = searchResults[index];
                      final isSelected = selectedContacts.any(
                        (element) => element.id == contact.id,
                      );
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatarImageProvider(contact.avatar),
                          backgroundColor: colorScheme.primaryContainer,
                          child: null,
                        ),
                        title: Text(
                          contact.title,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: textTheme.titleMedium?.fontSize ?? 16,
                          ),
                        ),
                        subtitle: Text(
                          contact.subtitle,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: textTheme.bodySmall?.fontSize ?? 12,
                          ),
                        ),
                        trailing: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                        onTap: () {
                          ref
                              .read(sendToProvider)
                              .toggleContactSelection(contact);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 发送消息
  void _send() {
    final logic = ref.read(sendToProvider);
    final selectedContacts = logic.selectedContacts;

    for (final contact in selectedContacts) {
      logic.sendMsg(contact, widget.msg);
    }
    context.pop();
  }
}
