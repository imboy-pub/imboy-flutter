import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imboy/component/ui/avatar.dart';
import 'package:imboy/component/ui/nodata_view.dart';
import 'package:imboy/i18n/strings.g.dart';
import 'package:imboy/page/contact/contact/contact_provider.dart';
import 'package:imboy/service/e2ee_service.dart';
import 'package:imboy/store/model/contact_model.dart';
import 'package:imboy/theme/default/app_colors.dart';
import 'package:imboy/theme/default/app_radius.dart';

/// E2EE 社交恢复 - 好友选择器页面
///
/// 从好友列表中选择信任的联系人作为恢复代理
class E2EEProxySelectorPage extends ConsumerStatefulWidget {
  /// 已选中的代理 UID 列表
  final List<String> selectedUids;

  /// 需要选择的代理数量
  final int requiredCount;

  const E2EEProxySelectorPage({
    super.key,
    this.selectedUids = const [],
    this.requiredCount = 3,
  });

  @override
  ConsumerState<E2EEProxySelectorPage> createState() =>
      _E2EEProxySelectorPageState();
}

class _E2EEProxySelectorPageState extends ConsumerState<E2EEProxySelectorPage> {
  late Set<String> _selectedUids;
  bool _isLoading = true;
  List<ContactModel> _contacts = [];

  /// 缓存好友的公钥信息，避免重复请求
  /// Key: peerId, Value: deviceId -> publicKey map
  final Map<String, Map<String, String>> _cachedPublicKeys = {};

  @override
  void initState() {
    super.initState();
    _selectedUids = widget.selectedUids.toSet();
    // 延迟加载联系人，避免布局期间触发 setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadContacts();
      }
    });
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(contactProvider.notifier);
      final contacts = await notifier.listFriend(false);

      // 过滤出真实的好友（排除特殊联系人）
      final friendContacts = contacts
          .where((c) => !c.isMenuEntry && c.peerId != 0)
          .toList();

      // 获取每个好友的公钥
      final contactsWithKeys = <ContactModel>[];
      for (final contact in friendContacts) {
        try {
          final keyData = await E2EEService.getUserDevicePublicKeys(
            contact.peerId.toString(),
          );
          final didToPem = keyData['didToPem'] ?? {};

          // 缓存公钥信息供后续使用
          if (didToPem.isNotEmpty) {
            _cachedPublicKeys[contact.peerId.toString()] =
                Map<String, String>.from(didToPem);
          }

          contactsWithKeys.add(contact);
        } on Exception {
          // 如果获取公钥失败，仍然显示好友（但可能无法作为代理）
          contactsWithKeys.add(contact);
        }
      }

      if (mounted) {
        setState(() {
          _contacts = contactsWithKeys;
          _isLoading = false;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(t.common.e2eeProxyLoadFriendsFailed)),
        );
      }
    }
  }

  void _toggleSelection(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else {
        _selectedUids.add(uid);
      }
    });
  }

  Future<void> _confirmSelection() async {
    if (_selectedUids.length < widget.requiredCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.main.e2eeProxyMinCount(count: widget.requiredCount)),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // 显示加载状态
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 获取选中好友的详细信息并获取公钥
      final selectedContacts = <Map<String, dynamic>>[];

      for (final contact in _contacts) {
        if (!_selectedUids.contains(contact.peerId.toString())) continue;

        try {
          // 优先使用缓存的公钥，避免重复请求
          Map<String, String> didToPem =
              _cachedPublicKeys[contact.peerId.toString()] ?? {};

          // 如果缓存中没有，从服务获取
          if (didToPem.isEmpty) {
            final keyData = await E2EEService.getUserDevicePublicKeys(
              contact.peerId.toString(),
            );
            didToPem = Map<String, String>.from(keyData['didToPem'] ?? {});
          }

          // 获取第一个可用设备的公钥
          String publicKey = '';
          String deviceId = '';
          if (didToPem.isNotEmpty) {
            final firstEntry = didToPem.entries.first;
            deviceId = firstEntry.key;
            publicKey = firstEntry.value;
          }

          if (publicKey.isEmpty) {
            throw Exception(t.common.e2eeProxyNoPublicKey);
          }

          selectedContacts.add({
            'uid': contact.peerId,
            'nickname': contact.title,
            'avatar': contact.avatar,
            'device_id': deviceId,
            'public_key': publicKey,
          });
        } on Exception {
          // 关闭加载对话框
          if (!mounted) return;
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                t.common.e2eeProxyGetKeyFailed(name: contact.title),
              ),
            ),
          );
          return;
        }
      }

      // 关闭加载对话框
      if (mounted) {
        Navigator.pop(context);
        // 返回选中的代理列表
        Navigator.pop(context, selectedContacts);
      }
    } on Exception {
      if (mounted) {
        // 关闭加载对话框
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(t.common.e2eeProxySelectFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedCount = _selectedUids.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.main.e2eeProxySelectTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: t.common.buttonBack,
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                t.main.e2eeProxySelectedCount(
                  selected: selectedCount,
                  total: widget.requiredCount,
                ),
                style: TextStyle(
                  fontSize: 14,
                  color: selectedCount >= widget.requiredCount
                      ? Colors.green
                      : isDark
                      ? Colors.white70
                      : Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? _buildEmptyView()
          : Column(
              children: [
                _buildInfoCard(isDark),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _contacts.length,
                    itemBuilder: (context, index) {
                      final contact = _contacts[index];
                      final isSelected = _selectedUids.contains(
                        contact.peerId.toString(),
                      );
                      return _buildContactItem(contact, isSelected, isDark);
                    },
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(isDark),
    );
  }

  Widget _buildEmptyView() {
    return NoDataView(
      text: t.common.e2eeProxyNoFriends,
      description: t.common.e2eeProxyNoFriendsHint,
      icon: Icons.people_outline,
      iconSize: 64,
    );
  }

  Widget _buildInfoCard(bool isDark) {
    final selectedCount = _selectedUids.length;
    final canConfirm = selectedCount >= widget.requiredCount;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: canConfirm
              ? [Colors.green.shade50, Colors.green.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.borderRadiusMedium,
      ),
      child: Row(
        children: [
          Icon(
            canConfirm ? Icons.check_circle : Icons.info_outline,
            color: canConfirm ? Colors.green : Colors.blue,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canConfirm
                      ? t.main.e2eeProxyReachedMin
                      : t.main.e2eeProxySelectTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: canConfirm ? Colors.green : Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.common.e2eeProxyNeedMore(
                    count: widget.requiredCount,
                    selected: selectedCount,
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    color: canConfirm
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem(ContactModel contact, bool isSelected, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                  ? Colors.blue.withValues(alpha: 0.2)
                  : Colors.blue.withValues(alpha: 0.1))
            : (isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white),
        borderRadius: AppRadius.borderRadiusMedium,
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => _toggleSelection(contact.peerId.toString()),
        borderRadius: AppRadius.borderRadiusMedium,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // 头像
              Avatar(
                imgUri: contact.avatar,
                width: 50,
                height: 50,
                heroTag: 'avatar_${contact.peerId}',
              ),
              const SizedBox(width: 12),
              // 信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (contact.sign.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        contact.sign,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // 选中状态
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: isSelected ? Colors.blue : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(bool isDark) {
    final selectedCount = _selectedUids.length;
    final canConfirm = selectedCount >= widget.requiredCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceGroupedTertiary : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: canConfirm ? _confirmSelection : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canConfirm ? Colors.blue : Colors.grey.shade300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.borderRadiusSmall,
              ),
              elevation: 0,
            ),
            child: Text(
              canConfirm
                  ? t.common.e2eeProxyConfirmCount(count: selectedCount)
                  : t.chat.e2eeProxyNeedAtLeast(count: widget.requiredCount),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}
