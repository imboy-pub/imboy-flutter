import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/common_bar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/store/api/channel_api.dart';
import 'package:imboy/store/model/channel_model.dart';
import 'package:imboy/store/repository/contact_repo_sqlite.dart';
import 'package:imboy/page/channel/channel_admin_add_rules.dart';

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
          _error = '${e.runtimeType}';
          _isLoading = false;
        });
      }
    }
  }

  /// 打开联系人选人底部弹层
  Future<void> _showContactPicker() async {
    // 构造已有管理员 ID 集合，用于在选人界面过滤
    final existingIds = _admins.map((a) => a.userId).toList();

    final picked = await showModalBottomSheet<({String userId, int role})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContactPickerSheet(
        existingAdminIds: existingIds,
        channelId: widget.channelId,
      ),
    );

    if (picked == null || !mounted) return;

    try {
      final success = await _api.addAdmin(
        widget.channelId,
        picked.userId,
        picked.role,
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.channel.addAdminSuccess)),
        );
        unawaited(_loadAdmins());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.channel.addAdminFailed)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.channel.addAdminFailed)),
        );
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
            // 规范角色码：editor=1, admin=2，与 ChannelUserRole.toInt() 一致。
            _buildRoleOption(
              context,
              ChannelUserRole.editor.toInt(),
              t.channel.roleEditor,
              admin.role,
            ),
            _buildRoleOption(
              context,
              ChannelUserRole.admin.toInt(),
              t.channel.roleAdmin,
              admin.role,
            ),
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
        // result 已是规范角色码（1=editor, 2=admin），直接透传。
        final success = await _api.updateAdminRole(
          widget.channelId,
          admin.userId,
          result,
        );
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.updateRoleSuccess)));
          unawaited(_loadAdmins());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.updateRoleFailed)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.updateRoleFailed)),
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
        if (!mounted) return;
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(t.channel.removeAdminSuccess)));
          unawaited(_loadAdmins());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.removeAdminFailed)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(t.channel.removeAdminFailed)),
          );
        }
      }
    }
  }

  /// 将后端返回的 role 整数映射为本地化角色名。
  ///
  /// 规范编码（与 [ChannelUserRole.toInt] 一致）：
  ///   1 = editor, 2 = admin, 3 = creator
  /// 历史实现错位一位（0/1/2），导致 editor 被显示为 admin、admin 被显示为
  /// creator，列表与后端数据完全错位。此版本按规范重建映射。
  String _getRoleName(int role) {
    switch (role) {
      case 3:
        return t.channel.roleCreator;
      case 2:
        return t.channel.roleAdmin;
      case 1:
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
            onPressed: _showContactPicker,
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
                    borderRadius: AppRadius.borderRadiusTiny,
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

// =============================================================================
// 联系人选人底部弹层
// =============================================================================

/// 从好友列表中选择要添加为管理员的联系人，并确认角色。
///
/// 返回值：`({userId, role})` 记录类型，调用方据此调 API；
/// 用户取消时返回 null。
class _ContactPickerSheet extends StatefulWidget {
  final List<String> existingAdminIds;
  final String channelId;

  const _ContactPickerSheet({
    required this.existingAdminIds,
    required this.channelId,
  });

  @override
  State<_ContactPickerSheet> createState() => _ContactPickerSheetState();
}

class _ContactPickerSheetState extends State<_ContactPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _candidates = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contacts = await ContactRepo().findFriend();
    final maps = contacts
        .map((c) => {
              'peer_id': c.peerId,
              'nickname': c.title, // title = remark ?? nickname ?? account
              'account': c.account,
              'remark': c.remark,
              'avatar': c.avatar,
            })
        .toList();

    final candidates = filterContactsForAdmin(
      maps,
      existingAdminIds: widget.existingAdminIds,
    );

    if (mounted) {
      setState(() {
        _candidates = candidates;
        _filtered = candidates;
        _isLoading = false;
      });
    }
  }

  void _onSearch() {
    setState(() {
      _filtered = searchContactCandidates(_candidates, _searchCtrl.text);
    });
  }

  /// 弹出角色选择对话框，返回用户选择的角色值（1/2），取消返回 null。
  Future<int?> _pickRole(BuildContext ctx) {
    final t = ctx.t;
    return showDialog<int>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: Text(t.channel.selectRole),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(t.channel.roleEditor),
              subtitle: Text(t.channel.roleEditorDesc),
              leading: const Icon(Icons.edit_outlined),
              onTap: () => Navigator.pop(context, 1),
            ),
            ListTile(
              title: Text(t.channel.roleAdmin),
              subtitle: Text(t.channel.roleAdminDesc),
              leading: const Icon(Icons.admin_panel_settings_outlined),
              onTap: () => Navigator.pop(context, 2),
            ),
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
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 顶部拖拽指示器
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // 标题
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  t.channel.selectFromContacts,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // 搜索框
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchCtrl,
              autofocus: false,
              decoration: InputDecoration(
                hintText: t.channel.searchContactsHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: AppRadius.borderRadiusXLarge,
                  borderSide: BorderSide.none,
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const Divider(height: 1),
          // 联系人列表
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          _candidates.isEmpty
                              ? t.channel.noContactsToAdd
                              : t.noContacts,
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (ctx, i) {
                          final c = _filtered[i];
                          final avatar = c['avatar'] as String? ?? '';
                          final nickname = c['nickname'] as String? ?? '';
                          final account = c['account'] as String? ?? '';
                          return ListTile(
                            leading: Avatar(
                              imgUri: avatar,
                              width: 44,
                              height: 44,
                            ),
                            title: Text(nickname),
                            subtitle: account.isNotEmpty ? Text(account) : null,
                            onTap: () async {
                              final role = await _pickRole(ctx);
                              if (role == null || !context.mounted) return;
                              final userId =
                                  c['peer_id']?.toString() ?? '';
                              if (userId.isEmpty) return;
                              // ignore: use_build_context_synchronously
                              Navigator.pop(
                                context,
                                (userId: userId, role: role),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
