import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../profile_logic.dart';

/// 资料完善度卡片组件
class ProfileCompletenessCard extends StatelessWidget {
  const ProfileCompletenessCard({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.find<ProfileLogic>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Get.theme.primaryColor.withValues(alpha: 0.1),
            Get.theme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Get.theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题和等级
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '资料完善度',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: logic.state.completenessColor.value.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: logic.state.completenessColor.value.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  logic.state.completenessLevel.value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: logic.state.completenessColor.value,
                  ),
                ),
              )),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 进度条和百分比
          Row(
            children: [
              Expanded(
                child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 进度条
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: logic.state.completeness.value / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                logic.state.completenessColor.value,
                                logic.state.completenessColor.value.withValues(alpha: 0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // 百分比文本
                    Text(
                      '${logic.state.completeness.value}% 完成',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                )),
              ),
              
              const SizedBox(width: 16),
              
              // 百分比数字
              Obx(() => Text(
                '${logic.state.completeness.value}%',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: logic.state.completenessColor.value,
                ),
              )),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 完善建议
          Obx(() {
            final suggestions = logic.getCompletionSuggestions();
            if (suggestions.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '资料已完善！',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '完善建议：',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.take(3).map((suggestion) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Get.theme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Get.theme.primaryColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      suggestion,
                      style: TextStyle(
                        fontSize: 12,
                        color: Get.theme.primaryColor,
                      ),
                    ),
                  )).toList(),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}