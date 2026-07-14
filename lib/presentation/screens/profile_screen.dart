import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/login_provider.dart';
import '../providers/whatsapp_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];
    final cardColor = Theme.of(context).cardColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    final user = ref.watch(loginProvider).user;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () {
             Navigator.of(context).pop();
          },
        ),
        title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                // Logo placeholder
                Container(
                    width: 30, height: 30,
                    decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Colors.orange, Colors.green])
                    ),
                    child: const Icon(Icons.g_translate, color: Colors.white, size: 20)
                ),
                const SizedBox(width: 8),
                Text('Trevion', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
            ]
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('My Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
            Text('View your account information', style: TextStyle(fontSize: 14, color: subTextColor)),
            
            const SizedBox(height: 20),

            // Profile Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Column(
                children: [
                   CircleAvatar(
                     radius: 40,
                     backgroundColor: Colors.grey[200],
                     child: const Icon(Icons.person, size: 40, color: Colors.grey),
                   ),
                   const SizedBox(height: 16),
                   Text(user?.name ?? 'Guest User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                   Text(user?.role.toUpperCase() ?? 'GUEST', style: TextStyle(fontSize: 14, color: subTextColor)),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            _buildInfoCard(context, Icons.badge, 'Unique ID', user?.uniqueId ?? '-'),
            _buildInfoCard(context, Icons.email, 'Email', user?.email ?? '-'),
            _buildInfoCard(context, Icons.phone, 'Phone Number', user?.phoneNo ?? '-'),
            
            const SizedBox(height: 16),
            
            _buildInfoCard(context, Icons.calendar_today, 'Company ID', user?.company ?? '-'),
            _buildInfoCard(context, Icons.security, 'System Role', user?.systemRole ?? '-'),
            
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Account Status', style: TextStyle(fontSize: 12, color: subTextColor)),
                   const SizedBox(height: 8),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                     decoration: BoxDecoration(
                       color: (user?.active == true ? Colors.green : Colors.red).withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(4),
                     ),
                     child: Text(
                        user?.active == true ? 'Active' : 'Inactive', 
                        style: TextStyle(
                            color: user?.active == true ? Colors.green : Colors.red, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 12
                        )
                     ),
                   )
                ],
              ),
            ),
            
            // WhatsApp Connection Status
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('WhatsApp Connection', style: TextStyle(fontSize: 12, color: subTextColor)),
                   const SizedBox(height: 8),
                   ref.watch(whatsappIntegrationProvider).when(
                     data: (isConnected) => Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                       decoration: BoxDecoration(
                         color: (isConnected ? Colors.green : Colors.orange).withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: Text(
                          isConnected ? 'Connected' : 'Not Connected', 
                          style: TextStyle(
                              color: isConnected ? Colors.green : Colors.orange, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                          )
                       ),
                     ),
                     loading: () => const SizedBox(
                       width: 16,
                       height: 16,
                       child: CircularProgressIndicator(strokeWidth: 2),
                     ),
                     error: (err, _) => Container(
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                       decoration: BoxDecoration(
                         color: Colors.red.withValues(alpha: 0.1),
                         borderRadius: BorderRadius.circular(4),
                       ),
                       child: const Text(
                          'Error checking connection', 
                          style: TextStyle(
                              color: Colors.red, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 12
                          )
                       ),
                     ),
                   ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            Row(
              children: [
                Text('Active Sessions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(width: 8),
                Text('(Mock)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            Text('Devices currently logged into your account', style: TextStyle(fontSize: 12, color: subTextColor)),
            
            const SizedBox(height: 16),
            
            _buildSessionCard(
                context, 
                Icons.desktop_windows, 
                'Current Session', 
                'This Device', 
                '::1', 
                'Logged In now'
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, IconData icon, String label, String value) {
     final isDark = Theme.of(context).brightness == Brightness.dark;
     return Container(
         width: double.infinity,
         margin: const EdgeInsets.only(bottom: 16),
         padding: const EdgeInsets.all(16),
         decoration: BoxDecoration(
           color: Theme.of(context).cardColor,
           borderRadius: BorderRadius.circular(12),
         ),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Row(
               children: [
                 Icon(icon, size: 16, color: Colors.grey),
                 const SizedBox(width: 8),
                 Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
               ],
             ),
             const SizedBox(height: 8),
             Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
           ],
         ),
     );
  }

  Widget _buildSessionCard(BuildContext context, IconData icon, String deviceName, String userAgent, String ip, String loginTime) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.blue),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deviceName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(userAgent, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(height: 8),
                     Row(
                       children: [
                         const Icon(Icons.public, size: 12, color: Colors.grey),
                         const SizedBox(width: 4),
                         Text(ip, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                       ],
                     ),
                     const SizedBox(height: 12),
                     Text('Logged In on:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                     Text(loginTime, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              )
            ],
          ),
      );
  }
}
