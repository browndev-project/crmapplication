import 'package:flutter/material.dart';
import 'whatsapp_status_indicator.dart';

class WhatsAppFailedMessage extends StatelessWidget {
  final Map<String, dynamic> message;
  final bool isDark;
  final String? senderLabel;
  final String? sourceBadge;
  final String? timestamp;
  final String? status;
  final Widget? child;

  const WhatsAppFailedMessage({
    super.key,
    required this.message,
    required this.isDark,
    this.senderLabel,
    this.sourceBadge,
    this.timestamp,
    this.status,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final direction = message['direction'] ?? 'INBOUND';
    final isOutbound = direction == 'OUTBOUND';
    final bubbleBg = isDark ? Colors.red.shade900.withValues(alpha: 0.35) : const Color(0xFFFFD2D2);
    final inboundBg = isDark ? const Color(0xFF3D272A) : const Color(0xFFFFF0F0);

    final errorDetails = _buildErrorDetails();

    return Column(
      crossAxisAlignment: isOutbound
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: isOutbound ? bubbleBg : inboundBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: isOutbound ? const Radius.circular(8) : Radius.zero,
              bottomRight: isOutbound ? Radius.zero : const Radius.circular(8),
            ),
            border: Border.all(
              color: isDark
                  ? Colors.red.shade900.withValues(alpha: 0.4)
                  : const Color(0xFFFFD2D2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOutbound && senderLabel != null)
                _buildSenderHeader(senderLabel!, sourceBadge),
              if (child != null) child!,
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: _buildErrorCard(errorDetails, isDark),
              ),
              if (timestamp != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          timestamp!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.grey[400]
                                : const Color(0xFF667781),
                          ),
                        ),
                        if (isOutbound && status != null) ...[
                          const SizedBox(width: 4),
                          WhatsAppStatusIndicator(
                            status: status!,
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildErrorCard(List<Widget> details, bool isDark) {
    if (details.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF3D272A) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isDark
              ? Colors.red.shade800.withValues(alpha: 0.5)
              : const Color(0xFFFFCDD2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.red, size: 16),
              const SizedBox(width: 6),
              const Text(
                'SEND FAILED',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'FAILED',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade300,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...details,
        ],
      ),
    );
  }

  List<Widget> _buildErrorDetails() {
    final errorText = _extractRawError(message) ?? 'Unknown delivery failure';

    return [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          errorText,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFC62828),
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ];
  }

  String? _extractRawError(Map<String, dynamic> msg) {
    final raw = msg['error'];
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw is Map) {
      if (raw['error'] is String) return raw['error'] as String;
      if (raw['message'] is String) return raw['message'] as String;
      if (raw['error_description'] is String) return raw['error_description'] as String;
    }
    if (msg['failureReason'] is String) return msg['failureReason'] as String;
    if (msg['metaError'] is String) return msg['metaError'] as String;
    if (msg['errorMessage'] is String) return msg['errorMessage'] as String;
    return null;
  }

  Widget _buildSenderHeader(String label, String? badge) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.green.withValues(alpha: 0.2)
                    : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isDark
                      ? Colors.green.withValues(alpha: 0.3)
                      : const Color(0xFF00A884).withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                badge.toUpperCase(),
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.green.shade300
                      : const Color(0xFF00A884),
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
