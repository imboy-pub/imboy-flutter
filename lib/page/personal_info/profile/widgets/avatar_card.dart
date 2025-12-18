import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:imboy/component/ui/avatar.dart';
import '../profile_logic.dart';

/// 增强版头像卡片组件
class AvatarCard extends StatelessWidget {
  const AvatarCard({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<ProfileLogic>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 头像区域
          Stack(
            children: [
              // 头像容器
              GestureDetector(
                onTap: () => logic.previewAvatar(),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Get.theme.primaryColor.withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Obx(() => logic.state.avatar.value.isEmpty
                        ? Container(
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.person,
                              size: 40,
                              color: Colors.grey[400],
                            ),
                          )
                        : Avatar(
                            imgUri: logic.state.avatar.value,
                            width: 80,
                            height: 80,
                          )),
                  ),
                ),
              ),
              
              // 编辑按钮
              Positioned(
                right: -4,
                bottom: -4,
                child: GestureDetector(
                  onTap: () => logic.selectAvatarSource(),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Get.theme.primaryColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
              
              // 上传进度指示器
              Obx(() => logic.state.isUploading.value
                  ? Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink()),
            ],
          ),
          
          const SizedBox(width: 20),
          
          // 用户信息区域
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 昵称
                Obx(() => Text(
                  logic.state.nickname.value.isEmpty 
                      ? '设置昵称' 
                      : logic.state.nickname.value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: logic.state.nickname.value.isEmpty
                        ? Colors.grey[400]
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                )),
                
                const SizedBox(height: 4),
                
                // 账号
                Obx(() => Text(
                  'ID: ${logic.state.userModel.value.account}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                )),
                
                const SizedBox(height: 8),
                
                // 个性签名
                Obx(() => Text(
                  logic.state.signature.value.isEmpty 
                      ? '设置个性签名，展示个人魅力' 
                      : logic.state.signature.value,
                  style: TextStyle(
                    fontSize: 14,
                    color: logic.state.signature.value.isEmpty
                        ? Colors.grey[400]
                        : (isDark ? Colors.white70 : Colors.black54),
                    fontStyle: logic.state.signature.value.isEmpty 
                        ? FontStyle.italic 
                        : FontStyle.normal,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                )),
              ],
            ),
          ),
          
          // 箭头图标
          Icon(
            Icons.navigate_next,
            color: Colors.grey[400],
            size: 24,
          ),
        ],
      ),
    );
  }
}