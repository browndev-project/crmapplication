import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/asset_service.dart';
import '../../../data/models/asset_model.dart';
import '../../widgets/global_app_bar.dart';
import '../../widgets/dashboard_stats_card.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/r2_service.dart';
import '../../providers/login_provider.dart';
import '../../providers/permissions_provider.dart';
import '../../../core/constants/permission_constants.dart';
import '../../widgets/access_denied_widget.dart';

class AssetsLibraryScreen extends ConsumerStatefulWidget {
  final bool isSelectionMode;
  final String? allowedType;
  const AssetsLibraryScreen({
    super.key,
    this.isSelectionMode = false,
    this.allowedType,
  });

  @override
  ConsumerState<AssetsLibraryScreen> createState() => _AssetsLibraryScreenState();
}

class _AssetsLibraryScreenState extends ConsumerState<AssetsLibraryScreen> {
  bool _isLoading = true;
  List<AssetModel> _assets = [];
  List<AssetModel> _filteredAssets = [];
  final TextEditingController _searchController = TextEditingController();

  // Stats
  double get _totalSize => _assets.fold(0, (sum, item) => sum + item.size);

  @override
  void initState() {
    super.initState();
    _fetchAssets();
  }

  Future<void> _fetchAssets() async {
    try {
      final assets = await ref.read(assetServiceProvider).fetchAssets();
      if (mounted) {
        setState(() {
          _assets = assets;
          _isLoading = false;
        });
        _filterAssets(_searchController.text);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAssets(String query) {
    setState(() {
      _filteredAssets = _assets.where((asset) {
        if (widget.allowedType != null) {
          final type = widget.allowedType!.toLowerCase();
          final fileType = asset.fileType.toLowerCase();
          if (type == 'image') {
            if (!fileType.contains('image')) return false;
          } else if (type == 'document') {
            final isDoc = fileType.contains('pdf') ||
                fileType.contains('document') ||
                fileType.contains('msword') ||
                fileType.contains('text') ||
                asset.name.toLowerCase().endsWith('.pdf') ||
                asset.name.toLowerCase().endsWith('.doc') ||
                asset.name.toLowerCase().endsWith('.docx');
            if (!isDoc) return false;
          }
        }
        final lowerQuery = query.toLowerCase();
        return asset.name.toLowerCase().contains(lowerQuery) ||
            asset.uploadedByName.toLowerCase().contains(lowerQuery);
      }).toList();
    });
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }



  Future<void> _confirmDelete(String assetId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Asset'),
            content: const Text(
                'Are you sure you want to delete this asset? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('CANCEL')),
              TextButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                      'DELETE', style: TextStyle(color: Colors.red))),
            ],
          ),
    );

    if (confirmed == true) {
      try {
        await ref.read(assetServiceProvider).deleteAsset(assetId);
        await _fetchAssets();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Asset deleted successfully'),
                  backgroundColor: Colors.green)
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete failed: $e'),
                  backgroundColor: Colors.red)
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = ref.watch(permissionsProvider);
    final userRole = ref.watch(loginProvider).user?.systemRole;

    final canView = permissions.can(
      PermissionModules.ASSETS,
      permission: PermissionModules.ASSETS_VIEW,
      userRole: userRole,
    );

    if (!canView) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Assets Library'),
        body: AccessDeniedWidget(
          sectionName: "Assets Library",
          showAppBar: false,
        ),
      );
    }

    final isDark = Theme
        .of(context)
        .brightness == Brightness.dark;

    return Scaffold(
      appBar: GlobalAppBar(
        title: widget.isSelectionMode ? 'Select Asset' : 'Assets Library',
        showBackButton: widget.isSelectionMode,
      ),
      backgroundColor: Theme
          .of(context)
          .scaffoldBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _fetchAssets,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats Section
            Column(
              children: [
                DashboardStatsCard(
                    title: 'Total Assets',
                    value: _assets.length.toString(),
                    icon: Icons.folder,
                    backgroundColor: const Color(0xFF1F2937),
                    gradientColors: const [Color(0xFF1F2937), Color(0xFF111827)]
                ),
                const SizedBox(height: 8),
                DashboardStatsCard(
                    title: 'Total Size',
                    value: _formatSize(_totalSize.toInt()),
                    icon: Icons.storage,
                    backgroundColor: Colors.teal,
                    gradientColors: const [Colors.teal, Colors.tealAccent]
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Controls & Upload
            Column(
              children: [
                /*
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showUploadDialog,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text("UPLOAD ASSET"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.blueAccent : Colors
                            .black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                ),
                */
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterAssets,
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: 'Search...',
                          hintStyle: TextStyle(color: isDark
                              ? Colors.grey[500]
                              : Colors.grey),
                          prefixIcon: Icon(Icons.search, color: isDark ? Colors
                              .grey[500] : Colors.grey),
                          filled: true,
                          fillColor: Theme
                              .of(context)
                              .cardColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1))
                          ),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Theme
                                  .of(context)
                                  .dividerColor
                                  .withValues(alpha:0.1))
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // List Header (Title)
            Text("Recent Uploads", style: TextStyle(fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.grey[800])),
            const SizedBox(height: 12),

            // Assets List (Cards for Mobile/Desktop unified style)
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator()))
            else
              if (_filteredAssets.isEmpty)
                Center(child: Padding(padding: const EdgeInsets.all(40),
                    child: Text("No assets found",
                        style: TextStyle(color: Colors.grey[500]))))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredAssets.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final asset = _filteredAssets[index];
                    return _buildAssetCard(asset, isDark);
                  },
                )
          ],
        ),
       ),
      ),
    );
  }

  Widget _buildAssetCard(AssetModel asset, bool isDark) {
    final isPdf = asset.fileType.contains('pdf');
    return InkWell(
      onTap: widget.isSelectionMode
          ? () {
              final url = '${R2Service.publicBaseUrl}/${Uri.encodeFull(asset.r2Key)}';
              Navigator.pop(context, url);
            }
          : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme
              .of(context)
              .cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme
              .of(context)
              .dividerColor
              .withValues(alpha:0.1)),
        ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isPdf ? Colors.red : Colors.blue).withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isPdf ? Icons.picture_as_pdf : Icons.image,
              color: isPdf ? Colors.red : Colors.blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.name,
                  style: TextStyle(fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // Meta Row
                Row(
                  children: [
                    Text(_formatSize(asset.size), style: TextStyle(
                        fontSize: 11, color: Colors.grey[500])),
                    const SizedBox(width: 8),
                    Container(width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                            color: Colors.grey[isDark ? 600 : 300],
                            shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(asset.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha:0.05) : Colors
                          .grey[100],
                      borderRadius: BorderRadius.circular(6)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_outline, size: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(child: Text(asset.uploadedByName,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight
                              .bold, color: isDark ? Colors.grey[300] : Colors
                              .black87), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                )
              ],
            ),
          ),
          // Actions
          Column(
            children: [
              IconButton(
                icon: Icon(Icons.download_rounded,
                    color: isDark ? Colors.grey[300] : Colors.black87),
                onPressed: () async {
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    // Properly encode the key to handle spaces and special characters
                    final url = Uri.parse('${R2Service.publicBaseUrl}/${Uri.encodeFull(asset.r2Key)}');
                    if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                    } else {
                        if (mounted) {
                            scaffoldMessenger.showSnackBar(
                                const SnackBar(content: Text('Could not open download link'))
                            );
                        }
                    }
                },
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 12),
              IconButton(
                icon: Icon(
                    Icons.delete_outline, color: Colors.red[isDark ? 400 : 300],
                    size: 20),
                onPressed: () => _confirmDelete(asset.id),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          )
        ],
      ),
      ),
    );
  }
}