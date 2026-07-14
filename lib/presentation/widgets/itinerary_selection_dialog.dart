import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/itinerary_model.dart';
import '../../data/models/quotation_model.dart';
import '../../core/services/itinerary_service.dart';
import '../../core/services/quotation_service.dart';
import 'itinerary_explorer_dialog.dart';

class ItinerarySelectionDialog extends ConsumerStatefulWidget {
  final String leadId;
  final String? currentlySelectedItineraryId;

  const ItinerarySelectionDialog({
    super.key,
    required this.leadId,
    this.currentlySelectedItineraryId,
  });

  @override
  ConsumerState<ItinerarySelectionDialog> createState() => _ItinerarySelectionDialogState();
}

class _ItinerarySelectionDialogState extends ConsumerState<ItinerarySelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<ItineraryV2> _itineraries = [];
  ItineraryV2? _selectedItinerary;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final itineraryService = ItineraryService();
      final quotationService = QuotationService();

      // 1. Fetch itineraries for the lead
      final itResponse = await itineraryService.getItineraries(
        lead: widget.leadId,
        limit: 100,
      );
      final itData = itResponse['data'] ?? itResponse;
      final List<ItineraryV2> allItineraries = (itData['itineraries'] as List? ?? [])
          .map((e) => ItineraryV2.fromJson(e))
          .toList();

      // 2. Fetch quotations for the lead to filter unquoted ones
      final qResponse = await quotationService.getQuotations(
        lead: widget.leadId,
        limit: 100,
      );
      final qData = qResponse['data'] ?? qResponse;
      final List<Quotation> allQuotations = (qData['quotations'] as List? ?? [])
          .map((e) => Quotation.fromJson(e))
          .toList();

      // 3. Find the itinerary IDs that already have a quotation
      final quotedItineraryIds = allQuotations
          .map((q) => q.itineraryId)
          .where((id) => id != null && id.isNotEmpty)
          .toSet();

      // 4. Filter unquoted itineraries, but ALWAYS allow the currently selected one to be visible if it exists
      final unquoted = allItineraries.where((it) {
        return it.id == widget.currentlySelectedItineraryId || !quotedItineraryIds.contains(it.id);
      }).toList();

      if (mounted) {
        setState(() {
          _itineraries = unquoted;
          _isLoading = false;
          
          if (widget.currentlySelectedItineraryId != null) {
            _selectedItinerary = _itineraries.firstWhere(
              (it) => it.id == widget.currentlySelectedItineraryId,
              orElse: () => null as dynamic,
            );
          }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filtered = _itineraries.where((it) {
      final query = _searchQuery.toLowerCase();
      return it.subject.toLowerCase().contains(query) ||
             it.clientName.toLowerCase().contains(query);
    }).toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 600),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(context, isDark),

            // Description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Text(
                'Base this quotation on one of the active itineraries that has not been quoted yet.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Filter itineraries...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400], fontSize: 14),
                    prefixIcon: Icon(Icons.search, size: 18, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // List of Itineraries
            Expanded(
              child: _buildContent(filtered, isDark),
            ),

            // Footer
            _buildFooter(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Itinerary',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(List<ItineraryV2> filtered, bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black87),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 36),
              const SizedBox(height: 8),
              Text(
                'Error loading itineraries: $_error',
                style: const TextStyle(fontSize: 13, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, color: isDark ? Colors.grey[700] : Colors.grey[300], size: 48),
              const SizedBox(height: 12),
              Text(
                'No unquoted itineraries found for this lead',
                style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[500] : Colors.grey[500], fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final it = filtered[index];
        final isSelected = _selectedItinerary?.id == it.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedItinerary = it;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF262626) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? (isDark ? Colors.teal[400]! : Colors.teal[700]!)
                    : (isDark ? Colors.white10 : Colors.grey[250] ?? const Color(0xFFE0E0E0)),
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 16,
                            color: isSelected
                                ? (isDark ? Colors.teal[300] : Colors.teal[700])
                                : (isDark ? Colors.grey[500] : Colors.grey[600]),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              it.subject,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (it.keyLocations.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                it.keyLocations.join(' • '),
                                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, size: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                          const SizedBox(width: 6),
                          Text(
                            '${it.noOfDays} Days',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.person_outline, size: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              it.clientName,
                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      currencyFormat.format(it.totalPrice),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: isDark ? Colors.teal[300] : Colors.teal[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_red_eye_outlined, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => ItineraryExplorerDialog(itineraryId: it.id),
                            );
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? (isDark ? Colors.teal[400] : Colors.teal[700])
                                : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark ? Colors.grey[700]! : Colors.grey[400]!),
                              width: 1.5,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, size: 12, color: Colors.white)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252525) : Colors.white,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _selectedItinerary == null
                ? null
                : () => Navigator.pop(context, _selectedItinerary),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.teal[600] : Colors.black,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
              disabledForegroundColor: isDark ? Colors.grey[600] : Colors.grey[400],
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              elevation: 0,
            ),
            child: const Text(
              'SELECT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
