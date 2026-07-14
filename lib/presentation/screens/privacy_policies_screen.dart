import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/global_app_bar.dart';
class PrivacyPoliciesScreen extends StatelessWidget {
  const PrivacyPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const GlobalAppBar(title: 'Policies & Info'),

      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(height: 5, color: const Color(0xFFFFE100)), // Trevion/Blinkit style strip
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Legal & Information",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Transparent policies for a better experience",
                    style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  
                  _buildSectionTitle(context, "Legal Documents"),
                  const SizedBox(height: 12),
                  _buildPolicyButton(
                    context, 
                    "Privacy Policy", 
                    "How we handle your data", 
                    Icons.privacy_tip_outlined, 
                    "https://trevion.browndevs.com/privacyPolicy",
                    Colors.blue
                  ),
                  _buildPolicyButton(
                    context, 
                    "Terms & Conditions", 
                    "Rules for using Trevion CRM", 
                    Icons.description_outlined, 
                    "https://trevion.browndevs.com/terms-and-conditions",
                    Colors.orange
                  ),
                  _buildPolicyButton(
                    context, 
                    "Refund & Cancellation", 
                    "Policy for payments and services", 
                    Icons.receipt_long_outlined, 
                    "https://trevion.browndevs.com/refund-and-cancellation",
                    Colors.green
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, "Account Management"),
                  const SizedBox(height: 12),
                  _buildPolicyButton(
                    context, 
                    "Account Deletion", 
                    "Request permanent removal of your account", 
                    Icons.person_remove_outlined, 
                    "https://trevion.browndevs.com/account-deletion",
                    Colors.red
                  ),
                  
                  const SizedBox(height: 24),
                  _buildSectionTitle(context, "Our Company"),
                  const SizedBox(height: 12),
                  _buildPolicyButton(
                    context, 
                    "About Trevion", 
                    "Learn more about the platform", 
                    Icons.business_outlined, 
                    "https://trevion.browndevs.com/about",
                    Colors.indigo
                  ),
                  _buildPolicyButton(
                    context, 
                    "About Brown Devs", 
                    "Parent company website", 
                    Icons.language_outlined, 
                    "https://www.browndevs.com/",
                    Colors.teal
                  ),
                  _buildPolicyButton(
                    context, 
                    "Contact Us", 
                    "Get in touch for support", 
                    Icons.support_agent_outlined, 
                    "https://www.browndevs.com/contact-us",
                    Colors.pink
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPolicyButton(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    String url,
    Color accentColor
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        elevation: 0,
        child: InkWell(
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Could not open $title"))
                );
              }
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: isDark ? 0.1 : 0.5),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: isDark ? Colors.grey[600] : Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
