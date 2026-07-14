import 'package:flutter/material.dart';

class PermissionDeniedWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onBack;

  const PermissionDeniedWidget({
    super.key,
    this.message = 'You do not have the required permissions to view this module. Please contact your administrator if you believe this is a mistake.',
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? Colors.redAccent.withValues(alpha: 0.1) : Colors.redAccent.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_person_rounded,
                size: 80,
                color: isDark ? Colors.redAccent.shade200 : Colors.redAccent,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Access Restricted',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
