import 'package:flutter/material.dart';

class AppRatingDialog extends StatelessWidget {
  final VoidCallback onRateNow;
  final VoidCallback onRemindLater;
  final VoidCallback onNoThanks;

  const AppRatingDialog({
    super.key,
    required this.onRateNow,
    required this.onRemindLater,
    required this.onNoThanks,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 8,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 5-Star Header Icon Badge
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFEF3C7),
                border: Border.all(color: const Color(0xFFF59E0B), width: 2),
              ),
              child: const Icon(
                Icons.star_rounded,
                size: 38,
                color: Color(0xFFD97706),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Enjoying Trevion CRM?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Your review on Google Play helps us continuously improve the experience for sales teams and real estate agents.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Primary Button: "Rate Now"
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                onPressed: onRateNow,
                icon: const Icon(Icons.star_rate_rounded, size: 20),
                label: const Text(
                  'Rate Now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Button: "Remind Me Later"
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton(
                onPressed: onRemindLater,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: isDark ? Colors.white24 : Colors.grey[300]!,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Remind Me Later',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Text Button: "No Thanks"
            TextButton(
              onPressed: onNoThanks,
              child: Text(
                'No Thanks',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
