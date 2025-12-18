import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'chat_background_logic.dart';
import 'chat_background_state.dart';

class ChatBackgroundPage extends StatefulWidget {
  const ChatBackgroundPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _ChatBackgroundPageState createState() => _ChatBackgroundPageState();
}

class _ChatBackgroundPageState extends State<ChatBackgroundPage> {
  final logic = Get.put(ChatBackgroundLogic());
  final ChatBackgroundState state = Get.find<ChatBackgroundLogic>().state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '聊天背景',
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: textTheme.titleMedium?.fontSize ?? 16,
          ),
        ),
        backgroundColor: colorScheme.surface,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: colorScheme.primary,
          ),
          onPressed: () => Get.back(),
        ),
      ),
      body: Container(
        color: colorScheme.surface,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            // 系统默认背景
            ListTile(
              title: Text(
                '系统默认',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: textTheme.titleMedium?.fontSize ?? 16,
                ),
              ),
              subtitle: Text(
                '使用系统默认背景',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: textTheme.bodySmall?.fontSize ?? 14,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: textTheme.bodySmall?.fontSize ?? 14,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: _navigateToSystemDefault,
            ),
            const Divider(height: 1),
            // 自定义背景
            ListTile(
              title: Text(
                '自定义',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: textTheme.titleMedium?.fontSize ?? 16,
                ),
              ),
              subtitle: Text(
                '选择自定义背景图片',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: textTheme.bodySmall?.fontSize ?? 14,
                ),
              ),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: textTheme.bodySmall?.fontSize ?? 14,
                color: colorScheme.onSurfaceVariant,
              ),
              onTap: _navigateToCustomBackground,
            ),
            const Divider(height: 1),
            // 聊天背景预览
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.outline.withValues(alpha: 0.1),
                    spreadRadius: 0,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前背景',
                    style: TextStyle(
                      color: colorScheme.primary,
                      fontSize: textTheme.titleMedium?.fontSize ?? 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '预览区域',
                          style: TextStyle(
                            color: colorScheme.onPrimaryContainer,
                            fontSize: textTheme.titleMedium?.fontSize ?? 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 导航到系统默认背景设置
  void _navigateToSystemDefault() {
    // 添加导航到系统默认背景设置的逻辑
    // 例如: Get.to(() => SystemDefaultBackgroundPage());
  }

  // 导航到自定义背景设置
  void _navigateToCustomBackground() {
    // 添加导航到自定义背景设置的逻辑
    // 例如: Get.to(() => CustomBackgroundPage());
  }

  @override
  void dispose() {
    Get.delete<ChatBackgroundLogic>();
    super.dispose();
  }
}
