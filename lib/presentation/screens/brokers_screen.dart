import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../core/constants/permission_constants.dart';
import '../../data/models/broker_model.dart';
import '../providers/broker_provider.dart';
import '../providers/permissions_provider.dart';
import '../providers/login_provider.dart';
import '../widgets/global_app_bar.dart';

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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 64.0),
                  child: Center(child: CircularProgressIndicator()),
                )
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
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
                      onPressed: () => _showAddEditDialog(context),
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
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
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
                      if (hasUpdatePermission)
                        IconButton(
                          onPressed: () => _showAddEditDialog(context, broker: broker),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(6),
                          style: IconButton.styleFrom(
                            backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                        ),
                      if (hasDeletePermission) ...[
                        const SizedBox(width: 6),
                        IconButton(
                          onPressed: () => _confirmDelete(broker),
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
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

  void _confirmDelete(Broker broker) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: const Text('Delete Partner'),
          content: Text('Are you sure you want to delete ${broker.name}? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                navigator.pop();
                try {
                  await ref.read(brokersProvider.notifier).deleteBroker(broker.id);
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Partner deleted successfully'), backgroundColor: Colors.green),
                  );
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _showAddEditDialog(BuildContext context, {Broker? broker}) {
    final isEdit = broker != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: broker?.name ?? '');
    final phoneController = TextEditingController(text: broker?.phoneNo ?? '');
    final emailController = TextEditingController(text: broker?.email ?? '');
    final agencyController = TextEditingController(text: broker?.agencyName ?? '');
    final panController = TextEditingController(text: broker?.panNumber ?? '');
    final reraController = TextEditingController(text: broker?.reraNumber ?? '');
    
    // Address fields
    final addr1Controller = TextEditingController(text: broker?.address.address1 ?? '');
    final addr2Controller = TextEditingController(text: broker?.address.address2 ?? '');
    final cityController = TextEditingController(text: broker?.address.city ?? '');
    final pinController = TextEditingController(text: broker?.address.pinCode ?? '');
    final countryController = TextEditingController(text: broker?.address.country ?? 'India');

    final notesController = TextEditingController(text: broker?.notes ?? '');

    String typeVal = broker?.type ?? 'Broker';
    String statusVal = broker?.status ?? 'active';
    String? stateVal = broker?.address.state;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: Theme.of(context).cardColor,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
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
                            onPressed: () => Navigator.pop(context),
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
                              // Row 1: Partner Type & Status Dropdowns
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDialogDropdown(
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
                                      label: 'Name *',
                                      controller: nameController,
                                      isDark: isDark,
                                      required: true,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDialogTextField(
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
                                      label: 'Email Address',
                                      controller: emailController,
                                      isDark: isDark,
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDialogTextField(
                                      label: 'Agency Name',
                                      controller: agencyController,
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Row 4: PAN Number & RERA Number
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDialogTextField(
                                      label: 'PAN Number',
                                      controller: panController,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDialogTextField(
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
                                      label: 'Address Line 1',
                                      controller: addr1Controller,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDialogTextField(
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
                                      label: 'City',
                                      controller: cityController,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDialogDropdown(
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
                                      label: 'Pin Code',
                                      controller: pinController,
                                      isDark: isDark,
                                      keyboardType: TextInputType.number,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildDialogTextField(
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
                            onPressed: () => Navigator.pop(context),
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
                              final navigator = Navigator.of(context);

                              final brokerPayload = {
                                'type': typeVal,
                                'status': statusVal,
                                'name': nameController.text.trim(),
                                'phoneNo': phoneController.text.trim(),
                                'email': emailController.text.trim(),
                                'agencyName': agencyController.text.trim(),
                                'panNumber': panController.text.trim(),
                                'reraNumber': reraController.text.trim(),
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
                                navigator.pop();
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
    required String label,
    required TextEditingController controller,
    required bool isDark,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 13),
        validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Enter $label',
          hintStyle: TextStyle(color: Colors.grey.withValues(alpha: 0.5), fontSize: 12),
          labelStyle: TextStyle(color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.4))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? Colors.white : Colors.black, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildDialogDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
    String? hintText,
  }) {
    final theme = Theme.of(context);
    return DropdownButtonFormField<String>(
      initialValue: value,
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
}

class BrokerDetailScreen extends StatelessWidget {
  final Broker broker;

  const BrokerDetailScreen({super.key, required this.broker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final formattedDate = broker.createdAt != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(broker.createdAt!))
        : '-';
    final isCp = broker.type == 'ChannelPartner';
    final isActive = broker.status == 'active';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Partner Details',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Distinct Profile Card structure
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black26 : Colors.grey.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            broker.name,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          if (broker.agencyName.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              broker.agencyName,
                              style: GoogleFonts.plusJakartaSans(
                                color: theme.hintColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCp
                                ? (isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.purple.withValues(alpha: 0.08))
                                : (isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isCp 
                                  ? (isDark ? Colors.purple.withValues(alpha: 0.4) : Colors.purple.withValues(alpha: 0.2))
                                  : (isDark ? Colors.blue.withValues(alpha: 0.4) : Colors.blue.withValues(alpha: 0.2)),
                            ),
                          ),
                          child: Text(
                            isCp ? 'Channel Partner' : 'Broker',
                            style: TextStyle(
                              color: isCp 
                                  ? (isDark ? const Color(0xFFD8B4FE) : Colors.purple[700])
                                  : (isDark ? const Color(0xFF93C5FD) : Colors.blue[700]),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark ? Colors.green.withValues(alpha: 0.2) : Colors.green.withValues(alpha: 0.08))
                                : (isDark ? Colors.red.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.08)),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive 
                                  ? (isDark ? Colors.green.withValues(alpha: 0.4) : Colors.green.withValues(alpha: 0.2))
                                  : (isDark ? Colors.red.withValues(alpha: 0.4) : Colors.red.withValues(alpha: 0.2)),
                            ),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color: isActive 
                                  ? (isDark ? const Color(0xFF86EFAC) : Colors.green[700])
                                  : (isDark ? const Color(0xFFFCA5A5) : Colors.red[700]),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Content Area
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Performance & Payouts Card - Premium Dashboard Grid Look
                  Container(
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
                                color: Colors.blueAccent.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, size: 18, color: Colors.blueAccent),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Performance & Payouts',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Grid layout for 4 items
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                label: 'TOTAL BOOKINGS',
                                value: '${broker.bookingsCount}',
                                color: isDark ? Colors.white : Colors.black87,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                label: 'TOTAL BROKERAGE',
                                value: currencyFormat.format(broker.totalBrokerage),
                                color: isDark ? Colors.white : Colors.black87,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildMetricCard(
                                label: 'PAID COMMISSION',
                                value: currencyFormat.format(broker.paidBrokerage),
                                color: Colors.green,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildMetricCard(
                                label: 'PENDING PAYOUT',
                                value: currencyFormat.format(broker.pendingBrokerage),
                                color: Colors.red,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Contact Info Card
                  _buildSectionCard(
                    title: 'Contact Information',
                    icon: Icons.contact_phone_outlined,
                    isDark: isDark,
                    children: [
                      _buildDetailRow(Icons.phone_rounded, 'Phone Number', broker.phoneNo, isDark),
                      _buildDetailRow(Icons.email_rounded, 'Email Address', broker.email.isNotEmpty ? broker.email : '-', isDark, isLast: true),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Identification Card
                  _buildSectionCard(
                    title: 'Identification Details',
                    icon: Icons.badge_outlined,
                    isDark: isDark,
                    children: [
                      _buildDetailRow(Icons.app_registration, 'RERA Registration No', broker.reraNumber.isNotEmpty ? broker.reraNumber : '-', isDark),
                      _buildDetailRow(Icons.credit_card, 'PAN Card No', broker.panNumber.isNotEmpty ? broker.panNumber : '-', isDark, isLast: true),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Address Details Card
                  _buildSectionCard(
                    title: 'Address Details',
                    icon: Icons.location_on_outlined,
                    isDark: isDark,
                    children: [
                      _buildDetailRow(Icons.home_outlined, 'Address Line 1', broker.address.address1.isNotEmpty ? broker.address.address1 : '-', isDark),
                      _buildDetailRow(Icons.home_work_outlined, 'Address Line 2', broker.address.address2.isNotEmpty ? broker.address.address2 : '-', isDark),
                      _buildDetailRow(Icons.location_city, 'City', broker.address.city.isNotEmpty ? broker.address.city : '-', isDark),
                      _buildDetailRow(Icons.map_outlined, 'State', broker.address.state.isNotEmpty ? broker.address.state : '-', isDark),
                      _buildDetailRow(Icons.pin_outlined, 'Pin Code', broker.address.pinCode.isNotEmpty ? broker.address.pinCode : '-', isDark),
                      _buildDetailRow(Icons.public, 'Country', broker.address.country.isNotEmpty ? broker.address.country : 'India', isDark, isLast: true),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Meta & Notes Card
                  _buildSectionCard(
                    title: 'Meta & Remarks',
                    icon: Icons.info_outline,
                    isDark: isDark,
                    children: [
                      _buildDetailRow(Icons.calendar_today, 'Registration Date', formattedDate, isDark),
                      _buildDetailRow(Icons.description_outlined, 'Notes / Remarks', broker.notes.isNotEmpty ? broker.notes : '-', isDark, isLast: true),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey[400],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
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

  Widget _buildDetailRow(IconData icon, String label, String val, bool isDark, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 10),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  val,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (!isLast) ...[
            const SizedBox(height: 8),
            Divider(height: 1, thickness: 0.5, color: isDark ? Colors.white12 : Colors.grey.shade200),
          ]
        ],
      ),
    );
  }
}
