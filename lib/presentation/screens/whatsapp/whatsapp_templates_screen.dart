import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/permission_constants.dart';
import '../../providers/whatsapp_provider.dart';
import '../../widgets/global_app_bar.dart';
import 'whatsapp_permission_guard.dart';
import 'whatsapp_template_create_screen.dart';
import 'widgets/whatsapp_icon.dart';
import 'widgets/whatsapp_markdown_text.dart';
import 'widgets/whatsapp_preview_bubble.dart';

class WhatsAppTemplatesScreen extends ConsumerStatefulWidget {
  const WhatsAppTemplatesScreen({super.key});

  @override
  ConsumerState<WhatsAppTemplatesScreen> createState() => _WhatsAppTemplatesScreenState();
}

class _WhatsAppTemplatesScreenState extends ConsumerState<WhatsAppTemplatesScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(whatsappTemplatesProvider.notifier).fetchTemplates();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesState = ref.watch(whatsappTemplatesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter local list based on selection and query
    final filteredList = templatesState.templates.where((temp) {
      final name = (temp['name'] ?? '').toString().toLowerCase();
      final query = templatesState.searchQuery.toLowerCase();
      final matchesSearch = name.contains(query);

      // Status gating
      bool matchesStatus = true;
      if (templatesState.filterStatus != 'ALL') {
        final isApproved = temp['isApproved'] ?? false;
        final status = temp['status'] ?? '';
        
        if (templatesState.filterStatus == 'APPROVED') {
          matchesStatus = isApproved || status.toString().toUpperCase() == 'APPROVED';
        } else if (templatesState.filterStatus == 'PENDING') {
          matchesStatus = !isApproved && status.toString().toUpperCase() == 'PENDING';
        } else if (templatesState.filterStatus == 'REJECTED') {
          matchesStatus = status.toString().toUpperCase() == 'REJECTED';
        }
      }

      // Category Gating
      bool matchesCat = true;
      if (templatesState.categoryFilter != 'ALL') {
        final cat = (temp['category'] ?? '').toString().toUpperCase();
        matchesCat = cat == templatesState.categoryFilter;
      }

      return matchesSearch && matchesStatus && matchesCat;
    }).toList();

    return WhatsAppPermissionGuard(
      requiredModules: const ['modules.integration', 'modules.whatsapp'],
      requiredPermission: PermissionModules.TEMPLATE_VIEW,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const GlobalAppBar(title: 'WhatsApp Templates'),

        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        whatsAppIcon(size: 24, color: const Color(0xFF25D366)),
                        const SizedBox(width: 8),
                        Text(
                          'WhatsApp Templates',
                          style: TextStyle(
                            fontSize: 22, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Manage and preview all templates',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            ref.read(whatsappTemplatesProvider.notifier).fetchTemplates();
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text("REFRESH"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? Colors.white : Colors.black87,
                            side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => const WhatsAppTemplateCreateDialog(),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("CREATE TEMPLATE"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            SliverToBoxAdapter(
              child: Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey[200]),
            ),

            // Filters & Search Bar Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search & Category row
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              ref.read(whatsappTemplatesProvider.notifier).setSearchQuery(val);
                            },
                            decoration: InputDecoration(
                              hintText: 'Search templates by name...',
                              hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[500]),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF1E2130) : Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Category drop down
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: templatesState.categoryFilter,
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                              ),
                            ),
                            dropdownColor: isDark ? const Color(0xFF1E2130) : Colors.white,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'ALL', child: Text('All')),
                              DropdownMenuItem(value: 'MARKETING', child: Text('MARKETING')),
                              DropdownMenuItem(value: 'UTILITY', child: Text('UTILITY')),
                              DropdownMenuItem(value: 'AUTHENTICATION', child: Text('AUTHENTICATION')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                ref.read(whatsappTemplatesProvider.notifier).setCategoryFilter(val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Status dropdown
                    DropdownButtonFormField<String>(
                      initialValue: templatesState.filterStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        labelStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                        ),
                      ),
                      dropdownColor: isDark ? const Color(0xFF1E2130) : Colors.white,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All')),
                        DropdownMenuItem(value: 'APPROVED', child: Text('APPROVED')),
                        DropdownMenuItem(value: 'REJECTED', child: Text('REJECTED')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          ref.read(whatsappTemplatesProvider.notifier).setFilterStatus(val);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Templates List
            if (templatesState.isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (templatesState.error != null)
              SliverFillRemaining(
                child: _buildErrorState(context, isDark, templatesState.error!),
              )
            else if (filteredList.isEmpty)
              SliverFillRemaining(
                child: _buildEmptyState(context, isDark),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final temp = filteredList[index];
                    return Padding(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: index == 0 ? 8 : 0,
                        bottom: 12,
                      ),
                      child: _buildTemplateCard(context, isDark, temp),
                    );
                  },
                  childCount: filteredList.length,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(BuildContext context, bool isDark, Map<String, dynamic> temp) {
    final String name = temp['name'] ?? '';
    final String language = temp['language'] ?? 'en';
    final String category = temp['category'] ?? 'MARKETING';
    final bool isApproved = temp['isApproved'] ?? false;
    final String status = (temp['status'] ?? (isApproved ? 'APPROVED' : 'PENDING')).toString().toUpperCase();

    final components = temp['components'] as List?;
    final bodyComp = components?.firstWhere((c) => c['type'] == 'BODY', orElse: () => <String, dynamic>{});
    final String bodyText = bodyComp?['text'] ?? '';

    Color statusColor = Colors.amber;
    if (status == 'APPROVED') statusColor = Colors.green;
    if (status == 'REJECTED') statusColor = Colors.red;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2130) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? Colors.white24 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSimpleChip(language, isDark),
              const SizedBox(width: 8),
              _buildSimpleChip(category, isDark),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          WhatsAppMarkdownText(
            bodyText,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => _showPreviewDialog(context, isDark, temp),
              icon: const Icon(Icons.visibility_outlined, size: 14),
              label: const Text("Preview", style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : Colors.black54,
                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade400),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewDialog(BuildContext context, bool isDark, Map<String, dynamic> temp) {
    final String name = temp['name'] ?? '';
    final String category = temp['category'] ?? 'MARKETING';

    final components = temp['components'] as List?;
    final headerComp = components?.firstWhere((c) => c['type'] == 'HEADER', orElse: () => <String, dynamic>{});
    final bodyComp = components?.firstWhere((c) => c['type'] == 'BODY', orElse: () => <String, dynamic>{});
    final footerComp = components?.firstWhere((c) => c['type'] == 'FOOTER', orElse: () => <String, dynamic>{});
    final buttonsComp = components?.firstWhere((c) => c['type'] == 'BUTTONS', orElse: () => <String, dynamic>{});

   headerComp?['text'] ?? '';
    final String bodyText = bodyComp?['text'] ?? '';
   footerComp?['text'] ?? '';
     buttonsComp?['buttons'] as List?;
    final List? headerExample = headerComp?['example']?['header_handle'] as List?;
     headerExample?.isNotEmpty == true ? headerExample![0] : null;

headerComp?['format'] ?? 'TEXT';

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Container(
          width: 360,
          constraints: const BoxConstraints(maxHeight: 600),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: whatsAppIcon(size: 18, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            category,
                            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black38, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: WhatsAppPreviewBubble(
                    template: temp,
                    bodyText: bodyText,
                    isDark: isDark,
                  ),
                ),
              ),
              // Timestamp
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(DateTime.now()),
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildMediaHeaderPlaceholder(String format) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          format == 'IMAGE'
              ? Icons.image_outlined
              : format == 'VIDEO'
                  ? Icons.play_circle_outline
                  : Icons.picture_as_pdf_outlined,
          size: 28,
          color: const Color(0xFF54656F),
        ),
        const SizedBox(height: 6),
        Text(
          format == 'IMAGE' ? 'IMAGE' : format == 'VIDEO' ? 'VIDEO' : 'DOCUMENT',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF54656F),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSimpleChip(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey[300] : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.library_books_outlined, size: 64, color: Colors.grey[500]),
          const SizedBox(height: 16),
          Text(
            "No templates found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try adjusting your filters or search terms.",
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          const SizedBox(height: 16),
          Text(
            "Failed to load templates",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.read(whatsappTemplatesProvider.notifier).fetchTemplates(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text("RETRY"),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.blue : Colors.black,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
