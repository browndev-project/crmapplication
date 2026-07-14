import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/auth_service.dart';
import '../../../providers/whatsapp_provider.dart';
import 'whatsapp_text_message.dart';
import 'whatsapp_image_message.dart';
import 'whatsapp_document_message.dart';
import 'whatsapp_template_message.dart';
import 'whatsapp_failed_message.dart';
import 'whatsapp_status_indicator.dart';

class WhatsAppMessageDispatcher extends ConsumerWidget {
  final Map<String, dynamic> message;
  final bool isDark;

  const WhatsAppMessageDispatcher({
    super.key,
    required this.message,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final direction = message['direction'] ?? 'INBOUND';
    final isOutbound = direction == 'OUTBOUND';
    final status = message['status'] ?? 'sent';
    final type = message['type'] ?? 'text';

    final timestamp = message['timestamp'] != null
        ? DateTime.tryParse(message['timestamp'])?.toLocal() ?? DateTime.now()
        : DateTime.now();
    final timeString = DateFormat('hh:mm a').format(timestamp);
    final fullTimeString = DateFormat('dd MMM, yy • hh:mm a').format(timestamp);

    final bool isAutomated =
        message['source'] == 'automation' ||
        message['isAutomated'] == true ||
        message['campaignId'] != null ||
        message['automationId'] != null ||
        message['tag'] != null;
    final String automationTag =
        message['tag'] ??
        message['automationType'] ??
        message['campaignName'] ??
        'AUTOMATED';

    String? senderLabel;
    if (isOutbound && message['sentBy'] != null) {
      final sentBy = message['sentBy'] as Map?;
      final name = sentBy?['name'] ?? 'You';
      final role = sentBy?['systemRole'];
      final roleLabels = {
        'company_admin': 'Admin',
        'sales_manager': 'Manager',
        'team_leader': 'TL',
        'sales_executive': 'Sales',
      };
      final roleLabel = roleLabels[role];
      senderLabel = roleLabel != null ? '$name ($roleLabel)' : name;
    } else if (isAutomated) {
      senderLabel = 'Automated';
    }

    String? sourceBadge;
    if (message['source'] != null && message['source'] != 'manual') {
      final sourceLabels = {
        'automation': 'Automation',
        'lead_automation': 'Automation',
        'status_trigger': 'Status Trigger',
        'visit_created': 'Visit Created',
        'visit_rescheduled': 'Visit Rescheduled',
        'visit_cancelled': 'Visit Cancelled',
        'visit_completed': 'Visit Completed',
        'visit_reminder': 'Visit Reminder',
      };
      sourceBadge =
          sourceLabels[message['source']] ??
          message['source'].toString().toUpperCase();
    } else if (isAutomated) {
      sourceBadge = automationTag;
    }

    final margin = EdgeInsets.only(
      left: isOutbound ? 48.0 : 0.0,
      right: isOutbound ? 0.0 : 48.0,
      bottom: 8.0,
    );

    final isFailed = status == 'failed';

    return Padding(
      padding: margin,
      child: Column(
        crossAxisAlignment: isOutbound
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          _buildMessageByType(
            context,
            ref,
            type,
            isOutbound,
            status,
            isFailed,
            timeString,
            fullTimeString,
            senderLabel,
            sourceBadge,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageByType(
    BuildContext context,
    WidgetRef ref,
    String type,
    bool isOutbound,
    String status,
    bool isFailed,
    String timeString,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
  ) {
    // Template messages
    if (type == 'template') {
      return _buildTemplateMessage(
        ref,
        isOutbound,
        status,
        isFailed,
        fullTimeString,
        senderLabel,
        sourceBadge,
      );
    }

    // Extract media URL once
    String? mediaUrl = _extractMediaUrl();

    switch (type) {
      case 'image':
        return _buildImageMessage(
          mediaUrl,
          isOutbound,
          status,
          isFailed,
          fullTimeString,
          senderLabel,
          sourceBadge,
          'image',
        );
      case 'video':
        return _buildImageMessage(
          mediaUrl,
          isOutbound,
          status,
          isFailed,
          fullTimeString,
          senderLabel,
          sourceBadge,
          'video',
        );
      case 'document':
        return _buildDocumentMessage(
          mediaUrl,
          isOutbound,
          status,
          isFailed,
          fullTimeString,
          senderLabel,
          sourceBadge,
        );
      case 'location':
        return _buildLocationMessage(
          isOutbound,
          status,
          fullTimeString,
          senderLabel,
          sourceBadge,
        );
      default:
        return _buildTextMessage(
          isOutbound,
          status,
          isFailed,
          fullTimeString,
          senderLabel,
          sourceBadge,
        );
    }
  }

  Widget _buildTextMessage(
    bool isOutbound,
    String status,
    bool isFailed,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
  ) {
    final body = message['body'] ?? '';
    String cleanBody = body
        .toString()
        .replaceAll(
          RegExp(r'\[(image|document|video|audio|file|sticker|location)\]'),
          '',
        )
        .trim();

    // If there's a mediaUrl but no text content and this is an image type
    final mediaUrl = _extractMediaUrl();
    if (cleanBody.isEmpty && mediaUrl != null) {
      return _buildImageMessage(
        mediaUrl,
        isOutbound,
        status,
        isFailed,
        fullTimeString,
        senderLabel,
        sourceBadge,
        'image',
      );
    }

    if (cleanBody.isEmpty) {
      return _buildEmptyBubble(
        isOutbound, status, fullTimeString, senderLabel, sourceBadge,
      );
    }

    final textWidget = WhatsAppTextMessage(
      text: cleanBody,
      timestamp: fullTimeString,
      isOutbound: isOutbound,
      isDark: isDark,
      status: status,
      senderLabel: senderLabel,
      sourceBadge: sourceBadge,
    );

    if (isFailed) {
      return WhatsAppFailedMessage(
        message: message,
        isDark: isDark,
        senderLabel: null,
        sourceBadge: null,
        timestamp: fullTimeString,
        status: status,
        child: textWidget,
      );
    }

    return textWidget;
  }

  Widget _buildImageMessage(
    String? mediaUrl,
    bool isOutbound,
    String status,
    bool isFailed,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
    String mediaType,
  ) {
    final caption =
        message['caption'] ??
        message['body']
            ?.toString()
            .replaceAll(RegExp(r'\[image\]|\[video\]'), '')
            .trim();

    final imageWidget = WhatsAppImageMessage(
      imageUrl: mediaUrl ?? '',
      caption: caption.toString().isNotEmpty ? caption.toString() : null,
      timestamp: fullTimeString,
      isOutbound: isOutbound,
      isDark: isDark,
      status: status,
      senderLabel: senderLabel,
      sourceBadge: sourceBadge,
      mediaType: mediaType,
    );

    if (isFailed) {
      return WhatsAppFailedMessage(
        message: message,
        isDark: isDark,
        senderLabel: null,
        sourceBadge: null,
        timestamp: fullTimeString,
        status: status,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildDocumentMessage(
    String? mediaUrl,
    bool isOutbound,
    String status,
    bool isFailed,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
  ) {
    final docWidget = WhatsAppDocumentMessage(
      documentUrl: mediaUrl,
      fileName:
          message['fileName'] ??
          message['document']?['filename'] ??
          'Document',
      fileSize: message['fileSize']?.toString(),
      timestamp: fullTimeString,
      isOutbound: isOutbound,
      isDark: isDark,
      status: status,
      senderLabel: senderLabel,
      sourceBadge: sourceBadge,
    );

    if (isFailed) {
      return WhatsAppFailedMessage(
        message: message,
        isDark: isDark,
        senderLabel: null,
        sourceBadge: null,
        timestamp: fullTimeString,
        status: status,
        child: docWidget,
      );
    }

    return docWidget;
  }

  Widget _buildTemplateMessage(
    WidgetRef ref,
    bool isOutbound,
    String status,
    bool isFailed,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
  ) {
    final templateData = message['template'];
    Map<String, dynamic>? fullTpl = message['__fullTemplate'];

    if (fullTpl == null && templateData != null) {
      final templateName = templateData['name'];
      debugPrint('Fetching full template for: $templateName');
      try {
        final templates = ref.watch(whatsappTemplatesProvider).templates;
        final matching = templates.firstWhere(
          (t) => t['name'] == templateName,
          orElse: () => <String, dynamic>{},
        );
        if (matching.isNotEmpty) {
          fullTpl = matching;
          debugPrint('Template found for: $templateName');
        } else {
          debugPrint('Template NOT found for: $templateName');
        }
      } catch (e) {
        debugPrint('Error fetching template: $e');
      }
    }

    String rawBodyText = '';
    String? headerText;
    if (fullTpl != null) {
      final comps = (fullTpl['components'] as List?) ?? [];
      final bodyComp = comps.firstWhere(
        (c) => (c['type'] ?? '').toString().toUpperCase() == 'BODY',
        orElse: () => <String, dynamic>{},
      );
      rawBodyText = bodyComp?['text'] ?? '';
      final headerComp = comps.firstWhere(
        (c) => (c['type'] ?? '').toString().toUpperCase() == 'HEADER',
        orElse: () => <String, dynamic>{},
      );
      if (headerComp != null && headerComp['format'] == 'TEXT') {
        headerText = headerComp['text'] ?? '';
      }
    } else {
      rawBodyText = message['body'] ?? '';
    }

    // Resolve placeholders
    if (templateData != null && templateData['components'] != null) {
      final List sentComps = templateData['components'];
      final bodyComp = sentComps.firstWhere(
        (c) => c['type'] == 'body' || c['type'] == 'BODY',
        orElse: () => <String, dynamic>{},
      );
      if (bodyComp != null && bodyComp['parameters'] != null) {
        final params = bodyComp['parameters'] as List;
        for (int i = 0; i < params.length; i++) {
          final val = params[i]['text'] ?? '';
          rawBodyText = rawBodyText.replaceAll('{{${i + 1}}}', val.toString());
        }
      }
    }

    // Extract sent media / location parameters
    String? mediaUrl;
    String? mediaType;
    Map<String, dynamic>? locationData;
    if (templateData != null && templateData['components'] != null) {
      final List sentComps = templateData['components'];
      final sentHeader = sentComps.firstWhere(
        (c) => c['type'] == 'header' || c['type'] == 'HEADER',
        orElse: () => <String, dynamic>{},
      );
      if (sentHeader != null && sentHeader['parameters'] != null) {
        final params = sentHeader['parameters'] as List;
        if (params.isNotEmpty) {
          final param = params[0] as Map;
          final pType = (param['type'] ?? '').toString().toLowerCase();
          if (pType == 'image' && param['image'] != null) {
            mediaUrl = param['image']['link'] ?? param['image']['url'];
            mediaType = 'image';
          } else if (pType == 'video' && param['video'] != null) {
            mediaUrl = param['video']['link'] ?? param['video']['url'];
            mediaType = 'video';
          } else if (pType == 'document' && param['document'] != null) {
            mediaUrl = param['document']['link'] ?? param['document']['url'];
            mediaType = 'document';
          } else if (pType == 'location' && param['location'] != null) {
            locationData = Map<String, dynamic>.from(param['location']);
          }
        }
      }
    }
    // Fallback: check message-level location data
    if (locationData == null) {
      if (message['location'] is Map) {
        locationData = Map<String, dynamic>.from(message['location'] as Map);
      } else if (message['latitude'] != null) {
        locationData = <String, dynamic>{
          'latitude': message['latitude'],
          'longitude': message['longitude'],
          'name': message['locationName'],
          'address': message['locationAddress'],
        };
      }
    }
    debugPrint('_buildTemplateMessage locationData: $locationData');

    // Fallback to design example
    if (mediaUrl == null && fullTpl != null) {
      final fullComponents = (fullTpl['components'] as List?) ?? [];
      for (var c in fullComponents) {
        if ((c['type'] ?? '').toString().toUpperCase() == 'HEADER') {
          final format = (c['format'] ?? '').toString().toUpperCase();
          if (format == 'IMAGE' || format == 'VIDEO' || format == 'DOCUMENT') {
            mediaType = format.toLowerCase();
            final example = c['example'] as Map?;
            if (example != null) {
              final handles = example['header_handle'];
              if (handles is List && handles.isNotEmpty) {
                mediaUrl = handles[0].toString();
              } else if (handles is String && handles.isNotEmpty) {
                mediaUrl = handles;
              }
            }
          }
        }
      }
    }

    // Merge header media into template for rendering
    final Map<String, dynamic> tplData = templateData != null
        ? Map<String, dynamic>.from(templateData)
        : <String, dynamic>{};
    final previewTpl = fullTpl != null
        ? Map<String, dynamic>.from(fullTpl)
        : {
            ...tplData,
            'name': tplData['name'] ?? '',
            'language': tplData['language'] ?? 'en',
            'components':
                tplData['components'] ??
                [
                  {'type': 'BODY', 'text': rawBodyText},
                ],
          };

    // Inject location header
    if (locationData != null) {
      previewTpl['components'] = _injectHeaderComponent(
        previewTpl['components'] as List? ?? [],
        'LOCATION',
        locationData,
      );
    } else if (mediaUrl != null && mediaUrl.isNotEmpty) {
      previewTpl['components'] = _injectMediaHeader(
        previewTpl['components'] as List? ?? [],
        mediaType?.toUpperCase() ?? 'IMAGE',
        mediaUrl,
      );
    }

    // Preserve category
    if (templateData?['category'] != null) {
      previewTpl['category'] = templateData['category'];
    } else if (fullTpl?['category'] != null) {
      previewTpl['category'] = fullTpl!['category'];
    }

    return WhatsAppTemplateMessage(
      template: previewTpl,
      bodyText: rawBodyText,
      headerText: headerText,
      isDark: isDark,
      timestamp: fullTimeString,
      status: isFailed ? 'failed' : status,
      isOutbound: isOutbound,
      templateMediaUrl: mediaUrl,
      templateMediaType: mediaType,
      locationData: locationData,
      senderLabel: senderLabel,
      sourceBadge: sourceBadge,
      replyContext: message['context'],
      errorMap: isFailed ? _extractErrorMap() : null,
      rawError: isFailed ? _extractRawError(message) : null,
    );
  }

  Map<String, dynamic>? _extractErrorMap() {
    final err = message['error'];
    if (err is Map) {
      return Map<String, dynamic>.from(err);
    }
    return {'message': err?.toString() ?? 'Unknown delivery failure'};
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

  List<dynamic> _injectHeaderComponent(
    List<dynamic> comps,
    String format,
    Map<String, dynamic> data,
  ) {
    final result = List<dynamic>.from(comps);
    final headerIdx = result.indexWhere(
      (c) => c is Map && (c['type'] ?? '').toString().toUpperCase() == 'HEADER',
    );
    final header = {'type': 'HEADER', 'format': format, ...data};
    if (headerIdx != -1) {
      result[headerIdx] = header;
    } else {
      result.insert(0, header);
    }
    return result;
  }

  List<dynamic> _injectMediaHeader(
    List<dynamic> comps,
    String format,
    String url,
  ) {
    final result = List<dynamic>.from(comps);
    final headerIdx = result.indexWhere(
      (c) => c is Map && (c['type'] ?? '').toString().toUpperCase() == 'HEADER',
    );
    final header = {
      'type': 'HEADER',
      'format': format,
      'example': {
        'header_handle': [url],
      },
    };
    if (headerIdx != -1) {
      final existing = Map<String, dynamic>.from(result[headerIdx]);
      existing['format'] = format;
      existing['example'] = {
        'header_handle': [url],
      };
      result[headerIdx] = existing;
    } else {
      result.insert(0, header);
    }
    return result;
  }

  String? _extractMediaUrl() {
    if (message['media'] is Map && message['media']['id'] != null) {
      return '${AuthService.baseUrl}/api/v1/whatsapp/media/${message['media']['id']}';
    }
    return message['mediaUrl'] ??
        message['url'] ??
        message['fileUrl'] ??
        message['link'] ??
        message['media']?['url'] ??
        message['media']?['link'] ??
        message['image']?['url'] ??
        message['image']?['link'] ??
        message['document']?['url'] ??
        message['document']?['link'] ??
        message['video']?['url'] ??
        message['video']?['link'];
  }

  Widget _buildLocationMessage(
    bool isOutbound,
    String status,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
  ) {
    final locationData = message['location'] is Map
        ? Map<String, dynamic>.from(message['location'] as Map)
        : <String, dynamic>{
            'name': message['locationName'],
            'address': message['locationAddress'],
            'latitude': message['latitude'],
            'longitude': message['longitude'],
          };

    return _buildLocationCard(
      locationData,
      isOutbound,
      status,
      fullTimeString,
      senderLabel,
      sourceBadge,
    );
  }

  Widget _buildLocationCard(
    Map<String, dynamic> locationData,
    bool isOutbound,
    String status,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
  ) {
    final textThemeColor = isDark ? Colors.white : const Color(0xFF111B21);
    final lat = locationData['latitude'] ?? locationData['lat'];
    final lng = locationData['longitude'] ?? locationData['long'] ?? locationData['lng'];
    final hasCoords = lat != null && lng != null;

    final placeName = locationData['name']?.toString() ??
        locationData['placeName']?.toString() ??
        'Dropped Pin';
    final address = locationData['address']?.toString() ??
        locationData['locationAddress']?.toString() ??
        '';

    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
      bottomLeft: isOutbound ? const Radius.circular(8) : Radius.zero,
      bottomRight: isOutbound ? Radius.zero : const Radius.circular(8),
    );

    final card = Container(
      constraints: const BoxConstraints(maxWidth: 320),
      decoration: BoxDecoration(
        color: isOutbound
            ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
            : (isDark ? const Color(0xFF1E2A30) : Colors.white),
        borderRadius: borderRadius,
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isOutbound && senderLabel != null)
            _buildSenderHeader(senderLabel, sourceBadge),
          Container(
            height: 150,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFB3E5FC), Color(0xFFA5D6A7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Center(
              child: Icon(Icons.location_on, size: 40, color: Colors.red.shade400),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: textThemeColor,
                  ),
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
            child: Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fullTimeString,
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
          ),
        ],
      ),
    );

    if (hasCoords) {
      return Column(
        crossAxisAlignment: isOutbound
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: () => _openGoogleMaps(lat, lng),
              borderRadius: borderRadius,
              child: card,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: isOutbound
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [card],
    );
  }

  Future<void> _openGoogleMaps(dynamic lat, dynamic lng) async {
    final uri = Uri.parse('https://maps.google.com/?q=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildEmptyBubble(
    bool isOutbound,
    String status,
    String fullTimeString,
    String? senderLabel,
    String? sourceBadge,
  ) {
    return Column(
      crossAxisAlignment: isOutbound
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.only(
            left: 10,
            top: 4,
            right: 10,
            bottom: 4,
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isOutbound && senderLabel != null)
                _buildSenderHeader(senderLabel, sourceBadge),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullTimeString,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF667781),
                      ),
                    ),
                    if (isOutbound) ...[
                      const SizedBox(width: 4),
                      WhatsAppStatusIndicator(
                          status: status, isDark: isDark),
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

  Widget _buildSenderHeader(String senderLabel, String? sourceBadge) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
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
              senderLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (sourceBadge != null) ...[
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
                sourceBadge.toUpperCase(),
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
