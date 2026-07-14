import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/lead_model.dart';
import '../providers/itinerary_provider.dart';
import 'itinerary_create_dialog.dart';
import 'itinerary_template_preview_dialog.dart';

class ChooseItineraryTemplateDialog extends ConsumerStatefulWidget {
  final Lead? prefilledLead;
  const ChooseItineraryTemplateDialog({super.key, this.prefilledLead});

  @override
  ConsumerState<ChooseItineraryTemplateDialog> createState() => _ChooseItineraryTemplateDialogState();
}

class _ChooseItineraryTemplateDialogState extends ConsumerState<ChooseItineraryTemplateDialog> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        width: 400,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Choose Itinerary Template',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Subtitle
              Text(
                'Select a template style to start building your customized travel plan.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),

              // Templates List or Loader
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: state.isLoading && templates.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black87,
                          ),
                        ),
                      )
                    : templates.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text(
                                'No templates available.',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                                ),
                              ),
                            ),
                          )
                        : SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: templates.map((t) {
                                final name = t['name'] ?? 'Unnamed Template';
                                final description = t['description'] ?? 'Elegantly styled travel layouts.';
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context); // close this choose template dialog
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) => ItineraryCreateDialog(
                                          initialTemplateData: t,
                                          prefilledLead: widget.prefilledLead,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isDark ? Colors.white10 : const Color(0xFFE5E7EB),
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? Colors.grey[200] : Colors.grey[800],
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.visibility_outlined, size: 20),
                                                onPressed: () {
                                                  // Open Template Preview Dialog
                                                  showDialog(
                                                    context: context,
                                                    builder: (ctx) => ItineraryTemplatePreviewDialog(
                                                      templateKey: t['templateKey'] as String? ?? '',
                                                      templateName: t['templateName'] as String? ?? '',
                                                    ),
                                                  );
                                                },
                                                tooltip: 'Preview Template',
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            description,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.grey[500] : Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
              ),
              const SizedBox(height: 24),

              // Cancel button aligned to bottom right
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      side: BorderSide(
                        color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
