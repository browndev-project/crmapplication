import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/common_shimmer_skeleton.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/permission_constants.dart';
import '../../data/models/booking_model.dart';
import '../providers/booking_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/dashboard_stats_card.dart';
import '../widgets/booking_create_dialog.dart';
// import '../widgets/booking_create_dialog.dart';
import '../widgets/voice_to_text_dialog.dart';
import '../widgets/access_denied_widget.dart';
import 'lead_profile_screen.dart';

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _showStats = true;
  String _selectedStatus = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingsProvider.notifier).fetchStats();
      ref.read(bookingsProvider.notifier).fetchBookings(isRefresh: true);
    });
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      // Lazy loading / pagination (handled by booking provider if pagination is implemented)
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      ref.read(bookingsProvider.notifier).applyFilters({'searchQuery': query});
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bookingsState = ref.watch(bookingsProvider);
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final userRole = user?.systemRole;

    final canView = permissions.can(PermissionModules.BOOKING, permission: PermissionModules.BOOKING_VIEW, userRole: userRole);
    final canCreate = permissions.can(PermissionModules.BOOKING, permission: PermissionModules.BOOKING_CREATE, userRole: userRole);
    final canUpdate = permissions.can(PermissionModules.BOOKING, permission: PermissionModules.BOOKING_UPDATE, userRole: userRole);
    final canDelete = permissions.can(PermissionModules.BOOKING, permission: PermissionModules.BOOKING_DELETE, userRole: userRole);

    if (!canView) {
      return const Scaffold(
        appBar: GlobalAppBar(title: 'Bookings'),
        body: AccessDeniedWidget(
          sectionName: "Bookings",
          showAppBar: false,
        ),
      );
    }

    final stats = bookingsState.stats;
    final activeCount = stats?.active ?? 0;
    final completedCount = stats?.completed ?? 0;
    final cancelledCount = stats?.cancelled ?? 0;
    final totalCount = activeCount + completedCount + cancelledCount;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: const GlobalAppBar(title: 'Bookings'),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.read(bookingsProvider.notifier).fetchStats();
          await ref.read(bookingsProvider.notifier).fetchBookings(isRefresh: true);
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section with Title, Toggle and Refresh buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Bookings',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'View, manage, and update real estate property bookings for leads.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    children: [
                      // Expand/Collapse Stats Button
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showStats = !_showStats;
                          });
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(_showStats ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20),
                      ),
                      const SizedBox(width: 8),
                      // Refresh Stats Button
                      IconButton(
                        onPressed: () {
                          ref.read(bookingsProvider.notifier).fetchStats();
                          ref.read(bookingsProvider.notifier).fetchBookings(isRefresh: true);
                        },
                        style: IconButton.styleFrom(
                          backgroundColor: isDark ? Colors.white54.withValues(alpha: 0.05) : Colors.grey.shade100,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (_showStats) ...[
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatsCard(
                        title: 'Total Bookings',
                        value: '$totalCount',
                        icon: Icons.check_circle_outline,
                        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.grey.shade900,
                        gradientColors: isDark ? [const Color(0xFF1E293B), const Color(0xFF334155)] : [Colors.grey.shade900, Colors.grey.shade800],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatsCard(
                        title: 'Active Bookings',
                        value: '$activeCount',
                        icon: Icons.check_circle,
                        backgroundColor: const Color(0xFF4F46E5),
                        gradientColors: const [Color(0xFF4F46E5), Color(0xFF6366F1)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DashboardStatsCard(
                        title: 'Completed Bookings',
                        value: '$completedCount',
                        icon: Icons.check_circle,
                        backgroundColor: const Color(0xFF10B981),
                        gradientColors: const [Color(0xFF10B981), Color(0xFF34D399)],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DashboardStatsCard(
                        title: 'Cancelled Bookings',
                        value: '$cancelledCount',
                        icon: Icons.cancel,
                        backgroundColor: const Color(0xFFEF4444),
                        gradientColors: const [Color(0xFFEF4444), Color(0xFFF87171)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Filter Controls & Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bookings',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Review details and active statuses.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      // Status dropdown
                      Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('All Status', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'active', child: Text('Active', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'completed', child: Text('Completed', style: TextStyle(fontSize: 12))),
                              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled', style: TextStyle(fontSize: 12))),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedStatus = val;
                                });
                                ref.read(bookingsProvider.notifier).applyFilters({'status': val == 'all' ? null : val});
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (canCreate)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: IconButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => const BookingCreateDialog(),
                                ),
                              ).then((_) {
                                ref.read(bookingsProvider.notifier).fetchStats();
                                ref.read(bookingsProvider.notifier).fetchBookings(isRefresh: true);
                              });
                            },
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search lead name, property name, or phone number...',
                  hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400, fontSize: 13),
                  // prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.white38 : Colors.grey.shade400, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_searchController.text.isNotEmpty)
                        IconButton(
                          icon: Icon(Icons.clear, size: 16, color: isDark ? Colors.white38 : Colors.grey.shade400),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                          ),
                          child: const Icon(Icons.mic_rounded, size: 16, color: Color(0xFF2563EB)),
                        ),
                        tooltip: 'Voice Search',
                        onPressed: () async {
                          final text = await VoiceToTextDialog.show(
                            context: context,
                            title: 'Search Bookings',
                            targetController: _searchController,
                          );
                          if (text != null && text.isNotEmpty) {
                            _onSearchChanged(text);
                          }
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // List of Bookings
              if (bookingsState.isLoading && bookingsState.bookings.isEmpty)
                const AppShimmerListSkeleton(itemCount: 5)
              else if (bookingsState.error != null && bookingsState.bookings.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64.0),
                    child: Text('Error: ${bookingsState.error}', style: const TextStyle(color: Colors.red)),
                  ),
                )
              else if (bookingsState.bookings.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64.0),
                    child: Text(
                      'No bookings found.',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bookingsState.bookings.length,
                  itemBuilder: (ctx, index) {
                    final booking = bookingsState.bookings[index];

                    // Payment summary calculations
                    final totalPaid = booking.bookingAmount + booking.paymentPlan
                        .where((m) => m.status == 'paid')
                        .fold(0.0, (sum, m) => sum + m.amount);
                    final outstanding = booking.finalAmount - totalPaid;

                    return InkWell(
                      onTap: () => _showBookingDetailsDrawer(context, booking, isDark),
                      borderRadius: BorderRadius.circular(16),
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
                        ),
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          booking.lead?.name ?? 'Unknown Lead',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 16,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        if (booking.lead?.phoneNo != null && booking.lead!.phoneNo.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            booking.lead!.phoneNo,
                                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(booking.status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: _getStatusColor(booking.status), width: 1),
                                    ),
                                    child: Text(
                                      booking.status.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: _getStatusColor(booking.status),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Divider(color: isDark ? Colors.white10 : Colors.grey.shade100, height: 1),
                              const SizedBox(height: 12),

                              // Property & Final Deal Amount Info
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _buildItemCol(
                                      "Property",
                                      booking.property?.name ?? 'Flat 101',
                                      isDark,
                                    ),
                                  ),
                                  _buildItemCol(
                                    "Final Amount",
                                    "₹ ${NumberFormat('#,##,###').format(booking.finalAmount)}",
                                    isDark,
                                    valueColor: const Color(0xFF2563EB),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Payments stats
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildItemCol(
                                    "Paid Payments",
                                    "₹ ${NumberFormat('#,##,###').format(totalPaid)}",
                                    isDark,
                                    valueColor: Colors.green,
                                  ),
                                  _buildItemCol(
                                    "Pending Balance",
                                    "₹ ${NumberFormat('#,##,###').format(outstanding)}",
                                    isDark,
                                    valueColor: Colors.red,
                                  ),
                                ],
                              ),

                              // Brokerage Deal section
                              if (booking.isBrokerageDeal && booking.broker != null) ...[
                                const SizedBox(height: 12),
                                Divider(color: isDark ? Colors.white10 : Colors.grey.shade100, height: 1),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: _buildItemCol(
                                        "Broker Details",
                                        booking.broker?.name ?? 'N/A',
                                        isDark,
                                      ),
                                    ),
                                    _buildItemCol(
                                      "Comm. Payout",
                                      "₹ ${NumberFormat('#,##,###').format(booking.brokerageAmount)}",
                                      isDark,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildItemCol(
                                      "Comm. Paid",
                                      "₹ ${NumberFormat('#,##,###').format(booking.paidBrokerageAmount)}",
                                      isDark,
                                      valueColor: Colors.green,
                                    ),
                                    _buildItemCol(
                                      "Comm. Pending",
                                      "₹ ${NumberFormat('#,##,###').format(booking.brokerageAmount - booking.paidBrokerageAmount)}",
                                      isDark,
                                      valueColor: Colors.red,
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 16),
                              Divider(color: isDark ? Colors.white10 : Colors.grey.shade100, height: 1),
                              const SizedBox(height: 12),

                              // Created By & Actions Footer
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      "Created By: ${booking.createdBy ?? 'System'}",
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white38 : Colors.grey.shade500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      // Eye Icon Button
                                      IconButton(
                                        icon: Icon(Icons.visibility_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                        onPressed: () {
                                          if (booking.lead?.id != null) {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (ctx) => LeadProfileScreen(
                                                  leadId: booking.lead!.id,
                                                  name: booking.lead?.name,
                                                  phone: booking.lead?.phoneNo,
                                                  initialTab: 'Bookings',
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        constraints: const BoxConstraints(),
                                        padding: const EdgeInsets.all(4),
                                      ),
                                      if (canUpdate) ...[
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: Icon(Icons.edit_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (ctx) => BookingCreateDialog(booking: booking),
                                              ),
                                            ).then((_) {
                                              ref.read(bookingsProvider.notifier).fetchStats();
                                              ref.read(bookingsProvider.notifier).fetchBookings(isRefresh: true);
                                            });
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ],
                                      if (canDelete) ...[
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Delete Booking'),
                                                content: const Text('Are you sure you want to delete this booking?'),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () async {
                                                      Navigator.pop(ctx);
                                                      try {
                                                        await ref.read(bookingsProvider.notifier).deleteBooking(booking.id);
                                                        ref.read(bookingsProvider.notifier).fetchStats();
                                                        if (!context.mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          const SnackBar(content: Text('Booking deleted successfully')),
                                                        );
                                                      } catch (e) {
                                                        if (!context.mounted) return;
                                                        ScaffoldMessenger.of(context).showSnackBar(
                                                          SnackBar(content: Text('Failed to delete booking: $e')),
                                                        );
                                                      }
                                                    },
                                                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemCol(String label, String value, bool isDark, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey.shade500),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  void _showBookingDetailsDrawer(BuildContext context, Booking booking, bool isDark) {
    final totalPaid = booking.bookingAmount + booking.paymentPlan
        .where((m) => m.status == 'paid')
        .fold(0.0, (sum, m) => sum + m.amount);
    final outstanding = booking.finalAmount - totalPaid;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Booking Details",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    // Lead section
                    _buildNestedCard(
                      title: "LEAD INFORMATION",
                      isDark: isDark,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildItemCol("Lead Name", booking.lead?.name ?? 'N/A', isDark),
                              _buildItemCol("Phone Number", booking.lead?.phoneNo ?? 'N/A', isDark),
                            ],
                          ),
                          if (booking.lead?.email != null && booking.lead!.email.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _buildItemCol("Email Address", booking.lead!.email, isDark),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Property & Calculations section
                    _buildNestedCard(
                      title: "PROPERTY & DEAL DETAILS",
                      isDark: isDark,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildItemCol("Property Name", booking.property?.name ?? 'N/A', isDark),
                              _buildItemCol("Property Type", (booking.property?.type ?? 'N/A').toUpperCase(), isDark),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildItemCol("Total Deal Value", "₹ ${NumberFormat('#,##,###').format(booking.finalAmount)}", isDark, valueColor: const Color(0xFF2563EB)),
                              _buildItemCol("Booking Deposit", "₹ ${NumberFormat('#,##,###').format(booking.bookingAmount)}", isDark),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildItemCol("Total Paid Sum", "₹ ${NumberFormat('#,##,###').format(totalPaid)}", isDark, valueColor: Colors.green),
                              _buildItemCol("Pending Balance", "₹ ${NumberFormat('#,##,###').format(outstanding)}", isDark, valueColor: Colors.red),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Broker section
                    if (booking.isBrokerageDeal && booking.broker != null) ...[
                      _buildNestedCard(
                        title: "BROKER / CHANNEL PARTNER DETAILS",
                        isDark: isDark,
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildItemCol("Broker Name", booking.broker?.name ?? 'N/A', isDark),
                                _buildItemCol("Agency Name", booking.broker?.agencyName ?? 'N/A', isDark),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildItemCol(
                                  "Brokerage Config",
                                  booking.brokerageType == 'percentage'
                                      ? "${booking.brokerageValue.toStringAsFixed(0)}%"
                                      : "₹ ${NumberFormat('#,##,###').format(booking.brokerageValue)}",
                                  isDark,
                                ),
                                _buildItemCol("Estimated Commission", "₹ ${NumberFormat('#,##,###').format(booking.brokerageAmount)}", isDark),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildItemCol("Paid Commission", "₹ ${NumberFormat('#,##,###').format(booking.paidBrokerageAmount)}", isDark, valueColor: Colors.green),
                                _buildItemCol("Outstanding Commission", "₹ ${NumberFormat('#,##,###').format(booking.brokerageAmount - booking.paidBrokerageAmount)}", isDark, valueColor: Colors.red),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Installments section
                    _buildNestedCard(
                      title: "INSTALLMENTS & MILESTONES",
                      isDark: isDark,
                      child: booking.paymentPlan.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Center(
                                child: Text(
                                  "No installments configured",
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.grey),
                                ),
                              ),
                            )
                          : Column(
                              children: booking.paymentPlan.map((milestone) {
                                final isPaid = milestone.status == 'paid';
                                DateTime? parsedDue;
                                try {
                                  parsedDue = DateTime.tryParse(milestone.dueDate);
                                } catch (_) {}
                                final dueDateStr = parsedDue != null ? DateFormat('dd MMM, yyyy').format(parsedDue) : milestone.dueDate;

                                DateTime? parsedPaid;
                                if (milestone.paidDate != null) {
                                  try {
                                    parsedPaid = DateTime.tryParse(milestone.paidDate!);
                                  } catch (_) {}
                                }
                                final paidDateStr = parsedPaid != null ? DateFormat('dd MMM, yyyy').format(parsedPaid) : milestone.paidDate;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.01) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade100),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              milestone.milestoneName,
                                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              isPaid ? "Paid on: ${paidDateStr ?? 'N/A'}" : "Due: $dueDateStr",
                                              style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            "₹ ${NumberFormat('#,##,###').format(milestone.amount)}",
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPaid ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: isPaid ? Colors.green : Colors.orange, width: 0.5),
                                            ),
                                            child: Text(
                                              milestone.status.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                                color: isPaid ? Colors.green : Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // WhatsApp Reminders section
                    _buildNestedCard(
                      title: "WHATSAPP REMINDERS",
                      isDark: isDark,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildItemCol(
                              "Status",
                              booking.sendReminders ? "Enabled" : "Disabled",
                              isDark,
                              valueColor: booking.sendReminders ? Colors.green : Colors.red,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _buildItemCol(
                              "Reminder Schedule",
                              "${booking.reminderDaysBefore} days before due",
                              isDark,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _buildItemCol(
                              "Daily Reminder Time",
                              booking.reminderTime,
                              isDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // WhatsApp Overdue Reminders section
                    _buildNestedCard(
                      title: "WHATSAPP OVERDUE REMINDERS",
                      isDark: isDark,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildItemCol(
                              "Status",
                              booking.sendOverdueReminders ? "Enabled" : "Disabled",
                              isDark,
                              valueColor: booking.sendOverdueReminders ? Colors.green : Colors.red,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _buildItemCol(
                              "Stop Reminder After",
                              "${booking.overdueReminderDaysLimit} days overdue",
                              isDark,
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: _buildItemCol(
                              "Daily Reminder Time",
                              booking.overdueReminderTime,
                              isDark,
                            ),
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
    );
  }

  Widget _buildNestedCard({
    required String title,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey.shade500,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}
