import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/media_helper.dart';
import 'whatsapp_markdown_text.dart';
import 'whatsapp_status_indicator.dart';
import 'whatsapp_reply_context.dart';

class WhatsAppTemplateMessage extends StatelessWidget {
  final Map<String, dynamic> template;
  final String bodyText;
  final String? headerText;
  final bool isDark;
  final String timestamp;
  final String? status;
  final bool isOutbound;
  final String? templateMediaUrl;
  final String? templateMediaType;
  final Map<String, dynamic>? locationData;
  final String? senderLabel;
  final String? sourceBadge;
  final Map<String, dynamic>? replyContext;
  final Map<String, dynamic>? errorMap;
  final String? rawError;

  const WhatsAppTemplateMessage({
    super.key,
    required this.template,
    required this.bodyText,
    this.headerText,
    required this.isDark,
    required this.timestamp,
    this.status,
    required this.isOutbound,
    this.templateMediaUrl,
    this.templateMediaType,
    this.locationData,
    this.senderLabel,
    this.sourceBadge,
    this.replyContext,
    this.errorMap,
    this.rawError,
  });

  bool get _isFailed => status == 'failed' || errorMap != null;

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
    if (example != null) {
      final handles = example['header_handle'] ?? example['headerHandle'];
      if (handles is List && handles.isNotEmpty) {
        return handles[0].toString();
      }
      if (handles is String && handles.isNotEmpty) return handles;
    }
    final directUrl =
        headerComp['link'] ?? headerComp['url'] ?? headerComp['mediaUrl'];
    if (directUrl != null && directUrl.toString().isNotEmpty) {
      return directUrl.toString();
    }
    return null;
  }

  String? _getHeaderMediaUrl(Map<String, dynamic> headerComp) {
    return _getHeaderImageUrl(headerComp) ?? templateMediaUrl;
  }

  Map<String, dynamic>? _extractLocationData(Map<String, dynamic> headerComp) {
    if (locationData != null) return locationData;
    if (headerComp['location'] is Map) {
      return Map<String, dynamic>.from(headerComp['location'] as Map);
    }
    final result = <String, dynamic>{};
    if (headerComp['latitude'] != null || headerComp['longitude'] != null) {
      result['latitude'] = headerComp['latitude'];
      result['longitude'] = headerComp['longitude'];
    }
    if (headerComp['name'] != null) result['name'] = headerComp['name'];
    if (headerComp['address'] != null) result['address'] = headerComp['address'];
    if (result.isNotEmpty) return result;
    if (headerComp['parameters'] is List) {
      final params = headerComp['parameters'] as List;
      if (params.isNotEmpty && params[0] is Map) {
        final param = params[0] as Map;
        if (param['location'] is Map) {
          return Map<String, dynamic>.from(param['location'] as Map);
        }
      }
    }
    return null;
  }

  Future<void> _handleHeaderTap(
    BuildContext context,
    Map<String, dynamic> headerComp,
  ) async {
    final format = (headerComp['format'] ?? 'TEXT').toString().toUpperCase();
    if (format == 'LOCATION') {
      final loc = _extractLocationData(headerComp);
      if (loc == null) return;
      final lat = loc['latitude'] ?? loc['lat'];
      final lon =
          loc['longitude'] ?? loc['long'] ?? loc['lng'] ?? loc['longitude'];
      String query;
      if (lat != null && lon != null) {
        query = '$lat,$lon';
      } else {
        query = (loc['address'] ?? loc['name'] ?? '').toString();
      }
      if (query.isEmpty) return;
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final url = _getHeaderMediaUrl(headerComp);
    if (url != null && url.isNotEmpty) {
      await MediaHelper.launchMediaUrl(context, url);
    }
  }

  Widget _wrapHeaderWithTap(
    BuildContext context,
    Widget child,
    Map<String, dynamic> headerComp,
  ) {
    final format = (headerComp['format'] ?? 'TEXT').toString().toUpperCase();
    final hasTapTarget = format == 'LOCATION'
        ? _extractLocationData(headerComp) != null
        : _getHeaderMediaUrl(headerComp) != null;
    if (!hasTapTarget) return child;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () => _handleHeaderTap(context, headerComp),
        child: child,
      ),
    );
  }

  String get _categoryLabel {
    final cat = template['category']?.toString() ?? 'MARKETING';
    return cat.toUpperCase();
  }

  Color get _categoryColor {
    switch (_categoryLabel) {
      case 'MARKETING':
        return const Color(0xFF00A884);
      case 'UTILITY':
        return const Color(0xFF5B5BD6);
      default:
        return const Color(0xFF8696A0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final headerComp = _getComponent('HEADER');
    final footerComp = _getComponent('FOOTER');
    final buttons = _getButtons();
    final textThemeColor = isDark ? Colors.white : const Color(0xFF111B21);
    final buttonTextColor = isDark
        ? const Color(0xFF34D399)
        : const Color(0xFF00A884);

    return Column(
      crossAxisAlignment: isOutbound
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          decoration: BoxDecoration(
            color: _isFailed
                ? const Color(0xFFFFF5F5)
                : isOutbound
                    ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
                    : (isDark ? const Color(0xFF1E2A30) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(8),
              topRight: const Radius.circular(8),
              bottomLeft: isOutbound ? const Radius.circular(8) : Radius.zero,
              bottomRight: isOutbound ? Radius.zero : const Radius.circular(8),
            ),
            border: _isFailed
                ? Border.all(color: const Color(0xFFFECACA))
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 1,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildCardContent(
            context, headerComp, footerComp, buttons,
            textThemeColor, buttonTextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    Map<String, dynamic>? headerComp,
    Map<String, dynamic>? footerComp,
    List<Map<String, dynamic>> buttons,
    Color textThemeColor,
    Color buttonTextColor,
  ) {
    final cardChildren = <Widget>[
      if (isOutbound && senderLabel != null)
        _buildSenderHeader(senderLabel!, sourceBadge, isFailed: _isFailed),
      if (replyContext != null)
        WhatsAppReplyContext(
          context: replyContext,
          isInbound: !isOutbound,
          isDark: isDark,
        ),
      if (headerComp != null)
        _buildHeader(context, headerComp, textThemeColor),
      Padding(
        padding: const EdgeInsets.only(left: 12, right: 12, top: 8, bottom: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bodyText.isNotEmpty)
              WhatsAppMarkdownText(
                bodyText,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: textThemeColor,
                ),
              ),
            if (footerComp != null &&
                footerComp['text'].toString().trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                footerComp['text'].toString(),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : const Color(0xFF8696A0),
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: _categoryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    _categoryLabel,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: _categoryColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timestamp,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : const Color(0xFF889196),
                  ),
                ),
                if (status != null && status != 'failed') ...[
                  const SizedBox(width: 4),
                  WhatsAppStatusIndicator(
                    status: status!,
                    isDark: isDark,
                    size: 13,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      if (buttons.isNotEmpty)
        _buildButtons(buttons, buttonTextColor, isFailed: _isFailed),
      if (_isFailed) _buildFailureSection(),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: cardChildren,
    );
  }

  Widget _buildFailureSection() {
    final errorText = rawError ??
        errorMap?['message']?.toString() ??
        errorMap?.toString() ??
        'Unknown delivery failure';

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Container(
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
            Text(
              errorText,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFC62828),
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Map<String, dynamic> headerComp,
    Color textColor,
  ) {
    final format = (headerComp['format'] ?? 'TEXT').toString().toUpperCase();

    if (format == 'TEXT') {
      final text = headerText ?? headerComp['text'] ?? '';
      if (text.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding:
            const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 2),
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
      final url = _getHeaderImageUrl(headerComp) ?? templateMediaUrl;
      final mediaUrl = url != null ? MediaHelper.getMediaUrl(url) : null;
      final content = Container(
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.04),
        child: AspectRatio(
          aspectRatio: 1.91,
          child: mediaUrl != null && mediaUrl.startsWith('http')
              ? Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) =>
                      _buildHeaderPlaceholder(Icons.image_outlined, 'IMAGE'),
                )
              : _buildHeaderPlaceholder(Icons.image_outlined, 'IMAGE HEADER'),
        ),
      );
      return _wrapHeaderWithTap(context, content, headerComp);
    }

    if (format == 'VIDEO') {
      final url = _getHeaderMediaUrl(headerComp);
      final mediaUrl = url != null ? MediaHelper.getMediaUrl(url) : null;
      final isYouTube = mediaUrl != null &&
          (mediaUrl.toLowerCase().contains('youtube.com') ||
              mediaUrl.toLowerCase().contains('youtu.be'));
      final youtubeThumb = isYouTube
          ? MediaHelper.youTubeThumbnail(MediaHelper.extractYouTubeId(mediaUrl))
          : null;

      final content = Container(
        width: double.infinity,
        color: Colors.black.withValues(alpha: 0.04),
        child: AspectRatio(
          aspectRatio: 1.91,
          child: Stack(
            fit: StackFit.expand,
            alignment: Alignment.center,
            children: [
              if (youtubeThumb != null)
                Image.network(
                  youtubeThumb,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                )
              else if (mediaUrl != null && mediaUrl.startsWith('http'))
                Image.network(
                  mediaUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              Container(color: Colors.black.withValues(alpha: 0.24)),
              const Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 48,
              ),
            ],
          ),
        ),
      );
      return _wrapHeaderWithTap(context, content, headerComp);
    }

    if (format == 'DOCUMENT') {
      final content = Padding(
        padding:
            const EdgeInsets.only(left: 12, right: 12, top: 10, bottom: 2),
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
                      headerComp['text']?.toString() ??
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
                      'PDF • Click to view',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
      return _wrapHeaderWithTap(context, content, headerComp);
    }

    if (format == 'LOCATION') {
      final loc = _extractLocationData(headerComp);
      final placeName = (loc?['name'] ??
              headerComp['placeName'] ??
              headerComp['name'])
          ?.toString() ??
          'Dropped Pin';
      final address = (loc?['address'] ?? headerComp['address'])
          ?.toString() ??
          '';
      final content = Padding(
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
                        color: textColor,
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
      return _wrapHeaderWithTap(context, content, headerComp);
    }

    return const SizedBox.shrink();
  }

  Widget _buildButtons(
    List<Map<String, dynamic>> buttons,
    Color buttonTextColor, {
    bool isFailed = false,
  }) {
    final failedDividerColor = isDark
        ? const Color(0xFFFCA5A5).withValues(alpha: 0.3)
        : const Color(0xFFFCA5A5);
    final failedTextColor = isDark
        ? const Color(0xFFFCA5A5)
        : const Color(0xFFDC2626);

    return Column(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: isFailed ? failedDividerColor : (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06)),
          ),
          Material(
            color: isFailed
                ? const Color(0xFFFEF2F2)
                : Colors.transparent,
            child: InkWell(
              onTap: isFailed ? null : () => _handleButtonTap(buttons[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_buttonIcon(buttons[i], null) != null) ...[
                      _buttonIcon(buttons[i], isFailed ? failedTextColor : buttonTextColor)!,
                      const SizedBox(width: 6),
                    ],
                    Text(
                      buttons[i]['text'] ?? 'Button',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: isFailed ? failedTextColor : buttonTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buttonIcon(Map<String, dynamic> button, Color? color) {
    final rawType = (button['type'] ?? '').toString();
    final type = rawType.toUpperCase() == 'BUTTON'
        ? (button['sub_type'] ?? '').toString().toUpperCase()
        : rawType.toUpperCase();

    switch (type) {
      case 'PHONE_NUMBER':
      case 'PHONE':
      case 'CALL':
        return Icon(Icons.phone, size: 15, color: color ?? buttonTextColor);
      case 'URL':
      case 'WEBSITE':
        return Icon(
          Icons.open_in_new,
          size: 15,
          color: color ?? buttonTextColor,
        );
      case 'QUICK_REPLY':
        return Icon(Icons.reply, size: 15, color: color ?? buttonTextColor);
      default:
        return null;
    }
  }

  Color get buttonTextColor =>
      isDark ? const Color(0xFF34D399) : const Color(0xFF00A884);

  void _handleButtonTap(Map<String, dynamic> button) async {
    final rawType = (button['type'] ?? '').toString();
    final type = rawType.toUpperCase() == 'BUTTON'
        ? (button['sub_type'] ?? '').toString().toUpperCase()
        : rawType.toUpperCase();

    if (type == 'PHONE_NUMBER' || type == 'PHONE' || type == 'CALL') {
      final phone = button['phone_number'] ?? button['phoneNumber'];
      if (phone != null && phone.toString().isNotEmpty) {
        final uri = Uri.parse('tel:${phone.toString().trim()}');
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      }
    } else if (type == 'URL' || type == 'WEBSITE') {
      var urlStr = (button['url'] ?? '').toString().trim();
      if (urlStr.isNotEmpty) {
        if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
          urlStr = 'https://$urlStr';
        }
        final uri = Uri.parse(urlStr);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    }
  }

  Widget _buildSenderHeader(String label, String? badge, {bool isFailed = false}) {
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
          if (isFailed) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.red.withValues(alpha: 0.2)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: isDark
                      ? Colors.red.withValues(alpha: 0.3)
                      : const Color(0xFFFECACA),
                ),
              ),
              child: Text(
                'FAILED',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.red.shade300
                      : const Color(0xFFDC2626),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
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
