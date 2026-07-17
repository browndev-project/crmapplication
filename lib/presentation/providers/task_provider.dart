
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/models/task_model.dart';
import '../../core/services/task_service.dart';
import '../../core/utils/date_utils.dart';

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
  final int dueTodayCount;
  final Pagination? pagination;
  final String selectedFilter;

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
    this.dueTodayCount = 0,
    this.pagination,
    this.selectedFilter = 'All',
  });

  int get pendingCount => notStartedCount;

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
    int? dueTodayCount,
    Pagination? pagination,
    String? selectedFilter,
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
      dueTodayCount: dueTodayCount ?? this.dueTodayCount,
      pagination: pagination ?? this.pagination,
      selectedFilter: selectedFilter ?? this.selectedFilter,
    );
  }
}

class TasksNotifier extends StateNotifier<TasksState> {
  final TaskService _taskService;
  int _currentLimit = 20;

  TasksNotifier(this._taskService) : super(const TasksState());

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
      final taskData = await _taskService.fetchTasks(page: 1, limit: 1000);
      if (!mounted) return;
      
      int notStarted = 0;
      int completed = 0;
      int inProgress = 0;
      int overdue = 0;
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
                      if (due.isBefore(now)) overdue++;
                      if (due.isAfter(todayStart) && due.isBefore(todayEnd)) {
                          dueToday++;
                      }
                  }
              } catch (_) {}
          }
      }

      state = state.copyWith(
        totalCount: taskData.tasks.length,
        notStartedCount: notStarted,
        inProgressCount: inProgress,
        completedCount: completed,
        overdueCount: overdue,
        dueTodayCount: dueToday,
      );
    } catch (_) {}
  }


  Future<void> fetchTasks({int page = 1, bool isRefresh = false, bool clearList = false}) async {
    if (page > 1 && state.pagination != null && !state.pagination!.hasNextPage) {
        return;
    }

    if (!isRefresh && !clearList) {
      if (state.isLoading || state.isLoadingMore) return;
    }

    final requestedFilter = state.selectedFilter;

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
        status: state.selectedFilter,
      );
      if (!mounted) return;

      if (requestedFilter != state.selectedFilter) return;
      
      final newPagination = taskData.pagination;
      
      List<Task> newTasks;
      if (page == 1 || clearList) {
          newTasks = taskData.tasks;
      } else {
          // PREVENT DUPLICATES: Filter out tasks that already exist in the list
          final existingIds = state.tasks.map((t) => t.id).toSet();
          final uniqueNewTasks = taskData.tasks.where((t) => !existingIds.contains(t.id)).toList();
          newTasks = [...state.tasks, ...uniqueNewTasks];
      }

      state = state.copyWith(
        tasks: newTasks,
        isLoading: false,
        isLoadingMore: false,
        pagination: newPagination,
        error: null,
      );

      // On first load or refresh, also update stats
      if (page == 1) {
          fetchStats();
      }
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, isLoadingMore: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    await fetchTasks(page: 1, isRefresh: true);
  }

  Future<void> createTask(Map<String, dynamic> data) async {
      try {
          await _taskService.createTask(data);
          if (!mounted) return;
          await refresh();
      } catch (e) {
          if (!mounted) return;
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> updateTask(String id, Map<String, dynamic> data) async {
      try {
          await _taskService.updateTask(id, data);
          if (!mounted) return;
          await refresh();
      } catch (e) {
          if (!mounted) return;
          state = state.copyWith(error: e.toString());
          rethrow;
      }
  }

  Future<void> deleteTask(String id) async {
       // Optimistic update
      final previousTasks = state.tasks;
      state = state.copyWith(tasks: state.tasks.where((t) => t.id != id).toList());

      try {
          await _taskService.deleteTask(id);
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
