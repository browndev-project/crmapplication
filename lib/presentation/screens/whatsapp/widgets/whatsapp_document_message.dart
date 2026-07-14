import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'whatsapp_status_indicator.dart';

class WhatsAppDocumentMessage extends StatelessWidget {
  final String? documentUrl;
  final String fileName;
  final String? fileSize;
  final String? fileType;
  final String timestamp;
  final bool isOutbound;
  final bool isDark;
  final String status;
  final String? senderLabel;
  final String? sourceBadge;

  const WhatsAppDocumentMessage({
    super.key,
    this.documentUrl,
    this.fileName = 'Document',
    this.fileSize,
    this.fileType,
    required this.timestamp,
    required this.isOutbound,
    required this.isDark,
    this.status = 'sent',
    this.senderLabel,
    this.sourceBadge,
  });

  String get _displayFileType {
    if (fileType != null && fileType!.isNotEmpty) return fileType!;
    final ext = fileName.split('.').last;
    if (ext.length <= 5) return ext.toUpperCase();
    return 'FILE';
  }

  IconData get _fileIcon {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'mp3':
      case 'wav':
      case 'ogg':
        return Icons.audio_file;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.video_file;
      case 'zip':
      case 'rar':
        return Icons.folder_zip;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color get _fileIconColor {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return Colors.redAccent;
      case 'doc':
      case 'docx':
        return Colors.blue;
      case 'xls':
      case 'xlsx':
        return Colors.green;
      case 'ppt':
      case 'pptx':
        return Colors.orange;
      default:
        return isDark ? Colors.white70 : Colors.grey[600]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isOutbound ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (documentUrl != null && documentUrl!.isNotEmpty) {
                  final uri = Uri.tryParse(documentUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isOutbound && senderLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildSenderHeader(senderLabel!, sourceBadge),
                      ),
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: (isOutbound
                                    ? (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06))
                                    : (isDark ? Colors.white10 : Colors.grey[100]))
                                as Color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            _fileIcon,
                            size: 24,
                            color: _fileIconColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF111B21),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_displayFileType${fileSize != null ? ' • $fileSize' : ''}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey[400] : const Color(0xFF667781),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Click to view document',
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
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
            ),
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
