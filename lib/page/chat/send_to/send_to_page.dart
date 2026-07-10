import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;
import 'package:go_router/go_router.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/app_loading.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/theme/default/app_spacing.dart';
import 'package:imboy/theme/default/font_types.dart';

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
      await ref.read(sendToProvider.notifier).conversationsList();
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
            fontSize:
                textTheme.titleMedium?.fontSize ?? FontSizeType.medium.size,
          ),
        ),
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.primary),
          onPressed: () => context.pop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        rightDMActions: [
          TextButton(
            onPressed: _send,
            child: Text(
              t.common.buttonSend,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize:
                    textTheme.bodyMedium?.fontSize ?? FontSizeType.normal.size,
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
                    fontSize:
                        textTheme.bodyMedium?.fontSize ??
                        FontSizeType.normal.size,
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
                  fontSize:
                      textTheme.bodyMedium?.fontSize ??
                      FontSizeType.normal.size,
                ),
                onChanged: (query) {
                  ref.read(sendToProvider.notifier).search(query);
                },
              ),
            ),
            // 联系人列表
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(sendToProvider);
                  final searchResults = state.searchResults;
                  final selectedContacts = state.selectedContacts;

                  if (searchResults.isEmpty) {
                    return Center(
                      child: Text(
                        t.common.noContacts,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize:
                              textTheme.bodyMedium?.fontSize ??
                              FontSizeType.normal.size,
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
                            fontSize:
                                textTheme.titleMedium?.fontSize ??
                                FontSizeType.medium.size,
                          ),
                        ),
                        subtitle: Text(
                          contact.subtitle,
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize:
                                textTheme.bodySmall?.fontSize ??
                                FontSizeType.small.size,
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
                              .read(sendToProvider.notifier)
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
  Future<void> _send() async {
    final selectedContacts = ref.read(sendToProvider).selectedContacts;
    if (selectedContacts.isEmpty) {
      context.pop();
      return;
    }

    final notifier = ref.read(sendToProvider.notifier);
    final failCount = await notifier.sendToSelected(widget.msg);
    if (!mounted) return;

    if (failCount > 0) {
      // 存在转发失败，留在当前页提示用户，避免静默丢消息
      final failedMsg = failCount == selectedContacts.length
          ? t.common.sendFailed
          : '${t.common.sendFailed} ($failCount/${selectedContacts.length})';
      AppLoading.showError(failedMsg);
      return;
    }

    AppLoading.showSuccess(t.common.success);
    context.pop();
  }
}
