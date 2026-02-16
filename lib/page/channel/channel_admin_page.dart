import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/channel_api.dart';

/// 管理员信息
class _AdminInfo {
  final String userId;
  final String? nickname;
  final String? avatar;
  final int role;
  final DateTime addedAt;

  _AdminInfo({
    required this.userId,
    this.nickname,
    this.avatar,
    required this.role,
    required this.addedAt,
  });

  factory _AdminInfo.fromJson(Map<String, dynamic> json) {
    return _AdminInfo(
      userId: json['user_id'] as String? ?? '',
      nickname: json['nickname'] as String?,
      avatar: json['avatar'] as String?,
      role: json['role'] as int? ?? 0,
      addedAt: json['added_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['added_at'] as int)
          : DateTime.now(),
    );
  }
}

/// 管理员管理页面
class ChannelAdminPage extends ConsumerStatefulWidget {
  final String channelId;

  const ChannelAdminPage({super.key, required this.channelId});

  @override
  ConsumerState<ChannelAdminPage> createState() => _ChannelAdminPageState();
}

class _ChannelAdminPageState extends ConsumerState<ChannelAdminPage> {
  final ChannelApi _api = ChannelApi();
  List<_AdminInfo> _admins = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final admins = await _api.getAdmins(widget.channelId);
      if (mounted) {
        setState(() {
          _admins = admins.map((e) => _AdminInfo.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showAddAdminDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.channel.addAdmin),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: t.channel.userId,
            hintText: t.channel.userIdHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(t.confirm),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      try {
        final success = await _api.addAdmin(
          widget.channelId,
          result,
          0, // 默认角色：编辑
        );
        if (success && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.addAdminSuccess)));
          _loadAdmins();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.channel.addAdminFailed}: $e')),
          );
        }
      }
    }
  }

  Future<void> _showRoleDialog(_AdminInfo admin) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.channel.changeRole),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleOption(context, 0, t.channel.roleEditor, admin.role),
            _buildRoleOption(context, 1, t.channel.roleAdmin, admin.role),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t.cancel),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      try {
        final success = await _api.updateAdminRole(
          widget.channelId,
          admin.userId,
          result,
        );
        if (success && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.updateRoleSuccess)));
          _loadAdmins();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.channel.updateRoleFailed}: $e')),
          );
        }
      }
    }
  }

  Widget _buildRoleOption(
    BuildContext context,
    int role,
    String label,
    int currentRole,
  ) {
    return ListTile(
      title: Text(label),
      trailing: role == currentRole
          ? const Icon(Icons.check, color: AppColors.primary)
          : null,
      onTap: () => Navigator.pop(context, role),
    );
  }

  Future<void> _removeAdmin(_AdminInfo admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.channel.removeAdmin),
        content: Text(t.channel.removeAdminConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(t.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(t.confirm),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final success = await _api.removeAdmin(widget.channelId, admin.userId);
        if (success && mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.removeAdminSuccess)));
          _loadAdmins();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${t.channel.removeAdminFailed}: $e')),
          );
        }
      }
    }
  }

  String _getRoleName(int role) {
    switch (role) {
      case 2:
        return t.channel.roleCreator;
      case 1:
        return t.channel.roleAdmin;
      case 0:
      default:
        return t.channel.roleEditor;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return t.channel.today;
    } else if (diff.inDays == 1) {
      return t.channel.yesterday;
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ${t.channel.daysAgo}';
    } else {
      return '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;

    return Scaffold(
      appBar: GlassAppBar(
        title: t.channel.manageAdmins,
        automaticallyImplyLeading: true,
        rightDMActions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAddAdminDialog,
            tooltip: t.channel.addAdmin,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final t = context.t;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAdmins, child: Text(t.buttonRetry)),
          ],
        ),
      );
    }

    if (_admins.isEmpty) {
      return NoDataView(
        icon: Icons.admin_panel_settings_outlined,
        text: t.channel.noAdmins,
      );
    }

    return ListView.builder(
      itemCount: _admins.length,
      itemBuilder: (context, index) {
        final admin = _admins[index];
        final isCreator = admin.role == 2;

        return ListTile(
          leading: Avatar(imgUri: admin.avatar ?? '', width: 48, height: 48),
          title: Text(admin.nickname ?? admin.userId),
          subtitle: Text(
            '${_getRoleName(admin.role)} · ${_formatTime(admin.addedAt)}',
          ),
          trailing: isCreator
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    t.channel.roleCreator,
                    style: TextStyle(color: AppColors.primary, fontSize: 12),
                  ),
                )
              : PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'change_role':
                        _showRoleDialog(admin);
                        break;
                      case 'remove':
                        _removeAdmin(admin);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'change_role',
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(t.channel.changeRole),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: 'remove',
                      child: ListTile(
                        leading: const Icon(
                          Icons.person_remove_outlined,
                          color: Colors.red,
                        ),
                        title: Text(
                          t.channel.removeAdmin,
                          style: const TextStyle(color: Colors.red),
                        ),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}
