import 'package:flutter/material.dart';
import '../widgets/common_shimmer_skeleton.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/permission_constants.dart';
import '../../core/services/broker_service.dart';
import '../../data/models/broker_model.dart';
import '../providers/broker_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../providers/staff_provider.dart';
import '../../data/models/staff_model.dart';
import '../widgets/global_app_bar.dart';
// import '../widgets/global_app_bar.dart';
import '../widgets/voice_to_text_dialog.dart';

const List<String> indianStates = [
  "Andhra Pradesh",
  "Arunachal Pradesh",
  "Assam",
  "Bihar",
  "Chhattisgarh",
  "Goa",
  "Gujarat",
  "Haryana",
  "Himachal Pradesh",
  "Jharkhand",
  "Karnataka",
  "Kerala",
  "Madhya Pradesh",
  "Maharashtra",
  "Manipur",
  "Meghalaya",
  "Mizoram",
  "Nagaland",
  "Odisha",
  "Punjab",
  "Rajasthan",
  "Sikkim",
  "Tamil Nadu",
  "Telangana",
  "Tripura",
  "Uttar Pradesh",
  "Uttarakhand",
  "West Bengal",
  "Andaman and Nicobar Islands",
  "Chandigarh",
  "Dadra and Nagar Haveli and Daman and Diu",
  "Delhi",
  "Jammu and Kashmir",
  "Ladakh",
  "Lakshadweep",
  "Puducherry"
];

class BrokersScreen extends ConsumerStatefulWidget {
  const BrokersScreen({super.key});

  @override
  ConsumerState<BrokersScreen> createState() => _BrokersScreenState();
}

class _BrokersScreenState extends ConsumerState<BrokersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(brokersProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(brokersProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final hasCreatePermission = permissions.hasPermission(PermissionModules.BROKER_CREATE, userRole: user?.systemRole);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey[50],
      appBar: const GlobalAppBar(title: 'Brokers'),
      body: RefreshIndicator(
        onRefresh: () async => ref.read(brokersProvider.notifier).refresh(),
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Manage Brokers & Channel Partners',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your real estate brokers, channel partners, and track their commission payouts.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              // Stats row
              _buildStatsRow(state, isDark),
              const SizedBox(height: 24),

              // Filters block
              _buildFiltersBlock(state, isDark, hasCreatePermission),
              const SizedBox(height: 16),

              // List area
              if (state.isLoading && state.brokers.isEmpty)
                const AppShimmerListSkeleton(itemCount: 5)
              else if (state.error != null && state.brokers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64.0),
                    child: Text('Error: ${state.error}', style: const TextStyle(color: Colors.red)),
                  ),
                )
              else if (state.brokers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 64.0),
                    child: Text(
                      'No brokers or channel partners found.',
                      style: TextStyle(color: theme.hintColor),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.brokers.length,
                  itemBuilder: (context, index) {
                    final broker = state.brokers[index];
                    return _buildBrokerCard(broker, isDark);
                  },
                ),

              // Loading more indicator
              if (state.isLoading && state.brokers.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: AppShimmerListSkeleton(itemCount: 2),
                ),
              const SizedBox(height: 80), // Fab space
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(BrokersState state, bool isDark) {
    final stats = state.stats;
    final total = stats?.totalAgents ?? 0;
    final cp = stats?.channelPartners ?? 0;
    final active = stats?.activeBrokers ?? 0;
    final inactive = stats?.inactiveBrokers ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard('Total Agents', total.toString(), Icons.people_outline, const Color(0xFF1E293B), isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Channel Partners', cp.toString(), Icons.handshake_outlined, const Color(0xFF6366F1), isDark)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard('Active Brokers', active.toString(), Icons.check_circle_outline, const Color(0xFF10B981), isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard('Inactive', inactive.toString(), Icons.cancel_outlined, const Color(0xFFEF4444), isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersBlock(BrokersState state, bool isDark, bool hasCreatePermission) {
    final theme = Theme.of(context);
    final borderCol = isDark ? Colors.white12 : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Brokers & CPs',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => ref.read(brokersProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (hasCreatePermission) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => showAddEditBrokerDialog(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          // Search input
          TextField(
            controller: _searchController,
            onChanged: (val) {
              ref.read(brokersProvider.notifier).updateFilters(searchQuery: val);
            },
            decoration: InputDecoration(
              hintText: 'Search by name, agency name, or phone number...',
              hintStyle: TextStyle(fontSize: 12, color: theme.hintColor),
              // prefixIcon: const Icon(Icons.search_rounded, size: 18),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        ref.read(brokersProvider.notifier).updateFilters(searchQuery: '');
                      },
                    ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.primaryColor.withValues(alpha: 0.12),
                      ),
                      child: Icon(Icons.mic_rounded, size: 16, color: theme.primaryColor),
                    ),
                    tooltip: 'Voice Search',
                    onPressed: () async {
                      final text = await VoiceToTextDialog.show(
                        context: context,
                        title: 'Search Brokers',
                        targetController: _searchController,
                      );
                      if (text != null && text.isNotEmpty) {
                        ref.read(brokersProvider.notifier).updateFilters(searchQuery: text);
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              filled: true,
              fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderCol)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.primaryColor)),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 10),
          // Dropdowns
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedType,
                      items: ['All Types', 'Broker', 'ChannelPartner'].map((t) {
                        return DropdownMenuItem(value: t, child: Text(t == 'ChannelPartner' ? 'Channel Partner' : t, style: const TextStyle(fontSize: 12)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(brokersProvider.notifier).updateFilters(type: val);
                        }
                      },
                      isExpanded: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderCol),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: state.selectedStatus,
                      items: ['All Status', 'Active', 'Inactive'].map((s) {
                        return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(brokersProvider.notifier).updateFilters(status: val);
                        }
                      },
                      isExpanded: true,
                    ),
                  ),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBrokerCard(Broker broker, bool isDark) {
    final theme = Theme.of(context);
    final isCp = broker.type == 'ChannelPartner';
    final isActive = broker.status == 'active';
    final formattedDate = broker.createdAt != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(broker.createdAt!))
        : '-';

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final hasUpdatePermission = permissions.hasPermission(PermissionModules.BROKER_UPDATE, userRole: user?.systemRole);
    final hasDeletePermission = permissions.hasPermission(PermissionModules.BROKER_DELETE, userRole: user?.systemRole);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300, width: 1.2),
      ),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: InkWell(
        onTap: () => _openDetailsScreen(context, broker),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row: Name, Type Tag, Status Tag
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      broker.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isCp
                              ? (isDark ? const Color(0x336366F1) : const Color(0xFFEEF2FF))
                              : (isDark ? const Color(0x3310B981) : const Color(0xFFECFDF5)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isCp ? const Color(0x666366F1) : const Color(0x6610B981),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isCp ? 'Channel Partner' : 'Broker',
                          style: TextStyle(
                            color: isCp ? const Color(0xFF6366F1) : const Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? (isDark ? const Color(0x3310B981) : const Color(0xFFD1FAE5))
                              : (isDark ? const Color(0x33EF4444) : const Color(0xFFFEE2E2)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive ? const Color(0x6610B981) : const Color(0x66EF4444),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            color: isActive ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Second Row: Agency Name (left) & Date Badge (right, no created word, in border box)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: broker.agencyName.isNotEmpty
                        ? Row(
                            children: [
                              Icon(Icons.business_outlined, size: 14, color: theme.hintColor),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  broker.agencyName,
                                  style: TextStyle(color: theme.hintColor, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      formattedDate,
                      style: TextStyle(color: theme.hintColor, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Phone Number row with Edit & Delete buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_outlined, size: 14, color: theme.hintColor),
                      const SizedBox(width: 6),
                      Text(
                        broker.phoneNo,
                        style: TextStyle(color: theme.hintColor, fontSize: 13),
                      ),
                    ],
                  ),
                  // Action Buttons
                  Row(
                    children: [
                      // View Performance Analytics Button
                      IconButton(
                        onPressed: () => _showBrokerDashboardModal(context, broker),
                        icon: const Icon(Icons.bar_chart_rounded, size: 16, color: Colors.purple),
                        tooltip: 'View Stats & Analytics',
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.purple.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Assign Sales Team (Round-Robin) Button
                      if (hasUpdatePermission) ...[
                        IconButton(
                          onPressed: () => _showAssignUsersDialog(context, broker),
                          icon: const Icon(Icons.person_add_outlined, size: 16, color: Colors.blue),
                          tooltip: 'Auto-Assign Sales Team',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => showAddEditBrokerDialog(context, ref, broker: broker),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          tooltip: 'Edit Partner',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                      if (hasDeletePermission) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => _confirmDelete(broker),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                          tooltip: 'Delete Partner',
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.red.withValues(alpha: 0.1) : const Color(0xFFFEF2F2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bookings & Brokerage container with professional borders
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.0),
                  color: isDark ? Colors.white.withValues(alpha: 0.01) : const Color(0xFFFAFAFA),
                ),
                child: Column(
                  children: [
                    // Bookings Linked & Total Brokerage Row (side-by-side cells with vertical divider!)
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('BOOKINGS LINKED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text('${broker.bookingsCount}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                                ],
                              ),
                            ),
                          ),
                          VerticalDivider(width: 1, thickness: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TOTAL BROKERAGE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey[400], letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text(currencyFormat.format(broker.totalBrokerage), style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                    // Paid & Pending Row (Side-by-side cells with vertical divider!)
                    IntrinsicHeight(
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PAID COMMISSION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green[700], letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text(currencyFormat.format(broker.paidBrokerage), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                          VerticalDivider(width: 1, thickness: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('PENDING PAYOUT', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.red[700], letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text(currencyFormat.format(broker.pendingBrokerage), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                                ],
                              ),
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

  void _openDetailsScreen(BuildContext context, Broker broker) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BrokerDetailScreen(broker: broker),
      ),
    );
  }

  void _showBrokerDashboardModal(BuildContext context, Broker broker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final referralUrl = 'https://trevion.browndevs.com/public/lead-onboard?bid=${broker.id}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141416) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(modalContext).size.height * 0.90,
              ),
              child: FutureBuilder<BrokerDashboardData>(
                future: BrokerService().fetchBrokerDashboard(broker.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const AppShimmerDetailSkeleton();
                  }

                  if (snapshot.hasError) {
                    return SizedBox(
                      height: 350,
                      child: Center(
                        child: Text('Error loading stats: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                      ),
                    );
                  }

                  final stats = snapshot.data!;
                  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BROKER PERFORMANCE ANALYTICS',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                      color: isDark ? Colors.white54 : Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${broker.name}${broker.agencyName.isNotEmpty ? ' (${broker.agencyName})' : ''}',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.refresh, size: 20),
                                  onPressed: () => setModalState(() {}),
                                  tooltip: 'Refresh Stats',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 20),
                                  onPressed: () => Navigator.pop(modalContext),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Row 1: Financial & Activity Cards Side-by-Side Grid
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final isMobile = constraints.maxWidth < 600;
                            return isMobile
                                ? Column(
                                    children: [
                                      _buildFinancialCard(stats, currencyFormat, isDark),
                                      const SizedBox(height: 16),
                                      _buildActivityCard(stats, isDark),
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildFinancialCard(stats, currencyFormat, isDark)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildActivityCard(stats, isDark)),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 20),

                        // Row 2: Day-Wise Lead Referrals (Last 30 Days)
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.show_chart_rounded, size: 20, color: Colors.blueAccent),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Day-Wise Lead Referrals (Last 30 Days)',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Daily trend of prospective buyers onboarded by this broker partner.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 20),

                              _TrendChartWidget(trend: stats.dailyLeadsTrend, isDark: isDark),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Row 3: Partner Onboarding Referral Link Box
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.2),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PARTNER ONBOARDING REFERRAL LINK',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: isDark ? Colors.white54 : Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        referralUrl,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.white70 : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(text: referralUrl));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Referral link copied to clipboard!'), backgroundColor: Colors.green),
                                        );
                                      },
                                      icon: const Icon(Icons.copy, size: 14),
                                      label: const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: isDark ? Colors.white : Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFinancialCard(BrokerDashboardData stats, NumberFormat currencyFormat, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 18, color: isDark ? Colors.white : Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    'Brokerage & Payouts',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Financial', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildFinancialRow('Total Brokerage:', currencyFormat.format(stats.totalBrokerage), isDark ? Colors.white : Colors.black87, isDark),
          const SizedBox(height: 8),
          _buildFinancialRow('Paid Commission:', currencyFormat.format(stats.paidBrokerage), Colors.green, isDark),
          const SizedBox(height: 8),
          _buildFinancialRow('Pending Payout:', currencyFormat.format(stats.pendingBrokerage), Colors.red, isDark),
        ],
      ),
    );
  }

  Widget _buildFinancialRow(String label, String value, Color valueColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.grey[700])),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: valueColor)),
        ],
      ),
    );
  }

  Widget _buildActivityCard(BrokerDashboardData stats, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.people_outline, size: 18, color: isDark ? Colors.white : Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    'Referrals & Conversions',
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Activity', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('LEADS REFERRED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      const SizedBox(height: 6),
                      Text('${stats.totalLeads}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Text('DEALS CONVERTED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green[700])),
                      const SizedBox(height: 6),
                      Text('${stats.totalBookings}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[600])),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAssignUsersDialog(BuildContext context, Broker broker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final staffState = ref.watch(staffProvider(''));
    final selectedUserIds = List<String>.from(broker.assignedUsers);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final isUnassigned = selectedUserIds.isEmpty;

            final salesExecs = <StaffUser>[];
            final admins = <StaffUser>[];

            for (final user in staffState.users) {
              final roleUpper = user.systemRole.toUpperCase();
              if (roleUpper.contains('ADMIN') || roleUpper.contains('SUPER')) {
                admins.add(user);
              } else {
                salesExecs.add(user);
              }
            }

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Theme.of(dialogContext).cardColor,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Assign Employees for Round Robin (${selectedUserIds.length} selected)',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Leads submitted by ${broker.name} will be distributed in round robin across selected users.',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(dialogContext),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Content Body
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Unassigned Default Card
                              GestureDetector(
                                onTap: () {
                                  setDialogState(() {
                                    selectedUserIds.clear();
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isUnassigned
                                        ? (isDark ? Colors.blue.withValues(alpha: 0.1) : const Color(0xFFF0F7FF))
                                        : (isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isUnassigned
                                          ? Colors.blue
                                          : (isDark ? Colors.white12 : Colors.grey.shade300),
                                      width: isUnassigned ? 1.8 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Unassigned (Default Lead Pool)',
                                              style: GoogleFonts.plusJakartaSans(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Referred leads will go into company default lead pool without auto-assignment',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (isUnassigned)
                                        const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 22),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Category 1: Sales Executives
                              if (salesExecs.isNotEmpty) ...[
                                _buildCategoryHeader('Sales Executives', isDark),
                                const SizedBox(height: 12),
                                _buildUserGrid(salesExecs, selectedUserIds, setDialogState, isDark),
                                const SizedBox(height: 20),
                              ],

                              // Category 2: Admins
                              if (admins.isNotEmpty) ...[
                                _buildCategoryHeader('Admins', isDark),
                                const SizedBox(height: 12),
                                _buildUserGrid(admins, selectedUserIds, setDialogState, isDark),
                                const SizedBox(height: 16),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Footer Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text('CANCEL', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () async {
                              final scaffold = ScaffoldMessenger.of(context);
                              final nav = Navigator.of(dialogContext);
                              try {
                                await ref.read(brokersProvider.notifier).updateBroker(
                                  broker.id,
                                  {'assignedUsers': selectedUserIds},
                                );
                                if (nav.canPop()) nav.pop();
                                scaffold.showSnackBar(
                                  const SnackBar(content: Text('Auto-assignment sales team updated!'), backgroundColor: Colors.green),
                                );
                              } catch (e) {
                                scaffold.showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? Colors.blueAccent : Colors.black,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text('SAVE ASSIGNMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCategoryHeader(String title, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade300),
      ],
    );
  }

  Widget _buildUserGrid(List<StaffUser> users, List<String> selectedUserIds, StateSetter setDialogState, bool isDark) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: users.map((staff) {
        final isSelected = selectedUserIds.contains(staff.id);
        return SizedBox(
          width: 260,
          child: GestureDetector(
            onTap: () {
              setDialogState(() {
                if (isSelected) {
                  selectedUserIds.remove(staff.id);
                } else {
                  selectedUserIds.add(staff.id);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? Colors.blue.withValues(alpha: 0.12) : const Color(0xFFF0F7FF))
                    : (isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.blue : (isDark ? Colors.white12 : Colors.grey.shade300),
                  width: isSelected ? 1.6 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          staff.name,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatRole(staff.systemRole),
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected ? Colors.blue : Colors.grey[500],
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(Icons.check_circle_rounded, color: Colors.blue, size: 20),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatRole(String role) {
    if (role.isEmpty) return 'Staff';
    final clean = role.replaceAll('_', ' ').toLowerCase();
    return clean.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  void _confirmDelete(Broker broker) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Partner'),
        content: Text('Are you sure you want to delete ${broker.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(context);
              try {
                await ref.read(brokersProvider.notifier).deleteBroker(broker.id);
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Partner deleted successfully'), backgroundColor: Colors.green),
                );
              } catch (e) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

void showAddEditBrokerDialog(BuildContext context, WidgetRef ref, {Broker? broker}) {
  final isEdit = broker != null;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController(text: broker?.name ?? '');
  final phoneController = TextEditingController(text: broker?.phoneNo ?? '');
  final emailController = TextEditingController(text: broker?.email ?? '');
  final agencyController = TextEditingController(text: broker?.agencyName ?? '');
  final panController = TextEditingController(text: broker?.panNumber ?? '');
  final reraController = TextEditingController(text: broker?.reraNumber ?? '');
  
  // Portal Credentials
  final uniqueIdController = TextEditingController(text: broker?.uniqueId ?? '');
  final passwordController = TextEditingController();
  bool obscurePassword = true;

  // Address fields
  final addr1Controller = TextEditingController(text: broker?.address.address1 ?? '');
  final addr2Controller = TextEditingController(text: broker?.address.address2 ?? '');
  final cityController = TextEditingController(text: broker?.address.city ?? '');
  final pinController = TextEditingController(text: broker?.address.pinCode ?? '');
  final countryController = TextEditingController(text: broker?.address.country ?? 'India');

  final notesController = TextEditingController(text: broker?.notes ?? '');

  String typeVal = (broker?.type == 'ChannelPartner' || broker?.type == 'channel_partner') ? 'ChannelPartner' : 'Broker';
  String statusVal = (broker?.status.toLowerCase() == 'inactive') ? 'inactive' : 'active';
  String? stateVal = broker?.address.state;

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            backgroundColor: Theme.of(dialogContext).cardColor,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 650),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isEdit ? 'Edit Broker / Channel Partner' : 'Add New Broker / Channel Partner',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(dialogContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  
                  // Form Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Form(
                        key: formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Partner & Agency Details Card Header
                            const Text('Partner & Agency Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 8),

                            // Row 1: Partner Type & Status Dropdowns
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogDropdown(
                                    context: dialogContext,
                                    label: 'Partner Type',
                                    value: typeVal,
                                    items: const [
                                      DropdownMenuItem(value: 'Broker', child: Text('Broker')),
                                      DropdownMenuItem(value: 'ChannelPartner', child: Text('Channel Partner')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => typeVal = val);
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDialogDropdown(
                                    context: dialogContext,
                                    label: 'Status',
                                    value: statusVal,
                                    items: const [
                                      DropdownMenuItem(value: 'active', child: Text('Active')),
                                      DropdownMenuItem(value: 'inactive', child: Text('Inactive')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) setDialogState(() => statusVal = val);
                                    },
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Row 2: Name & Phone Number
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Name *',
                                    controller: nameController,
                                    isDark: isDark,
                                    required: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Phone Number *',
                                    controller: phoneController,
                                    isDark: isDark,
                                    required: true,
                                    keyboardType: TextInputType.phone,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Row 3: Email Address & Agency Name
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Email Address',
                                    controller: emailController,
                                    isDark: isDark,
                                    keyboardType: TextInputType.emailAddress,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Agency Name',
                                    controller: agencyController,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // 🔑 Portal Credentials Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Portal Credentials', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDialogTextField(
                                          context: dialogContext,
                                          label: 'Unique ID (Login ID)',
                                          controller: uniqueIdController,
                                          isDark: isDark,
                                          hintText: 'e.g. rajesh_apex',
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDialogTextField(
                                          context: dialogContext,
                                          label: isEdit ? 'New Password (Optional)' : 'Password *',
                                          controller: passwordController,
                                          isDark: isDark,
                                          obscureText: obscurePassword,
                                          required: !isEdit,
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                              size: 18,
                                              color: Colors.grey,
                                            ),
                                            onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Only lowercase letters, numbers & underscores allowed for Unique ID.',
                                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Row 4: Identification Details (PAN & RERA)
                            const Text('Identification Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'PAN Number',
                                    controller: panController,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'RERA Number',
                                    controller: reraController,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Address Details Section Header
                            const Text('Address Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
                            const SizedBox(height: 8),

                            // Address Line 1 & Line 2
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Address Line 1',
                                    controller: addr1Controller,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Address Line 2',
                                    controller: addr2Controller,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // City & State
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'City',
                                    controller: cityController,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDialogDropdown(
                                    context: dialogContext,
                                    label: 'State',
                                    value: stateVal,
                                    items: indianStates.map((s) {
                                      return DropdownMenuItem(
                                        value: s,
                                        child: Text(s, overflow: TextOverflow.ellipsis),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setDialogState(() => stateVal = val);
                                    },
                                    isDark: isDark,
                                    hintText: 'Select State',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Pin Code & Country
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Pin Code',
                                    controller: pinController,
                                    isDark: isDark,
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildDialogTextField(
                                    context: dialogContext,
                                    label: 'Country',
                                    controller: countryController,
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Internal Notes
                            _buildDialogTextField(
                              context: dialogContext,
                              label: 'Internal Notes',
                              controller: notesController,
                              isDark: isDark,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // Footer Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) return;

                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            final navigator = Navigator.of(dialogContext);

                            final brokerPayload = <String, dynamic>{
                              'type': typeVal,
                              'status': statusVal,
                              'name': nameController.text.trim(),
                              'phoneNo': phoneController.text.trim(),
                              'email': emailController.text.trim(),
                              'agencyName': agencyController.text.trim(),
                              'panNumber': panController.text.trim(),
                              'reraNumber': reraController.text.trim(),
                              if (uniqueIdController.text.trim().isNotEmpty)
                                'uniqueId': uniqueIdController.text.trim().toLowerCase().replaceAll(' ', '_'),
                              if (passwordController.text.isNotEmpty)
                                'password': passwordController.text,
                              'address': {
                                'address1': addr1Controller.text.trim(),
                                'address2': addr2Controller.text.trim(),
                                'city': cityController.text.trim(),
                                'state': stateVal ?? '',
                                'pinCode': pinController.text.trim(),
                                'country': countryController.text.trim(),
                              },
                              'notes': notesController.text.trim(),
                            };

                            try {
                              if (isEdit) {
                                await ref.read(brokersProvider.notifier).updateBroker(broker.id, brokerPayload);
                              } else {
                                await ref.read(brokersProvider.notifier).createBroker(brokerPayload);
                              }
                              if (navigator.canPop()) {
                                navigator.pop();
                              }
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text(isEdit ? 'Partner updated successfully' : 'Partner created successfully'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              scaffoldMessenger.showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.blueAccent : Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          child: Text(isEdit ? 'Save Partner' : 'Save Partner'),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Widget _buildDialogTextField({
  required BuildContext context,
  required String label,
  required TextEditingController controller,
  required bool isDark,
  bool required = false,
  bool obscureText = false,
  int maxLines = 1,
  TextInputType? keyboardType,
  String? hintText,
  Widget? suffixIcon,
}) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 13),
      validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText ?? 'Enter $label',
        hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 12),
        labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    ),
  );
}

Widget _buildDialogDropdown({
  required BuildContext context,
  required String label,
  required String? value,
  required List<DropdownMenuItem<String>> items,
  required ValueChanged<String?> onChanged,
  required bool isDark,
  String? hintText,
}) {
  final theme = Theme.of(context);
  final validValue = items.any((item) => item.value == value) ? value : null;
  return DropdownButtonFormField<String>(
    initialValue: validValue,
    items: items,
    onChanged: onChanged,
    isExpanded: true,
    hint: hintText != null ? Text(hintText, style: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 12)) : null,
    style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}

class BrokerDetailScreen extends ConsumerWidget {
  final Broker broker;

  const BrokerDetailScreen({super.key, required this.broker});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final brokersState = ref.watch(brokersProvider);
    final currentBroker = brokersState.brokers.firstWhere(
      (b) => b.id == broker.id,
      orElse: () => broker,
    );

    final staffState = ref.watch(staffProvider(''));
    final assignedStaffList = currentBroker.assignedUsers.map((id) {
      for (final u in staffState.users) {
        if (u.id == id) return u;
      }
      return StaffUser(
        id: id,
        name: id,
        uniqueId: id,
        email: '',
        systemRole: 'Staff',
        phoneNo: '',
        status: '',
        active: true,
        createdAt: DateTime.now(),
        createdBy: '',
      );
    }).toList();

    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    final hasUpdatePermission = permissions.hasPermission(PermissionModules.BROKER_UPDATE, userRole: user?.systemRole);

    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final formattedDate = currentBroker.createdAt != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(currentBroker.createdAt!))
        : '-';
    final isActive = currentBroker.status == 'active';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        toolbarHeight: 64,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'BROKER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              currentBroker.name,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            if (currentBroker.agencyName.isNotEmpty) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.domain_outlined, size: 12, color: isDark ? Colors.white54 : Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    currentBroker.agencyName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        actions: [
          if (hasUpdatePermission)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit Partner',
              onPressed: () => showAddEditBrokerDialog(context, ref, broker: currentBroker),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Card 1: Performance & Payouts (Matching Image)
            _buildSectionCard(
              title: 'Performance & Payouts',
              icon: Icons.account_balance_wallet_outlined,
              isDark: isDark,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBlock('TOTAL BOOKINGS', '${currentBroker.bookingsCount}', isDark ? Colors.white : Colors.black87, isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricBlock('TOTAL BROKERAGE', currencyFormat.format(currentBroker.totalBrokerage), isDark ? Colors.white : Colors.black87, isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricBlock('PAID COMMISSION', currencyFormat.format(currentBroker.paidBrokerage), Colors.green[600]!, isDark, labelColor: Colors.green[700]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricBlock('PENDING PAYOUT', currencyFormat.format(currentBroker.pendingBrokerage), Colors.red[600]!, isDark, labelColor: Colors.red[600]),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Card 2: Contact Information (Matching Image)
            _buildSectionCard(
              title: 'Contact Information',
              icon: Icons.person_outline,
              isDark: isDark,
              children: [
                _buildContactRow(Icons.phone_outlined, 'PHONE NUMBER', currentBroker.phoneNo, isDark),
                const SizedBox(height: 12),
                _buildContactRow(Icons.email_outlined, 'EMAIL ADDRESS', currentBroker.email.isNotEmpty ? currentBroker.email : '-', isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Card 3: Portal Login & Round Robin Assignees (Matching Image)
            _buildSectionCard(
              title: 'Portal Login & Round Robin Assignees',
              icon: Icons.description_outlined,
              isDark: isDark,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildValueBlock('PORTAL UNIQUE ID', currentBroker.uniqueId.isNotEmpty ? currentBroker.uniqueId : '-', isDark),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildValueBlock('RERA NUMBER', currentBroker.reraNumber.isNotEmpty ? currentBroker.reraNumber : '-', isDark),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'ASSIGNED EMPLOYEES (${currentBroker.assignedUsers.length})',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white54 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                if (assignedStaffList.isEmpty)
                  Text(
                    'Unassigned (Default Lead Pool)',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: assignedStaffList.map((staff) {
                      final roleClean = staff.systemRole.replaceAll('_', ' ').toLowerCase();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? Colors.white24 : Colors.grey.shade300),
                        ),
                        child: Text(
                          '${staff.name} ($roleClean)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Card 4: Address Details (Matching Image)
            _buildSectionCard(
              title: 'Address Details',
              icon: Icons.location_on_outlined,
              isDark: isDark,
              children: [
                _buildValueBlock('FULL ADDRESS', currentBroker.address.toDisplayString(), isDark),
              ],
            ),
            const SizedBox(height: 16),

            // Card 5: Additional Details (Matching Image)
            _buildSectionCard(
              title: 'Additional Details',
              icon: Icons.info_outline,
              isDark: isDark,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'STATUS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive ? Colors.green.withValues(alpha: 0.05) : Colors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isActive ? Colors.green : Colors.red, width: 1),
                            ),
                            child: Text(
                              isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                color: isActive ? Colors.green[700] : Colors.red[700],
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildValueBlock('REGISTERED ON', formattedDate, isDark),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: isDark ? Colors.white54 : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildValueBlock(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white60 : Colors.grey[600]),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
        ),
      ],
    );
  }

  Widget _buildMetricBlock(String label, String value, Color color, bool isDark, {Color? labelColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: labelColor ?? (isDark ? Colors.white54 : Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: Colors.grey[600]),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white12 : Colors.grey.shade200),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _TrendChartWidget extends StatelessWidget {
  final List<DailyLeadTrend> trend;
  final bool isDark;

  const _TrendChartWidget({required this.trend, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (trend.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text('No lead referral data in the last 30 days', style: TextStyle(fontSize: 12, color: Colors.grey))),
      );
    }

    final maxLeads = trend.fold<int>(0, (max, e) => e.leads > max ? e.leads : max);
    final maxY = (maxLeads < 4 ? 4 : maxLeads).toDouble();

    return Column(
      children: [
        SizedBox(
          height: 120,
          width: double.infinity,
          child: CustomPaint(
            painter: _TrendChartPainter(trend: trend, maxY: maxY, isDark: isDark),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _buildXAxisLabels(),
        ),
      ],
    );
  }

  List<Widget> _buildXAxisLabels() {
    if (trend.isEmpty) return [];
    final labels = <Widget>[];
    final step = (trend.length / 5).ceil().clamp(1, trend.length);
    for (int i = 0; i < trend.length; i += step) {
      final t = trend[i];
      labels.add(
        Text(
          t.displayDate.isNotEmpty ? t.displayDate : t.date,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      );
    }
    return labels;
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<DailyLeadTrend> trend;
  final double maxY;
  final bool isDark;

  _TrendChartPainter({required this.trend, required this.maxY, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return;

    final gridPaint = Paint()
      ..color = (isDark ? Colors.white10 : Colors.grey.shade200)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Horizontal grid lines
    for (int i = 0; i <= 4; i++) {
      final y = size.height - (i / 4.0) * size.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final stepX = size.width / (trend.length - 1);
    final points = <Offset>[];

    for (int i = 0; i < trend.length; i++) {
      final x = i * stepX;
      final y = size.height - (trend[i].leads / maxY) * size.height;
      points.add(Offset(x, y.clamp(0.0, size.height)));
    }

    final path = Path();
    final fillPath = Path();

    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final controlP1 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p1.dy);
      final controlP2 = Offset(p1.dx + (p2.dx - p1.dx) / 2, p2.dy);
      path.cubicTo(controlP1.dx, controlP1.dy, controlP2.dx, controlP2.dy, p2.dx, p2.dy);
      fillPath.cubicTo(controlP1.dx, controlP1.dy, controlP2.dx, controlP2.dy, p2.dx, p2.dy);
    }

    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    // Fill gradient
    final fillGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.blueAccent.withValues(alpha: 0.30),
        Colors.blueAccent.withValues(alpha: 0.0),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Line Paint
    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) => true;
}
