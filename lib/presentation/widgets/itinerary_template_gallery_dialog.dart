import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lead_model.dart';
import '../providers/itinerary_provider.dart';
import 'itinerary_template_preview_dialog.dart';
import 'itinerary_create_dialog.dart';

class ItineraryTemplateGalleryDialog extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic> template)? onSelect;
  final Lead? prefilledLead;

  const ItineraryTemplateGalleryDialog({
    super.key,
    this.onSelect,
    this.prefilledLead,
  });

  @override
  ConsumerState<ItineraryTemplateGalleryDialog> createState() => _ItineraryTemplateGalleryDialogState();
}

class _ItineraryTemplateGalleryDialogState extends ConsumerState<ItineraryTemplateGalleryDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(itineraryV2Provider.notifier).fetchTemplates();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(itineraryV2Provider);
    final templates = state.templates;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFFFDFCF9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Template Gallery',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0D0C0A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'SELECT A BLUEPRINT FOR YOUR JOURNEY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: Color(0xFF4B5563)),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEAE8E3)),
            
            // Body
            Expanded(
              child: state.isLoading && templates.isEmpty
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : templates.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.style_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No templates available.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(20),
                          itemCount: templates.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 20),
                          itemBuilder: (context, index) {
                            final t = templates[index];
                            final key = t['templateKey'] ?? t['key'] ?? t['id'] ?? t['_id'] ?? t['slug'] ?? t['code'] ?? '';
                            final name = t['name'] ?? 'Unnamed Template';
                            final description = t['description'] ?? 'Elegantly styled travel layouts.';
                            final thumbnail = t['thumbnail'] ?? '';

                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFEAE8E3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Hero Image with Badge
                                  Stack(
                                    children: [
                                      Container(
                                        height: 180,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF3F4F6),
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                                          image: thumbnail.isNotEmpty
                                              ? DecorationImage(image: NetworkImage(thumbnail), fit: BoxFit.cover)
                                              : null,
                                        ),
                                        child: thumbnail.isEmpty
                                            ? const Center(child: Icon(Icons.image_outlined, size: 40, color: Colors.grey))
                                            : null,
                                      ),
                                      Positioned(
                                        top: 12, right: 12,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.95),
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.auto_awesome, size: 12, color: Color(0xFF374151)),
                                              SizedBox(width: 4),
                                              Text(
                                                'PREMIUM',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF374151),
                                                  letterSpacing: 0.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Card Body
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0D0C0A),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          description,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280),
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        // Action Buttons
                                        Row(
                                          children: [
                                            Expanded(
                                              child: SizedBox(
                                                height: 38,
                                                child: OutlinedButton.icon(
                                                   onPressed: () {
                                                     showDialog(
                                                       context: context,
                                                       builder: (ctx) => ItineraryTemplatePreviewDialog(
                                                         templateKey: key,
                                                         templateName: name,
                                                       ),
                                                     );
                                                   },
                                                  icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF374151)),
                                                  label: const Text(
                                                    'Preview',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: const Color(0xFF374151),
                                                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: SizedBox(
                                                height: 38,
                                                child: ElevatedButton.icon(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    if (widget.onSelect != null) {
                                                      widget.onSelect!(t);
                                                    } else {
                                                      showDialog(
                                                        context: context,
                                                        builder: (ctx) => ItineraryCreateDialog(
                                                          initialTemplateData: t,
                                                          prefilledLead: widget.prefilledLead,
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  icon: const Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
                                                  label: const Text(
                                                    'Select',
                                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                                  ),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF0D0C0A),
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
