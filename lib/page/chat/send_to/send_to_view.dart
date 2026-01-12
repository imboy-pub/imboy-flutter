import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' show Message;

import 'package:get/get.dart';
import 'package:imboy/component/helper/func.dart';
import 'package:imboy/component/ui/common_bar.dart';


import 'send_to_logic.dart';

/// 发送给 页面
class SendToPage extends StatefulWidget {
  final Message msg;

  const SendToPage({super.key, required this.msg});

  @override
  // ignore: library_private_types_in_public_api
  _SendToPageState createState() => _SendToPageState();
}

class _SendToPageState extends State<SendToPage> {
  final logic = Get.put(SendToLogic());
  
  @override
  void initState() {
    super.initState();
    logic.conversationsList().then((_) {
      // 初始化搜索结果
      logic.searchResults.assignAll(logic.state.conversations);
    });
  }

  void initData() async {
    await logic.conversationsList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: GlassAppBar(
        titleWidget: Text(
          '转发给',
          style: TextStyle(
            color: colorScheme.primary, // 应用主题主颜色
            fontSize: textTheme.titleMedium?.fontSize ?? 16, // 使用主题字体大小
          ),
        ),
        backgroundColor: colorScheme.surface, // 应用主题表面颜色
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.primary, // 应用主题主颜色
          ),
          onPressed: () => Get.back(),
        ),
        rightDMActions: [
          TextButton(
            onPressed: _send,
            child: Text(
              '发送',
              style: TextStyle(
                color: colorScheme.primary, // 应用主题主颜色
                fontSize: textTheme.bodyMedium?.fontSize ?? 14, // 使用主题字体大小
              ),
            ),
          ),
        ],
      ),
      body: Container(
        color: colorScheme.surface, // 应用主题表面颜色
        child: Column(
          children: [
            // 搜索框
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: logic.searchController,
                decoration: InputDecoration(
                  hintText: '搜索',
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant, // 应用主题文本颜色
                    fontSize: textTheme.bodyMedium?.fontSize ?? 14, // 使用主题字体大小
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant, // 应用主题文本颜色
                    size: textTheme.bodyMedium?.fontSize ?? 14, // 使用主题字体大小
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest, // 应用主题表面颜色
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: TextStyle(
                  color: colorScheme.onSurface, // 应用主题文本颜色
                  fontSize: textTheme.bodyMedium?.fontSize ?? 14, // 使用主题字体大小
                ),
                onChanged: logic.search,
              ),
            ),
            // 联系人列表
            Expanded(
              child: Obx(() {
                if (logic.searchResults.isEmpty) {
                  return Center(
                    child: Text(
                      '暂无联系人',
                      style: TextStyle(
                        color: colorScheme.onSurfaceVariant, // 应用主题文本颜色
                        fontSize: textTheme.bodyMedium?.fontSize ?? 14, // 使用主题字体大小
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: logic.searchResults.length,
                  itemBuilder: (context, index) {
                    final contact = logic.searchResults[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: cachedImageProvider(contact.avatar),
                        backgroundColor: colorScheme.primaryContainer, // 应用主题容器颜色
                        child: null,
                      ),
                      title: Text(
                        contact.title,
                        style: TextStyle(
                          color: colorScheme.onSurface, // 应用主题文本颜色
                          fontSize: textTheme.titleMedium?.fontSize ?? 16, // 使用主题字体大小
                        ),
                      ),
                      subtitle: Text(
                        contact.subtitle,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant, // 应用主题文本颜色
                          fontSize: textTheme.bodySmall?.fontSize ?? 12, // 使用主题字体大小
                        ),
                      ),
                      trailing: Obx(() {
                        final isSelected = logic.selectedContacts
                            .any((element) => element.id == contact.id);
                        return Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          color: isSelected
                              ? colorScheme.primary // 应用主题主颜色
                              : colorScheme.onSurfaceVariant, // 应用主题文本颜色
                        );
                      }),
                      onTap: () => logic.toggleContactSelection(contact),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  // 发送消息
  void _send() {
    // 添加发送消息的逻辑
    // 例如: logic.sendMessage(widget.msg);
    Get.back();
  }
}
