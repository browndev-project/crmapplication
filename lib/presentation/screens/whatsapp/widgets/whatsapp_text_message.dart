import 'package:flutter/material.dart';
import 'whatsapp_markdown_text.dart';
import 'whatsapp_status_indicator.dart';

class WhatsAppTextMessage extends StatelessWidget {
  final String text;
  final String timestamp;
  final bool isOutbound;
  final bool isDark;
  final String status;
  final String? senderLabel;
  final String? sourceBadge;

  const WhatsAppTextMessage({
    super.key,
    required this.text,
    required this.timestamp,
    required this.isOutbound,
    required this.isDark,
    this.status = 'sent',
    this.senderLabel,
    this.sourceBadge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isOutbound ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.only(left: 10, top: 8, right: 10, bottom: 4),
          decoration: BoxDecoration(
            color: isOutbound
                ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
                : (isDark ? const Color(0xFF1E2A30) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: isOutbound ? const Radius.circular(8) : Radius.zero,
              bottomRight: isOutbound ? Radius.zero : const Radius.circular(8),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOutbound && senderLabel != null)
                _buildSenderHeader(senderLabel!, sourceBadge),
              Padding(
                padding: EdgeInsets.only(top: senderLabel != null ? 6 : 0),
                child: WhatsAppMarkdownText(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF111B21),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timestamp,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.grey[400] : const Color(0xFF667781),
                      ),
                    ),
                    if (isOutbound) ...[
                      const SizedBox(width: 4),
                      WhatsAppStatusIndicator(status: status, isDark: isDark),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSenderHeader(String label, String? badge) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark ? Colors.green.withValues(alpha: 0.2) : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isDark ? Colors.green.withValues(alpha: 0.3) : const Color(0xFF00A884).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                badge.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.green.shade300 : const Color(0xFF00A884),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
