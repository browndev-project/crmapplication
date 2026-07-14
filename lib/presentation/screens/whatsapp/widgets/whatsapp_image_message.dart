import 'package:flutter/material.dart';
import '../../../../core/utils/media_helper.dart';
import '../../../widgets/full_screen_image_viewer.dart';
import '../../../widgets/in_app_video_player.dart';
import 'whatsapp_status_indicator.dart';

class WhatsAppImageMessage extends StatelessWidget {
  final String imageUrl;
  final String? caption;
  final String? mediaType;
  final String timestamp;
  final bool isOutbound;
  final bool isDark;
  final String status;
  final String? senderLabel;
  final String? sourceBadge;

  const WhatsAppImageMessage({
    super.key,
    required this.imageUrl,
    this.caption,
    this.mediaType,
    required this.timestamp,
    required this.isOutbound,
    required this.isDark,
    this.status = 'sent',
    this.senderLabel,
    this.sourceBadge,
  });

  bool get _isVideo => mediaType == 'video';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isOutbound
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: EdgeInsets.only(
            top: 6,
            left: 6,
            right: 6,
            bottom: caption != null ? 0 : 6,
          ),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isOutbound && senderLabel != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                  child: _buildSenderHeader(senderLabel!, sourceBadge),
                ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    final resolvedUrl = MediaHelper.getMediaUrl(imageUrl);
                    if (mediaType == 'image') {
                      FullScreenImageViewer.show(context, resolvedUrl);
                    } else if (mediaType == 'video') {
                      InAppVideoPlayer.show(context, resolvedUrl);
                    } else {
                      MediaHelper.launchMediaUrl(context, imageUrl);
                    }
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 300,
                        maxHeight: 300,
                      ),
                      child: Stack(
                        children: [
                          Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: 300,
                            height: 300,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              width: 300,
                              height: 180,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 32,
                                ),
                              ),
                            ),
                            loadingBuilder:
                                (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 300,
                                height: 180,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_isVideo)
                            Container(
                              color: Colors.black.withValues(alpha: 0.3),
                              child: const Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (caption != null && caption!.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
                  child: Text(
                    caption!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF111B21),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isVideo)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.videocam,
                          size: 12,
                          color: isDark ? Colors.grey[400] : const Color(0xFF667781),
                        ),
                      ),
                    Text(
                      timestamp,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF667781),
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
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
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
