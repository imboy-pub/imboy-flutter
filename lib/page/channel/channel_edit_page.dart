import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/api/channel_api.dart';

/// 编辑频道页面
class ChannelEditPage extends ConsumerStatefulWidget {
  final String channelId;
  final ChannelModel? channel;

  const ChannelEditPage({super.key, required this.channelId, this.channel});

  @override
  ConsumerState<ChannelEditPage> createState() => _ChannelEditPageState();
}

class _ChannelEditPageState extends ConsumerState<ChannelEditPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _customIdController;

  bool _isLoading = false;
  bool _isSaving = false;
  ChannelModel? _channel;
  int _selectedType = 0;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.channel?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.channel?.description ?? '',
    );
    _customIdController = TextEditingController(
      text: widget.channel?.customId ?? '',
    );
    _selectedType = widget.channel?.type.index ?? 0;
    _channel = widget.channel;

    if (_channel == null) {
      _loadChannel();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _customIdController.dispose();
    super.dispose();
  }

  Future<void> _loadChannel() async {
    setState(() => _isLoading = true);

    try {
      final api = ChannelApi();
      final channel = await api.getChannel(widget.channelId);
      if (mounted && channel != null) {
        setState(() {
          _channel = channel;
          _nameController.text = channel.name;
          _descriptionController.text = channel.description ?? '';
          _customIdController.text = channel.customId ?? '';
          _selectedType = channel.type.index;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final api = ChannelApi();
      final result = await api.updateChannel(
        widget.channelId,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.updateSuccess)));
          context.pop(true); // 返回 true 表示已更新
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(t.channel.updateFailed),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.channel.updateFailed}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    if (_isLoading) {
      return Scaffold(
        appBar: GlassAppBar(title: t.channel.editChannel),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.editChannel,
        automaticallyImplyLeading: true,
        rightDMActions: [
          TextButton(
            onPressed: _isSaving ? null : _saveChanges,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(t.save),
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

            // 频道类型（只读显示）
            Text(
              t.channel.typeLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedType == 0 ? Icons.public : Icons.lock_outline,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _selectedType == 0
                        ? t.channel.typePublic
                        : t.channel.typePrivate,
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const Spacer(),
                  Text(
                    t.channel.typeCannotChange,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 统计信息
            if (_channel != null) ...[
              Text(
                t.channel.stats,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildStatRow(
                      Icons.people_outline,
                      t.channel.subscribers,
                      _channel!.subscriberCount.toString(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
