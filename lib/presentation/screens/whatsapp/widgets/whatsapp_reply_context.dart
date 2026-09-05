import 'package:flutter/material.dart';
import 'whatsapp_quoted_message_box.dart';

class WhatsAppReplyContext extends StatelessWidget {
  final Map<String, dynamic>? replyContext;
  final bool isInbound;
  final bool isDark;
  final VoidCallback? onTap;

  const WhatsAppReplyContext({
    super.key,
    Map<String, dynamic>? context,
    Map<String, dynamic>? replyContext,
    required this.isInbound,
    required this.isDark,
    this.onTap,
  }) : replyContext = replyContext ?? context;

  @override
  Widget build(BuildContext context) {
    final data = replyContext;
    if (data == null || data.isEmpty) {
      return const SizedBox.shrink();
    }

    return WhatsAppQuotedMessageBox(
      quotedData: data,
      isOutbound: !isInbound,
      isDark: isDark,
      onTap: onTap,
    );
  }
}
