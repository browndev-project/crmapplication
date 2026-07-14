import 'package:flutter/material.dart';

class AccessDeniedWidget extends StatelessWidget {
  final String sectionName;
  final bool showAppBar;
  final VoidCallback? onBackTap;

  const AccessDeniedWidget({
    super.key,
    required this.sectionName,
    this.showAppBar = false,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon with soft background glow
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.red.withValues(alpha: 0.15), width: 1.5),
              ),
              child: const Icon(
                Icons.lock_person_outlined,
                color: Colors.red,
                size: 64,
              ),
            ),
            const SizedBox(height: 28),
            
            // Headline
            Text(
              "Access Denied",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            
            // Section message
            Text(
              "You do not have permission to access $sectionName.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.red[300] : Colors.red[700],
              ),
            ),
            const SizedBox(height: 12),
            
            // Descriptive text
            Text(
              "This section requires specific access permissions. Please contact your system administrator or account manager to update your role permissions.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );

    if (showAppBar) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
            onPressed: onBackTap ?? () => Navigator.maybePop(context),
          ),
          title: Text(
            sectionName,
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          centerTitle: true,
        ),
        body: content,
      );
    }

    return content;
  }
}
