import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/property_service.dart';
import '../../data/models/lead_model.dart';
import '../../data/models/property_model.dart';
import '../providers/lead_provider.dart';
import '../providers/login_provider.dart';
import '../providers/whatsapp_provider.dart';
import 'match_property_details_screen.dart';
import 'whatsapp/whatsapp_share_screen.dart';

class MatchingPropertiesScreen extends ConsumerStatefulWidget {
  final Lead lead;

  const MatchingPropertiesScreen({
    super.key,
    required this.lead,
  });

  @override
  ConsumerState<MatchingPropertiesScreen> createState() => _MatchingPropertiesScreenState();
}

class _MatchingPropertiesScreenState extends ConsumerState<MatchingPropertiesScreen> {
  final PropertyService _propertyService = PropertyService();
  
  List<Property> _properties = [];
  final Set<String> _selectedPropertyIds = {};
  bool _isLoading = true;
  String? _error;

  // CRM direct send check state
  bool _isCheckingCrm = false;
  bool _canSendCrm = false;
  String? _crmCheckTooltip;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _fetchMatchingProperties();
    _checkCrmChatWindow();
  }

  Future<void> _fetchMatchingProperties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _propertyService.getMatchingProperties(widget.lead.id);
      if (mounted) {
        setState(() {
          _properties = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkCrmChatWindow() async {
    setState(() {
      _isCheckingCrm = true;
      _canSendCrm = false;
      _crmCheckTooltip = 'Checking CRM Window...';
      _conversationId = null;
    });

    try {
      final phone = widget.lead.phoneNo.replaceAll(RegExp(r'[^0-9]'), '').trim();
      if (phone.isEmpty) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Lead phone number is invalid';
        });
        return;
      }

      final waService = ref.read(whatsappServiceProvider);
      final convResp = await waService.getConversationByPhone(phone);
      
      if (convResp['success'] != true || convResp['data'] == null) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'No active conversation history found to determine window';
        });
        return;
      }

      final convData = convResp['data'];
      final convId = convData['_id']?.toString() ?? convData['id']?.toString();
      if (convId == null || convId.isEmpty) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'No active conversation history found to determine window';
        });
        return;
      }

      final lastMsgResp = await waService.getLastInboundMessage(convId);
      if (lastMsgResp['success'] != true || lastMsgResp['data'] == null) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Chat window closed. Meta requires the customer to message you first within 24 hours to send custom text.';
        });
        return;
      }

      final lastMsg = lastMsgResp['data'];
      final timestampStr = lastMsg['timestamp']?.toString();
      if (timestampStr == null) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Chat window closed. Meta requires the customer to message you first within 24 hours to send custom text.';
        });
        return;
      }

      final lastInboundTime = DateTime.parse(timestampStr);
      final difference = DateTime.now().toUtc().difference(lastInboundTime.toUtc());

      if (difference.inHours <= 24) {
        setState(() {
          _isCheckingCrm = false;
          _canSendCrm = true;
          _crmCheckTooltip = null;
          _conversationId = convId;
        });
      } else {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Chat window closed. Meta requires the customer to message you first within 24 hours to send custom text.';
        });
      }
    } catch (e) {
      debugPrint('[MatchingPropertiesScreen] CRM chat window check failed: $e');
      if (mounted) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Failed to verify conversation status: $e';
        });
      }
    }
  }

  String _generateMessageText(Lead lead) {
    final buffer = StringBuffer();
    buffer.writeln("Dear ${lead.name}, Here are matching properties as per your requirements: -\n");
    
    int index = 1;
    final selectedProps = _properties.where((p) => _selectedPropertyIds.contains(p.id)).toList();
    
    for (final p in selectedProps) {
      buffer.writeln("*Property $index*");
      buffer.writeln("- Name: ${p.name}");
      buffer.writeln("- Type: ${p.propertyType} | ${p.bedrooms ?? 0} BHK");
      if (p.location != null) {
        final address = [p.location?.address1, p.location?.address2, p.location?.city].where((s) => s != null && s.isNotEmpty).join(', ');
        if (p.location?.lat != null && p.location!.lat != 0) {
          buffer.writeln("- Location: $address (https://maps.google.com/?q=${p.location!.lat},${p.location!.lng})");
        } else {
          buffer.writeln("- Location: $address");
        }
      }
      final priceStr = p.listingType.toLowerCase() == 'rent' ? '₹${p.price.toInt()}/mo' : '₹${p.price.toInt()}';
      buffer.writeln("- Price: $priceStr");
      buffer.writeln("- Details: https://trevion.browndevs.com/public/properties/${p.id}");
      buffer.writeln("_____________________________\n");
      index++;
    }
    
    final companyName = ref.read(loginProvider).user?.companyDetails?.name ?? 'Trevion CRM';
    buffer.writeln("Regards, $companyName. Reply to this message for any further info.");
    return buffer.toString();
  }

  Future<void> _sendDirectCrmMessage(Lead lead) async {
    if (!_canSendCrm || _conversationId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final phone = lead.phoneNo.replaceAll(RegExp(r'[^0-9]'), '').trim();
      final text = _generateMessageText(lead);
      final body = {
        'waId': phone,
        'conversationId': _conversationId,
        'type': 'text',
        'message': text,
      };

      final response = await ref.read(whatsappServiceProvider).sendMessage(body);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Properties shared successfully via WhatsApp CRM!')),
          );
          Navigator.pop(context);
        } else {
          throw response['message'] ?? 'Failed to send message via CRM';
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CRM Sending Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  List<Widget> _buildFilterTags(Lead lead) {
    final list = <Widget>[];
    final req = lead.requirements?.realEstate;
    
    final budgetVal = (lead.travelBudget != null && lead.travelBudget!.isNotEmpty)
        ? lead.travelBudget!
        : (lead.amount > 0 ? '${lead.amount.toInt()}' : '');

    if (budgetVal.isNotEmpty) {
      final displayBudget = budgetVal.startsWith('₹') ? budgetVal : '₹$budgetVal';
      list.add(_buildFilterChip(displayBudget, const Color(0xFF10B981)));
    }
    if (req != null) {
      if (req.listingType.isNotEmpty) {
        list.add(_buildFilterChip(req.listingType, const Color(0xFFEF4444)));
      }
      if (req.category.isNotEmpty) {
        list.add(_buildFilterChip(req.category, const Color(0xFFF59E0B)));
      }
      if (req.propertyType.isNotEmpty) {
        list.add(_buildFilterChip(req.propertyType, const Color(0xFF2563EB)));
      }
      if (req.bhk.isNotEmpty) {
        list.add(_buildFilterChip('${req.bhk} BHK', const Color(0xFF8B5CF6)));
      }
      if (req.area != null && req.area!.value.isNotEmpty) {
        list.add(_buildFilterChip('${req.area!.value} ${req.area!.unit}', const Color(0xFF06B6D4)));
      }
      if (req.preferredArea.isNotEmpty) {
        list.add(_buildFilterChip(req.preferredArea, const Color(0xFF6B7280)));
      }
    }
    return list;
  }

  Widget _buildFilterChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final detailState = ref.watch(leadDetailProvider);
    final lead = detailState.lead ?? widget.lead;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              'Matching Properties',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: _fetchMatchingProperties,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: isDark ? Colors.white30 : Colors.black26),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Refresh',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF151722) : Colors.white,
        elevation: 0.5,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: Stack(
        children: [
          // Main content containing scrollable filters box and properties grid
          Positioned.fill(
            child: _buildMainContent(isDark, lead),
          ),
          
          // Bottom Share Bar
          if (_selectedPropertyIds.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomActionBar(isDark, theme, lead),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(bool isDark, Lead lead) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Failed to load properties',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchMatchingProperties,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_properties.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              'No properties match the lead requirements',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 600 ? 2 : 1);
        
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: _selectedPropertyIds.isNotEmpty ? 100 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Filters tag list (takes full width, scrollable horizontally)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E334B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'FILTERS:',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _buildFilterTags(lead),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Row 2: matched count and Select All checkbox
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2E334B) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.grey[300]!,
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_properties.length} matched',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Select All (Max 10)',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Checkbox(
                          value: _properties.isNotEmpty &&
                              _selectedPropertyIds.length == (_properties.length > 10 ? 10 : _properties.length),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPropertyIds.clear();
                                final limit = _properties.length > 10 ? 10 : _properties.length;
                                for (int i = 0; i < limit; i++) {
                                  _selectedPropertyIds.add(_properties[i].id);
                                }
                              } else {
                                _selectedPropertyIds.clear();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Properties Grid View (using Wrap for dynamic height cards)
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: _properties.map((p) {
                  final cardWidth = (constraints.maxWidth - 32 - (cols - 1) * 16) / cols;
                  return SizedBox(
                    width: cardWidth,
                    child: _buildPropertyCard(p, isDark),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPropertyCard(Property p, bool isDark) {
    final isSelected = _selectedPropertyIds.contains(p.id);
    
    // Details RichText bullet dots
    final detailList = <String>[];
    if (p.propertyType.isNotEmpty) detailList.add(p.propertyType);
    if (p.area != null && p.area!.value > 0) {
      detailList.add('${p.area!.value.toInt()} ${p.area!.unit}');
    }
    if (p.bedrooms != null && p.bedrooms! > 0) {
      detailList.add('${p.bedrooms} BHK');
    } else if (p.builtUp) {
      detailList.add('Built Up');
    }

    final separator = TextSpan(
      text: '  •  ',
      style: TextStyle(color: isDark ? Colors.white30 : Colors.grey[400]),
    );

    final spans = <TextSpan>[];
    for (int i = 0; i < detailList.length; i++) {
      spans.add(TextSpan(
        text: detailList[i],
        style: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: isDark ? Colors.white70 : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ));
      spans.add(separator);
    }

    final priceStr = p.listingType.toLowerCase() == 'rent' ? '₹${p.price.toInt()}/mo' : '₹${p.price.toInt()}';
    spans.add(TextSpan(
      text: priceStr,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: const Color(0xFF10B981),
        fontWeight: FontWeight.bold,
      ),
    ));

    final fullAddress = p.location != null
        ? [p.location!.address1, p.location!.address2, p.location!.city].where((s) => s.isNotEmpty).join(', ').trim()
        : '';

    // Helper for Badge Colors
    Color getListingTypeColor(String type) {
      return type.toLowerCase() == 'rent' ? const Color(0xFF0F766E) : const Color(0xFFEA580C);
    }

    Color getStatusColor(String status) {
      final s = status.toLowerCase();
      if (s.contains('ready') || s.contains('available') || s == 'rented') {
        return const Color(0xFF16A34A);
      }
      return const Color(0xFF2563EB);
    }

    Color getCategoryColor(String cat) {
      final c = cat.toLowerCase();
      if (c.contains('res')) return const Color(0xFF7C3AED);
      if (c.contains('comm')) return const Color(0xFF4F46E5);
      if (c.contains('land')) return const Color(0xFFB45309);
      return const Color(0xFF6D28D9);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MatchPropertyDetailsScreen(
              property: p,
              title: p.name,
              subtitle: '${p.propertyType} • ${p.listingType}',
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2E334B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : (isDark ? Colors.white24 : const Color(0xFFCCCCCC)),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 10, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Property Name, Eye, Checkbox
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    p.name,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.visibility_outlined,
                    size: 22,
                    color: isDark ? Colors.white70 : Colors.grey[500],
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MatchPropertyDetailsScreen(
                          property: p,
                          title: p.name,
                          subtitle: '${p.propertyType} • ${p.listingType}',
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(width: 12),
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        if (_selectedPropertyIds.length >= 10) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Cannot select more than 10 properties')),
                          );
                          return;
                        }
                        _selectedPropertyIds.add(p.id);
                      } else {
                        _selectedPropertyIds.remove(p.id);
                      }
                    });
                  },
                ),
              ),
            ],
          ),

          // Project Subtitle
          if (p.project != null)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'Project: ${p.project?.name}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: const Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          const SizedBox(height: 6),

          // Specs RichText line with green price at end
          RichText(
            text: TextSpan(children: spans),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 6),

          // Outlined Badges Row (transparent background, clear colored border)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              _buildBadgeChip(p.listingType.toUpperCase(), getListingTypeColor(p.listingType)),
              _buildBadgeChip(p.status.replaceAll('_', ' ').toUpperCase(), getStatusColor(p.status)),
              _buildBadgeChip(p.category.toUpperCase(), getCategoryColor(p.category)),
              if (p.listingType.toLowerCase() == 'rent' && p.allowedTenants != null && p.allowedTenants!.isNotEmpty)
                _buildBadgeChip(p.allowedTenants!.toUpperCase(), const Color(0xFF4B5563)),
            ],
          ),
          
          // Location Row (only render if location is available)
          if (fullAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: isDark ? Colors.white38 : Colors.grey[500]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fullAddress,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 8),

          // Footer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  final uri = Uri.parse('https://trevion.browndevs.com/public/properties/${p.id}');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                child: Row(
                  children: [
                    Text(
                      'Public View',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: const Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF2563EB)),
                    ),
                  ],
                ),
              ),
              if (p.ownerName != null)
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: isDark ? Colors.white54 : Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      p.ownerName!,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

  Widget _buildBadgeChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildBottomActionBar(bool isDark, ThemeData theme, Lead lead) {
    final count = _selectedPropertyIds.length;
    
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: "X selected" and "Clear" link
            Row(
              children: [
                Text(
                  '$count selected',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPropertyIds.clear();
                    });
                  },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2563EB),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            
            // Right: Green "Share on WhatsApp" Button
            ElevatedButton.icon(
              onPressed: () {
                final msgText = _generateMessageText(lead);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WhatsAppShareScreen(
                      initialMessage: msgText,
                      preselectedLead: lead,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.share, color: Colors.white, size: 18),
              label: Text(
                'Share on WhatsApp',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E), // WhatsApp Green
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
