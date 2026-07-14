import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/services/report_service.dart';
import '../../../data/models/download_log_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/download_log_card.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../widgets/access_denied_widget.dart';

// Pagination Provider
final downloadLogPaginationProvider = StateNotifierProvider.autoDispose<DownloadLogNotifier, AsyncValue<List<DownloadLogModel>>>((ref) {
  return DownloadLogNotifier(ref);
});

class DownloadLogNotifier extends StateNotifier<AsyncValue<List<DownloadLogModel>>> {
  final Ref ref;
  int _page = 1;
  bool hasMore = true;
  bool _isLoadingMore = false;

  // Filter values
  String? _selectedModule;
  String? _selectedFormat;
  String? _selectedStatus;
  String? _searchQuery;

  DownloadLogNotifier(this.ref) : super(const AsyncValue.loading()) {
    _fetchInitial();
  }

  Future<void> updateFilters({
    String? module,
    String? format,
    String? status,
    String? searchQuery,
  }) async {
    _selectedModule = module;
    _selectedFormat = format;
    _selectedStatus = status;
    _searchQuery = searchQuery;

    state = const AsyncValue.loading();
    await _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    try {
      final service = ref.read(reportServiceProvider);
      // Map 'All' values to null/empty so they don't filter in API
      final moduleParam = (_selectedModule == 'All' || _selectedModule == null) ? null : _selectedModule;
      final formatParam = (_selectedFormat == 'All' || _selectedFormat == null) ? null : _selectedFormat;
      final statusParam = (_selectedStatus == 'All' || _selectedStatus == null) ? null : _selectedStatus;

      final logs = await service.fetchDownloadLogs(
        page: 1,
        limit: 15,
        module: moduleParam,
        format: formatParam,
        status: statusParam,
        user: _searchQuery,
      );
      _page = 1;
      hasMore = logs.isNotEmpty;
      state = AsyncValue.data(logs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !hasMore) return;
    _isLoadingMore = true;

    try {
      final service = ref.read(reportServiceProvider);
      final moduleParam = (_selectedModule == 'All' || _selectedModule == null) ? null : _selectedModule;
      final formatParam = (_selectedFormat == 'All' || _selectedFormat == null) ? null : _selectedFormat;
      final statusParam = (_selectedStatus == 'All' || _selectedStatus == null) ? null : _selectedStatus;

      final nextLogs = await service.fetchDownloadLogs(
        page: _page + 1,
        limit: 15,
        module: moduleParam,
        format: formatParam,
        status: statusParam,
        user: _searchQuery,
      );

      if (nextLogs.isEmpty) {
        hasMore = false;
      } else {
        _page++;
        final current = state.value ?? [];
        state = AsyncValue.data([...current, ...nextLogs]);
      }
    } catch (e) {
      // ignore
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _fetchInitial();
  }
}

class DownloadLogsScreen extends ConsumerStatefulWidget {
  const DownloadLogsScreen({super.key});

  @override
  ConsumerState<DownloadLogsScreen> createState() => _DownloadLogsScreenState();
}

class _DownloadLogsScreenState extends ConsumerState<DownloadLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // State variables for currently selected filters
  String _selectedModule = 'All';
  String _selectedFormat = 'All';
  String _selectedStatus = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(downloadLogPaginationProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
    });
    ref.read(downloadLogPaginationProvider.notifier).updateFilters(
          module: _selectedModule,
          format: _selectedFormat,
          status: _selectedStatus,
          searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
        );
  }

  void _showFiltersDialog() {
    String tempModule = _selectedModule;
    String tempFormat = _selectedFormat;
    String tempStatus = _selectedStatus;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Download Logs Filters',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Module Filter Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: tempModule,
                      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Module',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 13),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['All', 'Leads', 'Tasks', 'Meetings', 'Services', 'Attendance', 'Reports', 'Assets', 'Other']
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => tempModule = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Format Filter Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: tempFormat,
                      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Format',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 13),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['All', 'XLSX', 'CSV', 'PDF']
                          .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => tempFormat = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Status Filter Dropdown
                    DropdownButtonFormField<String>(
                      initialValue: tempStatus,
                      dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700, fontSize: 13),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['All', 'Started', 'Success', 'Failed']
                          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => tempStatus = val);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          tempModule = 'All';
                          tempFormat = 'All';
                          tempStatus = 'All';
                        });
                        setState(() {
                          _selectedModule = 'All';
                          _selectedFormat = 'All';
                          _selectedStatus = 'All';
                        });
                        ref.read(downloadLogPaginationProvider.notifier).updateFilters(
                              module: 'All',
                              format: 'All',
                              status: 'All',
                              searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
                            );
                        Navigator.of(context).pop();
                      },
                      child: const Text(
                        'RESET FILTERS',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedModule = tempModule;
                              _selectedFormat = tempFormat;
                              _selectedStatus = tempStatus;
                            });
                            ref.read(downloadLogPaginationProvider.notifier).updateFilters(
                                  module: tempModule,
                                  format: tempFormat,
                                  status: tempStatus,
                                  searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
                                );
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          child: const Text(
                            'APPLY',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.hasModule(
      PermissionModules.REPORTS_BASE,
      userRole: userRole,
    );

    if (!canView) {
      return const Scaffold(
        appBar: GlobalAppBar(title: "Download Logs"),
        body: AccessDeniedWidget(
          sectionName: "Download Logs",
          showAppBar: false,
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logsAsync = ref.watch(downloadLogPaginationProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: const GlobalAppBar(title: 'Download Logs'),
      body: RefreshIndicator(
        onRefresh: () => ref.read(downloadLogPaginationProvider.notifier).refresh(),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Refresh Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Logs',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Track who downloaded data and when.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(downloadLogPaginationProvider.notifier).refresh();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white70 : Colors.black87,
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      padding: const EdgeInsets.all(10),
                    ),
                    child: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Main Logs Card Container
              Card(
                margin: EdgeInsets.zero,
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logs',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'View download history by module, format and status.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Search text input
                      TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Search logs...',
                          hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey),
                          prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.white30 : Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade300),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Filters toggle buttons row
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: _showFiltersDialog,
                            icon: Icon(Icons.tune, size: 16, color: isDark ? Colors.white70 : Colors.black87),
                            label: Text(
                              'Filters',
                              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () {
                              ref.read(downloadLogPaginationProvider.notifier).refresh();
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? Colors.white70 : Colors.black87,
                              side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              padding: const EdgeInsets.all(8),
                            ),
                            child: const Icon(Icons.refresh, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Logs List inside the card
                      logsAsync.when(
                        data: (logs) {
                          if (logs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40.0),
                              child: Center(
                                child: Text(
                                  "No download logs found.",
                                  style: TextStyle(color: isDark ? Colors.white38 : Colors.grey),
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: logs.length + (ref.read(downloadLogPaginationProvider.notifier).hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == logs.length) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.0),
                                  child: Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                );
                              }
                              return DownloadLogCard(log: logs[index]);
                            },
                          );
                        },
                        loading: () => const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                        error: (err, stack) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40.0),
                          child: Center(
                            child: Text(
                              'Error: $err',
                              style: const TextStyle(color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
