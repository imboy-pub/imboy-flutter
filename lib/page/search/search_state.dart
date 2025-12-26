import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:get/get.dart';
import 'package:imboy/service/storage.dart';
import 'package:imboy/store/model/contact_model.dart';

class SearchState {
  // 搜索结果
  RxList<Message> searchResults = <Message>[].obs;
  RxBool isLoading = false.obs;
  RxString currentQuery = ''.obs;
  RxInt currentPage = 1.obs;
  RxBool hasMore = true.obs;
  RxString errorMessage = ''.obs;

  // 联系人信息缓存
  RxMap<String, ContactModel> contactCache = <String, ContactModel>{}.obs;
  
  // 搜索状态优化
  RxBool isSearching = false.obs;
  RxBool showSkeleton = false.obs;
  RxInt searchProgress = 0.obs;

  // 搜索历史
  RxList<String> searchHistory = <String>[].obs;
  RxList<String> searchSuggestions = <String>[].obs;

  // 搜索历史配置
  static const int _maxHistoryCount = 20;
  static const String _chatSearchHistoryKey = 'chat_search_history';

  // 搜索过滤器
  RxString selectedMessageType = 'all'.obs; // all, text, image, video, file
  RxString selectedTimeRange = 'all'.obs; // all, today, week, month
  RxString selectedSender = 'all'.obs; // all, me, other
  Rx<DateTime?> startDate = Rx<DateTime?>(null);
  Rx<DateTime?> endDate = Rx<DateTime?>(null);

  // 搜索统计
  RxInt totalResults = 0.obs;
  RxMap<String, int> typeDistribution = <String, int>{}.obs;

  SearchState() {
    ///Initialize variables
    _loadSearchHistory();
  }

  // 加载搜索历史
  void _loadSearchHistory() {
    try {
      searchHistory.value = StorageService.to.getStringList(_chatSearchHistoryKey) ?? [];
    } catch (e) {
      searchHistory.value = [];
    }
  }

  // 添加搜索历史
  Future<void> addToHistory(String query) async {
    if (query.trim().isEmpty) return;

    final List<String> history = getSearchHistory();

    // 移除重复项
    history.remove(query);

    // 添加到开头
    history.insert(0, query.trim());

    // 限制历史记录数量
    if (history.length > _maxHistoryCount) {
      history.removeRange(_maxHistoryCount, history.length);
    }

    await StorageService.to.setStringList(_chatSearchHistoryKey, history);
    searchHistory.value = history;
  }

  // 清空搜索历史
  Future<void> clearHistory() async {
    await StorageService.to.remove(_chatSearchHistoryKey);
    searchHistory.clear();
  }

  // 获取搜索建议
  void updateSearchSuggestions(String query) {
    if (query.trim().length < 2) {
      searchSuggestions.value = [];
      return;
    }

    final List<String> history = getSearchHistory();
    final List<String> suggestions = [];

    for (final item in history) {
      if (item.toLowerCase().contains(query.toLowerCase())) {
        suggestions.add(item);
        if (suggestions.length >= 5) break;
      }
    }

    searchSuggestions.value = suggestions;
  }

  // 获取搜索历史列表
  List<String> getSearchHistory() {
    try {
      return StorageService.to.getStringList(_chatSearchHistoryKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  // 检查是否有搜索历史
  bool hasSearchHistory() {
    return getSearchHistory().isNotEmpty;
  }

  // 重置搜索状态
  void resetSearch() {
    searchResults.clear();
    currentPage.value = 1;
    hasMore.value = true;
    errorMessage.value = '';
    totalResults.value = 0;
    typeDistribution.clear();
  }

  // 重置过滤器
  void resetFilters() {
    selectedMessageType.value = 'all';
    selectedTimeRange.value = 'all';
    selectedSender.value = 'all';
    startDate.value = null;
    endDate.value = null;
  }

  // 获取有效的搜索查询
  String getEffectiveQuery() {
    return currentQuery.value.trim();
  }

  // 检查是否有活动过滤器
  bool hasActiveFilters() {
    return selectedMessageType.value != 'all' ||
           selectedTimeRange.value != 'all' ||
           selectedSender.value != 'all' ||
           startDate.value != null ||
           endDate.value != null;
  }

  // 联系人缓存管理
  void cacheContact(String uid, ContactModel contact) {
    contactCache[uid] = contact;
    // 限制缓存大小
    if (contactCache.length > 100) {
      final firstKey = contactCache.keys.first;
      contactCache.remove(firstKey);
    }
  }

  ContactModel? getCachedContact(String uid) {
    return contactCache[uid];
  }

  void clearContactCache() {
    contactCache.clear();
  }

  // 搜索进度管理
  void updateSearchProgress(int progress) {
    searchProgress.value = progress;
  }

  void startSearching() {
    isSearching.value = true;
    showSkeleton.value = true;
    searchProgress.value = 0;
  }

  void stopSearching() {
    isSearching.value = false;
    showSkeleton.value = false;
    searchProgress.value = 100;
  }
}
