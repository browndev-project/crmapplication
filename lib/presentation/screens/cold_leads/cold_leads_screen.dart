import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/roles.dart';
import '../../providers/login_provider.dart';
import '../../providers/cold_lead_provider.dart';
import '../../../data/models/cold_lead_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/access_denied_widget.dart';
import '../../widgets/common_shimmer_skeleton.dart';

class ColdLeadsScreen extends ConsumerStatefulWidget {
  const ColdLeadsScreen({super.key});

  @override
  ConsumerState<ColdLeadsScreen> createState() => _ColdLeadsScreenState();
}

class _ColdLeadsScreenState extends ConsumerState<ColdLeadsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _chipScrollController = ScrollController();
  late PageController _pageController;
  Timer? _debounceTimer;

  static const List<String> _statusOptions = [
    'All',
    'New',
    'Connected',
    'Not Connected',
    'Invalid',
    'Qualified',
    'Unqualified',
  ];

  // @override
  // void initState() {
  //   super.initState();
  //   _scrollController.addListener(_onScroll);
  // }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    final currentStatus = ref.read(coldLeadsProvider).selectedStatus;
    final initialIndex = _statusOptions.indexWhere(
      (s) => s.toLowerCase() == currentStatus.toLowerCase(),
    );
    _pageController = PageController(initialPage: initialIndex != -1 ? initialIndex : 0);
  }

  // @override
  // void dispose() {
  //   _debounceTimer?.cancel();
  //   _searchController.dispose();
  //   _scrollController.dispose();
  //   super.dispose();
  // }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _chipScrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _scrollToStatusChip(int index) {
    if (!_chipScrollController.hasClients) return;
    final targetOffset = (index * 95.0 - 40.0).clamp(
      0.0,
      _chipScrollController.position.maxScrollExtent,
    );
    _chipScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(coldLeadsProvider.notifier).loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      ref.read(coldLeadsProvider.notifier).setSearchQuery(query.trim());
    });
  }

  Future<void> _makeCall(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No valid phone number available')),
      );
      return;
    }
    final uri = Uri.parse('tel:$cleanPhone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch call: $e')),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'new':
        return const Color(0xFF2563EB); // Blue
      case 'connected':
        return const Color(0xFF16A34A); // Green
      case 'not connected':
        return const Color(0xFFEA580C); // Orange
      case 'invalid':
        return const Color(0xFFDC2626); // Red
      case 'qualified':
        return const Color(0xFF059669); // Emerald
      case 'unqualified':
        return const Color(0xFF64748B); // Slate
      default:
        return const Color(0xFF6B7280);
    }
  }

  void _showUpdateSheet(BuildContext context, ColdLead lead) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String selectedStatus = lead.status;
    final notesController = TextEditingController(text: lead.notes ?? '');
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sheet Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Update Cold Lead',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lead.name} • ${lead.phoneNo}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                    const Divider(height: 24),

                    // Status selection
                    Text(
                      'Select Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _statusOptions
                          .where((s) => s != 'All')
                          .map((status) {
                        final isSelected = selectedStatus.toLowerCase() == status.toLowerCase();
                        final color = _getStatusColor(status);
                        return ChoiceChip(
                          label: Text(status),
                          selected: isSelected,
                          selectedColor: color.withValues(alpha: 0.15),
                          backgroundColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? color
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                          side: BorderSide(
                            color: isSelected ? color : Colors.transparent,
                            width: 1.5,
                          ),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                selectedStatus = status;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Notes input
                    Text(
                      'Notes / Feedback',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Enter notes or call feedback...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: Color(0xFF2563EB),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              side: BorderSide(
                                color: isDark ? Colors.white24 : const Color(0xFF0F172A),
                              ),
                              foregroundColor:
                                  isDark ? Colors.white : const Color(0xFF0F172A),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    setModalState(() => isSaving = true);
                                    final success = await ref
                                        .read(coldLeadsProvider.notifier)
                                        .updateStatusAndNotes(
                                          lead.id,
                                          status: selectedStatus,
                                          notes: notesController.text.trim(),
                                        );
                                    if (context.mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            success
                                                ? 'Cold lead updated successfully'
                                                : 'Failed to update cold lead',
                                          ),
                                          backgroundColor: success
                                              ? const Color(0xFF16A34A)
                                              : Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Save Changes',
                                    style: TextStyle(fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, ColdLead lead) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text('Delete Cold Lead', style: TextStyle(fontSize: 18)),
            ],
          ),
          content: Text(
            'Are you sure you want to delete ${lead.name}? This action cannot be undone.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final success = await ref
                    .read(coldLeadsProvider.notifier)
                    .deleteColdLead(lead.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? '${lead.name} deleted successfully'
                            : 'Failed to delete cold lead',
                      ),
                      backgroundColor: success ? Colors.black87 : Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(loginProvider).user;
    final systemRole = user?.systemRole;

    // Strict Admin Access Guard
    final isAdmin = systemRole == SystemRoles.COMPANY_ADMIN ||
        systemRole == SystemRoles.COMPANY;
    if (!isAdmin) {
      // Original:
      // return const AccessDeniedWidget(moduleName: 'Cold Data');
      return const AccessDeniedWidget(sectionName: 'Cold Data');
    }

    final state = ref.watch(coldLeadsProvider);

    ref.listen(coldLeadsProvider, (previous, next) {
      if (previous?.selectedStatus != next.selectedStatus) {
        final targetIndex = _statusOptions.indexWhere(
          (s) => s.toLowerCase() == next.selectedStatus.toLowerCase(),
        );
        if (targetIndex != -1 && _pageController.hasClients) {
          if ((_pageController.page?.round() ?? -1) != targetIndex) {
            _pageController.animateToPage(
              targetIndex,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
          _scrollToStatusChip(targetIndex);
        }
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: const GlobalAppBar(title: 'Cold Data'),
      body: Column(
        children: [
          // Top Search & Status Filter Section
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search Input Field
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search by name, phone or notes...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 20,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Status Filter Chips
                // SingleChildScrollView(
                //   scrollDirection: Axis.horizontal,
                //   child: Row(
                //     children: _statusOptions.map((status) {
                //       final isSelected =
                //           state.selectedStatus.toLowerCase() == status.toLowerCase();
                //       final chipColor = status == 'All'
                //           ? const Color(0xFF2563EB)
                //           : _getStatusColor(status);
                //
                //       return Padding(
                //         padding: const EdgeInsets.only(right: 8),
                //         child: FilterChip(
                //           label: Text(status),
                //           selected: isSelected,
                //           onSelected: (_) {
                //             ref
                //                 .read(coldLeadsProvider.notifier)
                //                 .setStatusFilter(status);
                //           },
                SingleChildScrollView(
                  controller: _chipScrollController,
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _statusOptions.map((status) {
                      final isSelected =
                          state.selectedStatus.toLowerCase() == status.toLowerCase();
                      final chipColor = status == 'All'
                          ? const Color(0xFF2563EB)
                          : _getStatusColor(status);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(status),
                          selected: isSelected,
                          onSelected: (_) {
                            final idx = _statusOptions.indexOf(status);
                            if (_pageController.hasClients &&
                                (_pageController.page?.round() ?? -1) != idx) {
                              _pageController.animateToPage(
                                idx,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                            ref
                                .read(coldLeadsProvider.notifier)
                                .setStatusFilter(status);
                            _scrollToStatusChip(idx);
                          },
                          backgroundColor: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          selectedColor: chipColor.withValues(alpha: 0.15),
                          checkmarkColor: chipColor,
                          side: BorderSide(
                            color: isSelected ? chipColor : Colors.transparent,
                            width: 1.2,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected
                                ? chipColor
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Count summary bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${state.totalCount} Cold Lead${state.totalCount == 1 ? '' : 's'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                if (state.selectedStatus != 'all')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getStatusColor(state.selectedStatus)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Filtered: ${state.selectedStatus}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(state.selectedStatus),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Lead Cards List (Swipeable via PageView)
          // Expanded(
          //   child: RefreshIndicator(
          //     onRefresh: () async {
          //       await ref
          //           .read(coldLeadsProvider.notifier)
          //           .fetchColdLeads(isRefresh: true);
          //     },
          //     child: _buildListContent(state, isDark),
          //   ),
          // ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _statusOptions.length,
              onPageChanged: (index) {
                final targetStatus = _statusOptions[index];
                ref
                    .read(coldLeadsProvider.notifier)
                    .setStatusFilter(targetStatus);
                _scrollToStatusChip(index);
              },
              itemBuilder: (context, index) {
                final pageStatus = _statusOptions[index];
                return RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(coldLeadsProvider.notifier)
                        .fetchColdLeads(isRefresh: true);
                  },
                  child: _buildListForStatus(pageStatus, state, isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListForStatus(String status, ColdLeadsState state, bool isDark) {
    if (status.toLowerCase() == state.selectedStatus.toLowerCase()) {
      return _buildListContent(state, isDark);
    }
    final cachedLeads = ref.read(coldLeadsProvider.notifier).getCachedLeadsForStatus(status);
    if (cachedLeads != null) {
      return _buildCachedList(cachedLeads, isDark, status);
    }
    return const SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: AppShimmerCardSkeleton(itemCount: 5),
    );
  }

  Widget _buildCachedList(List<ColdLead> leads, bool isDark, String status) {
    if (leads.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 64,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Cold Leads Found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: leads.length,
      itemBuilder: (context, index) => _buildLeadCard(leads[index], isDark),
    );
  }

  Widget _buildListContent(ColdLeadsState state, bool isDark) {
    if (state.isLoading && state.coldLeads.isEmpty) {
      // Original:
      // return ListView.builder(
      //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      //   itemCount: 5,
      //   itemBuilder: (_, __) => const Padding(
      //     padding: EdgeInsets.only(bottom: 12),
      //     child: AppShimmerCardSkeleton(height: 140),
      //   ),
      // );
      return const SingleChildScrollView(
        child: AppShimmerCardSkeleton(itemCount: 5),
      );
    }

    if (state.error != null && state.coldLeads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Failed to load cold leads',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                state.error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref
                      .read(coldLeadsProvider.notifier)
                      .fetchColdLeads(isRefresh: true);
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.coldLeads.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.folder_open_rounded,
                  size: 64,
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Cold Leads Found',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  state.searchQuery.isNotEmpty || state.selectedStatus != 'all'
                      ? 'No leads matched your search criteria.'
                      : 'No cold data has been imported yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Original:
    // return ListView.builder(
    //   controller: _scrollController,
    //   physics: const AlwaysScrollableScrollPhysics(),
    //   padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
    //   itemCount: state.coldLeads.length + (state.isMoreLoading ? 1 : 0),
    //   itemBuilder: (context, index) {
    //     if (index == state.coldLeads.length) {
    //       return const Padding(
    //         padding: EdgeInsets.symmetric(vertical: 16),
    //         child: Center(
    //           child: SizedBox(
    //             width: 24,
    //             height: 24,
    //             child: CircularProgressIndicator(strokeWidth: 2),
    //           ),
    //         ),
    //       );
    //     }
    //
    //     final lead = state.coldLeads[index];
    //     return _buildLeadCard(lead, isDark);
    //   },
    // );
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        if (scrollInfo.metrics.pixels >=
            scrollInfo.metrics.maxScrollExtent - 200) {
          ref.read(coldLeadsProvider.notifier).loadMore();
        }
        return false;
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: state.coldLeads.length + (state.isMoreLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == state.coldLeads.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final lead = state.coldLeads[index];
          return _buildLeadCard(lead, isDark);
        },
      ),
    );
  }

  Widget _buildLeadCard(ColdLead lead, bool isDark) {
    final statusColor = _getStatusColor(lead.status);
    final dateStr = lead.createdAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(lead.createdAt!)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Name, Status Badge, Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  child: Text(
                    lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      if (lead.source != null && lead.source!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          lead.source!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    lead.status,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Contact Info
            Row(
              children: [
                Icon(
                  Icons.phone_outlined,
                  size: 14,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lead.phoneNo,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : const Color(0xFF334155),
                    ),
                  ),
                ),
                if (lead.email != null && lead.email!.isNotEmpty) ...[
                  Icon(
                    Icons.email_outlined,
                    size: 14,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      lead.email!,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Notes Block (if any)
            if (lead.notes != null && lead.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes_rounded,
                      size: 14,
                      color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lead.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Date row
            if (dateStr != null) ...[
              const SizedBox(height: 8),
              Text(
                'Added: $dateStr',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
              ),
            ],

            const Divider(height: 18),

            // Action Buttons Row (Call, Update, Delete)
            Row(
              children: [
                // Quick Call Button
                SizedBox(
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: () => _makeCall(lead.phoneNo),
                    icon: const Icon(Icons.phone, size: 14),
                    label: const Text('Call', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Update Status & Notes Button
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      onPressed: () => _showUpdateSheet(context, lead),
                      icon: const Icon(Icons.edit_note, size: 16),
                      label: const Text(
                        'Update',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            isDark ? Colors.white : const Color(0xFF0F172A),
                        side: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFCBD5E1),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Delete button
                SizedBox(
                  height: 36,
                  width: 36,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: Colors.redAccent,
                    ),
                    onPressed: () => _confirmDelete(context, lead),
                    tooltip: 'Delete',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
