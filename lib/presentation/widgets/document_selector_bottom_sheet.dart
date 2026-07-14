import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/invoice_model.dart';
import '../../data/models/itinerary_model.dart';
import '../../data/models/quotation_model.dart';
import '../../data/models/voucher_model.dart';
import '../../core/utils/date_utils.dart';
import '../screens/invoice_detail_screen.dart';
import '../screens/voucher_detail_screen.dart';
import '../screens/quotation_detail_screen.dart';
import 'invoice_create_dialog.dart';
import 'itinerary_template_gallery_dialog.dart';
import 'quotation_create_dialog.dart';
import 'voucher_create_dialog.dart';
import 'itinerary_explorer_dialog.dart';
import '../../data/models/lead_model.dart';
import '../providers/invoice_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/quotation_provider.dart';
import '../providers/voucher_provider.dart';

class DocumentSelectorBottomSheet<T> extends ConsumerStatefulWidget {
  final String title;
  final List<T> documents;
  final void Function(T) onItemSelected;
  final Lead? lead;
  final BuildContext? parentContext;

  const DocumentSelectorBottomSheet({
    super.key,
    required this.title,
    required this.documents,
    required this.onItemSelected,
    this.lead,
    this.parentContext,
  });

  @override
  ConsumerState<DocumentSelectorBottomSheet<T>> createState() => _DocumentSelectorBottomSheetState<T>();
}

class _DocumentSelectorBottomSheetState<T> extends ConsumerState<DocumentSelectorBottomSheet<T>> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMoreLocal = false;

  List<T> getFilteredDocuments() {
    var filtered = widget.documents;
    if (widget.lead != null) {
      filtered = filtered.where((doc) {
        if (doc is Invoice) {
          return doc.leadId == widget.lead!.id;
        } else if (doc is ItineraryV2) {
          return doc.leadId == widget.lead!.id;
        } else if (doc is Quotation) {
          return doc.leadId == widget.lead!.id;
        } else if (doc is Voucher) {
          return doc.leadId == widget.lead!.id;
        }
        return true;
      }).toList();
    }
    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    // Do not auto-pop or auto-open create dialogs when document list is empty.
    // Let the user see the selector sheet and choose to click 'CREATE' manually.
  }

  @override
  void dispose() {
    // Reset ALL lead filters synchronously to prevent leaking into list screens
    ref.read(invoicesProvider.notifier).applyFilters({'lead': null});
    ref.read(itineraryV2Provider.notifier).setLeadFilter(null);
    ref.read(quotationsProvider.notifier).setLeadFilter(null);
    ref.read(vouchersProvider.notifier).applyFilters({'lead': null});
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {});
  }

  List<T> _getDocuments(WidgetRef ref) {
    if (T == Invoice) {
      return ref.watch(invoicesProvider).invoices as List<T>;
    } else if (T == ItineraryV2) {
      return ref.watch(itineraryV2Provider).itineraries as List<T>;
    } else if (T == Quotation) {
      return ref.watch(quotationsProvider).quotations as List<T>;
    } else if (T == Voucher) {
      return ref.watch(vouchersProvider).vouchers as List<T>;
    }
    return widget.documents;
  }

  bool _isLoading(WidgetRef ref) {
    if (T == Invoice) {
      return ref.watch(invoicesProvider).isLoading;
    } else if (T == ItineraryV2) {
      return ref.watch(itineraryV2Provider).isLoading || ref.watch(itineraryV2Provider).isMoreLoading;
    } else if (T == Quotation) {
      return ref.watch(quotationsProvider).isLoading || ref.watch(quotationsProvider).isMoreLoading;
    } else if (T == Voucher) {
      return ref.watch(vouchersProvider).isLoading;
    }
    return false;
  }

  bool _hasMore(WidgetRef ref) {
    if (T == Invoice) {
      final state = ref.watch(invoicesProvider);
      return state.currentPage < state.totalPages;
    } else if (T == ItineraryV2) {
      final state = ref.watch(itineraryV2Provider);
      return state.itineraries.length < state.totalCount;
    } else if (T == Quotation) {
      final state = ref.watch(quotationsProvider);
      return state.quotations.length < state.totalCount;
    } else if (T == Voucher) {
      final state = ref.watch(vouchersProvider);
      return state.currentPage < state.totalPages;
    }
    return false;
  }

  Future<void> _loadMore(WidgetRef ref) async {
    if (T == Invoice) {
      await ref.read(invoicesProvider.notifier).loadMore();
    } else if (T == ItineraryV2) {
      await ref.read(itineraryV2Provider.notifier).fetchItineraries();
    } else if (T == Quotation) {
      await ref.read(quotationsProvider.notifier).fetchQuotations();
    } else if (T == Voucher) {
      await ref.read(vouchersProvider.notifier).loadMore();
    }
  }

  void _onScroll() async {
    if (_isLoading(ref) || _isLoadingMoreLocal || !_hasMore(ref)) return;
    
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      setState(() => _isLoadingMoreLocal = true);
      try {
        await _loadMore(ref);
      } catch (e) {
        debugPrint('Error loading more documents: $e');
      } finally {
        if (mounted) {
          setState(() => _isLoadingMoreLocal = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 1. Get live documents from Riverpod providers
    final allDocs = _getDocuments(ref);
    
    // 2. Filter by lead
    var filtered = allDocs;
    if (widget.lead != null) {
      filtered = filtered.where((doc) {
        if (doc is Invoice) {
          return doc.leadId == widget.lead!.id;
        } else if (doc is ItineraryV2) {
          return doc.leadId == widget.lead!.id;
        } else if (doc is Quotation) {
          return doc.leadId == widget.lead!.id;
        } else if (doc is Voucher) {
          return doc.leadId == widget.lead!.id;
        }
        return true;
      }).toList();
    }

    // Build the sheet even when empty to allow manual search/creation.
    
    // 3. Filter by search query
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      filtered = filtered.where((doc) {
        if (doc is Invoice) {
          return doc.invoiceNumber.toLowerCase().contains(query) ||
                 doc.clientName.toLowerCase().contains(query);
        } else if (doc is ItineraryV2) {
          return doc.subject.toLowerCase().contains(query) ||
                 doc.clientName.toLowerCase().contains(query);
        } else if (doc is Quotation) {
          return doc.quotationNumber.toLowerCase().contains(query) ||
                 doc.clientName.toLowerCase().contains(query) ||
                 doc.subject.toLowerCase().contains(query);
        } else if (doc is Voucher) {
          return doc.voucherNo.toLowerCase().contains(query) ||
                 doc.clientName.toLowerCase().contains(query);
        }
        return false;
      }).toList();
    }

    final showLoaderSpinner = _isLoading(ref) || _isLoadingMoreLocal;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          
          // Search Bar & Create Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                if (T == Invoice || T == ItineraryV2 || T == Quotation || T == Voucher) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      final parentCtx = widget.parentContext ?? context;
                      Navigator.pop(context); // Close bottom sheet
                      if (T == Invoice) {
                        showDialog(
                          context: parentCtx,
                          barrierDismissible: false,
                          builder: (ctx) => InvoiceCreateDialog(prefilledLead: widget.lead),
                        );
                      } else if (T == ItineraryV2) {
                        showDialog(
                          context: parentCtx,
                          barrierDismissible: false,
                          builder: (ctx) => ItineraryTemplateGalleryDialog(prefilledLead: widget.lead),
                        );
                      } else if (T == Quotation) {
                        showDialog(
                          context: parentCtx,
                          barrierDismissible: false,
                          builder: (ctx) => QuotationCreateDialog(prefilledLead: widget.lead),
                        );
                      } else if (T == Voucher) {
                        showDialog(
                          context: parentCtx,
                          barrierDismissible: false,
                          builder: (ctx) => VoucherCreateDialog(prefilledLead: widget.lead),
                        );
                      }
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('CREATE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2D324A) : Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // List
          Expanded(
            child: filtered.isEmpty && !showLoaderSpinner
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          T == Invoice
                              ? Icons.receipt_long_outlined
                              : T == ItineraryV2
                                  ? Icons.map_outlined
                                  : T == Quotation
                                      ? Icons.request_quote_outlined
                                      : Icons.card_giftcard_outlined,
                          size: 48,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No ${widget.title.toLowerCase()} found',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: filtered.length + (showLoaderSpinner ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87),
                          ),
                        );
                      }
                      final doc = filtered[index];
                      return _buildCard(doc, isDark);
                    },
                  ),
          ),
          
          // Bottom Actions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('CANCEL', style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(T doc, bool isDark) {
    if (doc is Invoice) return _buildInvoiceCard(doc, isDark);
    if (doc is ItineraryV2) return _buildItineraryCard(doc, isDark);
    if (doc is Quotation) return _buildQuotationCard(doc, isDark);
    if (doc is Voucher) return _buildVoucherCard(doc, isDark);
    return const SizedBox();
  }

  Widget _buildInvoiceCard(Invoice invoice, bool isDark) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    
    return _BaseCard(
      onTap: () {
        Navigator.pop(context);
        widget.onItemSelected(invoice as T);
      },
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long_outlined, size: 18, color: isDark ? Colors.blue[300] : Colors.blue[700]),
                  const SizedBox(width: 8),
                  Text(
                    invoice.invoiceNumber,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Row(
                children: [
                  _Badge(text: invoice.status.toUpperCase(), color: Colors.blue),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InvoiceDetailScreen(
                            invoiceId: invoice.id,
                            initialInvoice: invoice,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.remove_red_eye_outlined, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (invoice.subject != null && invoice.subject!.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 26),
                Expanded(
                  child: Text(
                    invoice.subject!.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                'Due: ${DateTimeUtils.formatShort(DateTimeUtils.parseSafe(invoice.dueDate) ?? DateTime.now())}',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  invoice.clientName,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                currencyFormat.format(invoice.grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItineraryCard(ItineraryV2 itinerary, bool isDark) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return _BaseCard(
      onTap: () {
        Navigator.pop(context);
        widget.onItemSelected(itinerary as T);
      },
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.map_outlined, size: 18, color: isDark ? Colors.teal[300] : Colors.teal[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        itinerary.subject,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  _Badge(text: '${itinerary.noOfDays} DAYS', color: Colors.orange),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => ItineraryExplorerDialog(itineraryId: itinerary.id),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.remove_red_eye_outlined, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (itinerary.keyLocations.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    itinerary.keyLocations.join(' • '),
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  itinerary.clientName,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                currencyFormat.format(itinerary.totalPrice),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(Quotation quotation, bool isDark) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return _BaseCard(
      onTap: () {
        Navigator.pop(context);
        widget.onItemSelected(quotation as T);
      },
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                quotation.quotationNumber,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              Row(
                children: [
                  _Badge(text: quotation.status.toUpperCase(), color: Colors.indigo),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QuotationDetailScreen(
                            quotationId: quotation.id,
                            initialQuotation: quotation,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.remove_red_eye_outlined, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (quotation.subject.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                quotation.subject,
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[800]),
              ),
            ),
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: isDark ? Colors.grey[500] : Colors.grey[600]),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  quotation.clientName,
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              Text(
                currencyFormat.format(quotation.grandTotal),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoucherCard(Voucher voucher, bool isDark) {
    final currencyFormat = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

    return _BaseCard(
      onTap: () {
        Navigator.pop(context);
        widget.onItemSelected(voucher as T);
      },
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.confirmation_number_outlined, size: 18, color: isDark ? Colors.purple[300] : Colors.purple[700]),
                  const SizedBox(width: 8),
                  Text(
                    voucher.voucherNo,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              Row(
                children: [
                  _Badge(text: voucher.voucherType.toUpperCase(), color: Colors.amber),
                  const SizedBox(width: 8),
                  _Badge(text: voucher.status.toUpperCase(), color: Colors.purple),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => VoucherDetailScreen(voucherId: voucher.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.remove_red_eye_outlined, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    voucher.clientName,
                    style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[300] : Colors.grey[800], fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        'Date: ${DateTimeUtils.formatShort(DateTimeUtils.parseSafe(voucher.voucherDate) ?? DateTime.now())}',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                currencyFormat.format(voucher.financials.totalAmount),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.green),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final bool isDark;

  const _BaseCard({required this.child, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final MaterialColor color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.2) : color[50],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isDark ? color[200] : color[700],
        ),
      ),
    );
  }
}
