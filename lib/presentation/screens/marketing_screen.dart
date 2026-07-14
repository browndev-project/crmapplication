import 'package:flutter/material.dart';

import '../widgets/global_app_bar.dart';
import 'marketing/widgets/lead_selection_view.dart';
import 'marketing/widgets/csv_upload_view.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/permissions_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/login_provider.dart';
import '../widgets/access_denied_widget.dart';

class MarketingScreen extends ConsumerStatefulWidget {
  const MarketingScreen({super.key});

  @override
  ConsumerState<MarketingScreen> createState() => _MarketingScreenState();
}

class _MarketingScreenState extends ConsumerState<MarketingScreen> {
  bool _isLeadSelectionMode = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;
    final hasLeadsModule = permissions.hasModule(PermissionModules.LEADS, userRole: userRole);

    // Force CSV mode if no leads access
    if (!hasLeadsModule && _isLeadSelectionMode) {
        // Schedule state change to avoid build error or just use local var for rendering
        // Since this is in build, we shouldn't setState. 
        // We'll just render CSV view and treat _isLeadSelectionMode as nominally true/false but ignored if no permission.
        // Better: Update state in a post-frame callback if needed, but for now let's just use 'effectiveMode'.
    }
    
    final effectiveMode = hasLeadsModule ? _isLeadSelectionMode : false;

    // Top-Level Module Check
    if (!permissions.hasModule(PermissionModules.MARKETING, userRole: userRole)) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Marketing'),
        body: AccessDeniedWidget(
          sectionName: "Marketing",
          showAppBar: false,
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const GlobalAppBar(title: 'Marketing'),

      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Theme.of(context).cardColor,
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header / Description
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Marketing Campaigns',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black87),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Reach out to your leads instantly via email.',
                        style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                
                // Toggle Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2130) : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        if (hasLeadsModule)
                        Expanded(
                          child: _buildToggleButton('Select Leads', effectiveMode, () {
                            setState(() => _isLeadSelectionMode = true);
                          }),
                        ),
                        Expanded(
                          child: _buildToggleButton('Upload CSV', !effectiveMode, () {
                            setState(() => _isLeadSelectionMode = false);
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Main Content
          Expanded(
            child: effectiveMode 
                ? const LeadSelectionView()
                : const CsvUploadView(),
          ),
        ],
      ),
    );
  }

   Widget _buildToggleButton(String text, bool isActive, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? (isDark ? const Color(0xFF2D324A) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            if (isActive && !isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
          border: isActive && isDark ? Border.all(color: Colors.white.withValues(alpha: 0.05)) : null,
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? (isDark ? Colors.white : Colors.black) : Colors.grey[500],
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
