import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'whatsapp_markdown_text.dart';

class WhatsAppPreviewBubble extends StatelessWidget {
  final Map<String, dynamic> template;
  final String bodyText;
  final String? headerText;
  final bool isDark;
  final String? timestamp;
  final String? status;
  final Alignment? alignment;

  const WhatsAppPreviewBubble({
    super.key,
    required this.template,
    required this.bodyText,
    this.headerText,
    required this.isDark,
    this.timestamp,
    this.status,
    this.alignment,
  });

  Map<String, dynamic>? _getComponent(String type) {
    final components = template['components'] as List?;
    if (components == null) return null;
    final matched = components.where(
      (c) =>
          c is Map &&
          (c['type'] ?? '').toString().toUpperCase() == type.toUpperCase(),
    );
    return matched.isNotEmpty ? Map<String, dynamic>.from(matched.first) : null;
  }

  List<Map<String, dynamic>> _getButtons() {
    final components = template['components'] as List?;
    if (components == null) return [];
    final List<Map<String, dynamic>> result = [];
    final buttonsComp = _getComponent('BUTTONS');
    if (buttonsComp != null) {
      final buttonsList =
          buttonsComp['buttons'] as List? ?? buttonsComp['button'] as List?;
      if (buttonsList != null) {
        result.addAll(buttonsList.map((b) => Map<String, dynamic>.from(b)));
      }
    }
    for (final comp in components) {
      if (comp is Map &&
          (comp['type'] ?? '').toString().toUpperCase() == 'BUTTON') {
        result.add(Map<String, dynamic>.from(comp));
      }
    }
    return result;
  }

  String? _getHeaderImageUrl(Map<String, dynamic> headerComp) {
    final example = headerComp['example'] as Map?;
    final handles = example?['header_handle'] ?? example?['headerHandle'];
    if (handles is List && handles.isNotEmpty) {
      return handles[0].toString();
    }
    if (handles is String && handles.isNotEmpty) return handles;
    final directUrl =
        headerComp['link'] ?? headerComp['url'] ?? headerComp['mediaUrl'];
    if (directUrl != null && directUrl.toString().isNotEmpty) {
      return directUrl.toString();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bubbleBgColor = isDark
        ? const Color(0xFF1C2D24)
        : const Color(0xFFD9FDD3);
    final textThemeColor = isDark ? Colors.white : const Color(0xFF111B21);
    final buttonTextColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF00A884);

    final headerComp = _getComponent('HEADER');
    final footerComp = _getComponent('FOOTER');
    final buttons = _getButtons();

    final String finalBodyText = bodyText.isEmpty
        ? 'Enter your message body here... Use {{1}} for variables.'
        : bodyText;

    final String timeStr =
        timestamp ?? DateFormat('dd MMM, yy • hh:mm a').format(DateTime.now());
    final isOutbound =
        alignment == Alignment.centerRight ||
        alignment == Alignment.topRight ||
        alignment == Alignment.bottomRight;

    return Align(
      alignment: alignment ?? Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        decoration: BoxDecoration(
          color: bubbleBgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isOutbound ? const Radius.circular(12) : Radius.zero,
            bottomRight: isOutbound ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER RENDER (outside padding to be flush to borders) ---
            if (headerComp != null) _buildHeader(headerComp, textThemeColor),

            Padding(
              padding: const EdgeInsets.only(
                left: 12.0,
                right: 12.0,
                top: 8.0,
                bottom: 6.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- BODY RENDER ---
                  WhatsAppMarkdownText(
                    finalBodyText,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.35,
                      color: textThemeColor,
                    ),
                  ),

                  // --- FOOTER RENDER ---
                  if (footerComp != null &&
                      (footerComp['text'] ?? '')
                          .toString()
                          .trim()
                          .isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      footerComp['text'].toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xFF8696A0),
                      ),
                    ),
                  ],

                  const SizedBox(height: 4),

                  // --- TIMESTAMP & META ROW ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        "${(template['category'] ?? 'MARKETING').toString().toUpperCase()}  $timeStr",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF889196),
                        ),
                      ),
                      if (status != null && status != 'failed') ...[
                        const SizedBox(width: 4),
                        Icon(
                          status == 'read'
                              ? Icons.done_all
                              : (status == 'delivered'
                                    ? Icons.done_all
                                    : Icons.done),
                          size: 13,
                          color: status == 'read'
                              ? const Color(0xFF53BDEB)
                              : (isDark
                                    ? Colors.white38
                                    : const Color(0xFF889196)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // --- BUTTONS RENDER ---
            if (buttons.isNotEmpty) ...[
              for (var i = 0; i < buttons.length; i++)
                Builder(
                  builder: (context) {
                    final rawType = (buttons[i]['type'] ?? '').toString();
                    final type = rawType.toUpperCase() == 'BUTTON'
                        ? (buttons[i]['sub_type'] ?? '')
                              .toString()
                              .toUpperCase()
                        : rawType.toUpperCase();
                    return Column(
                      children: [
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () async {
                              if (type == 'PHONE_NUMBER' || type == 'PHONE') {
                                final phone =
                                    buttons[i]['phone_number'] ??
                                    buttons[i]['phoneNumber'];
                                if (phone != null &&
                                    phone.toString().isNotEmpty) {
                                  final Uri telUri = Uri.parse(
                                    'tel:${phone.toString().trim()}',
                                  );
                                  if (await canLaunchUrl(telUri)) {
                                    await launchUrl(telUri);
                                  }
                                }
                              } else if (type == 'URL') {
                                var urlStr = (buttons[i]['url'] ?? '')
                                    .toString()
                                    .trim();
                                if (urlStr.isNotEmpty) {
                                  if (!urlStr.startsWith('http://') &&
                                      !urlStr.startsWith('https://')) {
                                    urlStr = 'https://$urlStr';
                                  }
                                  final Uri webUri = Uri.parse(urlStr);
                                  if (await canLaunchUrl(webUri)) {
                                    await launchUrl(
                                      webUri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                }
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (type == 'PHONE_NUMBER' ||
                                      type == 'PHONE') ...[
                                    Icon(
                                      Icons.phone,
                                      size: 15,
                                      color: buttonTextColor,
                                    ),
                                    const SizedBox(width: 6),
                                  ] else if (type == 'URL') ...[
                                    Icon(
                                      Icons.open_in_new,
                                      size: 15,
                                      color: buttonTextColor,
                                    ),
                                    const SizedBox(width: 6),
                                  ] else if (type == 'QUICK_REPLY') ...[
                                    Icon(
                                      Icons.reply,
                                      size: 15,
                                      color: buttonTextColor,
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Text(
                                    buttons[i]['text'] ?? 'Button',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: buttonTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> headerComp, Color textColor) {
    final format = (headerComp['format'] ?? 'TEXT').toString().toUpperCase();

    if (format == 'TEXT') {
      final text = headerText ?? headerComp['text'] ?? 'Header';
      return Padding(
        padding: const EdgeInsets.only(
          left: 12.0,
          right: 12.0,
          top: 10.0,
          bottom: 2.0,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      );
    }

    if (format == 'IMAGE') {
      final url = _getHeaderImageUrl(headerComp);
      return Container(
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.04),
        child: AspectRatio(
          aspectRatio: 1.91,
          child: url != null && url.startsWith('http')
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _buildHeaderPlaceholder(
                    Icons.image_outlined,
                    'IMAGE HEADER',
                  ),
                )
              : _buildHeaderPlaceholder(Icons.image_outlined, 'IMAGE HEADER'),
        ),
      );
    }

    if (format == 'VIDEO') {
      return Container(
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.04),
        child: AspectRatio(
          aspectRatio: 1.91,
          child: _buildHeaderPlaceholder(
            Icons.play_circle_outline,
            'VIDEO HEADER',
          ),
        ),
      );
    }

    if (format == 'DOCUMENT') {
      return Padding(
        padding: const EdgeInsets.only(
          left: 12.0,
          right: 12.0,
          top: 10.0,
          bottom: 2.0,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                size: 28,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Template Document.pdf',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'PDF • 1.2 MB',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (format == 'LOCATION') {
      final placeName = (headerComp['placeName'] ?? headerComp['name'])
          ?.toString() ??
          'Dropped Pin';
      final address = (headerComp['address'])
          ?.toString() ??
          '';
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 2),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? Colors.black26 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 130,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFB3E5FC), Color(0xFFA5D6A7)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.location_on, size: 36, color: Colors.red.shade400),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.map_outlined, size: 14, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          'GOOGLE MAPS',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.directions_outlined, size: 14, color: Colors.grey.shade600),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      placeName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111B21),
                      ),
                    ),
                    if (address.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        address,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildHeaderPlaceholder(IconData icon, String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 30, color: const Color(0xFF54656F)),
        const SizedBox(height: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF54656F),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
