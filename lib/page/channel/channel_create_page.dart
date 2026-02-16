import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';

import 'channel_provider.dart';

/// 创建频道页面
class ChannelCreatePage extends ConsumerStatefulWidget {
  const ChannelCreatePage({super.key});

  @override
  ConsumerState<ChannelCreatePage> createState() => _ChannelCreatePageState();
}

class _ChannelCreatePageState extends ConsumerState<ChannelCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customIdController = TextEditingController();
  int _selectedType = 0;
  bool _isPublic = true;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customIdController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(createChannelNotifierProvider.notifier);

    final channel = await notifier.createChannel(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      customId: _customIdController.text.trim().isNotEmpty
          ? _customIdController.text.trim()
          : null,
      type: _selectedType,
    );

    if (channel != null && mounted) {
      // 刷新频道列表
      ref.read(channelListNotifierProvider.notifier).loadSubscribedChannels();
      // 跳转到频道详情
      context.pushReplacement('/channel/${channel.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final state = ref.watch(createChannelNotifierProvider);

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.create,
        automaticallyImplyLeading: true,
        rightDMActions: [
          TextButton(
            onPressed: state.isCreating ? null : _createChannel,
            child: state.isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.confirm),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 频道名称
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: t.channel.nameLabel,
                hintText: t.channel.nameHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.campaign),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return t.channel.nameRequired;
                }
                if (value.trim().length > 50) {
                  return t.channel.nameTooLong;
                }
                return null;
              },
              maxLength: 50,
            ),
            const SizedBox(height: 16),

            // 频道描述
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: t.channel.descriptionLabel,
                hintText: t.channel.descriptionHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.description_outlined),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
              maxLength: 500,
            ),
            const SizedBox(height: 16),

            // 自定义 ID
            TextFormField(
              controller: _customIdController,
              decoration: InputDecoration(
                labelText: t.channel.customIdLabel,
                hintText: t.channel.customIdHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.alternate_email),
                helperText: t.channel.customIdHelper,
              ),
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return t.channel.customIdInvalid;
                  }
                  if (value.length < 4 || value.length > 30) {
                    return t.channel.customIdLength;
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 频道类型
            Text(
              t.channel.typeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 0,
                  label: Text(t.channel.typePublic),
                  icon: const Icon(Icons.public),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text(t.channel.typePrivate),
                  icon: const Icon(Icons.lock_outline),
                ),
              ],
              selected: {_selectedType},
              onSelectionChanged: (Set<int> selection) {
                setState(() {
                  _selectedType = selection.first;
                  _isPublic = _selectedType == 0;
                });
              },
            ),
            const SizedBox(height: 24),

            // 频道类型说明
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _isPublic ? Icons.public : Icons.lock_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isPublic
                          ? t.channel.typePublicDesc
                          : t.channel.typePrivateDesc,
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 提示信息
            Text(
              t.channel.createTips,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),

            // 错误信息
            if (state.error != null)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(color: Colors.red),
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
}
