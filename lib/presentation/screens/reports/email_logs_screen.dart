import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../core/services/report_service.dart';
import '../../../data/models/email_log_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/email_log_card.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../widgets/access_denied_widget.dart';

class EmailLogState {
  final AsyncValue<List<EmailLogModel>> logs;
  final String searchQuery;
  final String providerFilter;
  final String typeFilter;
  final int activeFilterCount;

  EmailLogState({
    required this.logs,
    this.searchQuery = '',
    this.providerFilter = 'All',
    this.typeFilter = 'All',
  }) : activeFilterCount = (providerFilter != 'All' ? 1 : 0) + (typeFilter != 'All' ? 1 : 0);

  EmailLogState copyWith({
    AsyncValue<List<EmailLogModel>>? logs,
    String? searchQuery,
    String? providerFilter,
    String? typeFilter,
  }) {
    return EmailLogState(
      logs: logs ?? this.logs,
      searchQuery: searchQuery ?? this.searchQuery,
      providerFilter: providerFilter ?? this.providerFilter,
      typeFilter: typeFilter ?? this.typeFilter,
    );
  }
}

final emailLogPaginationProvider = StateNotifierProvider.autoDispose<EmailLogNotifier, EmailLogState>((ref) {
  return EmailLogNotifier(ref);
});

class EmailLogNotifier extends StateNotifier<EmailLogState> {
  final Ref ref;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  Timer? _debounce;

  EmailLogNotifier(this.ref) : super(EmailLogState(logs: const AsyncValue.loading())) {
    _fetchInitial();
  }

  Future<void> _fetchInitial() async {
    try {
      final service = ref.read(reportServiceProvider);
      final fetchedLogs = await service.fetchEmailLogs(
        page: 1, 
        limit: 15,
        searchQuery: state.searchQuery,
        provider: state.providerFilter,
        type: state.typeFilter,
      );
      _page = 1;
      _hasMore = fetchedLogs.isNotEmpty; 
      state = state.copyWith(logs: AsyncValue.data(fetchedLogs));
    } catch (e, st) {
      state = state.copyWith(logs: AsyncValue.error(e, st));
    }
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    
    try {
      final service = ref.read(reportServiceProvider);
      final nextLogs = await service.fetchEmailLogs(
        page: _page + 1, 
        limit: 15,
        searchQuery: state.searchQuery,
        provider: state.providerFilter,
        type: state.typeFilter,
      );
      
      if (nextLogs.isEmpty) {
        _hasMore = false;
      } else {
        _page++;
        final current = state.logs.value ?? [];
        state = state.copyWith(logs: AsyncValue.data([...current, ...nextLogs]));
      }
    } catch (e) {
      // Ignore
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> refresh() async {
     state = state.copyWith(logs: const AsyncValue.loading());
     await _fetchInitial();
  }

  void setSearchQuery(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (state.searchQuery != query) {
        state = state.copyWith(searchQuery: query, logs: const AsyncValue.loading());
        _fetchInitial();
      }
    });
  }

  void setFilters(String provider, String type) {
    state = state.copyWith(providerFilter: provider, typeFilter: type, logs: const AsyncValue.loading());
    _fetchInitial();
  }
}

class EmailLogsScreen extends ConsumerStatefulWidget {
  const EmailLogsScreen({super.key});

  @override
  ConsumerState<EmailLogsScreen> createState() => _EmailLogsScreenState();
}

class _EmailLogsScreenState extends ConsumerState<EmailLogsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

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
      ref.read(emailLogPaginationProvider.notifier).loadMore();
    }
  }

  void _showFilters() {
    final state = ref.read(emailLogPaginationProvider);
    String tempProvider = state.providerFilter;
    String tempType = state.typeFilter;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Email Logs Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Provider', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tempProvider,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: ['All', 'Gmail', 'Outlook'].map((e) {
                    return DropdownMenuItem(value: e, child: Text(e));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => tempProvider = val);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Mail Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tempType,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: ['All', 'Marketing', 'Meeting', 'Personal', 'Other'].map((e) {
                    return DropdownMenuItem(value: e, child: Text(e));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => tempType = val);
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        setModalState(() {
                          tempProvider = 'All';
                          tempType = 'All';
                        });
                      },
                      child: const Text('RESET FILTERS', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            ref.read(emailLogPaginationProvider.notifier).setFilters(tempProvider, tempType);
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('APPLY', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
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

        appBar: GlobalAppBar(title: "Email Logs"),
        body: AccessDeniedWidget(
          sectionName: "Email Logs",
          showAppBar: false,
        ),
      );
    }

    final state = ref.watch(emailLogPaginationProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const GlobalAppBar(title: 'Email Logs'),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Email Logs', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Track who sent email and when.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 16),
                
                // Search Box
                TextField(
                  controller: _searchController,
                  onChanged: (val) => ref.read(emailLogPaginationProvider.notifier).setSearchQuery(val),
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Buttons Row
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showFilters,
                      icon: const Icon(Icons.tune, size: 18),
                      label: Text('Filters ${state.activeFilterCount > 0 ? "(${state.activeFilterCount})" : ""}'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => ref.read(emailLogPaginationProvider.notifier).refresh(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.all(12),
                        minimumSize: const Size(48, 40),
                      ),
                      child: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(emailLogPaginationProvider.notifier).refresh(),
              child: state.logs.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 100),
                        Center(child: Text("No email logs found.")),
                      ],
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: logs.length + 1, 
                    itemBuilder: (context, index) {
                      if (index == logs.length) {
                         if (!_hasMore(ref)) return const SizedBox.shrink();
                         return const SizedBox(height: 50, child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))); 
                      }
                      return EmailLogCard(log: logs[index]);
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasMore(WidgetRef ref) {
     return ref.read(emailLogPaginationProvider.notifier)._hasMore;
  }
}
