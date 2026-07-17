import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/formatters.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/lead_document_provider.dart';
import '../../providers/login_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/access_denied_widget.dart';

import '../../../core/utils/date_utils.dart';

class LeadDocumentsScreen extends ConsumerStatefulWidget {
  const LeadDocumentsScreen({super.key});

  @override
  ConsumerState<LeadDocumentsScreen> createState() => _LeadDocumentsScreenState();
}

class _LeadDocumentsScreenState extends ConsumerState<LeadDocumentsScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(globalDocumentsProvider.notifier).fetchDocuments();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(globalDocumentsProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.can(
      PermissionModules.LEAD_DOCS,
      permission: PermissionModules.LEAD_DOCS_VIEW,
      userRole: userRole,
    );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Lead Documents'),
        body: AccessDeniedWidget(
          sectionName: "Lead Documents",
          showAppBar: false,
        ),
      );
    }

    final state = ref.watch(globalDocumentsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalBytes = state.documents.fold<int>(0, (sum, doc) => sum + doc.size);
    final totalSizeStr = formatBytes(totalBytes);

    return Scaffold(
      endDrawer: Drawer(
        child: Column(
          children: [
            AppBar(
              title: const Text('Filters'),
              automaticallyImplyLeading: false,
              actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))],
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('File Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: state.fileType,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      const DropdownMenuItem(value: 'pdf', child: Text('PDF')),
                      const DropdownMenuItem(value: 'image', child: Text('Image')),
                      const DropdownMenuItem(value: 'doc', child: Text('Doc')),
                    ],
                    onChanged: (val) {
                      ref.read(globalDocumentsProvider.notifier).fetchDocuments(
                        fileType: val,
                        clearFileType: val == null,
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  const Text('Uploaded By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: state.uploadedBy,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All')),
                      const DropdownMenuItem(value: 'Staff', child: Text('Staff')),
                      const DropdownMenuItem(value: 'Client', child: Text('Client')),
                    ],
                    onChanged: (val) {
                      ref.read(globalDocumentsProvider.notifier).fetchDocuments(
                        uploadedBy: val,
                        clearUploadedBy: val == null,
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(globalDocumentsProvider.notifier).fetchDocuments(
                          clearFileType: true,
                          clearUploadedBy: true,
                          search: '',
                        );
                        _searchController.clear();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade200,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                      ),
                      child: const Text('RESET FILTERS'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      appBar: const GlobalAppBar(title: 'Documents'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Documents',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.documents.length == state.totalCount
                          ? '${state.totalCount} files · $totalSizeStr total'
                          : '${state.documents.length} of ${state.totalCount} files · $totalSizeStr total',
                      style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('To upload a document, please open a lead profile page and upload it from there.'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.file_upload_outlined,
                      color: isDark ? Colors.black87 : Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Search & Filters Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Search documents...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          size: 20,
                        ),
                        suffixIcon: _searchController.text.isNotEmpty 
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, size: 18, color: isDark ? Colors.grey[500] : Colors.grey[400]),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(globalDocumentsProvider.notifier).fetchDocuments(search: '');
                              },
                            )
                          : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (val) {
                        ref.read(globalDocumentsProvider.notifier).fetchDocuments(search: val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Builder(
                  builder: (context) => Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Scaffold.of(context).openEndDrawer(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 46,
                        width: 46,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey.shade200,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.tune_rounded,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Document Table/List
          Expanded(
            child: state.isLoading && state.documents.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : state.error != null
                    ? Center(child: Text('Error: ${state.error}'))
                    : state.documents.isEmpty
                        ? const Center(child: Text('No documents found'))
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: state.documents.length + (state.currentPage < state.totalPages ? 1 : 0),
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              if (index >= state.documents.length) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              }
                              final doc = state.documents[index];
                              final type = doc.fileType.toLowerCase() ;
                              Color iconColor;
                              Color iconBgColor;
                              if (type.contains('pdf')) {
                                iconColor = isDark ? Colors.blueAccent : const Color(0xFF1E3A8A);
                                iconBgColor = isDark ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.blue[50]!;
                              } else if (type.contains('jpg') || type.contains('jpeg') || type.contains('png')) {
                                iconColor = isDark ? Colors.purpleAccent : const Color(0xFF5B21B6);
                                iconBgColor = isDark ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.purple[50]!;
                              } else if (type.contains('xls') || type.contains('xlsx') || type.contains('csv')) {
                                iconColor = isDark ? Colors.greenAccent : const Color(0xFF065F46);
                                iconBgColor = isDark ? Colors.greenAccent.withValues(alpha: 0.2) : Colors.green[50]!;
                              } else if (type.contains('doc') || type.contains('docx') || type.contains('txt')) {
                                iconColor = isDark ? Colors.orangeAccent : const Color(0xFF9A3412);
                                iconBgColor = isDark ? Colors.orangeAccent.withValues(alpha: 0.2) : Colors.orange[50]!;
                              } else {
                                iconColor = isDark ? Colors.amberAccent : const Color(0xFF92400E);
                                iconBgColor = isDark ? Colors.amberAccent.withValues(alpha: 0.2) : Colors.amber[50]!;
                              }

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: theme.cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
                                    width: 1.0,
                                  ),
                                  boxShadow: isDark
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.02),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: iconBgColor,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(_getFileIcon(doc.fileType), color: iconColor, size: 20),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            doc.label, 
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Lead: ${doc.lead?.name ?? "-"} · ${formatBytes(doc.size)}',
                                            style: TextStyle(fontSize: 12, color: theme.hintColor),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Uploaded by ${doc.uploadedBy} on ${DateTimeUtils.formatSafe(doc.createdAt)}',
                                            style: TextStyle(fontSize: 10, color: theme.hintColor.withValues(alpha: 0.7)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (permissions.hasPermission(PermissionModules.LEAD_DOCS_DOWNLOAD, userRole: userRole))
                                          _buildSmallOutlineActionButton(
                                            icon: Icons.download_rounded,
                                            color: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                                            onTap: () => launchUrl(Uri.parse('https://treviondocs.browndevs.com/${doc.r2Key}')),
                                            isDark: isDark,
                                          ),
                                        if (permissions.hasPermission(PermissionModules.LEAD_DOCS_DOWNLOAD, userRole: userRole) &&
                                            permissions.hasPermission(PermissionModules.LEAD_DOCS_DELETE, userRole: userRole))
                                          const SizedBox(width: 6),
                                        if (permissions.hasPermission(PermissionModules.LEAD_DOCS_DELETE, userRole: userRole))
                                          _buildSmallOutlineActionButton(
                                            icon: Icons.delete_outline_rounded,
                                            color: Colors.red,
                                            onTap: () => _showDeleteConfirmation(context, doc.id),
                                            isDark: isDark,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Document'),
        content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              final success = await ref.read(globalDocumentsProvider.notifier).deleteDocument(docId);
              if (mounted) {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(success ? 'Document deleted successfully' : 'Failed to delete document'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallOutlineActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    final type = fileType?.toLowerCase() ?? '';
    if (type.contains('pdf')) {
      return Icons.picture_as_pdf;
    } else if (type.contains('jpg') || type.contains('jpeg') || type.contains('png')) {
      return Icons.image;
    } else if (type.contains('xls') || type.contains('xlsx') || type.contains('csv')) {
      return Icons.table_chart;
    } else if (type.contains('doc') || type.contains('docx') || type.contains('txt')) {
      return Icons.description;
    } else {
      return Icons.insert_drive_file;
    }
  }
}
