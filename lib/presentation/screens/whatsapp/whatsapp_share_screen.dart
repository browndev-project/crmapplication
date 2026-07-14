import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../data/models/lead_model.dart';
import '../../providers/permissions_provider.dart';
import '../../providers/login_provider.dart';
import '../../providers/lead_provider.dart';
import '../../providers/whatsapp_provider.dart';
import 'widgets/active_chat_area.dart';
import 'widgets/whatsapp_icon.dart'; // Ensure GlobalAppBar is available or use standard AppBar

class WhatsAppShareScreen extends ConsumerStatefulWidget {
  final String initialMessage;
  final Lead? preselectedLead;

  const WhatsAppShareScreen({
    super.key,
    required this.initialMessage,
    this.preselectedLead,
  });

  @override
  ConsumerState<WhatsAppShareScreen> createState() => _WhatsAppShareScreenState();
}

class _WhatsAppShareScreenState extends ConsumerState<WhatsAppShareScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _messageController;
  late TabController _tabController;
  final ScrollController _crmScrollController = ScrollController();

  bool _isCrmVisible = false;
  Lead? _selectedLead;

  // Search controller for Leads
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialMessage);
    _tabController = TabController(length: 2, vsync: this);

    _selectedLead = widget.preselectedLead;

    // Load leads for CRM tab
    Future.microtask(() {
      final perms = ref.read(permissionsProvider);
      final userRole = ref.read(loginProvider).user?.systemRole;

      final hasInt = perms.hasModule('modules.integration', userRole: userRole);
      final hasWa = perms.hasModule('modules.whatsapp', userRole: userRole);
      final hasAdmin = userRole == 'company_admin' || userRole == 'company';

      if (hasAdmin || (hasInt && hasWa)) {
        setState(() {
          _isCrmVisible = true;
        });
        // Removed _tabController.index = 1; to ensure Message tab opens automatically
        ref.read(leadsProvider.notifier).fetchLeads(page: 1, isRefresh: true);
        ref.read(whatsappChatsProvider.notifier).fetchConversations(clearCache: true).then((_) {
          if (widget.preselectedLead != null) {
            _selectLead(widget.preselectedLead!);
          }
        });
        ref.read(whatsappMessagesProvider.notifier).clearCache();
      }
    });

    _crmScrollController.addListener(() {
      if (_crmScrollController.position.pixels >= _crmScrollController.position.maxScrollExtent - 200) {
        ref.read(leadsProvider.notifier).loadMore();
      }
    });

    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        FocusScope.of(context).unfocus();
      } else {
        if (_tabController.index == 1) {
          ref.read(leadsProvider.notifier).refresh();
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _crmScrollController.dispose();
    super.dispose();
  }

  Future<void> _launchWhatsApp() async {
    final text = Uri.encodeComponent(_messageController.text);
    final urlStr = kIsWeb ? 'https://wa.me/?text=$text' : 'whatsapp://send?text=$text';
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback
        await launchUrl(Uri.parse('https://wa.me/?text=$text'),
            mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch WhatsApp: $e');
    }
  }

  void _copyMessage() {
    Clipboard.setData(ClipboardData(text: _messageController.text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message copied to clipboard')),
    );
  }

  void _selectLead(Lead lead) {
    setState(() {
      _selectedLead = lead;
    });

    // Check if we have an existing conversation for this lead
    final chatsState = ref.read(whatsappChatsProvider);
    final phone = lead.phoneNo.replaceAll(RegExp(r'[^0-9]'), '').trim();
    
    String? convId;
    try {
      final existingConv = chatsState.conversations.firstWhere((c) {
        final cPhone = (c['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '').trim();
        final cWaId = (c['waId'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '').trim();
        
        // Match if one ends with the other (e.g., 919876543210 vs 9876543210)
        bool matches = false;
        if (cPhone.isNotEmpty && phone.isNotEmpty) {
          matches = cPhone.endsWith(phone) || phone.endsWith(cPhone);
        }
        if (!matches && cWaId.isNotEmpty && phone.isNotEmpty) {
          matches = cWaId.endsWith(phone) || phone.endsWith(cWaId);
        }
        return matches;
      });
      convId = (existingConv['id'] ?? existingConv['_id'])?.toString();
    } catch (e) {
      convId = null;
    }

    if (convId != null) {
      ref.read(whatsappChatsProvider.notifier).selectConversation(convId);
      ref.read(whatsappMessagesProvider.notifier).fetchMessages(convId);
    } else {
      // Simulate new conversation
      final dummyConvId = 'new_${lead.id}';
      ref.read(whatsappChatsProvider.notifier).selectConversation(dummyConvId);
      ref.read(whatsappMessagesProvider.notifier).clearMessages(dummyConvId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
      appBar: AppBar(
        title: Text(
          "Share via WhatsApp",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: isDesktop
          ? _buildDesktopLayout(isDark)
          : _buildMobileLayout(isDark),
    );
  }

  Widget _buildDesktopLayout(bool isDark) {
    if (!_isCrmVisible) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildMessageFlow(isDark),
        ),
      );
    }
    return Row(
      children: [
        // Left: Message
        Expanded(
          flex: 1,
          child: _buildMessageFlow(isDark),
        ),
        VerticalDivider(width: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),
        // Right: CRM
        Expanded(
          flex: 1,
          child: _buildCrmFlow(isDark),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    if (!_isCrmVisible) {
      return _buildMessageFlow(isDark);
    }
    return Column(
      children: [
        Container(
          color: isDark ? const Color(0xFF1E2130) : Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: "Message"),
              Tab(text: "CRM"),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildMessageFlow(isDark),
              _buildCrmFlow(isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageFlow(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "WHATSAPP MESSAGE PREVIEW",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Edit before sharing. Sent as-is via Web or copied to CRM.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D324A) : Colors.grey.shade50,
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black, width: 1.2),
                  ),
                  child: TextField(
                    controller: _messageController,
                    maxLines: 15,
                    minLines: 10,
                    textAlignVertical: TextAlignVertical.top,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13, 
                      height: 1.5, 
                      color: isDark ? Colors.white : Colors.black87
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "${_messageController.text.length} chars",
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            border: Border(
              top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyMessage,
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text("Copy Message", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _launchWhatsApp,
                    icon: whatsAppIcon(size: 18, color: Colors.white),
                    label: const Text("Send on WhatsApp", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCrmFlow(bool isDark) {
    if (_selectedLead == null) {
      return _buildLeadList(isDark);
    } else {
      return _buildChatArea(isDark);
    }
  }

  Widget _buildLeadList(bool isDark) {
    final leadsState = ref.watch(leadsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
               ref.read(leadsProvider.notifier).applyFilters({'search': val});
            },
            decoration: InputDecoration(
              hintText: 'Search leads by name or phone...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? const Color(0xFF2D324A) : Colors.grey.shade100,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: leadsState.leads.isEmpty && leadsState.isLoading
              ? const Center(child: CircularProgressIndicator())
              : leadsState.leads.isEmpty
                  ? const Center(child: Text("No leads found."))
                  : ListView.builder(
                      controller: _crmScrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: leadsState.leads.length + (leadsState.isLoading ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == leadsState.leads.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final lead = leadsState.leads[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                            boxShadow: isDark ? null : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () => _selectLead(lead),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isDark ? const Color(0xFF202334) : Colors.blue.shade50,
                                    radius: 22,
                                    child: Text(
                                      lead.name.isNotEmpty ? lead.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          lead.name,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600, 
                                            fontSize: 15,
                                            color: isDark ? Colors.white : Colors.grey.shade900,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          lead.phoneNo,
                                          style: TextStyle(
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF25D366).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        whatsAppIcon(size: 16, color: const Color(0xFF1DA851)),
                                        const SizedBox(width: 6),
                                        const Text(
                                          "Chat",
                                          style: TextStyle(
                                            color: Color(0xFF1DA851),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildChatArea(bool isDark) {
    final chatsState = ref.watch(whatsappChatsProvider);
    final convId = chatsState.selectedConversationId ?? 'new_${_selectedLead!.id}';

    Map<String, dynamic> conversation = {};
    try {
      conversation = chatsState.conversations.firstWhere((c) => c['id'] == convId);
    } catch (e) {
      // Dummy conversation for new leads
      conversation = {
        'waId': _selectedLead!.phoneNo.replaceAll('+', '').trim(),
        'phone': _selectedLead!.phoneNo,
        'leads': [
          {'name': _selectedLead!.name}
        ]
      };
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ActiveChatArea(
        conversationId: convId,
        conversation: conversation,
        onBack: () {
          setState(() {
            _selectedLead = null;
          });
          ref.read(whatsappChatsProvider.notifier).selectConversation(null);
        },
      ),
    );
  }
}
