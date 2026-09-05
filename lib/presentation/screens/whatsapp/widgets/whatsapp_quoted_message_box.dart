import 'package:flutter/material.dart';

class WhatsAppQuotedMessageBox extends StatelessWidget {
  final Map<String, dynamic> quotedData;
  final bool isOutbound;
  final bool isDark;
  final VoidCallback? onTap;

  const WhatsAppQuotedMessageBox({
    super.key,
    required this.quotedData,
    required this.isOutbound,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final rawSender = quotedData['sender'] ??
        quotedData['senderName'] ??
        quotedData['name'] ??
        quotedData['from'] ??
        quotedData['title'] ??
        'You';
    final senderName = rawSender.toString();

    final campaignName = (quotedData['campaignName'] ??
            quotedData['campaign'] ??
            quotedData['titleSuffix'])
        ?.toString();

    final type = (quotedData['type'] ?? quotedData['mediaType'] ?? quotedData['format'] ?? '')
        .toString()
        .toLowerCase();

    final text = (quotedData['text'] ??
            quotedData['body'] ??
            quotedData['content'] ??
            quotedData['message'] ??
            quotedData['snippet'] ??
            '')
        .toString()
        .trim();

    final mediaUrl = (quotedData['mediaUrl'] ??
            quotedData['imageUrl'] ??
            quotedData['url'] ??
            quotedData['thumbnailUrl'] ??
            quotedData['headerUrl'])
        ?.toString()
        .trim();

    final bool isImageOrMedia = type == 'image' ||
        type == 'photo' ||
        type == 'media' ||
        (mediaUrl != null && mediaUrl.startsWith('http'));

    final bool isCampaign = (campaignName != null && campaignName.trim().isNotEmpty) ||
        type == 'campaign' ||
        quotedData['isCampaign'] == true ||
        quotedData['campaignId'] != null ||
        (quotedData['title'] != null && quotedData['title'].toString().toLowerCase().contains('campaign')) ||
        text.toLowerCase().contains('campaign:');

    // If there is no text, no image/media, no campaign, and no valid media URL, do not render a empty quote box
    if (text.isEmpty && !isImageOrMedia && !isCampaign && (mediaUrl == null || mediaUrl.isEmpty) && type.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool showViewFull = text.length > 70 || text.contains('\n');

    final String titleText;
    if (campaignName != null && campaignName.isNotEmpty) {
      titleText = '$senderName • 📢 Campaign: $campaignName';
    } else {
      titleText = senderName;
    }

    final accentColor = isOutbound
        ? (isDark ? const Color(0xFF6B4EE6) : const Color(0xFF00A884))
        : (isDark ? const Color(0xFF00A884) : const Color(0xFF6B4EE6));

    final bgColor = isOutbound
        ? (isDark ? const Color(0xFF024438) : const Color(0xFFC8ECC0))
        : (isDark ? const Color(0xFF131C21) : const Color(0xFFF0F2F5));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!isCampaign && onTap != null) {
          onTap!();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left Accent Bar (3.5px)
            Container(
              width: 3.5,
              color: accentColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Quoted Sender / Campaign Title + View Full Button
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  titleText,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (showViewFull)
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    _showFullMessageModal(context, senderName, text, isDark);
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 6, right: 2),
                                    child: Text(
                                      'View full',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white70 : Colors.black54,
                                        decoration: TextDecoration.underline,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          // Content / Image indicator
                          if (isImageOrMedia && text.isEmpty)
                            Row(
                              children: [
                                Icon(
                                  Icons.camera_alt_rounded,
                                  size: 13,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Photo',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          else
                            Row(
                              children: [
                                if (isImageOrMedia) ...[
                                  Icon(
                                    Icons.camera_alt_rounded,
                                    size: 13,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                  const SizedBox(width: 4),
                                ],
                                Expanded(
                                  child: Text(
                                    text.isNotEmpty
                                        ? text
                                        : (isImageOrMedia ? 'Photo' : 'Quoted Message'),
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontStyle: FontStyle.italic,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    // Small Image Thumbnail on Top-Right
                    if (mediaUrl != null && mediaUrl.startsWith('http')) ...[
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(
                          mediaUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  void _showFullMessageModal(
      BuildContext context, String sender, String fullText, bool isDark) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF1F2C34) : Colors.white,
          elevation: 8,
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        sender,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00A884),
                        ),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 350),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      fullText,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
