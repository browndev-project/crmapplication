import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../data/models/lead_model.dart';
import '../../../providers/whatsapp_provider.dart';
import 'active_chat_area.dart';
import 'whatsapp_icon.dart';

class WhatsAppChatPanel extends ConsumerStatefulWidget {
  final Lead lead;

  const WhatsAppChatPanel({super.key, required this.lead});

  static void show(BuildContext context, Lead lead) {
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    if (isDesktop) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'WhatsApp Chat',
        barrierColor: Colors.black.withValues(alpha: 0.5),
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) {
          return Align(
            alignment: Alignment.centerRight,
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              elevation: 16,
              child: SizedBox(
                width: 450,
                height: double.infinity,
                child: WhatsAppChatPanel(lead: lead),
              ),
            ),
          );
        },
        transitionBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
            child: child,
          );
        },
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: WhatsAppChatPanel(lead: lead),
          ),
        ),
      );
    }
  }

  @override
  ConsumerState<WhatsAppChatPanel> createState() => _WhatsAppChatPanelState();
}

class _WhatsAppChatPanelState extends ConsumerState<WhatsAppChatPanel> {
  bool _isInitializing = true;
  String? _convId;
  Map<String, dynamic> _conversation = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _initChat());
  }

  Future<void> _initChat() async {
    // Clear old cached messages to prevent previous company conversations from appearing
    ref.read(whatsappMessagesProvider.notifier).clearCache();
    // Fetch conversations to ensure we have the latest list
    await ref.read(whatsappChatsProvider.notifier).fetchConversations(clearCache: true);
    
    if (!mounted) return;
    
    final chatsState = ref.read(whatsappChatsProvider);
    final phone = widget.lead.phoneNo.replaceAll(RegExp(r'[^0-9]'), '').trim();
    
    String? convId;
    Map<String, dynamic>? existingConv;
    
    try {
      existingConv = chatsState.conversations.firstWhere((c) {
        final cPhone = (c['phone'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '').trim();
        final cWaId = (c['waId'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '').trim();
        
        bool matches = false;
        if (cPhone.isNotEmpty && phone.isNotEmpty) {
          matches = cPhone.endsWith(phone) || phone.endsWith(cPhone);
        }
        if (!matches && cWaId.isNotEmpty && phone.isNotEmpty) {
          matches = cWaId.endsWith(phone) || phone.endsWith(cWaId);
        }
        return matches;
      });
      convId = existingConv['id']?.toString() ?? existingConv['_id']?.toString();
    } catch (e) {
      convId = null;
    }

    if (convId != null) {
      _convId = convId;
      _conversation = existingConv ?? {};
      ref.read(whatsappChatsProvider.notifier).selectConversation(convId);
      ref.read(whatsappMessagesProvider.notifier).fetchMessages(convId);
    } else {
      // Simulate new conversation
      _convId = 'new_${widget.lead.id}';
      final cleanPhone = widget.lead.phoneNo.replaceAll(RegExp(r'[^\d+]'), '');
      _conversation = {
        'waId': cleanPhone.startsWith('+') ? cleanPhone.substring(1) : cleanPhone,
        'phone': widget.lead.phoneNo,
        'leads': [
          {'name': widget.lead.name}
        ]
      };
      ref.read(whatsappChatsProvider.notifier).selectConversation(_convId!);
      ref.read(whatsappMessagesProvider.notifier).clearMessages(_convId!);
    }
    
    setState(() {
      _isInitializing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        // Header matching Figma Mockup
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  whatsAppIcon(size: 20, color: const Color(0xFF25D366)),
                  const SizedBox(width: 8),
                  Text('Chat: ${widget.lead.name}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isDark ? Colors.white : Colors.black87)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, size: 20),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
        
        // Body
        Expanded(
          child: _isInitializing
              ? const Center(child: CircularProgressIndicator())
              : ActiveChatArea(
                  conversationId: _convId!,
                  conversation: _conversation,
                  onBack: () => Navigator.of(context).pop(),
                ),
        ),
      ],
    );
  }
}
