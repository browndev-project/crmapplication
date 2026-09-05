import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../widgets/common_shimmer_skeleton.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../core/services/broker_service.dart';
import '../../../data/models/broker_model.dart';
import '../../providers/login_provider.dart';
import '../../providers/theme_provider.dart';
import '../login_screen.dart';

class BrokerShellScreen extends ConsumerStatefulWidget {
  const BrokerShellScreen({super.key});

  @override
  ConsumerState<BrokerShellScreen> createState() => _BrokerShellScreenState();
}

class _BrokerShellScreenState extends ConsumerState<BrokerShellScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // State for My Dashboard
  Future<BrokerDashboardData>? _dashboardFuture;

  // State for My Referrals
  Future<List<BrokerReferredLead>>? _leadsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  void _refreshData() {
    setState(() {
      _dashboardFuture = BrokerService().fetchMyDashboard();
      _leadsFuture = BrokerService().fetchMyLeads();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out of Broker Partner Portal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(loginProvider.notifier).logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(loginProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final String brokerId = (user?.id.isNotEmpty == true)
        ? user!.id
        : (user?.uniqueId.isNotEmpty == true ? user!.uniqueId : '');
    final referralUrl = brokerId.isNotEmpty
        ? 'https://trevion.browndevs.com/public/lead-onboard?bid=$brokerId'
        : 'https://trevion.browndevs.com/public/lead-onboard';

    final titles = [
      'Broker Partner Portal',
      'My Referred Leads',
      'Referral Link & QR Code',
      'My Profile',
    ];

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          titles[_currentIndex],
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final themeMode = ref.watch(themeProvider);
              final isDarkMode = themeMode == ThemeMode.dark;
              return IconButton(
                icon: Icon(
                  isDarkMode ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                onPressed: () {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: isDark ? Colors.white24 : Colors.black,
              child: Text(
                user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'B',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildAppDrawer(context, user, isDark),
      extendBody: true,
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDashboardTab(user, isDark, referralUrl),
          _buildReferredLeadsTab(isDark),
          _buildShareQrTab(user, isDark, referralUrl),
          _buildProfileTab(user, isDark),
        ],
      ),
      bottomNavigationBar: BrokerLiquidGlassNavBar(
        targetIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }

  // --- DRAWER ---
  Widget _buildAppDrawer(BuildContext context, dynamic user, bool isDark) {
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: Column(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Trevion',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Broker Panel Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Broker Panel',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user?.agencyName.isNotEmpty == true ? user!.agencyName! : (user?.companyDetails?.name ?? 'Partner Portal'),
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Drawer Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 8, top: 4),
                  child: Text(
                    'GENERAL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                ),
                _buildDrawerNavItem(
                  icon: Icons.grid_view_rounded,
                  title: 'Dashboard',
                  isSelected: _currentIndex == 0,
                  onTap: () {
                    setState(() => _currentIndex = 0);
                    Navigator.pop(context);
                  },
                  isDark: isDark,
                ),
                _buildDrawerNavItem(
                  icon: Icons.people_alt_outlined,
                  title: 'My Referrals',
                  isSelected: _currentIndex == 1,
                  onTap: () {
                    setState(() => _currentIndex = 1);
                    Navigator.pop(context);
                  },
                  isDark: isDark,
                ),
                _buildDrawerNavItem(
                  icon: Icons.qr_code_2_rounded,
                  title: 'Share QR & Form',
                  isSelected: _currentIndex == 2,
                  onTap: () {
                    setState(() => _currentIndex = 2);
                    Navigator.pop(context);
                  },
                  isDark: isDark,
                ),
                _buildDrawerNavItem(
                  icon: Icons.person_outline_rounded,
                  title: 'My Profile',
                  isSelected: _currentIndex == 3,
                  onTap: () {
                    setState(() => _currentIndex = 3);
                    Navigator.pop(context);
                  },
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const Divider(height: 1),
          // User Card Footer
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.black,
                      child: Text(
                        user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'B',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Broker Partner',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.agencyName ?? 'Channel Partner',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                      onPressed: _handleLogout,
                      tooltip: 'Logout',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerNavItem({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white60 : Colors.grey[700]),
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        dense: true,
      ),
    );
  }

  // --- TAB 1: DASHBOARD ---
  Widget _buildDashboardTab(dynamic user, bool isDark, String referralUrl) {
    final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<BrokerDashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Welcome Header Box
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Broker Partner Portal',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Welcome back, ${user?.name ?? 'Partner'}! Monitor your lead referrals, conversions, and financial brokerage payouts.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        onPressed: _refreshData,
                        tooltip: 'Refresh Dashboard',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                if (isLoading)
                  const AppShimmerCardSkeleton(itemCount: 2)
                else ...[
                  // Card 1: Brokerage & Payout Breakdown
                  _buildDashboardSectionCard(
                    title: 'Brokerage & Payout Breakdown',
                    subtitle: 'Financial commission status summary',
                    badgeText: 'Financial Overview',
                    badgeColor: Colors.grey,
                    icon: Icons.account_balance_wallet_outlined,
                    isDark: isDark,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildFinancialBox(
                            icon: Icons.account_balance_wallet_outlined,
                            iconColor: Colors.purple,
                            label: 'Total Brokerage',
                            value: currencyFormat.format(stats?.totalBrokerage ?? 0),
                            subtext: 'Total earned commission',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFinancialBox(
                            icon: Icons.payments_outlined,
                            iconColor: Colors.green,
                            label: 'Paid Commission',
                            value: currencyFormat.format(stats?.paidBrokerage ?? 0),
                            subtext: 'Disbursed to partner account',
                            valueColor: Colors.green[700],
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFinancialBox(
                            icon: Icons.hourglass_empty_outlined,
                            iconColor: Colors.red,
                            label: 'Pending Payout',
                            value: currencyFormat.format(stats?.pendingBrokerage ?? 0),
                            subtext: 'Awaiting release',
                            valueColor: Colors.red[700],
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 2: Referrals & Conversions
                  _buildDashboardSectionCard(
                    title: 'Referrals & Conversions',
                    subtitle: 'Buyer lead activity & property sales',
                    badgeText: 'Activity',
                    badgeColor: Colors.green,
                    icon: Icons.people_outline,
                    isDark: isDark,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildActivityBox(
                            icon: Icons.people_alt_outlined,
                            iconColor: Colors.blue,
                            label: 'Leads Referred',
                            value: '${stats?.totalLeads ?? 0}',
                            subtext: 'Total registered buyers',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildActivityBox(
                            icon: Icons.check_circle_outline_rounded,
                            iconColor: Colors.green,
                            label: 'Deals Converted',
                            value: '${stats?.totalBookings ?? 0}',
                            subtext: 'Properties sold',
                            valueColor: Colors.green[700],
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 3: Day-Wise Lead Referrals (Last 30 Days)
                  _buildDashboardSectionCard(
                    title: 'Day-Wise Lead Referrals (Last 30 Days)',
                    subtitle: 'Daily count of prospective property buyers onboarded through your link or QR code.',
                    icon: Icons.trending_up_rounded,
                    isDark: isDark,
                    child: _PortalTrendChartWidget(
                      trend: stats?.dailyLeadsTrend ?? [],
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Card 4: Partner Onboarding Referral Link
                  _buildDashboardSectionCard(
                    title: 'Partner Onboarding Referral Link',
                    subtitle: 'Share your referral link with prospective property buyers. Any lead submitted will automatically be credited to your broker account.',
                    icon: Icons.link_rounded,
                    isDark: isDark,
                    child: Container(
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
                  ),
                ],
                const SizedBox(height: 100),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- TAB 2: MY REFERRALS ---
  Widget _buildReferredLeadsTab(bool isDark) {
    return RefreshIndicator(
      onRefresh: () async => _refreshData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<BrokerReferredLead>>(
          future: _leadsFuture,
          builder: (context, snapshot) {
            final allLeads = snapshot.data ?? [];
            final isLoading = snapshot.connectionState == ConnectionState.waiting;

            final filteredLeads = allLeads.where((lead) {
              if (_searchQuery.isEmpty) return true;
              return lead.name.toLowerCase().contains(_searchQuery) ||
                  lead.phoneNo.toLowerCase().contains(_searchQuery) ||
                  lead.notes.toLowerCase().contains(_searchQuery);
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Referred Leads (${allLeads.length})',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Live tracking of prospective buyers who registered using your referral form or QR code.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        onPressed: _refreshData,
                        tooltip: 'Refresh Leads',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Search Bar Box
                TextField(
                  controller: _searchController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by customer name, phone or requirements...',
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[500], fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (isLoading)
                  const AppShimmerCardSkeleton(itemCount: 2)
                else if (filteredLeads.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.person_search_outlined, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty ? 'No matching referred leads found' : 'No buyer leads registered yet',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Share your QR code or referral link with clients to onboard buyers.',
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 580,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Table Header Row
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFFAFAFA),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                border: Border(bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300)),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(width: 140, child: Text('CUSTOMER NAME', style: _tableHeaderStyle(isDark))),
                                  SizedBox(width: 130, child: Text('PHONE NUMBER', style: _tableHeaderStyle(isDark))),
                                  SizedBox(width: 150, child: Text('REQUIREMENTS', style: _tableHeaderStyle(isDark))),
                                  SizedBox(width: 120, child: Text('SUBMITTED ON', style: _tableHeaderStyle(isDark))),
                                ],
                              ),
                            ),

                            // Table List Items
                            for (int i = 0; i < filteredLeads.length; i++) ...[
                              if (i > 0) Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Customer Name
                                    SizedBox(
                                      width: 140,
                                      child: Text(
                                        filteredLeads[i].name.isNotEmpty ? filteredLeads[i].name : '-',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Phone Number (Interactive Call)
                                    SizedBox(
                                      width: 130,
                                      child: InkWell(
                                        onTap: () {
                                          if (filteredLeads[i].phoneNo.isNotEmpty) {
                                            launchUrl(Uri.parse('tel:${filteredLeads[i].phoneNo}'));
                                          }
                                        },
                                        child: Row(
                                          children: [
                                            Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                filteredLeads[i].phoneNo.isNotEmpty ? filteredLeads[i].phoneNo : '-',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    // Requirements / Notes
                                    SizedBox(
                                      width: 150,
                                      child: Text(
                                        filteredLeads[i].notes.isNotEmpty ? filteredLeads[i].notes : 'None',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: filteredLeads[i].notes.isNotEmpty
                                              ? (isDark ? Colors.white70 : Colors.grey[700])
                                              : (isDark ? Colors.white38 : Colors.grey[400]),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // Submitted On
                                    SizedBox(
                                      width: 120,
                                      child: Text(
                                        filteredLeads[i].createdAt.isNotEmpty
                                            ? DateFormat('dd MMM yyyy,\nhh:mm a').format(DateTime.tryParse(filteredLeads[i].createdAt) ?? DateTime.now())
                                            : '-',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            );
          },
        ),
      ),
    );
  }

  TextStyle _tableHeaderStyle(bool isDark) {
    return TextStyle(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
      color: isDark ? Colors.white54 : Colors.grey[600],
    );
  }

  // --- TAB 3: SHARE QR & FORM ---
  Widget _buildShareQrTab(dynamic user, bool isDark, String referralUrl) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Title
          Text(
            'Referral Link & QR Code 📱',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Any prospective buyer who scans your QR code or submits through your referral link will automatically be credited to your account.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 20),

          // Card 1: Your Custom QR Code Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_2_rounded, size: 20, color: Colors.black87),
                    const SizedBox(width: 8),
                    Text(
                      'Your Custom QR Code',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // QR Code Generator Widget
                GestureDetector(
                  onTap: () => _showQrStandeeDialog(context, user, isDark, referralUrl),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: referralUrl,
                      version: QrVersions.auto,
                      size: 200.0,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Download Poster Button
                ElevatedButton.icon(
                  onPressed: () => _showQrStandeeDialog(context, user, isDark, referralUrl),
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Download Printable QR Poster', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueAccent : const Color(0xFF18181B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'Clients can scan this QR code directly with any smartphone camera to open your lead registration form.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card 2: Direct Referral Link & WhatsApp Share
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Direct Referral Link',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Copy your unique link or share it directly to WhatsApp with your clients.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
                const SizedBox(height: 16),

                // Link Container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  child: Text(
                    referralUrl,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 16),

                // Copy Referral Link Button
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: referralUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Referral link copied to clipboard!'), backgroundColor: Colors.green),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy Referral Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark ? Colors.white : Colors.black,
                    minimumSize: const Size(double.infinity, 44),
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 10),

                // WhatsApp Share Button
                ElevatedButton.icon(
                  onPressed: () async {
                    final message = Uri.encodeComponent(
                      'Hi! Please register your property inquiry using our official partner portal link:\n$referralUrl',
                    );
                    final whatsappUri = Uri.parse('https://api.whatsapp.com/send?text=$message');
                    if (await canLaunchUrl(whatsappUri)) {
                      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
                    } else {
                      if (!mounted) return;
                      Clipboard.setData(ClipboardData(text: referralUrl));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link copied! Open WhatsApp to paste.'), backgroundColor: Colors.green),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                  label: const Text('Share on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  // --- TAB 4: MY PROFILE ---
  Widget _buildProfileTab(dynamic user, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Profile Card Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isDark ? Colors.blueAccent : Colors.black,
                  child: Text(
                    user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'B',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Broker Partner',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (user?.agencyName.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          user!.agencyName!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green),
                  ),
                  child: Text(
                    user?.status?.toUpperCase() ?? 'ACTIVE',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Portal Identification
          _buildProfileSectionCard(
            title: 'Portal Credentials',
            icon: Icons.badge_outlined,
            isDark: isDark,
            children: [
              _buildProfileRow('PORTAL UNIQUE ID', user?.uniqueId ?? '-', isDark),
              _buildProfileRow('RERA REGISTRATION NO', user?.reraNumber ?? '-', isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Contact Details
          _buildProfileSectionCard(
            title: 'Contact Information',
            icon: Icons.phone_outlined,
            isDark: isDark,
            children: [
              _buildProfileRow('PHONE NUMBER', user?.phoneNo ?? '-', isDark),
              _buildProfileRow('EMAIL ADDRESS', user?.email ?? '-', isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Company Details
          _buildProfileSectionCard(
            title: 'Associated Company',
            icon: Icons.business_outlined,
            isDark: isDark,
            children: [
              _buildProfileRow('COMPANY NAME', user?.companyDetails?.name ?? 'Trevion Developers Ltd', isDark),
            ],
          ),
          const SizedBox(height: 24),

          // Logout Action
          ElevatedButton.icon(
            onPressed: _handleLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('LOGOUT OF BROKER PORTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  void _showQrStandeeDialog(BuildContext context, dynamic user, bool isDark, String referralUrl) {
    final GlobalKey qrKey = GlobalKey();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dialog Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Printable QR Standee Poster',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(dialogContext),
                        child: const Text(
                          'CLOSE',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Standee Poster Card inside RepaintBoundary
                  RepaintBoundary(
                    key: qrKey,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Official Partner Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'OFFICIAL PARTNER STANDEE',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Partner Name
                          Text(
                            user?.name ?? 'Partner Name',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Agency Name
                          Text(
                            user?.agencyName.isNotEmpty == true
                                ? user!.agencyName!
                                : (user?.companyDetails?.name ?? 'Partner Agency'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // QR Code Container
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300, width: 1.5),
                            ),
                            child: QrImageView(
                              data: referralUrl,
                              version: QrVersions.auto,
                              size: 180.0,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Action Headline
                          Text(
                            'SCAN QR CODE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Subtitle
                          Text(
                            'Scan with any mobile camera to view exclusive properties',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Bottom Pill Button inside Poster
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'SUBMIT YOUR ENQUIRY HERE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Modal Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : Colors.black87,
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('CANCEL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            RenderRepaintBoundary? boundary = qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
                            if (boundary == null) return;

                            ui.Image image = await boundary.toImage(pixelRatio: 3.0);
                            ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
                            if (byteData == null) return;

                            Uint8List pngBytes = byteData.buffer.asUint8List();
                            final tempDir = await getTemporaryDirectory();
                            final file = File('${tempDir.path}/partner_qr_standee_${DateTime.now().millisecondsSinceEpoch}.png');
                            await file.writeAsBytes(pngBytes);

                            if (context.mounted) {
                              Navigator.pop(dialogContext);
                              await Share.shareXFiles(
                                [XFile(file.path)],
                                text: 'Trevion Partner QR Standee Poster - ${user?.name ?? ''}',
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to generate PNG image: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: const Text('DOWNLOAD PNG IMAGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
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
  }

  Widget _buildProfileSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: isDark ? Colors.white12 : Colors.grey.shade200),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildProfileRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey[600]),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
          ),
        ],
      ),
    );
  }

  // --- DASHBOARD HELPER WIDGETS ---
  Widget _buildDashboardSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isDark,
    required Widget child,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (badgeColor ?? Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor ?? Colors.grey),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.white38 : Colors.grey[500]),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildFinancialBox({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtext,
    required bool isDark,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 9, color: isDark ? Colors.white38 : Colors.grey[500]),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityBox({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String subtext,
    required bool isDark,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.grey[600]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _PortalTrendChartWidget extends StatefulWidget {
  final List<DailyLeadTrend> trend;
  final bool isDark;

  const _PortalTrendChartWidget({required this.trend, required this.isDark});

  @override
  State<_PortalTrendChartWidget> createState() => _PortalTrendChartWidgetState();
}

class _PortalTrendChartWidgetState extends State<_PortalTrendChartWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.trend.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No lead referral data in the last 30 days',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }

    final maxLeads = widget.trend.fold<int>(0, (max, e) => e.leads > max ? e.leads : max);
    final maxY = (maxLeads < 4 ? 4 : maxLeads).toDouble();
    final ySteps = [maxY.toInt(), (maxY * 0.75).round(), (maxY * 0.5).round(), (maxY * 0.25).round(), 0];

    return GestureDetector(
      onTap: () {
        if (_selectedIndex != null) {
          setState(() => _selectedIndex = null);
        }
      },
      behavior: HitTestBehavior.translucent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-Axis Numeric Labels (0, 1, 2, 3, 4)
              SizedBox(
                width: 20,
                height: 140,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: ySteps.map((val) => Text(
                    '$val',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: widget.isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  )).toList(),
                ),
              ),
              const SizedBox(width: 8),
              // Chart Canvas & Touch Handler
              Expanded(
                child: SizedBox(
                  height: 140,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final chartWidth = constraints.maxWidth;
                      final chartHeight = constraints.maxHeight;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapDown: (details) => _handleTouch(details.localPosition, chartWidth),
                        onPanUpdate: (details) => _handleTouch(details.localPosition, chartWidth),
                        child: CustomPaint(
                          size: Size(chartWidth, chartHeight),
                          painter: _PortalTrendChartPainter(
                            trend: widget.trend,
                            maxY: maxY,
                            isDark: widget.isDark,
                            selectedIndex: _selectedIndex,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // X-Axis Date Labels
          Padding(
            padding: const EdgeInsets.only(left: 28.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: _buildXAxisLabels(),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTouch(Offset localPosition, double width) {
    if (widget.trend.isEmpty) return;
    final stepX = width / (widget.trend.length - 1);
    final index = (localPosition.dx / stepX).round().clamp(0, widget.trend.length - 1);
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
    });
  }

  List<Widget> _buildXAxisLabels() {
    if (widget.trend.isEmpty) return [];
    final labels = <Widget>[];
    final step = (widget.trend.length / 9).ceil().clamp(1, widget.trend.length);
    for (int i = 0; i < widget.trend.length; i += step) {
      final t = widget.trend[i];
      labels.add(
        Text(
          t.displayDate.isNotEmpty ? t.displayDate : t.date,
          style: TextStyle(
            fontSize: 10,
            color: widget.isDark ? Colors.white54 : Colors.grey[600],
          ),
        ),
      );
    }
    return labels;
  }
}

class _PortalTrendChartPainter extends CustomPainter {
  final List<DailyLeadTrend> trend;
  final double maxY;
  final bool isDark;
  final int? selectedIndex;

  _PortalTrendChartPainter({
    required this.trend,
    required this.maxY,
    required this.isDark,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trend.length < 2) return;

    // Horizontal grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.shade200)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

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

    final linePaint = Paint()
      ..color = Colors.blueAccent
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);

    // Interactive Hover / Tap Tooltip Box
    if (selectedIndex != null && selectedIndex! >= 0 && selectedIndex! < points.length) {
      final selPoint = points[selectedIndex!];
      final selData = trend[selectedIndex!];

      // Vertical guide line
      final vLinePaint = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.5)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(selPoint.dx, 0), Offset(selPoint.dx, size.height), vLinePaint);

      // Outer glow circle
      final glowPaint = Paint()
        ..color = Colors.blueAccent.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPoint, 10, glowPaint);

      // Solid blue circle
      final dotPaint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPoint, 5, dotPaint);

      // Inner white dot
      final innerDotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(selPoint, 2.5, innerDotPaint);

      // Tooltip Text Content
      final dateText = selData.displayDate.isNotEmpty ? selData.displayDate : selData.date;
      final leadsText = '${selData.leads} ${selData.leads == 1 ? 'Lead' : 'Leads'}';

      final titleSpan = TextSpan(
        text: '$dateText\n',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
        children: [
          TextSpan(
            text: leadsText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      );

      final textPainter = TextPainter(
        text: titleSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      const paddingH = 10.0;
      const paddingV = 6.0;
      final tooltipWidth = textPainter.width + paddingH * 2;
      final tooltipHeight = textPainter.height + paddingV * 2;

      // Position tooltip above point (or below if point is near top of chart)
      double tooltipX = selPoint.dx - tooltipWidth / 2;
      double tooltipY = selPoint.dy - tooltipHeight - 12;

      tooltipX = tooltipX.clamp(4.0, size.width - tooltipWidth - 4.0);
      if (tooltipY < 4.0) {
        tooltipY = selPoint.dy + 12;
      }

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(8),
      );

      // Shadow
      canvas.drawRRect(
        tooltipRect.shift(const Offset(0, 3)),
        Paint()
          ..color = Colors.black.withValues(alpha: isDark ? 0.4 : 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );

      // Translucent white / dark background box
      final bgPaint = Paint()
        ..color = isDark ? const Color(0xEE1E293B) : const Color(0xF5FFFFFF)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(tooltipRect, bgPaint);

      // Border
      final borderPaint = Paint()
        ..color = isDark ? Colors.white24 : Colors.grey.shade300
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(tooltipRect, borderPaint);

      // Paint text inside tooltip
      textPainter.paint(
        canvas,
        Offset(tooltipX + paddingH, tooltipY + paddingV),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PortalTrendChartPainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.isDark != isDark ||
      oldDelegate.maxY != maxY;
}

class _BrokerTabItem {
  final String title;
  final IconData activeIcon;
  final IconData inactiveIcon;

  const _BrokerTabItem({
    required this.title,
    required this.activeIcon,
    required this.inactiveIcon,
  });
}

class BrokerLiquidGlassNavBar extends StatelessWidget {
  final int targetIndex;
  final ValueChanged<int> onTap;

  const BrokerLiquidGlassNavBar({
    super.key,
    required this.targetIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const tabCount = 4;

    final glassColor = isDark ? const Color(0xB31F2937) : const Color(0xCCFFFFFF);
    final activeTextColor = isDark ? Colors.white : Colors.black;
    final inactiveTextColor = isDark ? Colors.white60 : Colors.black;
    final activeIndicatorColor = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final borderColor = isDark ? const Color(0x1AFFFFFF) : const Color(0x15000000);

    final bottomSafePadding = MediaQuery.of(context).padding.bottom;
    final bottomPad = bottomSafePadding > 0 
        ? (Theme.of(context).platform == TargetPlatform.iOS ? bottomSafePadding - 6.0 : bottomSafePadding + 12.0)
        : 16.0;

    const tabs = [
      _BrokerTabItem(title: 'Home', activeIcon: Icons.home, inactiveIcon: Icons.home_outlined),
      _BrokerTabItem(title: 'Referrals', activeIcon: Icons.people, inactiveIcon: Icons.people_outline),
      _BrokerTabItem(title: 'QR Code', activeIcon: Icons.qr_code_2_rounded, inactiveIcon: Icons.qr_code_outlined),
      _BrokerTabItem(title: 'Profile', activeIcon: Icons.person, inactiveIcon: Icons.person_outline),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: LiquidGlass.withOwnLayer(
          shape: const LiquidRoundedRectangle(borderRadius: 28),
          settings: LiquidGlassSettings(
            thickness: 16.0,
            blur: 20.0,
            glassColor: glassColor,
            lightIntensity: 0.5,
            refractiveIndex: 1.4,
          ),
          child: Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor, width: 0.5),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / tabCount;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Sliding Pill background (neomorphic glass capsule)
                    AnimatedAlign(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutQuad,
                      alignment: Alignment(
                        tabCount > 1
                            ? -1.0 + (targetIndex * 2.0 / (tabCount - 1))
                            : 0.0,
                        0,
                      ),
                      child: Container(
                        width: itemWidth - 4,
                        height: 48,
                        decoration: BoxDecoration(
                          color: activeIndicatorColor,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isDark ? const Color(0x26FFFFFF) : const Color(0x80FFFFFF),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Nav Items
                    Row(
                      children: List.generate(tabCount, (index) {
                        final tab = tabs[index];
                        final bool isActive = (targetIndex == index);
                        final double scale = isActive ? 1.25 : ((targetIndex - index).abs() == 1 ? 1.10 : 1.0);

                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              onTap(index);
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                AnimatedScale(
                                  scale: scale,
                                  duration: const Duration(milliseconds: 280),
                                  curve: Curves.easeOutBack,
                                  child: Icon(
                                    isActive ? tab.activeIcon : tab.inactiveIcon,
                                    size: 21,
                                    color: isActive ? activeTextColor : inactiveTextColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  tab.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
                                    color: isActive ? activeTextColor : inactiveTextColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
