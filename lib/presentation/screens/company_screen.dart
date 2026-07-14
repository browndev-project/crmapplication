
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/company_provider.dart';
import '../widgets/global_app_bar.dart';
import '../../core/utils/roles.dart';
import '../providers/login_provider.dart';
import '../widgets/access_denied_widget.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(companyProvider.notifier).fetchCompanyDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(loginProvider).user;
    if (!SystemRoles.canViewCompanyPanel(user?.systemRole)) {
      return const Scaffold(
        appBar: GlobalAppBar(title: 'Company Panel', showBackButton: true),
        body: AccessDeniedWidget(
          sectionName: "Company Panel",
          showAppBar: false,
        ),
      );
    }

    final state = ref.watch(companyProvider);
    final company = state.company;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Safety check for optional subscription
    final subscription = company?.billing.subscription;
    final hasSubscription = subscription != null;
    final planEndDate = subscription?.currentPeriodEnd ?? DateTime.now();
    final planStartDate = subscription?.currentPeriodStart ?? DateTime.now();
    final daysLeft = hasSubscription ? subscription.daysLeft : 0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,

      appBar: const GlobalAppBar(title: ''), // Title handled in body custom header
      body: state.isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : state.error != null
             ? Center(child: Text("Error: ${state.error}", style: const TextStyle(color: Colors.red)))
             : company == null 
                 ? const Center(child: Text("No Company Data Found"))
                 : SingleChildScrollView(
                     padding: const EdgeInsets.all(16),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         // Custom Header
                         Row(
                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                           children: [
                             Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text('Company Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 20)),
                                 const SizedBox(height: 4),
                                 Text('Complete overview of company\ninformation and statistics', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13, height: 1.4)),
                               ],
                             ),
                             OutlinedButton(
                               onPressed: () => ref.read(companyProvider.notifier).refresh(),
                               style: OutlinedButton.styleFrom(
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Sharp but slightly rounded as per screenshot
                                 side: BorderSide(color: Colors.grey.shade400)
                               ),
                               child: Text("REFRESH", style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 12)),
                             )
                           ],
                         ),

                         const SizedBox(height: 20),

                         // Summary Card
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                             borderRadius: BorderRadius.circular(16),
                             boxShadow: [
                               BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                             ]
                           ),
                           child: Row(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Container(
                                 width: 60, height: 60,
                                 decoration: BoxDecoration(
                                   color: Colors.grey.shade100,
                                   borderRadius: BorderRadius.circular(12),
                                 ),
                                 child: Icon(Icons.domain, size: 30, color: Theme.of(context).iconTheme.color), // Placeholder for logo
                               ),
                               const SizedBox(width: 16),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(company.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                     const SizedBox(height: 4),
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         Column(
                                           crossAxisAlignment: CrossAxisAlignment.start,
                                           children: [
                                              Text('ID:', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13)),
                                              const SizedBox(height: 2),
                                              Text(company.companyId, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14)),
                                           ],
                                         ),
                                         Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                           decoration: BoxDecoration(
                                             color: company.status == 'Active' ? Colors.green.shade50 : Colors.red.shade50,
                                             borderRadius: BorderRadius.circular(20)
                                           ),
                                           child: Row(
                                             children: [
                                                if (company.status == 'Active')
                                                   Icon(Icons.check_circle, size: 16, color: Colors.green.shade700)
                                                else
                                                   Icon(Icons.cancel, size: 16, color: Colors.red.shade700),
                                                const SizedBox(width: 4),
                                                Text(company.status, style: TextStyle(
                                                    color: company.status == 'Active' ? Colors.green.shade700 : Colors.red.shade700,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13
                                                ))
                                             ],
                                           ),
                                         )
                                       ],
                                     )
                                   ],
                                 ),
                               )
                             ],
                           ),
                         ),

                         const SizedBox(height: 16),

                         // Stats Cards (Vertical Stack)
                         _buildStatRow(context, 'Total Users', '${company.totalUsers}', Icons.people, Colors.blue),
                         const SizedBox(height: 12),
                         _buildStatRow(context, 'Total Leads', '${company.totalLeads}', Icons.bar_chart, Colors.green),
                         const SizedBox(height: 12),
                         _buildStatRow(context, 'Total Services', '${company.totalServices}', Icons.settings, Colors.purple),

                         const SizedBox(height: 16),

                         // Basic Information
                         _buildSectionCard(context, 'Basic Information', Icons.domain, [
                            _buildInfoRow('Company Name:', company.name),
                            const Divider(height: 24, thickness: 0.5),
                            _buildInfoRow('Company ID:', company.companyId),
                            const Divider(height: 24, thickness: 0.5),
                            _buildInfoRow('Address:', company.address),
                            const Divider(height: 24, thickness: 0.5),
                            _buildInfoRow('GST Number:', company.gstNumber ?? 'N/A'),
                         ]),

                         const SizedBox(height: 16),

                         // Subscription Period (Only show if subscription exists)
                         if (hasSubscription)
                         Container(
                           width: double.infinity,
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                             borderRadius: BorderRadius.circular(16),
                             boxShadow: [
                               BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
                             ]
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   Icon(Icons.calendar_today_outlined, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                                   const SizedBox(width: 8),
                                   Text('Subscription Period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                                 ],
                               ),
                               const SizedBox(height: 20),
                               
                               // Green Active Box
                               Container(
                                 width: double.infinity,
                                 padding: const EdgeInsets.all(16),
                                 decoration: BoxDecoration(
                                   color: Colors.green.shade50,
                                   borderRadius: BorderRadius.circular(8),
                                   border: Border.all(color: Colors.green.shade100)
                                 ),
                                 child: Row(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Container(
                                       padding: const EdgeInsets.all(2),
                                       decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                                       child: const Icon(Icons.check, size: 14, color: Colors.white),
                                     ),
                                     const SizedBox(width: 12),
                                     Expanded(
                                       child: Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           Text('Active', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.bold, fontSize: 16)),
                                           const SizedBox(height: 4),
                                           Text('Subscription is active and will\nexpire in $daysLeft days', style: TextStyle(color: Colors.green.shade700, fontSize: 13, height: 1.4)),
                                         ],
                                       ),
                                     )
                                   ],
                                 ),
                               ),

                               const SizedBox(height: 24),
                               
                               // Dates Grid
                               _buildDateRow(Icons.calendar_today, 'Current Plan:', '${DateFormat('dd MMM, yyyy').format(planStartDate)} - ${DateFormat('dd MMM, yyyy').format(planEndDate)}'),
                               const SizedBox(height: 24),
                               _buildDateRow(Icons.access_time, 'Expiry Date:', '${DateFormat('dd MMM, yyyy').format(planEndDate)} (in $daysLeft days)', highlightValue: true),
                               const SizedBox(height: 24),
                               _buildDateRow(Icons.repeat, 'Next Due:', 'Normal: ${DateFormat('dd MMM, yyyy').format(planEndDate)}'),
                             ],
                           ),
                         ),

                         const SizedBox(height: 16),

                         // Contact Information
                         _buildSectionCard(context, 'Contact Information', Icons.email_outlined, [
                            _buildInfoRow('Email:', company.email),
                            const Divider(height: 24, thickness: 0.5),
                            _buildInfoRow('Contact Phone:', company.phone),
                            const Divider(height: 24, thickness: 0.5),
                            _buildInfoRow('Alt Contact Phone:', company.altPhone),
                         ]),

                         const SizedBox(height: 16),

                         // Billing Plan
                         _buildSectionCard(context, 'Billing Plan', Icons.receipt_long_outlined, [
                            _buildBillingRow('Plan:', company.billing.plan, isBadge: true),
                            const Divider(height: 24, thickness: 0.5),
                            _buildBillingRow('Per User Price:', '₹${company.billing.perUserPrice.toInt()} / user', isBold: false),
                            const Divider(height: 24, thickness: 0.5),
                            _buildBillingRow('User Limit:', '${company.billing.userLimit}', isBold: false),
                         ]),

                         const SizedBox(height: 16),

                         // Subscription Details (Extra)
                         if (hasSubscription)
                         _buildSectionCard(context, 'Subscription Details', Icons.autorenew, [
                            _buildBillingRow('Status:', subscription.status, isStatusBadge: true),
                            const Divider(height: 24, thickness: 0.5),
                            _buildBillingRow('Billing Cycle:', '${subscription.billingCycleDays} days', isBold: false),
                            const Divider(height: 24, thickness: 0.5),
                            _buildBillingRow('Grace Period:', '${subscription.graceDays} days', isBold: false),
                            const Divider(height: 24, thickness: 0.5),
                            _buildBillingRow('Currency:', subscription.currency, isBold: false),
                         ]),

                         const SizedBox(height: 16),

                         // System Information
                         _buildSectionCard(context, 'System Information', Icons.calendar_today, [
                            _buildInfoRow('Created At:', DateFormat('dd MMM yyyy,\nhh:mm a').format(company.createdAt)),
                            const Divider(height: 24, thickness: 0.5),
                            _buildInfoRow('Last Updated:', DateFormat('dd MMM yyyy,\nhh:mm a').format(company.updatedAt)),
                         ]),

                         const SizedBox(height: 30),
                       ],
                     ),
                 ),
    );
  }

  Widget _buildStatRow(BuildContext context, String title, String value, IconData icon, MaterialColor color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          )
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, IconData icon, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
         width: double.infinity,
         padding: const EdgeInsets.all(20),
         decoration: BoxDecoration(
           color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
           borderRadius: BorderRadius.circular(16),
           boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
           ]
         ),
         child: Column(
           children: [
             Row(
               children: [
                 Icon(icon, size: 20, color: isDark ? Colors.white70 : Colors.black87), // Assuming Icon is mostly purely decorative or dark grey
                 const SizedBox(width: 8),
                 Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
               ],
             ),
             const SizedBox(height: 24),
             ...children
           ],
         ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(flex: 2, child: Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w600, fontSize: 13))), // Reduced width for label
        Expanded(
          flex: 3, 
          child: Text(
            value, 
            textAlign: TextAlign.right, 
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)
          )
        ),
      ],
    );
  }
  
  Widget _buildDateRow(IconData icon, String label, String value, {bool highlightValue = false}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Icon(icon, size: 20, color: Colors.grey[600]), // Left Icon
           const SizedBox(width: 12),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    value, 
                    style: TextStyle(
                      fontSize: 15, 
                      fontWeight: FontWeight.w600, 
                      color: highlightValue ? Colors.green.shade700 : Theme.of(context).textTheme.bodyLarge?.color
                    )
                  ), // Value wrapped if long, as seen in "Current Plan"
               ],
             ),
           )
        ],
      );
  }

  Widget _buildBillingRow(String label, String value, {bool isBadge = false, bool isStatusBadge = false, bool isBold = true}) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontWeight: FontWeight.w600, fontSize: 13)),
          if (isBadge)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
               decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
               child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
             )
          else if (isStatusBadge)
             Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
               decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
               child: Text(value, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 13)),
             )
          else
             Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.w500, fontSize: 14)),
        ],
      );
  }
}
