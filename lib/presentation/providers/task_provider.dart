
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../data/models/task_model.dart';
import '../../core/services/task_service.dart';
import '../../core/utils/date_utils.dart';

// class TasksState {
//   final bool isLoading;
//   final bool isLoadingMore;
//   final String? error;
//   final List<Task> tasks;
//   final int totalCount;
//   final int notStartedCount;
//   final int inProgressCount;
//   final int completedCount;
//   final int overdueCount;
//   final int dueTodayCount;
//   final Pagination? pagination;
//   final String selectedFilter;
// 
//   const TasksState({
//     this.isLoading = false,
//     this.isLoadingMore = false,
//     this.error,
//     this.tasks = const [],
//     this.totalCount = 0,
//     this.notStartedCount = 0,
//     this.inProgressCount = 0,
//     this.completedCount = 0,
//     this.overdueCount = 0,
//     this.dueTodayCount = 0,
//     this.pagination,
//     this.selectedFilter = 'All',
//   });
// ...

class TasksState {
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final List<Task> tasks;
  final int totalCount;
  final int notStartedCount;
  final int inProgressCount;
  final int completedCount;
  final int overdueCount;
  final int upcomingCount;
  final int dueTodayCount;
  final int allCount;
  final Pagination? pagination;
  final String selectedFilter;

  // New Tab-by-Tab Category & Filter state
  final String selectedCategory; // 'overdue' | 'upcoming' | 'completed' | 'all'
  final String? quickDate;
  final String? dateField;
  final String? fromDue;
  final String? toDue;
  final String? assignedTo;
  final String? assignedToName;
  final String? sortBy;
  final String? statusFilter;
  final String searchQuery;

  const TasksState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.tasks = const [],
    this.totalCount = 0,
    this.notStartedCount = 0,
    this.inProgressCount = 0,
    this.completedCount = 0,
    this.overdueCount = 0,
    this.upcomingCount = 0,
    this.dueTodayCount = 0,
    this.allCount = 0,
    this.pagination,
    this.selectedFilter = 'All',
    this.selectedCategory = 'overdue',
    this.quickDate,
    this.dateField,
    this.fromDue,
    this.toDue,
    this.assignedTo,
    this.assignedToName,
    this.sortBy,
    this.statusFilter,
    this.searchQuery = '',
  });

  int get pendingCount => notStartedCount;

  bool get hasActiveFilters {
    return (fromDue != null && fromDue!.isNotEmpty) ||
        (toDue != null && toDue!.isNotEmpty) ||
        // (statusFilter != null && statusFilter!.isNotEmpty && statusFilter != 'All');
        (statusFilter != null && statusFilter!.isNotEmpty && statusFilter!.toLowerCase() != 'all');
  }

  TasksState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    List<Task>? tasks,
    int? totalCount,
    int? notStartedCount,
    int? inProgressCount,
    int? completedCount,
    int? overdueCount,
    int? upcomingCount,
    int? dueTodayCount,
    int? allCount,
    Pagination? pagination,
    String? selectedFilter,
    String? selectedCategory,
    String? quickDate,
    bool clearQuickDate = false,
    String? dateField,
    bool clearDateField = false,
    String? fromDue,
    bool clearFromDue = false,
    String? toDue,
    bool clearToDue = false,
    String? assignedTo,
    bool clearAssignedTo = false,
    String? assignedToName,
    bool clearAssignedToName = false,
    String? sortBy,
    String? statusFilter,
    bool clearStatusFilter = false,
    String? searchQuery,
  }) {
    return TasksState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      tasks: tasks ?? this.tasks,
      totalCount: totalCount ?? this.totalCount,
      notStartedCount: notStartedCount ?? this.notStartedCount,
      inProgressCount: inProgressCount ?? this.inProgressCount,
      completedCount: completedCount ?? this.completedCount,
      overdueCount: overdueCount ?? this.overdueCount,
      upcomingCount: upcomingCount ?? this.upcomingCount,
      dueTodayCount: dueTodayCount ?? this.dueTodayCount,
      allCount: allCount ?? this.allCount,
      pagination: pagination ?? this.pagination,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      quickDate: clearQuickDate ? null : (quickDate ?? this.quickDate),
      dateField: clearDateField ? null : (dateField ?? this.dateField),
      fromDue: clearFromDue ? null : (fromDue ?? this.fromDue),
      toDue: clearToDue ? null : (toDue ?? this.toDue),
      assignedTo: clearAssignedTo ? null : (assignedTo ?? this.assignedTo),
      assignedToName: clearAssignedToName ? null : (assignedToName ?? this.assignedToName),
      sortBy: sortBy ?? this.sortBy,
      statusFilter: clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class _TaskCategoryCache {
  final List<Task> tasks;
  final Pagination? pagination;
  final String? quickDate;
  final String? dateField;
  final String? fromDue;
  final String? toDue;
  final String? assignedTo;
  final String? assignedToName;
  final String? statusFilter;
  // final String sortBy;
  final String? sortBy;
  final DateTime timestamp;

  _TaskCategoryCache({
    required this.tasks,
    this.pagination,
    this.quickDate,
    this.dateField,
    this.fromDue,
    this.toDue,
    this.assignedTo,
    this.assignedToName,
    this.statusFilter,
    // required this.sortBy,
    this.sortBy,
    required this.timestamp,
  });
}

class TasksNotifier extends StateNotifier<TasksState> {
  final TaskService _taskService;
  // final Ref _ref;
  // Original:
  // int _currentLimit = 20;
  int _currentLimit = 10;
  final Map<String, _TaskCategoryCache> _categoryCache = {};

  // TasksNotifier(this._taskService) : super(const TasksState(
  //   selectedCategory: 'overdue',
  //   quickDate: 'all',
  //   sortBy: 'due_asc',
  // ));

  // TasksNotifier(this._taskService) : super(const TasksState(
  //   selectedCategory: 'overdue',
  //   quickDate: 'all',
  //   sortBy: 'due_asc',
  // )) {
  TasksNotifier(this._taskService) : super(const TasksState(
    selectedCategory: 'overdue',
    quickDate: 'overdue',
    sortBy: 'dueDate_asc',
  )) {
    _loadCachedCounts();
    fetchTabCounts();
  }

  Future<void> _loadCachedCounts() async {
    try {
      final box = await Hive.openBox('taskBox');
      final cached = box.get('task_tab_counts');
      if (cached != null && cached is Map && mounted) {
        state = state.copyWith(
          overdueCount: cached['overdue'] is int ? cached['overdue'] : int.tryParse(cached['overdue']?.toString() ?? '0'),
          upcomingCount: cached['upcoming'] is int ? cached['upcoming'] : int.tryParse(cached['upcoming']?.toString() ?? '0'),
          completedCount: cached['completed'] is int ? cached['completed'] : int.tryParse(cached['completed']?.toString() ?? '0'),
          allCount: cached['all'] is int ? cached['all'] : int.tryParse(cached['all']?.toString() ?? '0'),
        );
      }
    } catch (_) {}
  }

  Future<void> fetchTabCounts() async {
    try {
      final results = await Future.wait([
        _taskService.fetchTasks(page: 1, limit: 1, category: 'overdue', forceRefresh: true),
        _taskService.fetchTasks(page: 1, limit: 1, category: 'upcoming', forceRefresh: true),
        _taskService.fetchTasks(page: 1, limit: 1, category: 'completed', forceRefresh: true),
        _taskService.fetchTasks(page: 1, limit: 1, category: 'all', forceRefresh: true),
      ]);
      if (!mounted) return;

      int getCount(TaskData td) {
        if (td.pagination.totalCount > 0) return td.pagination.totalCount;
        if (td.totalCount > 0) return td.totalCount;
        return td.tasks.length;
      }

      final overdueTotal = getCount(results[0]);
      final upcomingTotal = getCount(results[1]);
      final completedTotal = getCount(results[2]);
      final allTotal = getCount(results[3]);

      state = state.copyWith(
        overdueCount: overdueTotal,
        upcomingCount: upcomingTotal,
        completedCount: completedTotal,
        allCount: allTotal,
      );

      try {
        final box = await Hive.openBox('taskBox');
        await box.put('task_tab_counts', {
          'overdue': overdueTotal,
          'upcoming': upcomingTotal,
          'completed': completedTotal,
          'all': allTotal,
        });
      } catch (_) {}
    } catch (e) {
      debugPrint("Error fetching tab counts: $e");
    }
  }

  // String _getDefaultSortForCategory(String category) {
  //   switch (category) {
  //     case 'overdue':
  //       return 'due_asc';
  //     case 'upcoming':
  //       return 'due_asc';
  //     case 'completed':
  //       return 'updated_desc';
  //     case 'all':
  //     default:
  //       return 'due_asc';
  //   }
  // }
  //
  // String? _getDefaultQuickDateForCategory(String category) {
  //   return 'all';
  // }

  String _getDefaultSortForCategory(String category) {
    switch (category) {
      case 'overdue':
        return 'dueDate_asc';
      case 'upcoming':
        return 'dueDate_asc';
      case 'completed':
        return 'updatedAt_desc';
      case 'all':
      default:
        return 'dueDate_asc';
    }
  }

  String? _getDefaultQuickDateForCategory(String category) {
    if (category == 'overdue') return 'overdue';
    return 'all';
  }

  void setCategory(String category) {
    if (state.selectedCategory != category) {
      // 1. Cache current tab's state if we have tasks and not actively searching
      if (state.tasks.isNotEmpty && state.searchQuery.isEmpty) {
        _categoryCache[state.selectedCategory] = _TaskCategoryCache(
          tasks: state.tasks,
          pagination: state.pagination,
          quickDate: state.quickDate,
          dateField: state.dateField,
          fromDue: state.fromDue,
          toDue: state.toDue,
          assignedTo: state.assignedTo,
          assignedToName: state.assignedToName,
          statusFilter: state.statusFilter,
          sortBy: state.sortBy,
          timestamp: DateTime.now(),
        );
      }

      // 2. If target category exists in cache (and no search query), restore instantly
      final cached = _categoryCache[category];
      if (cached != null && state.searchQuery.isEmpty) {
        state = state.copyWith(
          selectedCategory: category,
          tasks: cached.tasks,
          pagination: cached.pagination,
          quickDate: cached.quickDate,
          dateField: cached.dateField,
          clearDateField: cached.dateField == null,
          fromDue: cached.fromDue,
          clearFromDue: cached.fromDue == null,
          toDue: cached.toDue,
          clearToDue: cached.toDue == null,
          assignedTo: cached.assignedTo,
          clearAssignedTo: cached.assignedTo == null,
          assignedToName: cached.assignedToName,
          clearAssignedToName: cached.assignedToName == null,
          statusFilter: cached.statusFilter,
          clearStatusFilter: cached.statusFilter == null,
          sortBy: cached.sortBy,
          isLoading: false,
          isLoadingMore: false,
          error: null,
        );
        return;
      }

      // Original:
      // state = state.copyWith(
      //   selectedCategory: category,
      //   quickDate: _getDefaultQuickDateForCategory(category),
      //   clearDateField: true,
      //   clearFromDue: true,
      //   clearToDue: true,
      //   clearAssignedTo: true,
      //   clearAssignedToName: true,
      //   clearStatusFilter: true,
      //   sortBy: _getDefaultSortForCategory(category),
      //   tasks: [],
      //   pagination: null,
      // );
      // fetchTasks(page: 1, isRefresh: true, clearList: true);

      // 3. Not in cache: reset for new category and fetch from backend
      state = state.copyWith(
        selectedCategory: category,
        quickDate: _getDefaultQuickDateForCategory(category),
        clearDateField: true,
        clearFromDue: true,
        clearToDue: true,
        clearAssignedTo: true,
        clearAssignedToName: true,
        clearStatusFilter: true,
        sortBy: _getDefaultSortForCategory(category),
        tasks: [],
        pagination: null,
      );
      fetchTasks(page: 1, isRefresh: true, clearList: true);
    }
  }

  void setQuickDate(String? quickDate, {String? dateField}) {
    state = state.copyWith(
      quickDate: quickDate,
      dateField: dateField,
      clearDateField: dateField == null,
      clearFromDue: true,
      clearToDue: true,
      tasks: [],
      pagination: null,
    );
    fetchTasks(page: 1, isRefresh: true, clearList: true);
  }

  void setFilters({
    String? dateField,
    String? fromDue,
    String? toDue,
    String? assignedTo,
    String? assignedToName,
    String? statusFilter,
    String? status,
  }) {
    final effectiveStatus = statusFilter ?? status;
    state = state.copyWith(
      dateField: dateField,
      clearDateField: dateField == null,
      fromDue: fromDue,
      clearFromDue: fromDue == null,
      toDue: toDue,
      clearToDue: toDue == null,
      assignedTo: assignedTo,
      clearAssignedTo: assignedTo == null,
      assignedToName: assignedToName,
      clearAssignedToName: assignedToName == null,
      statusFilter: effectiveStatus,
      clearStatusFilter: effectiveStatus == null,
      clearQuickDate: (fromDue != null || toDue != null),
      tasks: [],
      pagination: null,
    );
    fetchTasks(page: 1, isRefresh: true, clearList: true);
  }

  void setSort(String sortBy) {
    if (state.sortBy != sortBy) {
      state = state.copyWith(sortBy: sortBy, tasks: [], pagination: null);
      fetchTasks(page: 1, isRefresh: true, clearList: true);
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery != query) {
      state = state.copyWith(searchQuery: query, tasks: [], pagination: null);
      fetchTasks(page: 1, isRefresh: true, clearList: true);
    }
  }

  void clearFilters() {
    state = state.copyWith(
      quickDate: _getDefaultQuickDateForCategory(state.selectedCategory),
      clearDateField: true,
      clearFromDue: true,
      clearToDue: true,
      clearAssignedTo: true,
      clearAssignedToName: true,
      clearStatusFilter: true,
      sortBy: _getDefaultSortForCategory(state.selectedCategory),
      tasks: [],
      pagination: null,
    );
    fetchTasks(page: 1, isRefresh: true, clearList: true);
  }

  void setFilter(String filter) {
    if (state.selectedFilter != filter) {
      state = state.copyWith(
        selectedFilter: filter,
        tasks: [],
        pagination: null,
      );
      fetchTasks(page: 1, isRefresh: true, clearList: true);
    }
  }

  void setLimit(int limit) {
    _currentLimit = limit;
    refresh();
  }

  Future<void> fetchStats() async {
    try {
      final taskData = await _taskService.fetchTasks(page: 1, limit: 1000, category: 'all');
      if (!mounted) return;
      
      int notStarted = 0;
      int completed = 0;
      int inProgress = 0;
      int overdue = 0;
      int upcoming = 0;
      int dueToday = 0;
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayEnd = todayStart.add(const Duration(days: 1));

      for (var task in taskData.tasks) {
        final isCompleted = task.status == 'Completed' || task.status == 'Done';
        final isNotStarted = task.status == 'Not Started' || task.status == 'Pending';
        final isInProgress = task.status == 'In Progress';

        if (isCompleted) {
          completed++;
        } else if (isNotStarted) {
          notStarted++;
        } else if (isInProgress) {
          inProgress++;
        }

        if (!isCompleted && task.dueDate != null) {
          try {
            final due = DateTimeUtils.parseSafe(task.dueDate);
            if (due != null) {
              if (due.isBefore(now)) {
                overdue++;
              } else {
                upcoming++;
              }
              if (due.isAfter(todayStart) && due.isBefore(todayEnd)) {
                dueToday++;
              }
            } else {
              upcoming++;
            }
          } catch (_) {
            upcoming++;
          }
        } else if (!isCompleted) {
          upcoming++;
        }
      }

      // If categoryCounts are provided directly by API
      // if (taskData.categoryCounts != null) {
      //   final cc = taskData.categoryCounts!;
      //   if (cc.containsKey('overdue')) overdue = cc['overdue']!;
      //   if (cc.containsKey('upcoming')) upcoming = cc['upcoming']!;
      //   if (cc.containsKey('completed')) completed = cc['completed']!;
      // }
      //
      // state = state.copyWith(
      //   totalCount: taskData.totalCount > 0 ? taskData.totalCount : taskData.tasks.length,
      //   allCount: taskData.totalCount > 0 ? taskData.totalCount : taskData.tasks.length,
      //   notStartedCount: notStarted,
      //   inProgressCount: inProgress,
      //   completedCount: completed,
      //   overdueCount: overdue,
      //   upcomingCount: upcoming,
      //   dueTodayCount: dueToday,
      // );

      if (taskData.categoryCounts != null && taskData.categoryCounts!.isNotEmpty) {
        final cc = taskData.categoryCounts!;
        if (cc.containsKey('overdue')) overdue = cc['overdue']!;
        if (cc.containsKey('upcoming')) upcoming = cc['upcoming']!;
        if (cc.containsKey('completed')) completed = cc['completed']!;
        state = state.copyWith(
          totalCount: taskData.totalCount > 0 ? taskData.totalCount : taskData.tasks.length,
          allCount: taskData.totalCount > 0 ? taskData.totalCount : taskData.tasks.length,
          notStartedCount: notStarted,
          inProgressCount: inProgress,
          completedCount: completed,
          overdueCount: overdue,
          upcomingCount: upcoming,
          dueTodayCount: dueToday,
        );
      } else {
        // Tab counts are accurately managed by fetchTabCounts() and fetchTasks(),
        // so do not overwrite them with single-page iteration numbers!
        state = state.copyWith(
          totalCount: taskData.totalCount > 0 ? taskData.totalCount : state.totalCount,
          notStartedCount: notStarted,
          inProgressCount: inProgress,
          dueTodayCount: dueToday,
        );
      }
    } catch (_) {}
  }

  Future<void> fetchTasks({int page = 1, bool isRefresh = false, bool clearList = false}) async {
    if (page > 1 && state.pagination != null && !state.pagination!.hasNextPage) {
      return;
    }

    if (!isRefresh && !clearList) {
      if (state.isLoading || state.isLoadingMore) return;
    }

    final requestedCategory = state.selectedCategory;
    final requestedQuery = state.searchQuery;

    if (page == 1 || clearList) {
      state = state.copyWith(isLoading: true, tasks: (isRefresh || clearList) ? [] : state.tasks, error: null);
    } else {
      state = state.copyWith(isLoadingMore: true, error: null);
    }

    try {
      final taskData = await _taskService.fetchTasks(
        page: page, 
        limit: _currentLimit,
        forceRefresh: isRefresh || clearList,
        category: state.selectedCategory,
        quickDate: state.quickDate,
        dateField: state.dateField,
        fromDue: state.fromDue,
        toDue: state.toDue,
        assignedTo: state.assignedTo,
        searchQuery: state.searchQuery,
        sortBy: state.sortBy,
        status: state.statusFilter,
      );
      if (!mounted) return;

      if (requestedCategory != state.selectedCategory || requestedQuery != state.searchQuery) return;
      
      final newPagination = taskData.pagination;
      
      List<Task> newTasks;
      if (page == 1 || clearList) {
        newTasks = taskData.tasks;
      } else {
        final existingIds = state.tasks.map((t) => t.id).toSet();
        final uniqueNewTasks = taskData.tasks.where((t) => !existingIds.contains(t.id)).toList();
        newTasks = [...state.tasks, ...uniqueNewTasks];
      }

      // state = state.copyWith(
      //   tasks: newTasks,
      //   isLoading: false,
      //   isLoadingMore: false,
      //   pagination: newPagination,
      //   error: null,
      // );

      int overdueCount = state.overdueCount;
      int upcomingCount = state.upcomingCount;
      int completedCount = state.completedCount;
      int allCount = state.allCount;

      final currentTotal = newPagination.totalCount > 0
          ? newPagination.totalCount
          : (taskData.totalCount > 0 ? taskData.totalCount : newTasks.length);

      if (taskData.categoryCounts != null && taskData.categoryCounts!.isNotEmpty) {
        final cc = taskData.categoryCounts!;
        if (cc.containsKey('overdue')) overdueCount = cc['overdue']!;
        if (cc.containsKey('upcoming')) upcomingCount = cc['upcoming']!;
        if (cc.containsKey('completed')) completedCount = cc['completed']!;
        if (cc.containsKey('all')) allCount = cc['all']!;
        if (cc.containsKey('total') && !cc.containsKey('all')) allCount = cc['total']!;
      } else {
        if (requestedCategory == 'overdue') overdueCount = currentTotal;
        if (requestedCategory == 'upcoming') upcomingCount = currentTotal;
        if (requestedCategory == 'completed') completedCount = currentTotal;
        if (requestedCategory == 'all') allCount = currentTotal;
      }

      state = state.copyWith(
        tasks: newTasks,
        isLoading: false,
        isLoadingMore: false,
        pagination: newPagination,
        overdueCount: overdueCount,
        upcomingCount: upcomingCount,
        completedCount: completedCount,
        allCount: allCount,
        error: null,
      );

      // Cache page 1 results for this category when no active search query
      if (requestedCategory == state.selectedCategory && requestedQuery.isEmpty) {
        _categoryCache[requestedCategory] = _TaskCategoryCache(
          tasks: newTasks,
          pagination: newPagination,
          quickDate: state.quickDate,
          dateField: state.dateField,
          fromDue: state.fromDue,
          toDue: state.toDue,
          assignedTo: state.assignedTo,
          assignedToName: state.assignedToName,
          statusFilter: state.statusFilter,
          sortBy: state.sortBy,
          timestamp: DateTime.now(),
        );
      }

      // On first load or refresh, update stats
      if (page == 1) {
        fetchStats();
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, isLoadingMore: false, error: e.toString());
    }
  }

  // Future<void> refresh() async {
  //   await fetchTasks(page: 1, isRefresh: true);
  //   fetchTabCounts();
  // }

  Future<void> refresh() async {
    _categoryCache.remove(state.selectedCategory);
    await fetchTasks(page: 1, isRefresh: true);
    fetchTabCounts();
  }

  // Future<void> createTask(Map<String, dynamic> data) async {
  //   try {
  //     await _taskService.createTask(data);
  //     if (!mounted) return;
  //     await refresh();
  //     fetchTabCounts();
  //   } catch (e) {
  //     if (!mounted) return;
  //     state = state.copyWith(error: e.toString());
  //     rethrow;
  //   }
  // }

  Future<void> createTask(Map<String, dynamic> data) async {
    try {
      await _taskService.createTask(data);
      if (!mounted) return;
      _categoryCache.clear();
      await refresh();
      fetchTabCounts();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // Future<void> updateTask(String id, Map<String, dynamic> data) async {
  //   try {
  //     await _taskService.updateTask(id, data);
  //     if (!mounted) return;
  //     await refresh();
  //     fetchTabCounts();
  //   } catch (e) {
  //     if (!mounted) return;
  //     state = state.copyWith(error: e.toString());
  //     rethrow;
  //   }
  // }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
    try {
      await _taskService.updateTask(id, data);
      if (!mounted) return;
      _categoryCache.clear();
      await refresh();
      fetchTabCounts();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(error: e.toString());
      rethrow;
    }
  }

  // Future<void> deleteTask(String id) async {
  //   // Optimistic update
  //   final previousTasks = state.tasks;
  //   state = state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList());
  // 
  //   try {
  //     await _taskService.deleteTask(id);
  //     fetchTabCounts();
  //   } catch (e) {
  //     if (!mounted) return;
  //     state = state.copyWith(tasks: previousTasks, error: "Failed to delete task");
  //     rethrow;
  //   }
  // }

  Future<void> deleteTask(String id) async {
    // Optimistic update
    final previousTasks = state.tasks;
    state = state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList());

    try {
      await _taskService.deleteTask(id);
      _categoryCache.clear();
      fetchTabCounts();
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(tasks: previousTasks, error: "Failed to delete task");
      rethrow;
    }
  }
}

final taskServiceProvider = Provider<TaskService>((ref) => TaskService());

final tasksProvider = StateNotifierProvider<TasksNotifier, TasksState>((ref) {
  final taskService = ref.watch(taskServiceProvider);
  return TasksNotifier(taskService);
});
