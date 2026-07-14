import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/global_app_bar.dart';
import '../providers/login_provider.dart';
import '../../core/constants/permission_constants.dart';
import '../providers/permissions_provider.dart';
import '../providers/service_provider.dart';
import '../../data/models/service_model.dart';
import '../widgets/access_denied_widget.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(servicesProvider.notifier).fetchServices();
    });
    _searchController.addListener(() {
        setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _showAddEditDialog({Service? service}) {
    showDialog(
      context: context, 
      builder: (ctx) => _ServiceDialog(service: service)
    );
  }

  void _confirmDelete(Service service) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
            title: const Text("Delete Service?"),
            content: Text("Are you sure you want to delete '${service.name}'?"),
            actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
                TextButton(
                    onPressed: () {
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        ref.read(servicesProvider.notifier).deleteService(service.id).then((_) {
                           if (mounted) scaffoldMessenger.showSnackBar(const SnackBar(content: Text("Service deleted")));
                        }).catchError((e) {
                           if (mounted) scaffoldMessenger.showSnackBar(SnackBar(content: Text("Error: $e")));
                        });
                    }, 
                    child: const Text("DELETE", style: TextStyle(color: Colors.red))
                ),
            ],
        )
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final permissions = ref.watch(permissionsProvider);
    final user = ref.watch(loginProvider).user;
    if (!permissions.hasModule(PermissionModules.SERVICES, userRole: user?.systemRole) ||
        !permissions.hasPermission(PermissionModules.SERVICES_VIEW, userRole: user?.systemRole)) {
      return const Scaffold(

        appBar: GlobalAppBar(title: 'Services'),
        body: AccessDeniedWidget(
          sectionName: "Services",
          showAppBar: false,
        ),
      );
    }

    final state = ref.watch(servicesProvider);
    
    // Filter services
    final services = state.services.where((s) {
        return s.name.toLowerCase().contains(_searchQuery);
    }).toList();

    // Stats
    final total = state.services.length;
    final active = state.services.where((s) => s.active).length;
    final inactive = total - active;

    final displayName = user?.name ?? 'RS';
    final initials = displayName.trim().isNotEmpty
        ? displayName.trim().split(' ').map((s) => s[0]).take(2).join().toUpperCase()
        : 'RS';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: const GlobalAppBar(title: ''), // Custom title in body
      body: RefreshIndicator(
        onRefresh: () async => ref.read(servicesProvider.notifier).refresh(),
        child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Service Catalog",
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Manage your lending offerings",
                              style: TextStyle(
                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.blueAccent.withValues(alpha: 0.2) : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Stats Dashboard Gradient Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: isDark
                              ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B)]
                              : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'TOTAL SERVICES',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.6),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.baseline,
                                    textBaseline: TextBaseline.alphabetic,
                                    children: [
                                      Text(
                                        '$total',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 36,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'products',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.arrow_forward, size: 12, color: Colors.white.withValues(alpha: 0.9)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${total > 0 ? ((active / total) * 100).toInt() : 0}% live',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox(
                              height: 6,
                              width: double.infinity,
                              child: Row(
                                children: [
                                  if (active > 0)
                                    Expanded(
                                      flex: active,
                                      child: Container(color: const Color(0xFF6366F1)),
                                    ),
                                  if (inactive > 0)
                                    Expanded(
                                      flex: inactive,
                                      child: Container(color: const Color(0xFFF97316)),
                                    ),
                                  if (total == 0)
                                    Expanded(
                                      child: Container(color: Colors.white24),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF6366F1),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Active  $active',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 24),
                              Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFF97316),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Inactive  $inactive',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Catalog & Add Header
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            Text(
                              "Catalog",
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 22,
                              ),
                            ),
                            if (permissions.hasPermission(PermissionModules.SERVICES_CREATE, userRole: user?.systemRole))
                              GestureDetector(
                                onTap: () => _showAddEditDialog(),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.blueAccent : const Color(0xFF6366F1),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                                ),
                              ),
                        ],
                    ),
                    const SizedBox(height: 16),

                    // Search capsule
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          hintText: "Search services...",
                          hintStyle: TextStyle(
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: isDark ? Colors.grey[500] : Colors.grey[400],
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // List
                    if (state.isLoading && services.isEmpty)
                        const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                    else if (services.isEmpty)
                         Center(
                             child: Padding(
                                 padding: const EdgeInsets.all(40), 
                                 child: Column(
                                     children: [
                                         Icon(Icons.search_off, size: 48, color: Colors.grey[300]),
                                         const SizedBox(height: 12),
                                         Text("No services found", style: TextStyle(color: Colors.grey[500]))
                                     ],
                                 )
                             )
                         )
                    else
                        ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: services.length,
                            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                            itemBuilder: (ctx, i) {
                                final service = services[i];
                                final permissions = ref.watch(permissionsProvider);
                                final userRole = ref.watch(loginProvider).user?.systemRole;

                                return _ServiceItem(
                                   service: service,
                                   onToggle: permissions.hasPermission(PermissionModules.SERVICES_UPDATE, userRole: userRole)
                                       ? (val) => ref.read(servicesProvider.notifier).toggleServiceStatus(service)
                                       : null,
                                   onEdit: permissions.hasPermission(PermissionModules.SERVICES_UPDATE, userRole: userRole)
                                       ? () => _showAddEditDialog(service: service)
                                       : null,
                                   onDelete: permissions.hasPermission(PermissionModules.SERVICES_DELETE, userRole: userRole)
                                       ? () => _confirmDelete(service)
                                       : null,
                                );
                            },
                        ),
                     
                     const SizedBox(height: 40),
                ],
            ),
        ),
      ),
    );
  }
}



class _ServiceItem extends StatelessWidget {
    final Service service;
    final Function(bool)? onToggle;
    final VoidCallback? onEdit;
    final VoidCallback? onDelete;

    const _ServiceItem({required this.service, this.onToggle, this.onEdit, this.onDelete});

    @override
    Widget build(BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        // Custom icon mapping based on service name
        final nameLower = service.name.toLowerCase();
        IconData iconData = Icons.widgets_outlined;
        Color iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
        Color iconBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100]!;

        if (nameLower.contains('car') || nameLower.contains('vehicle')) {
          iconData = Icons.directions_car_outlined;
          iconColor = isDark ? Colors.blueAccent : const Color(0xFF2563EB);
          iconBg = isDark ? Colors.blueAccent.withValues(alpha: 0.2) : const Color(0xFFDBEAFE);
        } else if (nameLower.contains('home') || nameLower.contains('house') || nameLower.contains('property')) {
          iconData = Icons.home_outlined;
          iconColor = isDark ? Colors.greenAccent : const Color(0xFF16A34A);
          iconBg = isDark ? Colors.greenAccent.withValues(alpha: 0.2) : const Color(0xFFDCFCE7);
        } else if (nameLower.contains('personal') || nameLower.contains('business') || nameLower.contains('loan')) {
          iconData = Icons.business_center_outlined;
          iconColor = isDark ? Colors.purpleAccent : const Color(0xFF9333EA);
          iconBg = isDark ? Colors.purpleAccent.withValues(alpha: 0.2) : const Color(0xFFF3E8FF);
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
                            color: iconBg,
                            borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(iconData, color: iconColor, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        service.name, 
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold, 
                                          fontSize: 15,
                                          color: isDark ? Colors.white : Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: service.active
                                            ? (isDark ? Colors.green.withValues(alpha: 0.15) : const Color(0xFFDCFCE7))
                                            : (isDark ? Colors.orange.withValues(alpha: 0.15) : const Color(0xFFFFEDD5)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        service.active ? 'ACTIVE' : 'INACTIVE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: service.active
                                              ? (isDark ? Colors.greenAccent : const Color(0xFF15803D))
                                              : (isDark ? Colors.orangeAccent : const Color(0xFFC2410C)),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (service.description != null && service.description!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        service.description!, 
                                        maxLines: 1, 
                                        overflow: TextOverflow.ellipsis, 
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[400] : Colors.grey[500], 
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                            ],
                        ),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                        value: service.active,
                        onChanged: onToggle,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF6366F1),
                    ),
                    if (onEdit != null || onDelete != null)
                    PopupMenuButton(
                        icon: Icon(Icons.more_vert, color: Colors.grey[400], size: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        onSelected: (val) {
                            if (val == 'edit') onEdit?.call();
                            if (val == 'delete') onDelete?.call();
                        },
                        itemBuilder: (ctx) => [
                            if (onEdit != null)
                               const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 16), SizedBox(width: 8), Text("Edit")])),
                            if (onDelete != null)
                               const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 16), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                        ]
                    )
                ],
            ),
        );
    }
}

class _ServiceDialog extends ConsumerStatefulWidget {
    final Service? service;
    const _ServiceDialog({this.service});

    @override
    ConsumerState<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends ConsumerState<_ServiceDialog> {
    final _formKey = GlobalKey<FormState>();
    late TextEditingController _nameController;
    late TextEditingController _descController;
    bool _isLoading = false;

    @override
    void initState() {
        super.initState();
        _nameController = TextEditingController(text: widget.service?.name ?? '');
        _descController = TextEditingController(text: widget.service?.description ?? '');
    }

    Future<void> _submit() async {
        if (!_formKey.currentState!.validate()) return;
        setState(() => _isLoading = true);
        
        try {
            final data = {
                "name": _nameController.text.trim(),
                "description": _descController.text.trim(),
                "active": widget.service?.active ?? true
            };

            if (widget.service != null) {
                await ref.read(servicesProvider.notifier).updateService(widget.service!.id, data);
            } else {
                await ref.read(servicesProvider.notifier).createService(data);
            }
            if (mounted) Navigator.pop(context);
        } catch (e) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        } finally {
            if (mounted) setState(() => _isLoading = false);
        }
    }

    @override
    Widget build(BuildContext context) {
        return Dialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(widget.service != null ? "Edit Service" : "Add New Service", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        Form(
                            key: _formKey,
                            child: Column(
                                children: [
                                    TextFormField(
                                        controller: _nameController,
                                        validator: (v) => v!.isEmpty ? 'Required' : null,
                                        decoration: InputDecoration(
                                            labelText: "Service Name",
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            filled: true,
                                            fillColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5)
                                        ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                        controller: _descController,
                                        maxLines: 3,
                                        decoration: InputDecoration(
                                            labelText: "Description (Optional)",
                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                            filled: true,
                                            fillColor: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.5),
                                            alignLabelWithHint: true
                                        ),
                                    ),
                                ],
                            ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                                onPressed: _isLoading ? null : _submit,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).brightness == Brightness.dark ? Colors.blueAccent : Colors.black,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                child: _isLoading 
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                    : Text(widget.service != null ? "UPDATE SERVICE" : "CREATE SERVICE", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                        )
                    ],
                ),
            ),
        );
    }
}
