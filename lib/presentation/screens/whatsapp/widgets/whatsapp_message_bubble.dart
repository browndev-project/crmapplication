import 'package:flutter/material.dart';

class WhatsAppMessageBubble extends StatelessWidget {
  final Widget child;
  final bool isOutbound;
  final bool isDark;
  final String status;
  final double maxWidth;

  const WhatsAppMessageBubble({
    super.key,
    required this.child,
    required this.isOutbound,
    required this.isDark,
    this.status = 'sent',
    this.maxWidth = 320,
  });

  Color get _backgroundColor {
    if (status == 'failed') {
      return isDark ? const Color(0xFF2D1F21) : const Color(0xFFFFF5F5);
    }
    return isOutbound
        ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
        : (isDark ? const Color(0xFF1E2A30) : Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.only(left: 10, top: 8, right: 10, bottom: 4),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: isOutbound ? const Radius.circular(8) : Radius.zero,
          bottomRight: isOutbound ? Radius.zero : const Radius.circular(8),
        ),
        border: status == 'failed'
            ? Border.all(
                color: isDark
                    ? Colors.red.shade900.withValues(alpha: 0.4)
                    : const Color(0xFFFFD2D2),
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}
