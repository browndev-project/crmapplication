import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../providers/whatsapp_provider.dart';
import 'widgets/active_chat_area.dart';
import '../../providers/navigation_provider.dart';
import '../../widgets/global_app_bar.dart';
import 'widgets/whatsapp_icon.dart';
import 'whatsapp_permission_guard.dart';
import '../lead_profile_screen.dart';
import '../../../core/services/whatsapp_state_tracker.dart';

class WhatsAppChatsScreen extends ConsumerStatefulWidget {
  final String? initialConversationId;
  const WhatsAppChatsScreen({super.key, this.initialConversationId});

  @override
  ConsumerState<WhatsAppChatsScreen> createState() => _WhatsAppChatsScreenState();
}

class _WhatsAppChatsScreenState extends ConsumerState<WhatsAppChatsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _mobileSelectedConvId;
  bool _hasHandledInitialNavigation = false;

  late final StateController<BackHandler?> _backHandlerController;

  @override
  void initState() {
    super.initState();
    WhatsAppStateTracker.isScreenOpen = true;
    _backHandlerController = ref.read(backHandlerProvider.notifier);
    _searchController.addListener(() {
      setState(() {});
    });
    Future.microtask(() {
      ref.read(whatsappChatsProvider.notifier).fetchConversations(clearCache: true);
      ref.read(whatsappMessagesProvider.notifier).clearCache();
      ref.read(whatsappTemplatesProvider.notifier).fetchTemplates();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasHandledInitialNavigation) {
      _hasHandledInitialNavigation = true;
      final pendingId = widget.initialConversationId ?? WhatsAppStateTracker.pendingConversationId;
      if (pendingId != null && pendingId.isNotEmpty) {
        WhatsAppStateTracker.pendingConversationId = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _openConversation(pendingId);
        });
      }
    }
  }

  void _openConversation(String convId) {
    final chatsState = ref.read(whatsappChatsProvider);
    final exists = chatsState.conversations.any((c) => (c['id'] ?? c['_id']).toString() == convId);
    if (!exists) return;

    if (MediaQuery.of(context).size.width > 800) {
      ref.read(whatsappChatsProvider.notifier).selectConversation(convId);
      ref.read(whatsappMessagesProvider.notifier).fetchMessages(convId);
    } else {
      setState(() => _mobileSelectedConvId = convId);
      ref.read(whatsappChatsProvider.notifier).selectConversation(convId);
      ref.read(whatsappMessagesProvider.notifier).fetchMessages(convId);
    }
  }

  @override
  void dispose() {
    WhatsAppStateTracker.isScreenOpen = false;
    WhatsAppStateTracker.activeConversationId = null;
    _backHandlerController.state = null;
    _searchController.dispose();
    super.dispose();
  }

  void _syncSearchFromProvider() {
    final query = ref.read(whatsappChatsProvider).searchQuery;
    if (_searchController.text != query) {
      _searchController.text = query;
      _searchController.selection = TextSelection.fromPosition(
        TextPosition(offset: query.length),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final chatsState = ref.watch(whatsappChatsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter conversations based on search
    final filteredConversations = chatsState.conversations.where((conv) {
      final phone = (conv['phone'] ?? '').toString().toLowerCase();
      
      String extractedName = '';
      final leadsList = conv['leads'] as List?;
      if (leadsList != null && leadsList.isNotEmpty) {
        final firstLead = leadsList[0];
        if (firstLead is Map) {
          extractedName = (firstLead['name'] ?? '').toString();
        }
      }
      
      final name = extractedName.toLowerCase();
      final query = chatsState.searchQuery.toLowerCase();
      return phone.contains(query) || name.contains(query);
    }).toList();

    // Guard chats access
    return WhatsAppPermissionGuard(
      requiredModules: const ['modules.integration', 'modules.whatsapp'],
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: const GlobalAppBar(title: 'WhatsApp Chats'),

        body: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;

            if (isDesktop) {
              // --- DESKTOP LAYOUT ---
              return Row(
                children: [
                  // Left Pane (Conversations list)
                  SizedBox(
                    width: 320,
                    child: _buildConversationsList(
                      context,
                      isDark,
                      filteredConversations,
                      chatsState.selectedConversationId,
                      (convId) {
                        ref.read(whatsappChatsProvider.notifier).selectConversation(convId);
                        ref.read(whatsappMessagesProvider.notifier).fetchMessages(convId);
                      },
                      isLoading: chatsState.isLoading,
                      error: chatsState.error,
                    ),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                  ),
                  // Right Pane (Active Chat Details)
                  Expanded(
                    child: chatsState.selectedConversationId == null
                        ? _buildNoConversationSelected(context, isDark)
                        : ActiveChatArea(
                            conversationId: chatsState.selectedConversationId!,
                            conversation: filteredConversations.firstWhere(
                              (c) => c['id'] == chatsState.selectedConversationId,
                              orElse: () => {},
                            ),
                          ),
                  ),
                ],
              );
            } else {
              // --- MOBILE LAYOUT ---
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                ref.read(backHandlerProvider.notifier).state = _mobileSelectedConvId != null
                    ? () {
                        if (_mobileSelectedConvId != null) {
                          setState(() => _mobileSelectedConvId = null);
                          ref.read(whatsappChatsProvider.notifier).selectConversation(null);
                          return true;
                        }
                        return false;
                      }
                    : null;
              });
              if (_mobileSelectedConvId != null) {
                // Render single Active Chat window
                final activeConv = chatsState.conversations.firstWhere(
                  (c) => c['id'] == _mobileSelectedConvId,
                  orElse: () => {},
                );
                return PopScope(
                  canPop: _mobileSelectedConvId == null,
                  onPopInvokedWithResult: (bool didPop, Object? result) {
                    if (!didPop && _mobileSelectedConvId != null) {
                      setState(() => _mobileSelectedConvId = null);
                      ref.read(whatsappChatsProvider.notifier).selectConversation(null);
                    }
                  },
                  child: ActiveChatArea(
                    conversationId: _mobileSelectedConvId!,
                    conversation: activeConv,
                    onBack: () {
                      setState(() => _mobileSelectedConvId = null);
                      ref.read(whatsappChatsProvider.notifier).selectConversation(null);
                    },
                  ),
                );
              } else {
                // Sync search controller with provider when returning from chat
                _syncSearchFromProvider();
                // Render Conversations list
                return _buildConversationsList(
                  context,
                  isDark,
                  filteredConversations,
                  null,
                  (convId) {
                    setState(() => _mobileSelectedConvId = convId);
                    ref.read(whatsappChatsProvider.notifier).selectConversation(convId);
                    ref.read(whatsappMessagesProvider.notifier).fetchMessages(convId);
                  },
                  isLoading: chatsState.isLoading,
                  error: chatsState.error,
                );
              }
            }
          },
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildConversationsList(
    BuildContext context,
    bool isDark,
    List<Map<String, dynamic>> conversations,
    String? selectedId,
    Function(String) onSelect, {
    bool isLoading = false,
    String? error,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search & Header
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  whatsAppIcon(size: 24, color: const Color(0xFF25D366)),
                  const SizedBox(width: 8),
                  Text(
                    "WhatsApp",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: (val) {
                  ref.read(whatsappChatsProvider.notifier).setSearchQuery(val);
                },
                decoration: InputDecoration(
                  hintText: 'Search leads or phones...',
                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                  prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey[500]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close, size: 18, color: Colors.grey[500]),
                          onPressed: () {
                            _searchController.clear();
                            ref.read(whatsappChatsProvider.notifier).setSearchQuery('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2130) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: isDark ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: isDark ? BorderSide.none : BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : error != null
                  ? _buildErrorState(context, isDark, error)
                  : conversations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              whatsAppIcon(size: 40, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Text(
                                "No conversations",
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: conversations.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: isDark ? Colors.white10 : Colors.grey.shade300),
                  itemBuilder: (context, index) {
                    final conv = conversations[index];
                    final String id = (conv['id'] ?? conv['_id'] ?? '').toString();
                    final String phone = conv['phone'] ?? '';
                    final leadsList = conv['leads'] as List? ?? [];
                    
                    final String lastMessage = (conv['lastMessage'] ?? 'No messages').toString();
                    final int unread = int.tryParse(conv['unreadCount'].toString()) ?? 0;
                    
                    String timeStr = '';
                    if (conv['lastMessageAt'] != null) {
                      try {
                        final dt = DateTime.parse(conv['lastMessageAt'].toString()).toLocal();
                        timeStr = DateFormat('hh:mm a').format(dt);
                      } catch (_) {}
                    }

                    final isSelected = id == selectedId;

                    return InkWell(
                      onTap: () => onSelect(id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: isSelected
                            ? (isDark ? const Color(0xFF2D324A) : Colors.blue.shade50)
                            : (isDark ? Colors.transparent : Colors.white),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isDark
                                  ? const Color(0xFF2A2D3E)
                                  : const Color(0xFFF0F2F5),
                              child: Text(
                                phone.isNotEmpty ? phone[0] : '#',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 18,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          phone,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF202124),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (timeStr.isNotEmpty)
                                        Text(
                                          timeStr,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.white54 : const Color(0xFF5F6368),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (leadsList.isNotEmpty)
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        ...leadsList.take(3).map((lead) {
                                          return GestureDetector(
                                            onTap: () {
                                              final String leadIdForProfile = (lead['_id'] ?? lead['id'] ?? '').toString();
                                              if (leadIdForProfile.isNotEmpty) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => LeadProfileScreen(
                                                      leadId: leadIdForProfile,
                                                      name: (lead['name'] ?? 'Unknown').toString(),
                                                      phone: phone,
                                                      details: 'Navigated from WhatsApp Chat',
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF333646) : const Color(0xFFF1F3F4),
                                                borderRadius: BorderRadius.circular(16),
                                              ),
                                              child: Text(
                                                (lead['name'] ?? 'Unknown').toString(),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.white70 : const Color(0xFF3C4043),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          );
                                        }),
                                        if (leadsList.length > 3)
                                          Text(
                                            '+${leadsList.length - 3} more',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              color: isDark ? Colors.white54 : const Color(0xFF5F6368),
                                            ),
                                          ),
                                      ],
                                    ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          lastMessage,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: unread > 0
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark ? Colors.white70 : const Color(0xFF4A4B4D)),
                                            fontWeight: unread > 0
                                                ? FontWeight.w700
                                                : FontWeight.w400,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (unread > 0)
                                        TweenAnimationBuilder<double>(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOutBack,
                                          tween: Tween<double>(begin: 0.0, end: 1.0),
                                          builder: (context, scale, child) {
                                            return Transform.scale(
                                              scale: scale,
                                              child: Container(
                                                margin: const EdgeInsets.only(left: 8),
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF25D366),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  unread.toString(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoConversationSelected(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          whatsAppIcon(size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            "Select a conversation",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Choose a lead from the sidebar list to start chatting.",
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
            "Failed to load conversations",
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
            onPressed: () => ref.read(whatsappChatsProvider.notifier).fetchConversations(),
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
