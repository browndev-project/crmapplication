import 'package:flutter/material.dart';

class WhatsAppReplyContext extends StatelessWidget {
  final Map<String, dynamic>? replyContext;
  final bool isInbound;
  final bool isDark;

  const WhatsAppReplyContext({
    super.key,
    Map<String, dynamic>? context,
    Map<String, dynamic>? replyContext,
    required this.isInbound,
    required this.isDark,
  }) : replyContext = replyContext ?? context;

  @override
  Widget build(BuildContext context) {
    final data = replyContext;
    if (data == null || data['messageId'] == null) {
      return const SizedBox.shrink();
    }

    final messageId = data['messageId'].toString();
    final shortId = messageId.length > 8
        ? messageId.substring(messageId.length - 8)
        : messageId;
    final from = data['from']?.toString() ?? '';
    final isFromMe = from == 'me' || from == 'outbound';

    final bgColor = isDark
        ? (isInbound
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.white.withValues(alpha: 0.1))
        : (isInbound
              ? Colors.grey.shade100
              : Colors.green.withValues(alpha: 0.1));
    final borderColor = isInbound
        ? Colors.grey.shade300
        : const Color(0xFF00A884);
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final labelColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Replying to ${isFromMe ? 'yourself' : 'message'}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: labelColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Source message referenced (ID: $shortId)',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: textColor,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
