import 'package:flutter/material.dart';

class WhatsAppStatusIndicator extends StatelessWidget {
  final String status;
  final bool isDark;
  final double size;

  const WhatsAppStatusIndicator({
    super.key,
    required this.status,
    required this.isDark,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'pending') {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: isDark ? Colors.grey[400] : const Color(0xFF667781),
        ),
      );
    }

    IconData icon;
    Color color;

    switch (status) {
      case 'sent':
        icon = Icons.done;
        color = isDark ? Colors.grey[400]! : const Color(0xFF667781);
      case 'delivered':
        icon = Icons.done_all;
        color = isDark ? Colors.grey[400]! : const Color(0xFF667781);
      case 'read':
        icon = Icons.done_all;
        color = const Color(0xFF53BDEB);
      case 'failed':
        icon = Icons.error_outline;
        color = Colors.red;
      default:
        icon = Icons.done;
        color = isDark ? Colors.grey[400]! : const Color(0xFF667781);
    }

    return Icon(icon, size: size, color: color);
  }
}
