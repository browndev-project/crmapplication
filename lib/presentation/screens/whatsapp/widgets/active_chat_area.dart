import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../../providers/whatsapp_provider.dart';
import 'whatsapp_select_template_dialog.dart';
import 'whatsapp_message_dispatcher.dart';

import '../../../widgets/common_shimmer_skeleton.dart';

class ActiveChatArea extends ConsumerStatefulWidget {
  final String conversationId;
  final Map<String, dynamic> conversation;
  final VoidCallback? onBack;

  const ActiveChatArea({
    super.key,
    required this.conversationId,
    required this.conversation,
    this.onBack,
  });

  @override
  ConsumerState<ActiveChatArea> createState() => _ActiveChatAreaState();
}

class _ActiveChatAreaState extends ConsumerState<ActiveChatArea> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  Timer? _highlightTimer;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _highlightTimer?.cancel();
    super.dispose();
  }

  Set<String> _extractAllMsgIds(Map<String, dynamic> msg) {
    final ids = <String>{};
    final rawId = msg['id']?.toString().trim();
    if (rawId != null && rawId.isNotEmpty) ids.add(rawId);

    final rawMongoId = msg['_id']?.toString().trim();
    if (rawMongoId != null && rawMongoId.isNotEmpty) ids.add(rawMongoId);

    final rawWaId = msg['waId']?.toString().trim();
    if (rawWaId != null && rawWaId.isNotEmpty) ids.add(rawWaId);

    final rawWamid = msg['wamid']?.toString().trim();
    if (rawWamid != null && rawWamid.isNotEmpty) ids.add(rawWamid);

    final rawMessageId = msg['messageId']?.toString().trim();
    if (rawMessageId != null && rawMessageId.isNotEmpty) ids.add(rawMessageId);

    final rawStanzaId = msg['stanzaId']?.toString().trim();
    if (rawStanzaId != null && rawStanzaId.isNotEmpty) ids.add(rawStanzaId);

    if (msg['key'] is Map) {
      final keyId = msg['key']['id']?.toString().trim();
      if (keyId != null && keyId.isNotEmpty) ids.add(keyId);
    }
    return ids;
  }

  double _estimateItemHeight(Map<String, dynamic> msg) {
    final type = (msg['type'] ?? '').toString().toLowerCase();
    final body = (msg['body'] ?? msg['text'] ?? '').toString();

    if (type == 'template' || msg['template'] != null) {
      return 360.0;
    }
    if (type == 'image' || type == 'video' || msg['mediaUrl'] != null) {
      return 280.0;
    }
    if (type == 'document' || type == 'file') {
      return 140.0;
    }
    if (msg['context'] != null || msg['quotedMessage'] != null) {
      return 110.0 + (body.length / 30.0) * 18.0;
    }
    return 70.0 + (body.length / 35.0) * 16.0;
  }

  void _scrollToMessage(String targetId, {String? targetText}) {
    final cleanTargetId = targetId.trim();
    final cleanTargetText = targetText?.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

    if (cleanTargetText != null && (cleanTargetText.contains('campaign') || cleanTargetText.contains('campaign:'))) {
      debugPrint('[AutoScroll] Skipped scroll for campaign message: "$cleanTargetText"');
      return;
    }

    final messages = ref.read(whatsappMessagesProvider).messages;
    int index = -1;

    if (cleanTargetId.isNotEmpty) {
      index = messages.indexWhere((m) {
        final allIds = _extractAllMsgIds(m);
        if (allIds.contains(cleanTargetId)) return true;
        for (final id in allIds) {
          if (id.endsWith(cleanTargetId) || cleanTargetId.endsWith(id)) {
            return true;
          }
        }
        return false;
      });
    }

    if (index == -1 && cleanTargetText != null && cleanTargetText.length >= 2) {
      index = messages.indexWhere((m) {
        final body = (m['body'] ?? m['text'] ?? m['caption'] ?? m['message'] ?? '')
            .toString()
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'\s+'), ' ');
        if (body.isEmpty) return false;
        return body.contains(cleanTargetText) || cleanTargetText.contains(body);
      });
    }

    if (index == -1) {
      debugPrint('[AutoScroll] Message not found for targetId="$cleanTargetId", text="$cleanTargetText"');
      return;
    }

    final targetMsg = messages[index];
    final allTargetIds = _extractAllMsgIds(targetMsg);
    final keyToUse = allTargetIds.isNotEmpty ? allTargetIds.first : cleanTargetId;

    if (mounted) {
      setState(() {
        _highlightedMessageId = keyToUse;
      });

      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    }

    final keyContext = _messageKeys[keyToUse]?.currentContext;

    if (keyContext != null) {
      Scrollable.ensureVisible(
        keyContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
    } else {
      // Accumulate individual estimated heights of all messages below the target index
      double accumulatedOffset = 0.0;
      for (int i = index + 1; i < messages.length; i++) {
        accumulatedOffset += _estimateItemHeight(messages[i]);
      }

      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetOffset = accumulatedOffset.clamp(0.0, maxScroll);

        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        ).then((_) {
          void attemptEnsureVisible() {
            final postContext = _messageKeys[keyToUse]?.currentContext;
            if (postContext != null) {
              Scrollable.ensureVisible(
                postContext,
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                alignment: 0.5,
              );
            }
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            attemptEnsureVisible();
            Future.delayed(const Duration(milliseconds: 80), attemptEnsureVisible);
          });
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(whatsappMessagesProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final leadsList = widget.conversation['leads'] as List?;
    String leadName = '';
    
    if (leadsList != null && leadsList.isNotEmpty) {
      final firstLead = leadsList[0];
      if (firstLead is Map) {
        leadName = firstLead['name']?.toString() ?? '';
      }
    }
    
    if (leadName.isEmpty) {
      leadName = widget.conversation['name']?.toString() ?? widget.conversation['phone']?.toString() ?? 'Unknown Lead';
    }
    
    final String waId = widget.conversation['waId'] ?? '';

    // 24-Hour Rule Check
    bool is24HourWindowActive = false;
    if (messagesState.messages.isNotEmpty) {
      // Find the last INBOUND message
      final lastInboundMsg = messagesState.messages.lastWhere(
        (msg) => msg['direction'] == 'INBOUND',
        orElse: () => <String, dynamic>{},
      );
      if (lastInboundMsg.isNotEmpty && lastInboundMsg['timestamp'] != null) {
        final lastInboundTime = DateTime.tryParse(lastInboundMsg['timestamp'])?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
        is24HourWindowActive = DateTime.now().difference(lastInboundTime).inHours < 24;
      }
    } else {
       // If no messages at all, we might rely on conversation lastMessageAt or assume closed
       final lastMsgAtStr = widget.conversation['lastMessageAt'];
       if (lastMsgAtStr != null) {
          final lastMsgAt = DateTime.tryParse(lastMsgAtStr)?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
          is24HourWindowActive = DateTime.now().difference(lastMsgAt).inHours < 24;
       }
    }


    final bottomInset = math.max(
      MediaQuery.of(context).padding.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );

    return Column(
      children: [
        // Chat Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
          ),
          child: Row(
            children: [
              if (widget.onBack != null)
                Consumer(
                  builder: (context, ref, child) {
                    final chatsState = ref.watch(whatsappChatsProvider);
                    final totalUnread = chatsState.conversations
                        .where((c) => c['id'] != widget.conversationId)
                        .fold(0, (sum, c) => sum + (int.tryParse(c['unreadCount']?.toString() ?? '0') ?? 0));

                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.onBack,
                        ),
                        if (totalUnread > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Color(0xFF25D366), // WhatsApp Green
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                totalUnread > 99 ? '99+' : totalUnread.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark
                    ? const Color(0xFF202334)
                    : Colors.blueGrey.shade100,
                child: Text(
                  leadName.isNotEmpty ? leadName.substring(0, 1).toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      leadName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      waId.isNotEmpty ? '+$waId' : '',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              // Template dispatch button
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (c) => WhatsAppSelectTemplateDialog(waId: waId),
                  );
                },
                icon: const Icon(Icons.description_outlined, size: 14),
                label: const Text("SEND TEMPLATE"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF2D324A) : Colors.black,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child: messagesState.isLoading
              ? const WhatsAppMessageListSkeleton()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: messagesState.messages.length,
                  itemBuilder: (context, index) {
                    final msg = messagesState.messages[messagesState.messages.length - 1 - index];
                    final keys = _extractAllMsgIds(msg);
                    GlobalKey? mainKey;
                    bool isHighlighted = false;

                    if (keys.isNotEmpty) {
                      mainKey = _messageKeys[keys.first] ??= GlobalKey();
                      for (final id in keys) {
                        _messageKeys[id] = mainKey;
                        if (_highlightedMessageId != null && _highlightedMessageId == id) {
                          isHighlighted = true;
                        }
                      }
                    }

                    return Container(
                      key: mainKey,
                      child: WhatsAppMessageDispatcher(
                        message: msg,
                        isDark: isDark,
                        isHighlighted: isHighlighted,
                        onQuotedTap: (targetId, targetText) =>
                            _scrollToMessage(targetId, targetText: targetText),
                      ),
                    );
                  },
                ),
        ),

        // Composer Container with full bottomInset padding to prevent system navigation bar overlap
        Container(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 12 + bottomInset),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!is24HourWindowActive && !messagesState.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Standard messages are disabled because it has been more than 24 hours since the customer's last message. You can only send templates.",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        enabled: is24HourWindowActive,
                        decoration: InputDecoration(
                          hintText: is24HourWindowActive ? 'Type your message...' : 'Templates only...',
                          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                          filled: true,
                          fillColor: isDark ? const Color(0xFF1E2130) : Colors.grey[100],
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (val) {
                          if (is24HourWindowActive && val.trim().isNotEmpty) {
                            ref.read(whatsappMessagesProvider.notifier).sendTextMessage(val, waId);
                            _messageController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: is24HourWindowActive ? (isDark ? Colors.blue : Colors.black) : Colors.grey,
                      child: IconButton(
                        icon: const Icon(Icons.send, size: 16, color: Colors.white),
                        onPressed: is24HourWindowActive ? () {
                          final text = _messageController.text;
                          if (text.trim().isNotEmpty) {
                            ref.read(whatsappMessagesProvider.notifier).sendTextMessage(text, waId);
                            _messageController.clear();
                          }
                        } : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> pickAndSendFile(String waId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'mp3', 'mp4', 'docx'],
      );

      if (result == null || result.files.single.path == null) return;

      final path = result.files.single.path!;
      final name = result.files.single.name;
      final file = File(path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Picked file: $name. Uploading...'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      final ext = name.split('.').last.toLowerCase();
      final String type = (ext == 'jpg' || ext == 'png' || ext == 'jpeg') ? 'image' : 'document';

      // Trigger physical media dispatch
      ref.read(whatsappMessagesProvider.notifier).sendMediaMessage(
        file,
        waId,
        type,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Attachment error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
