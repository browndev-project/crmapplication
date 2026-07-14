import 'package:flutter/material.dart';

class DashboardStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final List<Color>? gradientColors;

  const DashboardStatsCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle = '',
    required this.icon,
    required this.backgroundColor,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: gradientColors == null ? theme.cardColor : backgroundColor,
        gradient: gradientColors != null 
            ? LinearGradient(
                colors: gradientColors!, 
                begin: Alignment.topLeft, 
                end: Alignment.bottomRight,
              ) 
            : null,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: gradientColors != null ? Colors.transparent : (isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1)),
        ),
        boxShadow: [
          BoxShadow(
            color: gradientColors != null 
                ? gradientColors!.last.withValues(alpha: 0.3) 
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: gradientColors != null 
                        ? Colors.white.withValues(alpha: 0.9) 
                        : (isDark ? Colors.grey[300] : Colors.black87),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      color: gradientColors != null ? Colors.white : theme.textTheme.bodyLarge?.color,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: gradientColors != null 
                  ? Colors.white.withValues(alpha: 0.2) 
                  : (isDark ? Colors.grey[800] : Colors.grey[100]), 
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon, 
              color: gradientColors != null ? Colors.white : (isDark ? Colors.white : Colors.black87), 
              size: 20
            ),
          ),
        ],
      ),
    );
  }
}

