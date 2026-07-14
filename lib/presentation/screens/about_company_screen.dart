import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/services/company_service.dart';
import '../../data/models/company_model.dart';
import '../widgets/global_app_bar.dart';
import '../widgets/dashboard_stats_card.dart';

class AboutCompanyScreen extends StatefulWidget {
  const AboutCompanyScreen({super.key});

  @override
  State<AboutCompanyScreen> createState() => _AboutCompanyScreenState();
}

class _AboutCompanyScreenState extends State<AboutCompanyScreen> {
  final CompanyService _companyService = CompanyService();
  Company? _company;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCompanyDetails();
  }

  Future<void> _fetchCompanyDetails() async {
    try {
      final company = await _companyService.fetchCompanyDetails();
      if (mounted) {
        setState(() {
          _company = company;
          _isLoading = false;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 900;

    return Scaffold(
      appBar: GlobalAppBar(
        title: '${_company?.name ?? "Company"} Owner Dashboard',
      ),

      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       Icon(Icons.wifi_off_rounded, size: 64, color: isDark ? Colors.blue.withValues(alpha: 0.5) : Colors.blue.shade200),
                       const SizedBox(height: 24),
                       Text('Something went wrong', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                       const SizedBox(height: 8),
                       Text(_error ?? 'Unable to load company details', style: TextStyle(color: Colors.grey[500], fontSize: 14), textAlign: TextAlign.center),
                       const SizedBox(height: 32),
                       ElevatedButton(
                         onPressed: () {
                           setState(() {
                             _isLoading = true;
                             _error = null;
                           });
                           _fetchCompanyDetails();
                         },
                         style: ElevatedButton.styleFrom(
                           backgroundColor: isDark ? Colors.blue : Colors.black,
                           foregroundColor: Colors.white,
                           elevation: 0,
                           padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                         ),
                         child: const Text('RETRY', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                       ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header Section with gradient
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))),
                        ),
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Company Details',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.grey[500] : Colors.grey[600],
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Complete overview of company information and statistics',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[600] : Colors.grey[500],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Company Name Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(Icons.business, color: Colors.blue.shade700, size: 28),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _company?.name ?? 'N/A',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'ID: ${_company?.companyId ?? 'N/A'}',
                                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: (_company?.status == 'Active' ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 7,
                                          height: 7,
                                          decoration: BoxDecoration(
                                            color: _company?.status == 'Active'
                                                ? Colors.green
                                                : Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _company?.status ?? 'Inactive',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: _company?.status == 'Active'
                                                ? Colors.green.shade700
                                                : Colors.red.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Stats Cards
                            Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: DashboardStatsCard(
                                        title: 'Total Users',
                                        value: '${_company?.totalUsers ?? 0}',
                                        icon: Icons.people,
                                        backgroundColor: const Color(0xFF1A73E8),
                                        gradientColors: const [Color(0xFF1A73E8), Color(0xFF4285F4)],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DashboardStatsCard(
                                        title: 'Total Leads',
                                        value: '${_company?.totalLeads ?? 0}',
                                        icon: Icons.leaderboard,
                                        backgroundColor: const Color(0xFF00BFA5),
                                        gradientColors: const [Color(0xFF00BFA5), Color(0xFF1DE9B6)],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DashboardStatsCard(
                                        title: 'Total Services',
                                        value: '${_company?.totalServices ?? 0}',
                                        icon: Icons.miscellaneous_services,
                                        backgroundColor: const Color(0xFF6A1B9A),
                                        gradientColors: const [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(child: SizedBox()),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Content Section
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: isMobile
                            ? Column(
                                children: [
                                  _buildInfoSection(
                                    title: 'Basic Information',
                                    icon: Icons.info_outline,
                                    items: [
                                      _InfoItem(label: 'Company Name', value: _company?.name ?? 'N/A'),
                                      _InfoItem(label: 'Company ID', value: _company?.companyId ?? 'N/A'),
                                      _InfoItem(label: 'Address', value: _company?.address ?? 'N/A'),
                                      _InfoItem(label: 'GST Number', value: _company?.gstNumber ?? 'N/A'),
                                    ],
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildInfoSection(
                                    title: 'Contact Information',
                                    icon: Icons.contact_phone,
                                    items: [
                                      _InfoItem(label: 'Email', value: _company?.email ?? 'N/A'),
                                      _InfoItem(label: 'Contact Phone', value: _company?.phone ?? 'N/A'),
                                      _InfoItem(label: 'Alt Contact Phone', value: _company?.altPhone ?? 'N/A'),
                                    ],
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildSubscriptionPeriodCard(isDark),
                                  const SizedBox(height: 16),
                                  _buildInfoSection(
                                    title: 'Subscription Details',
                                    icon: Icons.subscriptions,
                                    items: [
                                      _InfoItem(
                                        label: 'Status',
                                        value: _company?.billing.subscription?.status.toUpperCase() ?? 'N/A',
                                        valueColor: _getStatusColor(_company?.billing.subscription?.status),
                                      ),
                                      _InfoItem(
                                        label: 'Billing Cycle',
                                        value: '${_company?.billing.subscription?.billingCycleDays ?? 0} days',
                                      ),
                                      _InfoItem(
                                        label: 'Grace Period',
                                        value: '${_company?.billing.subscription?.graceDays ?? 0} days',
                                      ),
                                    ],
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildBillingPlanCard(isDark),
                                  const SizedBox(height: 16),
                                  _buildSystemInfoCard(isDark),
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Column
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildInfoSection(
                                          title: 'Basic Information',
                                          icon: Icons.info_outline,
                                          items: [
                                            _InfoItem(label: 'Company Name', value: _company?.name ?? 'N/A'),
                                            _InfoItem(label: 'Company ID', value: _company?.companyId ?? 'N/A'),
                                            _InfoItem(label: 'Address', value: _company?.address ?? 'N/A'),
                                            _InfoItem(label: 'GST Number', value: _company?.gstNumber ?? 'N/A'),
                                          ],
                                          isDark: isDark,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInfoSection(
                                          title: 'Contact Information',
                                          icon: Icons.contact_phone,
                                          items: [
                                            _InfoItem(label: 'Email', value: _company?.email ?? 'N/A'),
                                            _InfoItem(label: 'Contact Phone', value: _company?.phone ?? 'N/A'),
                                            _InfoItem(label: 'Alt Contact Phone', value: _company?.altPhone ?? 'N/A'),
                                          ],
                                          isDark: isDark,
                                        ),
                                        const SizedBox(height: 16),
                                        _buildInfoSection(
                                          title: 'Subscription Details',
                                          icon: Icons.subscriptions,
                                          items: [
                                            _InfoItem(
                                              label: 'Status',
                                              value: _company?.billing.subscription?.status.toUpperCase() ?? 'N/A',
                                              valueColor: _getStatusColor(_company?.billing.subscription?.status),
                                            ),
                                            _InfoItem(
                                              label: 'Billing Cycle',
                                              value: '${_company?.billing.subscription?.billingCycleDays ?? 0} days',
                                            ),
                                            _InfoItem(
                                              label: 'Grace Period',
                                              value: '${_company?.billing.subscription?.graceDays ?? 0} days',
                                            ),
                                          ],
                                          isDark: isDark,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Right Column
                                  Expanded(
                                    child: Column(
                                      children: [
                                        _buildSubscriptionPeriodCard(isDark),
                                        const SizedBox(height: 16),
                                        _buildBillingPlanCard(isDark),
                                        const SizedBox(height: 16),
                                        _buildSystemInfoCard(isDark),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }



  Widget _buildInfoSection({
    required String title,
    required IconData icon,
    required List<_InfoItem> items,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...items.asMap().entries.map((entry) {
            final isLast = entry.key == items.length - 1;
            final item = entry.value;
            return Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: item.valueColor ?? (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                    ),
                  ],
                ),
                if (!isLast) ...[
                  const SizedBox(height: 14),
                  Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.05), height: 1),
                  const SizedBox(height: 14),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubscriptionPeriodCard(bool isDark) {
    final subscription = _company?.billing.subscription;
    final isActive = subscription?.status == 'active';
    final daysLeft = subscription?.daysLeft ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.calendar_today, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 10),
              Text(
                'Subscription Period',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildPeriodItem(
            icon: Icons.circle,
            iconColor: isActive ? Colors.green : Colors.red,
            label: isActive ? 'Active' : 'Inactive',
            sublabel: isActive
                ? 'Subscription is active and will expire in $daysLeft days'
                : 'Subscription is not active',
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, height: 1),
          const SizedBox(height: 14),
          _buildPeriodItem(
            icon: Icons.event,
            iconColor: Colors.blue,
            label: 'Current Plan',
            sublabel:
                '${DateFormat('dd MMM yyyy').format(subscription?.currentPeriodStart ?? DateTime.now())} - ${DateFormat('dd MMM yyyy').format(subscription?.currentPeriodEnd ?? DateTime.now())}',
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, height: 1),
          const SizedBox(height: 14),
          _buildPeriodItem(
            icon: Icons.access_time,
            iconColor: Colors.orange,
            label: 'Expiry Date',
            sublabel: DateFormat('dd MMM yyyy (hh:mm a)').format(subscription?.currentPeriodEnd ?? DateTime.now()),
            isDark: isDark,
          ),
          const SizedBox(height: 14),
          Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.05), height: 1),
          const SizedBox(height: 14),
          _buildPeriodItem(
            icon: Icons.event_available,
            iconColor: Colors.purple,
            label: 'Next Due',
            sublabel: DateFormat('dd MMM yyyy').format(subscription?.currentPeriodEnd ?? DateTime.now()),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String sublabel,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBillingPlanCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.payment, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 10),
              Text(
                'Billing Plan',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildBillingItem('Plan', _company?.billing.plan ?? 'N/A', isDark),
        const SizedBox(height: 14),
        Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.05), height: 1),
        const SizedBox(height: 14),
        _buildBillingItem('Per User Price', '₹${_company?.billing.perUserPrice ?? 0}', isDark),
        const SizedBox(height: 14),
        Divider(color: Theme.of(context).dividerColor.withValues(alpha: 0.05), height: 1),
        const SizedBox(height: 14),
        _buildBillingItem('User Limit', '${_company?.billing.userLimit ?? 0}', isDark),
        ],
      ),
    );
  }

  Widget _buildBillingItem(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.settings, size: 16, color: isDark ? Colors.grey[400] : Colors.grey[700]),
              ),
              const SizedBox(width: 10),
              Text(
                'System Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildSystemItem(
            'Created At',
            DateFormat('dd MMM yyyy, hh:mm a').format(_company?.createdAt ?? DateTime.now()),
            isDark,
          ),
          const SizedBox(height: 14),
          Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, height: 1),
          const SizedBox(height: 14),
          _buildSystemItem(
            'Last Updated',
            DateFormat('dd MMM yyyy, hh:mm a').format(_company?.updatedAt ?? DateTime.now()),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildSystemItem(String label, String value, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'inactive':
      case 'expired':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
}

class _InfoItem {
  final String label;
  final String value;
  final Color? valueColor;

  _InfoItem({required this.label, required this.value, this.valueColor});
}
