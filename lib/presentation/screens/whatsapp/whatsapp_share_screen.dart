import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../../../data/models/lead_model.dart';
import '../../providers/whatsapp_provider.dart';
import '../whatsapp/widgets/whatsapp_icon.dart';
import 'whatsapp_chats_screen.dart';

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

class _WhatsAppShareScreenState extends ConsumerState<WhatsAppShareScreen> {
  late TextEditingController _messageController;
  Lead? _selectedLead;
  bool _isSendingCrm = false;

  // CRM direct send check state
  bool _isCheckingCrm = false;
  bool _canSendCrm = false;
  String? _crmCheckTooltip;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialMessage);
    _selectedLead = widget.preselectedLead;
    if (_selectedLead != null) {
      _checkCrmChatWindow();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _checkCrmChatWindow() async {
    if (_selectedLead == null) return;
    
    setState(() {
      _isCheckingCrm = true;
      _canSendCrm = false;
      _crmCheckTooltip = 'Checking CRM Window...';
      _conversationId = null;
    });

    try {
      final phone = _selectedLead!.phoneNo.replaceAll(RegExp(r'[^0-9]'), '').trim();
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

      _conversationId = convId;

      final lastMsgResp = await waService.getLastInboundMessage(convId);
      if (lastMsgResp['success'] != true || lastMsgResp['data'] == null) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Chat window closed. Meta requires the customer to message you first within 24 hours to send custom text.';
        });
        return;
      }

      final lastInbound = lastMsgResp['data'];
      if (lastInbound['timestamp'] == null) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Chat window closed. Meta requires the customer to message you first within 24 hours to send custom text.';
        });
        return;
      }

      final lastInboundTime = DateTime.tryParse(lastInbound['timestamp'].toString())?.toLocal();
      if (lastInboundTime == null) {
        setState(() {
          _isCheckingCrm = false;
          _crmCheckTooltip = 'Chat window closed. Meta requires the customer to message you first within 24 hours to send custom text.';
        });
        return;
      }

      final diffInHours = DateTime.now().difference(lastInboundTime).inHours;
      if (diffInHours <= 24) {
        setState(() {
          _isCheckingCrm = false;
          _canSendCrm = true;
          _crmCheckTooltip = 'Chat window open. Custom text allowed.';
        });
      } else {
        setState(() {
          _isCheckingCrm = false;
          _canSendCrm = false;
          _crmCheckTooltip = 'Chat window closed. Meta requires the customer to message you first within 24 hours to send custom text.';
        });
      }
    } catch (e) {
      setState(() {
        _isCheckingCrm = false;
        _canSendCrm = false;
        _crmCheckTooltip = 'Error checking chat window: $e';
      });
    }
  }

  Future<void> _launchWhatsApp() async {
    final text = Uri.encodeComponent(_messageController.text);
    final urlStr = kIsWeb ? 'https://wa.me/?text=$text' : 'whatsapp://send?text=$text';
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
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

  Future<void> _sendOnCrm() async {
    if (_selectedLead == null || !_canSendCrm || _conversationId == null) return;
    
    setState(() {
      _isSendingCrm = true;
    });

    try {
      final phone = _selectedLead!.phoneNo.replaceAll(RegExp(r'[^0-9]'), '').trim();
      final text = _messageController.text;
      
      final waService = ref.read(whatsappServiceProvider);

      final body = {
        'waId': phone,
        'conversationId': _conversationId,
        'type': 'text',
        'message': text,
      };

      final response = await waService.sendMessage(body);
      if (mounted) {
        setState(() {
          _isSendingCrm = false;
        });
        if (response['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message sent successfully via WhatsApp CRM!')),
          );
          
          // Open WhatsApp CRM chats page!
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WhatsAppChatsScreen(initialConversationId: _conversationId),
            ),
          );
        } else {
          throw response['message'] ?? 'Failed to send message via CRM';
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSendingCrm = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CRM Sending Failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
      appBar: AppBar(
        title: Text(
          "Share via WhatsApp",
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E2130) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      ),
      body: _buildMessageFlow(isDark),
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
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Edit before sharing. Sent as-is via Web or copied to CRM.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2D324A) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300, width: 1.2),
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
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
                

              ],
            ),
          ),
        ),
        
        // 3 buttons in the bottom container
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2130) : Colors.white,
            border: Border(
              top: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Button 1: Copy
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyMessage,
                        icon: const Icon(Icons.copy, size: 18),
                        label: Text(
                          "Copy Message",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Button 2: Open WhatsApp Web
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _launchWhatsApp,
                        icon: whatsAppIcon(size: 18, color: Colors.white),
                        label: Text(
                          "Open WhatsApp Web",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_selectedLead != null) ...[
                  const SizedBox(height: 12),
                  // Button 3: Send on WhatsApp CRM
                  _isSendingCrm
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Sending via CRM...",
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _isCheckingCrm
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      "Checking CRM Window...",
                                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            )
                      : Tooltip(
                          message: _crmCheckTooltip ?? '',
                          child: ElevatedButton.icon(
                            onPressed: _canSendCrm ? _sendOnCrm : null,
                            icon: const Icon(Icons.send_rounded, size: 18),
                            label: Text(
                              "Send on WhatsApp CRM",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB), // Primary Blue
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                  if (_conversationId != null) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WhatsAppChatsScreen(initialConversationId: _conversationId),
                            ),
                          );
                        },
                        icon: const Icon(Icons.forum_outlined, size: 16, color: Color(0xFF2563EB)),
                        label: Text(
                          "Open CRM Chat Screen",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
