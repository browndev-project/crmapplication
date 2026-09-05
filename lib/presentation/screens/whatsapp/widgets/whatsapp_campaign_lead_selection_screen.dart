import 'package:flutter/material.dart';
import '../../../widgets/common_shimmer_skeleton.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../../../data/models/lead_model.dart';
import '../../../providers/lead_provider.dart';
import '../../../widgets/global_app_bar.dart';
import '../../../widgets/lead_filter_bottom_sheet.dart';

class WhatsAppCampaignLeadSelectionScreen extends ConsumerStatefulWidget {
  final List<String> initialSelectedLeadIds;
  final String initialQuantity;
  final Map<String, dynamic> initialFilters;

  const WhatsAppCampaignLeadSelectionScreen({
    super.key,
    required this.initialSelectedLeadIds,
    required this.initialQuantity,
    required this.initialFilters,
  });

  @override
  ConsumerState<WhatsAppCampaignLeadSelectionScreen> createState() =>
      _WhatsAppCampaignLeadSelectionScreenState();
}

class _WhatsAppCampaignLeadSelectionScreenState
    extends ConsumerState<WhatsAppCampaignLeadSelectionScreen> {
  final List<String> _selectedLeadIds = [];
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  Map<String, dynamic> _appliedFilters = {};

  String _leadsSearchQuery = '';
  final List<Lead> _searchedLeads = [];
  bool _isLoadingLeads = false;
  int _currentLeadPage = 1;
  bool _hasMoreLeads = true;
  Timer? _searchTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _selectedLeadIds.addAll(widget.initialSelectedLeadIds);
    _quantityController.text = widget.initialQuantity;
    _appliedFilters = Map<String, dynamic>.from(widget.initialFilters);

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50) {
        _fetchLeads();
      }
    });

    Future.microtask(() {
      _fetchLeads(refresh: true);
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeads({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentLeadPage = 1;
        _searchedLeads.clear();
        _hasMoreLeads = true;
      });
    }
    if (!_hasMoreLeads || _isLoadingLeads) return;

    setState(() => _isLoadingLeads = true);

    try {
      final service = ref.read(leadServiceProvider);
      final response = await service.fetchLeads(
        page: _currentLeadPage,
        limit: 500, // Fetch 300-500 leads in ONE API call
        search: _leadsSearchQuery,
        service: _appliedFilters['service']?.toString(),
        status: _appliedFilters['status']?.toString(),
        source: _appliedFilters['source']?.toString(),
        pipeline: _appliedFilters['pipeline']?.toString(),
        assignedTo: _appliedFilters['assignedTo']?.toString(),
        team: _appliedFilters['team']?.toString(),
        group: _appliedFilters['group']?.toString(),
        project: _appliedFilters['project']?.toString(),
        sort: _appliedFilters['sort']?.toString(),
        startDate: _appliedFilters['startDate']?.toString(),
        endDate: _appliedFilters['endDate']?.toString(),
        metaFormId: _appliedFilters['metaFormId']?.toString(),
        metaCampaignId: _appliedFilters['metaCampaignId']?.toString(),
        metaAdsetId: _appliedFilters['metaAdsetId']?.toString(),
        metaAdId: _appliedFilters['metaAdId']?.toString(),
      );

      setState(() {
        final seenIds = <String>{};
        for (final l in _searchedLeads) {
          seenIds.add(l.id);
        }
        for (final l in response.leads) {
          if (!seenIds.contains(l.id)) {
            _searchedLeads.add(l);
            seenIds.add(l.id);
          }
        }
        _hasMoreLeads = _currentLeadPage < response.totalPages;
        if (_hasMoreLeads) _currentLeadPage++;
        _isLoadingLeads = false;

        if (_quantityController.text.trim().isNotEmpty) {
          _applyQuantitySelection();
        }
      });
    } catch (e) {
      setState(() => _isLoadingLeads = false);
    }
  }

  void _applyQuantitySelection() {
    final qtyText = _quantityController.text.trim();
    final n = int.tryParse(qtyText) ?? 0;
    setState(() {
      _selectedLeadIds.clear();
      if (n > 0 && _searchedLeads.isNotEmpty) {
        // If n is greater than available leads, select all available leads
        final countToSelect = n.clamp(0, _searchedLeads.length);
        final added = <String>{};
        for (int i = 0; i < countToSelect; i++) {
          final lead = _searchedLeads[i];
          if (added.add(lead.id)) {
            _selectedLeadIds.add(lead.id);
          }
        }
      }
    });

    // If requested quantity is more than currently loaded leads and more exist, fetch more
    if (n > _searchedLeads.length && _hasMoreLeads && !_isLoadingLeads) {
      _fetchLeads();
    }
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LeadFilterBottomSheet(
        currentFilters: _appliedFilters,
        onApply: (newFilters) {
          setState(() {
            _appliedFilters = newFilters;
          });
          _fetchLeads(refresh: true);
        },
      ),
    );
  }

  void _confirmSelection() {
    Navigator.of(context).pop({
      'selectedLeadIds': _selectedLeadIds,
      'quantity': _quantityController.text,
      'filters': _appliedFilters,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final allSelected = _searchedLeads.isNotEmpty &&
        _selectedLeadIds.length >= _searchedLeads.map((l) => l.id).toSet().length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: GlobalAppBar(
        title: 'Select Campaign Leads',
        actions: [
          TextButton(
            onPressed: _confirmSelection,
            child: const Text(
              'DONE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search + Quantity inputs row (Matching uploaded mockup)
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              _leadsSearchQuery = val;
                              _searchTimer?.cancel();
                              _searchTimer =
                                  Timer(const Duration(milliseconds: 400), () {
                                _fetchLeads(refresh: true);
                              });
                            },
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search leads...',
                              prefixIcon: const Icon(Icons.search, size: 18),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              fillColor: isDark
                                  ? const Color(0xFF25293C)
                                  : Colors.white,
                              filled: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            onChanged: (val) => _applyQuantitySelection(),
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Quantity to send',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              fillColor: isDark
                                  ? const Color(0xFF25293C)
                                  : Colors.white,
                              filled: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Actions Row: FILTERS button, Refresh, Selection Counter & SELECT ALL
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openFilterSheet,
                          icon: Icon(
                            Icons.tune_rounded,
                            size: 16,
                            color: _appliedFilters.isNotEmpty
                                ? Colors.blue
                                : (isDark ? Colors.white70 : Colors.black87),
                          ),
                          label: Text(
                            _appliedFilters.isNotEmpty
                                ? 'FILTERS (${_appliedFilters.length})'
                                : 'FILTERS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: _appliedFilters.isNotEmpty
                                  ? Colors.blue
                                  : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: _appliedFilters.isNotEmpty
                                  ? Colors.blue
                                  : (isDark
                                      ? Colors.white30
                                      : Colors.grey.shade400),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            backgroundColor: _appliedFilters.isNotEmpty
                                ? Colors.blue.withValues(alpha: 0.08)
                                : Colors.transparent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          onPressed: () => _fetchLeads(refresh: true),
                          tooltip: 'Refresh Leads',
                        ),
                        if (_appliedFilters.isNotEmpty) ...[
                          TextButton(
                            onPressed: () {
                              setState(() => _appliedFilters.clear());
                              _fetchLeads(refresh: true);
                            },
                            child: const Text("Clear Filters",
                                style: TextStyle(
                                    fontSize: 11, color: Colors.redAccent)),
                          ),
                        ],
                        const Spacer(),
                        Text(
                          "${_selectedLeadIds.length} of ${_searchedLeads.length} selected",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _searchedLeads.isEmpty
                              ? null
                              : () {
                                  final uniqueCount = _searchedLeads
                                      .map((l) => l.id)
                                      .toSet()
                                      .length;
                                  setState(() {
                                    if (_selectedLeadIds.length >=
                                        uniqueCount) {
                                      _selectedLeadIds.clear();
                                    } else {
                                      _selectedLeadIds.clear();
                                      final added = <String>{};
                                      for (final l in _searchedLeads) {
                                        if (added.add(l.id)) {
                                          _selectedLeadIds.add(l.id);
                                        }
                                      }
                                    }
                                  });
                                },
                          child: Text(
                            allSelected ? "DESELECT ALL" : "SELECT ALL",
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Leads Table (500 limit single-call)
                    Container(
                      height: 480,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300,
                            width: 1.2),
                        borderRadius: BorderRadius.circular(10),
                        color: isDark ? const Color(0xFF1E2130) : Colors.white,
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF25293C)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(9)),
                              border: Border(
                                  bottom: BorderSide(
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300)),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 28,
                                  height: 24,
                                  child: Checkbox(
                                    value: allSelected,
                                    onChanged: _searchedLeads.isEmpty
                                        ? null
                                        : (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedLeadIds.clear();
                                                final added = <String>{};
                                                for (final l in _searchedLeads) {
                                                  if (added.add(l.id)) {
                                                    _selectedLeadIds.add(l.id);
                                                  }
                                                }
                                              } else {
                                                _selectedLeadIds.clear();
                                              }
                                            });
                                          },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const SizedBox(
                                  width: 40,
                                  child: Text("Sr No",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5)),
                                ),
                                const Expanded(
                                  flex: 3,
                                  child: Text("Name",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5)),
                                ),
                                const Expanded(
                                  flex: 3,
                                  child: Text("Contact",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5)),
                                ),
                                const Expanded(
                                  flex: 2,
                                  child: Text("Service / Status",
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11.5)),
                                ),
                              ],
                            ),
                          ),
                          // Table Body
                          Expanded(
                            child: _searchedLeads.isEmpty && !_isLoadingLeads
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.person_off_rounded,
                                            size: 36,
                                            color: Colors.grey.shade400),
                                        const SizedBox(height: 8),
                                        Text("No leads found",
                                            style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  )
                                : ListView.separated(
                                    controller: _scrollController,
                                    itemCount: _searchedLeads.length +
                                        (_hasMoreLeads ? 1 : 0),
                                    separatorBuilder: (context, index) => Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: isDark
                                          ? Colors.grey.shade800
                                              .withValues(alpha: 0.6)
                                          : Colors.grey.shade200,
                                    ),
                                    itemBuilder: (context, idx) {
                                      if (idx >= _searchedLeads.length) {
                                         return const Padding(
                                           padding: EdgeInsets.all(12),
                                           child: AppShimmerListSkeleton(itemCount: 2),
                                         );
                                      }
                                      final lead = _searchedLeads[idx];
                                      final isChecked =
                                          _selectedLeadIds.contains(lead.id);
                                      final serviceOrStatus = (lead
                                                  .service?.name !=
                                              null &&
                                          lead.service!.name.isNotEmpty)
                                          ? lead.service!.name
                                          : (lead.status.isNotEmpty
                                              ? lead.status
                                              : (lead.source.isNotEmpty
                                                  ? lead.source
                                                  : '-'));

                                      return InkWell(
                                        onTap: () {
                                          setState(() {
                                            if (isChecked) {
                                              _selectedLeadIds.remove(lead.id);
                                            } else {
                                              _selectedLeadIds.add(lead.id);
                                            }
                                          });
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 10),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 28,
                                                height: 24,
                                                child: Checkbox(
                                                  value: isChecked,
                                                  onChanged: (val) {
                                                    setState(() {
                                                      if (val == true) {
                                                        _selectedLeadIds
                                                            .add(lead.id);
                                                      } else {
                                                        _selectedLeadIds
                                                            .remove(lead.id);
                                                      }
                                                    });
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              SizedBox(
                                                width: 40,
                                                child: Text(
                                                  "${idx + 1}",
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? Colors.grey.shade400
                                                        : Colors.grey.shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      lead.name.isNotEmpty
                                                          ? lead.name
                                                          : 'No Name',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 12.5),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    if (lead.destination !=
                                                            null &&
                                                        lead.destination!
                                                            .isNotEmpty)
                                                      Text(
                                                        'Req: ${lead.destination}',
                                                        style: TextStyle(
                                                            fontSize: 10.5,
                                                            color: Colors
                                                                .grey.shade500),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 3,
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        lead.phoneNo.isNotEmpty
                                                            ? lead.phoneNo
                                                            : '-',
                                                        style: const TextStyle(
                                                            fontSize: 12,
                                                            fontWeight:
                                                                FontWeight.w500),
                                                        maxLines: 1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    if (lead.phoneNo
                                                        .isNotEmpty) ...[
                                                      InkWell(
                                                        onTap: () async {
                                                          final Uri telUri = Uri(
                                                              scheme: 'tel',
                                                              path: lead.phoneNo);
                                                          if (await canLaunchUrl(
                                                              telUri)) {
                                                            await launchUrl(telUri);
                                                          }
                                                        },
                                                        child: const Padding(
                                                          padding:
                                                              EdgeInsets.all(3.0),
                                                          child: Icon(
                                                              Icons.phone_rounded,
                                                              size: 15,
                                                              color: Colors.green),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      InkWell(
                                                        onTap: () async {
                                                          final cleanPhone = lead
                                                              .phoneNo
                                                              .replaceAll(
                                                                  RegExp(r'\D'),
                                                                  '');
                                                          final Uri waUri =
                                                              Uri.parse(
                                                                  'https://wa.me/$cleanPhone');
                                                          if (await canLaunchUrl(
                                                              waUri)) {
                                                            await launchUrl(waUri,
                                                                mode: LaunchMode
                                                                    .externalApplication);
                                                          }
                                                        },
                                                        child: const Padding(
                                                          padding:
                                                              EdgeInsets.all(3.0),
                                                          child: Icon(
                                                              Icons
                                                                  .chat_bubble_rounded,
                                                              size: 15,
                                                              color: Color(
                                                                  0xFF25D366)),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              Expanded(
                                                flex: 2,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isDark
                                                        ? Colors.grey.shade800
                                                        : const Color(0xFFF1F5F9),
                                                    borderRadius:
                                                        BorderRadius.circular(12),
                                                    border: Border.all(
                                                        color: isDark
                                                            ? Colors.white24
                                                            : Colors.grey.shade300),
                                                  ),
                                                  child: Text(
                                                    serviceOrStatus,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark
                                                          ? Colors.grey.shade300
                                                          : Colors.black87,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                          ),
                          // Footer Summary Bar
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF25293C)
                                  : const Color(0xFFF8FAFC),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(9)),
                              border: Border(
                                  top: BorderSide(
                                      color: isDark
                                          ? Colors.grey.shade800
                                          : Colors.grey.shade300)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Rows per page: 500",
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: isDark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600),
                                ),
                                Text(
                                  "1-${_searchedLeads.length} of ${_searchedLeads.length} leads",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border(
                    top: BorderSide(
                        color: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _confirmSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black87,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'CONFIRM SELECTION ',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
