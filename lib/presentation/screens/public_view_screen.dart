import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/models/property_model.dart';
import '../providers/property_provider.dart';
import '../../core/utils/media_helper.dart';

class PublicViewScreen extends ConsumerStatefulWidget {
  final Project? project;
  final Property? property;

  const PublicViewScreen({
    super.key,
    this.project,
    this.property,
  }) : assert(project != null || property != null, 'Either project or property must be provided');

  /// Extracts a public page URL from a message, preferring URLs containing /public/
  /// over any other URLs (e.g. image thumbnails) that might appear first.
  static String? _extractPublicUrl(String message) {
    final publicMatch = RegExp(r'https?://[^\s]*/public/[^\s]*').firstMatch(message);
    if (publicMatch != null) return publicMatch.group(0);
    final anyMatch = RegExp(r'https?://[^\s]+').firstMatch(message);
    return anyMatch?.group(0);
  }

  static Future<void> launchPublicView(
    BuildContext context,
    WidgetRef ref, {
    Project? project,
    Property? property,
  }) async {
    assert(project != null || property != null, 'Either project or property must be provided');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Opening Public View…', style: TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );

    String? publicUrl;
    try {
      Map<String, dynamic> data;
      if (project != null) {
        data = await ref.read(propertyProvider.notifier).generateProjectShareMessage(project.id);
      } else {
        data = await ref.read(propertyProvider.notifier).generatePropertyShareMessage(property!.id);
      }
      final message = data['message'] as String?;
      if (message != null && message.isNotEmpty) {
        publicUrl = _extractPublicUrl(message);
      }
    } catch (e) {
      debugPrint('PublicViewScreen.launchPublicView: Error fetching URL: $e');
    }

    if (publicUrl == null) {
      final isProject = project != null;
      final id = isProject ? project.id : property!.id;
      final path = isProject ? 'project' : 'property';
      publicUrl = 'https://crm-app-backend-btpi.onrender.com/public/$path/$id';
    }

    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();

    if (context.mounted) {
      await MediaHelper.launchMediaUrl(context, publicUrl);
    }
  }

  @override
  ConsumerState<PublicViewScreen> createState() => _PublicViewScreenState();
}

class _PublicViewScreenState extends ConsumerState<PublicViewScreen> {
  String? _publicUrl;
  bool _isLoadingUrl = false;

  @override
  void initState() {
    super.initState();
    _fetchPublicUrl();
  }

  Future<void> _fetchPublicUrl() async {
    setState(() => _isLoadingUrl = true);
    try {
      if (widget.project != null) {
        final data = await ref.read(propertyProvider.notifier).generateProjectShareMessage(widget.project!.id);
        final message = data['message'] as String?;
        _extractUrl(message, isProject: true, id: widget.project!.id);
      } else if (widget.property != null) {
        final data = await ref.read(propertyProvider.notifier).generatePropertyShareMessage(widget.property!.id);
        final message = data['message'] as String?;
        _extractUrl(message, isProject: false, id: widget.property!.id);
      }
    } catch (e) {
      debugPrint("PublicViewScreen: Error fetching public url: $e");
      // Fallback fallback URL
      if (mounted) {
        setState(() {
          final isProject = widget.project != null;
          final id = isProject ? widget.project!.id : widget.property!.id;
          final path = isProject ? 'project' : 'property';
          _publicUrl = 'https://crm-app-backend-btpi.onrender.com/public/$path/$id';
          _isLoadingUrl = false;
        });
      }
    }
  }

  void _extractUrl(String? message, {required bool isProject, required String id}) {
    if (!mounted) return;
    if (message != null && message.isNotEmpty) {
      final url = PublicViewScreen._extractPublicUrl(message);
      if (url != null) {
        setState(() {
          _publicUrl = url;
          _isLoadingUrl = false;
        });
        return;
      }
    }
    setState(() {
      final path = isProject ? 'project' : 'property';
      _publicUrl = 'https://crm-app-backend-btpi.onrender.com/public/$path/$id';
      _isLoadingUrl = false;
    });
  }

  void _copyLink() {
    if (_publicUrl == null) return;
    Clipboard.setData(ClipboardData(text: _publicUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
            SizedBox(width: 8),
            Text("Public view link copied!"),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Extracted fields based on Project or Property
    final String name = widget.project?.name ?? widget.property?.name ?? '';
    final String developer = widget.project?.developerName ?? widget.property?.project?.developerName ?? 'Samvitha Developers';
    final String address = widget.project?.location?.address1 ?? widget.property?.location?.address1 ?? 'No Address Listed';
    
    // Status & launch values
    final String status = widget.project?.status ?? widget.property?.status ?? 'Active';
 widget.project?.active ?? (widget.property?.status.toLowerCase() == 'available');

    // Image list
    final List<String> rawImages = widget.project?.images ?? widget.property?.images ?? [];
    final List<String> resolvedImages = rawImages.map((e) => MediaHelper.getMediaUrl(e)).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111422) : const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Public View',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Slider (if images present)
            if (resolvedImages.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 200,
                  child: PageView.builder(
                    itemCount: resolvedImages.length,
                    itemBuilder: (context, idx) {
                      return Image.network(
                        resolvedImages[idx],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey.withValues(alpha: 0.1),
                            child: const Icon(Icons.broken_image_outlined, size: 40),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Project / Property Name Title
            Text(
              name,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),

            // Developer Label
            Text(
              'Developed by $developer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            // Location with Icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on, color: Colors.redAccent[400], size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Button Row: Copy Link Action
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _isLoadingUrl ? null : _copyLink,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _isLoadingUrl
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.link, size: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Copy Link',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Listing Agent Chip
            Row(
              children: [
                Text(
                  'LISTING AGENT:  ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300]!,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.business_center, size: 12, color: Colors.blueAccent),
                      const SizedBox(width: 6),
                      Text(
                        'Alpha Tech',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Project/Property status card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2238) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.project != null ? 'PROJECT LAUNCH STATUS' : 'PROPERTY AVAILABILITY',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatStatus(status),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Overview Section
            Text(
              widget.project != null ? 'PROJECT OVERVIEW' : 'PROPERTY OVERVIEW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            ..._buildOverviewBullets(isDark),
            const SizedBox(height: 20),

            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 24),

            // Additional Information
            Text(
              'Additional Information',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            _buildAdditionalInfoGrid(isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String raw) {
    return raw.split('_').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  List<Widget> _buildOverviewBullets(bool isDark) {
    final List<String> bullets = [];

    if (widget.project != null) {
      final p = widget.project!;
      if (p.description.isNotEmpty) {
        bullets.add(p.description);
      }
      if (p.amenities.isNotEmpty) {
        bullets.add("Premium amenities: ${p.amenities.take(4).join(', ')}");
      }
      if (p.reraId != null && p.reraId!.isNotEmpty) {
        bullets.add("Verified RERA approval (ID: ${p.reraId})");
      }
    } else if (widget.property != null) {
      final pr = widget.property!;
      if (pr.description.isNotEmpty) {
        bullets.add(pr.description);
      }
      bullets.add("Property Category: ${pr.category} (${pr.propertyType})");
      if (pr.area != null) {
        bullets.add("Spacious plot of ${pr.area!.value} ${pr.area!.unit}");
      }
      if (pr.amenities.isNotEmpty) {
        bullets.add("Equipped with: ${pr.amenities.take(4).join(', ')}");
      }
    }

    if (bullets.isEmpty) {
      bullets.add("Modern architectural design and premium build quality offering state-of-the-art experiences.");
      bullets.add("Prime localization ensuring rich neighborhood connectivity and top-tier infrastructure.");
    }

    return bullets.map((text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Icon(Icons.circle, size: 6, color: Colors.blueAccent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[300] : Colors.grey[850],
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildAdditionalInfoGrid(bool isDark) {
    final List<Map<String, String>> items = [];

    if (widget.project != null) {
      final p = widget.project!;
      items.addAll([
        {'label': 'PROJECT CATEGORY', 'value': p.category},
        {'label': 'DEVELOPER', 'value': p.developerName},
        {'label': 'TOTAL PROJECT AREA', 'value': p.totalArea != null ? '${p.totalArea!.value} ${p.totalArea!.unit}' : '—'},
        {'label': 'POSSESSION TIMELINE', 'value': p.possessionDate ?? '—'},
      ]);
    } else if (widget.property != null) {
      final pr = widget.property!;
      items.addAll([
        {'label': 'PROPERTY TYPE', 'value': pr.propertyType},
        {'label': 'DEVELOPER', 'value': pr.project?.developerName ?? 'Samvitha Developers'},
        {'label': 'DIMENSIONS', 'value': pr.length != null && pr.breadth != null ? '${pr.length!.value} × ${pr.breadth!.value} feet' : '—'},
        {'label': 'PRICE', 'value': '₹${NumberFormat('#,##,###').format(pr.price)}'},
      ]);
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.2,
      ),
      itemCount: items.length,
      itemBuilder: (context, idx) {
        final item = items[idx];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              item['label']!,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.grey[400] : Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item['value']!,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      },
    );
  }
}
