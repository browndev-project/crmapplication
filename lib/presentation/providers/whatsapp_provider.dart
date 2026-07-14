import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/services/socket_service.dart';
import '../../core/services/r2_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/whatsapp_state_tracker.dart';
import 'login_provider.dart';
import '../../core/services/local_notification_service.dart';

// --- SERVICE PROVIDERS ---

final whatsappIntegrationProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  try {
    final loginState = ref.watch(loginProvider);
    final user = loginState.user;
    if (user == null || user.company.isEmpty) {
      return false;
    }

    final service = ref.read(whatsappServiceProvider);

    // Phase 0: Try checking via Account Details endpoint
    try {
      final accRes = await service.fetchAccountDetails(user.company);
      if (accRes['success'] == true) {
        return true;
      }
      if (accRes['success'] == false) {
        debugPrint(
          '[whatsappIntegrationProvider] Account details: Integration not found',
        );
        return false;
      }
    } catch (e) {
      debugPrint(
        '[whatsappIntegrationProvider] Account details check error (falling back): $e',
      );
    }

    // Phase 1: Try checking via Meta Integration Status endpoint
    try {
      final metaRes = await service.fetchMetaIntegrationStatus(user.company);
      if (metaRes['success'] == true && metaRes['data'] is Map) {
        final isIntegrated = metaRes['data']['isIntegrated'] == true;
        final isActive = metaRes['data']['isActive'] == true;
        if (isIntegrated && isActive) {
          debugPrint(
            '[whatsappIntegrationProvider] Meta integration active and connected',
          );
          return true;
        }
        debugPrint(
          '[whatsappIntegrationProvider] Meta integration not fully active, falling back to conversations check',
        );
      }
    } catch (e) {
      debugPrint(
        '[whatsappIntegrationProvider] Meta status check error (falling back): $e',
      );
    }

    // Phase 2: Fallback to Conversations endpoint
    final res = await service.checkIntegrationStatus();
    if (res['success'] == true) {
      if (res['data'] is Map && res['data']['isActive'] != null) {
        return res['data']['isActive'] == true;
      }
      return true;
    }
    return false;
  } catch (e) {
    debugPrint('[whatsappIntegrationProvider] Error checking integration: $e');
    return false;
  }
});

final whatsappServiceProvider = Provider<WhatsAppService>(
  (ref) => WhatsAppService(),
);

final socketServiceProvider = Provider<SocketService>((ref) {
  final socketService = SocketService();

  // Initialize Socket.io after state is fully rendered
  Future.microtask(() => socketService.initSocket());

  ref.onDispose(() {
    socketService.dispose();
  });
  return socketService;
});

// --- CHATS PROVIDER ---

class WhatsAppChatsState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> conversations;
  final String? selectedConversationId;
  final String searchQuery;
  final bool integrationActive;

  const WhatsAppChatsState({
    this.isLoading = false,
    this.error,
    this.conversations = const [],
    this.selectedConversationId,
    this.searchQuery = '',
    this.integrationActive = true, // Default to true until checked
  });

  WhatsAppChatsState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? conversations,
    String? selectedConversationId,
    String? searchQuery,
    bool? integrationActive,
    bool clearError = false,
  }) {
    return WhatsAppChatsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      conversations: conversations ?? this.conversations,
      selectedConversationId:
          selectedConversationId ?? this.selectedConversationId,
      searchQuery: searchQuery ?? this.searchQuery,
      integrationActive: integrationActive ?? this.integrationActive,
    );
  }
}

class WhatsAppChatsNotifier extends Notifier<WhatsAppChatsState>
    with WidgetsBindingObserver {
  bool _isBackground = false;

  @override
  WhatsAppChatsState build() {
    WidgetsBinding.instance.addObserver(this);
    final socketService = ref.watch(socketServiceProvider);

    // Listen to global real-time message alerts
    final subscription = socketService.conversationIncomingStream.listen((
      data,
    ) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('🔔 [SOCKET] INCOMING CHAT ALERT');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('  conversationId:  ${data['conversationId']}');
      debugPrint('  selectedConvId:  ${state.selectedConversationId}');
      debugPrint(
        '  matches:         ${data['conversationId'] == state.selectedConversationId}',
      );
      debugPrint('  data keys:       ${data.keys.toList()}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final convId = data['conversationId'];
      if (convId != state.selectedConversationId) {
        if (!_isBackground) {
          try {
            AudioPlayer().play(AssetSource('notification/message_notify.mp3'));
          } catch (e) {
            debugPrint('Error playing notification sound: $e');
          }
        }

        // Instantly increment unread badge
        final updatedConversations = state.conversations.map((c) {
          if ((c['id'] ?? c['_id']).toString() == convId) {
            final copy = Map<String, dynamic>.from(c);
            copy['unreadCount'] =
                (int.tryParse(copy['unreadCount'].toString()) ?? 0) + 1;
            return copy;
          }
          return c;
        }).toList();

        state = state.copyWith(conversations: updatedConversations);
      }

      fetchConversations(isRefresh: true);
    });

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      subscription.cancel();
    });

    return const WhatsAppChatsState();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isBackground =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
  }

  WhatsAppService get _service => ref.read(whatsappServiceProvider);

  Future<void> checkIntegrationStatus() async {
    try {
      final res = await _service.checkIntegrationStatus();
      if (res['success'] == true) {
        state = state.copyWith(
          integrationActive: res['data']?['isActive'] ?? true,
        );
      } else {
        state = state.copyWith(
          integrationActive: res['statusCode'] == 200 || res['data'] != null,
        );
      }
    } catch (e) {
      debugPrint('[WhatsAppChatsNotifier] checkIntegrationStatus error: $e');
      state = state.copyWith(integrationActive: false);
    }
  }

  void clearCache() {
    state = const WhatsAppChatsState();
  }

  Future<void> fetchConversations({
    bool isRefresh = false,
    bool clearCache = false,
  }) async {
    if (state.isLoading && !isRefresh) return;
    state = state.copyWith(
      isLoading: true,
      error: null,
      clearError: true,
      conversations: clearCache ? [] : state.conversations,
      selectedConversationId: clearCache ? null : state.selectedConversationId,
    );

    if (!isRefresh) {
      await checkIntegrationStatus();
    }

    if (!state.integrationActive) {
      state = state.copyWith(isLoading: false);
      return;
    }

    try {
      final response = await _service.fetchConversations();
      debugPrint(
        '[WhatsAppChatsNotifier] fetchConversations response: $response',
      );
      if (response['success'] == true) {
        final dynamic data = response['data'];
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = data['conversations'] ?? [];
        } else if (response['conversations'] is List) {
          list = response['conversations'];
        }

        final List<Map<String, dynamic>> parsedList = list
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        state = state.copyWith(isLoading: false, conversations: parsedList);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to load conversations',
        );
      }
    } catch (e) {
      debugPrint('[WhatsAppChatsNotifier] fetchConversations error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void selectConversation(String? conversationId) {
    List<Map<String, dynamic>> updatedConversations = state.conversations;
    if (conversationId != null) {
      updatedConversations = state.conversations.map((c) {
        if ((c['id'] ?? c['_id']).toString() == conversationId) {
          final copy = Map<String, dynamic>.from(c);
          copy['unreadCount'] = 0;
          return copy;
        }
        return c;
      }).toList();
    }

    WhatsAppStateTracker.activeConversationId = conversationId;

    state = state.copyWith(
      selectedConversationId: conversationId,
      conversations: updatedConversations,
    );

    final socketService = ref.read(socketServiceProvider);
    if (conversationId != null) {
      socketService.joinConversation(conversationId);
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final whatsappChatsProvider =
    NotifierProvider<WhatsAppChatsNotifier, WhatsAppChatsState>(() {
      return WhatsAppChatsNotifier();
    });

// --- MESSAGES PROVIDER ---

class WhatsAppMessagesState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> messages;
  final String? activeConversationId;

  const WhatsAppMessagesState({
    this.isLoading = false,
    this.error,
    this.messages = const [],
    this.activeConversationId,
  });

  WhatsAppMessagesState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? messages,
    String? activeConversationId,
  }) {
    return WhatsAppMessagesState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      messages: messages ?? this.messages,
      activeConversationId: activeConversationId ?? this.activeConversationId,
    );
  }
}

class WhatsAppMessagesNotifier extends Notifier<WhatsAppMessagesState> {
  @override
  WhatsAppMessagesState build() {
    final socketService = ref.watch(socketServiceProvider);

    // Stream listener 1: Prepend new real-time messages directly
    final subMessage = socketService.incomingMessageStream.listen((data) {
      final msg = data['message'];
      final convId = data['conversationId'];
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('💬 [SOCKET] INCOMING MESSAGE');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('  conversationId:  $convId');
      debugPrint('  activeConvId:    ${state.activeConversationId}');
      debugPrint('  matches:         ${convId == state.activeConversationId}');
      debugPrint('  direction:       ${msg?['direction']}');
      debugPrint('  type:            ${msg?['type']}');
      debugPrint('  body:            ${msg?['body']}');
      debugPrint(
        '  senderId:        ${msg?['sentBy']?['id'] ?? msg?['senderId'] ?? 'N/A'}',
      );
      debugPrint('  data keys:       ${data.keys.toList()}');
      debugPrint('  msg keys:        ${msg?.keys.toList()}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      if (convId == state.activeConversationId && msg != null) {
        final msgMap = Map<String, dynamic>.from(msg);
        final msgId = msgMap['_id']?.toString() ??
            msgMap['id']?.toString() ??
            msgMap['wamid']?.toString() ??
            msgMap['messageId']?.toString();

        final isDuplicate = msgId != null && state.messages.any((m) {
          final existingId = m['_id']?.toString() ??
              m['id']?.toString() ??
              m['wamid']?.toString() ??
              m['messageId']?.toString();
          return existingId != null && existingId == msgId;
        });

        debugPrint('[MessagesNotifier] ${isDuplicate ? 'SKIPPING duplicate' : 'Appending'} real-time message bubble.');

        if (!isDuplicate) {
          try {
            AudioPlayer().play(AssetSource('notification/message_recieve.mp3'));
          } catch (e) {
            debugPrint('Error playing receive sound: $e');
          }

          state = state.copyWith(
            messages: [...state.messages, msgMap],
          );
        }

        // Auto-read active conversation since we are viewing it
        // We can emit read event if supported by backend, or just let UI clear it.
      } else if (msg != null && msg['direction'] == 'INBOUND') {
        // Show global notification
        String bodyText = msg['body'] ?? 'New message';

        // Try to find conversation and name
        String senderName = 'WhatsApp Message';
        try {
          final chats = ref.read(whatsappChatsProvider).conversations;
          final conversation = chats.firstWhere(
            (c) => (c['id'] ?? c['_id']).toString() == convId.toString(),
            orElse: () => <String, dynamic>{},
          );
          if (conversation.isNotEmpty) {
            final leadsList = conversation['leads'] as List?;
            if (leadsList != null && leadsList.isNotEmpty) {
              final firstLead = leadsList[0];
              if (firstLead is Map && firstLead['name'] != null) {
                senderName = firstLead['name'].toString();
              }
            }
            if (senderName == 'WhatsApp Message' &&
                conversation['name'] != null) {
              senderName = conversation['name'].toString();
            }
          }
        } catch (e) {
          debugPrint('Error getting sender name: $e');
        }

        String? imageUrl;
        final type = msg['type'];
        if (type == 'image' ||
            type == 'document' ||
            bodyText.toLowerCase().contains('[image]')) {
          if (msg['media'] is Map && msg['media']['id'] != null) {
            imageUrl =
                '${AuthService.baseUrl}/api/v1/whatsapp/media/${msg['media']['id']}';
          } else {
            imageUrl =
                msg['mediaUrl'] ?? msg['url'] ?? msg['fileUrl'] ?? msg['link'];
            if (imageUrl == null && msg['media'] is Map) {
              imageUrl = msg['media']['url'] ?? msg['media']['link'];
            }
            if (imageUrl == null && msg['image'] is Map) {
              imageUrl = msg['image']['url'] ?? msg['image']['link'];
            }
            if (imageUrl == null && msg['document'] is Map) {
              imageUrl = msg['document']['url'] ?? msg['document']['link'];
            }
            if (imageUrl == null && bodyText.contains('Shared File: ')) {
              final match = RegExp(
                r'Shared File:\s*(https?://[^\s]+)',
              ).firstMatch(bodyText);
              if (match != null) imageUrl = match.group(1);
            }
          }

          if (bodyText.isEmpty ||
              bodyText == 'New message' ||
              bodyText.contains('business.facebook.com')) {
            bodyText = '📷 Photo';
          }
        }

        LocalNotificationService.showNotification(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: senderName,
          body: bodyText.toString(),
          imageUrl: imageUrl,
          soundName: 'message_notify',
        );
      }
    });

    // Stream listener 2: Update delivery check ticks in real-time
    final subStatus = socketService.messageStatusStream.listen((data) {
      final msgId = data['messageId'];
      final status = data['status'];
      final error = data['error'];
      if (msgId != null && status != null) {
        debugPrint(
          '[MessagesNotifier] Updating message status ticks. status=$status error=$error',
        );
        final updatedMessages = state.messages.map((m) {
          if (m['_id'] == msgId || m['id'] == msgId) {
            final copy = Map<String, dynamic>.from(m);
            copy['status'] = status;
            if (error != null) {
              copy['error'] = error is Map
                  ? Map<String, dynamic>.from(error)
                  : {'message': error.toString()};
            } else if (status == 'failed') {
              copy['error'] = {
                'message': 'Delivery failed - no error details from server',
              };
            }
            return copy;
          }
          return m;
        }).toList();
        state = state.copyWith(messages: updatedMessages);
      }
    });

    ref.onDispose(() {
      subMessage.cancel();
      subStatus.cancel();
    });

    return const WhatsAppMessagesState();
  }

  WhatsAppService get _service => ref.read(whatsappServiceProvider);

  void clearCache() {
    state = const WhatsAppMessagesState();
  }

  Future<void> fetchMessages(
    String conversationId, {
    bool silent = false,
  }) async {
    WhatsAppStateTracker.activeConversationId = conversationId;

    final failedMessages = state.messages
        .where((m) => m['status'] == 'failed')
        .toList();
    final pendingMessages = state.messages
        .where((m) => m['status'] == 'pending')
        .toList();

    state = state.copyWith(
      isLoading: !silent,
      error: null,
      activeConversationId: conversationId,
      messages: silent ? state.messages : [],
    );

    try {
      final response = await _service.fetchMessages(conversationId);
      if (response['success'] == true) {
        final dynamic data = response['data'];
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map) {
          list = data['messages'] ?? [];
        } else if (response['messages'] is List) {
          list = response['messages'];
        }

        final List<Map<String, dynamic>> parsedList = [];
        for (final item in list) {
          if (item is Map) {
            parsedList.add(
              _normalizeFetchedMessage(
                Map<String, dynamic>.from(item.cast<String, dynamic>()),
              ),
            );
          }
        }

        // Attach full template definitions to template-type messages
        var templates = ref.read(whatsappTemplatesProvider).templates;
        if (templates.isEmpty) {
          await ref.read(whatsappTemplatesProvider.notifier).fetchTemplates();
          templates = ref.read(whatsappTemplatesProvider).templates;
        }
        for (final msg in parsedList) {
          if (msg['type'] == 'template' && msg['__fullTemplate'] == null) {
            final templateData = msg['template'];
            if (templateData != null) {
              final templateName = templateData['name']?.toString();
              if (templateName != null && templateName.isNotEmpty) {
                try {
                  final matching = templates.firstWhere(
                    (t) => t['name'] == templateName,
                    orElse: () => <String, dynamic>{},
                  );
                  if (matching.isNotEmpty) {
                    msg['__fullTemplate'] = Map<String, dynamic>.from(matching);
                  }
                } catch (e) {
                  debugPrint(
                    '[fetchMessages] Error matching template $templateName: $e',
                  );
                }
              }
            }
          }
        }

        bool matchesAnyId(Map<String, dynamic> a, Map<String, dynamic> b) {
          return a['_id'] != null && a['_id'] == b['_id'] ||
              a['id'] != null && a['id'] == b['id'] ||
              a['wamid'] != null && a['wamid'] == b['wamid'] ||
              a['messageId'] != null && a['messageId'] == b['messageId'];
        }

        final List<Map<String, dynamic>> mergedMessages =
            List<Map<String, dynamic>>.from(parsedList);
        for (final failed in failedMessages) {
          final existsInApi = mergedMessages.any(
            (m) => matchesAnyId(m, failed),
          );
          if (!existsInApi) {
            mergedMessages.add(failed);
          }
        }
        for (final pending in pendingMessages) {
          final existsInApi = mergedMessages.any(
            (m) => matchesAnyId(m, pending),
          );
          if (!existsInApi) {
            mergedMessages.add(pending);
          }
        }

        state = state.copyWith(isLoading: false, messages: mergedMessages);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to fetch messages',
        );
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Map<String, dynamic> _normalizeFetchedMessage(
    Map<String, dynamic> rawMessage,
  ) {
    final message = Map<String, dynamic>.from(rawMessage);

    if (message['template'] == null && message['templateMeta'] is Map) {
      message['template'] = Map<String, dynamic>.from(
        (message['templateMeta'] as Map).cast<String, dynamic>(),
      );
    }

    if (message['template'] is Map && message['templateMeta'] == null) {
      message['templateMeta'] = Map<String, dynamic>.from(
        (message['template'] as Map).cast<String, dynamic>(),
      );
    }

    if (message['id'] == null && message['_id'] != null) {
      message['id'] = message['_id'];
    }
    if (message['_id'] == null && message['id'] != null) {
      message['_id'] = message['id'];
    }

    if (message['body'] == null && message['message'] != null) {
      message['body'] = message['message'];
    }
    if (message['message'] == null && message['body'] != null) {
      message['message'] = message['body'];
    }

    if (message['timestamp'] == null) {
      message['timestamp'] = message['createdAt'] ?? message['sentAt'];
    }

    if (message['status'] == null && message['deliveryStatus'] != null) {
      message['status'] = message['deliveryStatus'];
    }

    if (message['direction'] == null) {
      if (message['isOutbound'] == true || message['isOutbound'] == 'true') {
        message['direction'] = 'OUTBOUND';
      } else if (message['isInbound'] == true ||
          message['isInbound'] == 'true') {
        message['direction'] = 'INBOUND';
      }
    }

    return message;
  }

  void clearMessages(String conversationId) {
    state = state.copyWith(
      messages: [],
      activeConversationId: conversationId,
      error: null,
    );
  }

  Future<void> sendTextMessage(String text, String waId) async {
    final activeConvId = state.activeConversationId;
    if (activeConvId == null) return;

    final body = {
      'waId': waId,
      'conversationId': activeConvId,
      'type': 'text',
      'message': text,
    };

    // Optimistic UI updates
    final mockMsg = {
      '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'direction': 'OUTBOUND',
      'type': 'text',
      'status': 'pending',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'body': text,
      'sentBy': {
        'id': ref.read(loginProvider).user?.id ?? '',
        'name': ref.read(loginProvider).user?.name ?? 'Me',
      },
    };

    state = state.copyWith(messages: [...state.messages, mockMsg]);

    try {
      AudioPlayer().play(AssetSource('notification/message_sent.mp3'));
    } catch (e) {
      debugPrint('Error playing send sound: $e');
    }

    try {
      final response = await _service.sendMessage(body);
      if (response['success'] == true) {
        // Fetch conversations to refresh last message snippets
        ref
            .read(whatsappChatsProvider.notifier)
            .fetchConversations(isRefresh: true);
        // Refetch messages to get the real DB message
        fetchMessages(activeConvId, silent: true);
      }
    } catch (e) {
      // Mark optimistic message as failed
      final failedList = state.messages.map((m) {
        if (m['_id'] == mockMsg['_id']) {
          final copy = Map<String, dynamic>.from(m);
          copy['status'] = 'failed';
          copy['error'] = {'message': e.toString()};
          return copy;
        }
        return m;
      }).toList();
      state = state.copyWith(messages: failedList);
    }
  }

  Future<void> sendTemplateMessage(
    Map<String, dynamic> template,
    String waId, {
    String? previewText,
    Map<String, dynamic>? fullTemplate,
  }) async {
    final activeConvId = state.activeConversationId;
    if (activeConvId == null) return;

    final body = {
      'waId': waId,
      'conversationId': activeConvId,
      'type': 'template',
      'template': template,
      if (fullTemplate != null) '__fullTemplate': fullTemplate,
    };

    // Optimistic UI updates
    final mockMsg = {
      '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'direction': 'OUTBOUND',
      'type': 'template',
      'status': 'pending',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'body': previewText ?? '[Template: ${template['name']}]',
      'sentBy': {
        'id': ref.read(loginProvider).user?.id ?? '',
        'name': ref.read(loginProvider).user?.name ?? 'Me',
      },
      if (fullTemplate != null)
        '__fullTemplate': Map<String, dynamic>.from(fullTemplate),
    };

    state = state.copyWith(messages: [...state.messages, mockMsg]);

    try {
      AudioPlayer().play(AssetSource('notification/message_sent.mp3'));
    } catch (e) {
      debugPrint('Error playing send sound: $e');
    }

    try {
      final response = await _service.sendMessage(body);
      if (response['success'] == true) {
        // Refetch messages silently so we don't blink a spinner
        fetchMessages(activeConvId, silent: true);
        ref
            .read(whatsappChatsProvider.notifier)
            .fetchConversations(isRefresh: true);
      } else {
        // Extract rich error from the response before throwing
        final errorMap = <String, dynamic>{
          'message': response['message'] ?? 'Unknown error',
        };
        if (response['error'] is Map) {
          final err = response['error'] as Map;
          if (err['code'] != null) {
            errorMap['code'] = err['code'];
          }
          if (err['error_subcode'] != null) {
            errorMap['error_subcode'] = err['error_subcode'];
          }
          if (err['fbtrace_id'] != null) {
            errorMap['fbtrace_id'] = err['fbtrace_id'];
          }
          if (err['type'] != null) {
            errorMap['type'] = err['type'];
          }
          if (err['error_data'] is Map) {
            errorMap['error_data'] = Map<String, dynamic>.from(
              err['error_data'] as Map,
            );
          }
          if (err['error_user_title'] != null) {
            errorMap['error_user_title'] = err['error_user_title'];
          }
          if (err['error_user_msg'] != null) {
            errorMap['error_user_msg'] = err['error_user_msg'];
          }
        }
        throw errorMap;
      }
    } catch (e) {
      // Mark optimistic message as failed
      final failedList = state.messages.map((m) {
        if (m['_id'] == mockMsg['_id']) {
          final copy = Map<String, dynamic>.from(m);
          copy['status'] = 'failed';
          if (e is Map) {
            copy['error'] = Map<String, dynamic>.from(e);
          } else {
            copy['error'] = {'message': e.toString()};
          }
          return copy;
        }
        return m;
      }).toList();
      state = state.copyWith(messages: failedList);
      // Rethrow as string for callers that expect string errors
      if (e is Map) {
        throw (e['message'] ?? e.toString()).toString();
      }
      rethrow;
    }
  }

  Future<void> sendMediaMessage(File file, String waId, String type) async {
    final activeConvId = state.activeConversationId;
    if (activeConvId == null) return;

    final fileName = file.path.split('/').last;

    // Optimistic UI updates
    final mockMsg = {
      '_id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
      'direction': 'OUTBOUND',
      'type': type,
      'status': 'pending',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'body': '[Attached File: $fileName]',
      'sentBy': {
        'id': ref.read(loginProvider).user?.id ?? '',
        'name': ref.read(loginProvider).user?.name ?? 'Me',
      },
    };

    state = state.copyWith(messages: [...state.messages, mockMsg]);

    try {
      AudioPlayer().play(AssetSource('notification/message_sent.mp3'));
    } catch (e) {
      debugPrint('Error playing send sound: $e');
    }

    try {
      final response = await _service.sendMediaMessage(
        waId: waId,
        conversationId: activeConvId,
        type: type,
        file: file,
      );
      if (response['success'] == true) {
        ref
            .read(whatsappChatsProvider.notifier)
            .fetchConversations(isRefresh: true);
        fetchMessages(activeConvId, silent: true);
      }
    } catch (e) {
      debugPrint(
        '[WhatsAppMessagesNotifier] Multipart upload failed: $e. Trying R2 fallback...',
      );
      try {
        final r2Service = R2Service();
        final folder = type == 'image'
            ? 'whatsapp-images'
            : 'whatsapp-documents';
        final mimeType = type == 'image' ? 'image/jpeg' : 'application/pdf';

        final bytes = await file.readAsBytes();
        final r2Key = await r2Service.uploadFile(
          bytes,
          '$folder/$fileName',
          mimeType,
        );
        if (r2Key != null) {
          final publicUrl = '${R2Service.publicBaseUrl}/$r2Key';

          final body = {
            'waId': waId,
            'conversationId': activeConvId,
            'type': 'text',
            'message': 'Shared File: $publicUrl',
          };

          await _service.sendMessage(body);
          ref
              .read(whatsappChatsProvider.notifier)
              .fetchConversations(isRefresh: true);
          fetchMessages(activeConvId);
          return;
        }
      } catch (r2Err) {
        debugPrint('[WhatsAppMessagesNotifier] R2 Fallback failed: $r2Err');
      }

      // Mark optimistic message as failed if both direct upload & fallback fail
      final failedList = state.messages.map((m) {
        if (m['_id'] == mockMsg['_id']) {
          final copy = Map<String, dynamic>.from(m);
          copy['status'] = 'failed';
          copy['error'] = {'message': e.toString()};
          return copy;
        }
        return m;
      }).toList();
      state = state.copyWith(messages: failedList);
    }
  }
}

final whatsappMessagesProvider =
    NotifierProvider<WhatsAppMessagesNotifier, WhatsAppMessagesState>(() {
      return WhatsAppMessagesNotifier();
    });

// --- TEMPLATES PROVIDER ---

class WhatsAppTemplatesState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> templates;
  final String filterStatus; // 'ALL', 'APPROVED', 'PENDING', 'REJECTED'
  final String searchQuery;
  final String
  categoryFilter; // 'ALL', 'MARKETING', 'UTILITY', 'AUTHENTICATION'

  const WhatsAppTemplatesState({
    this.isLoading = false,
    this.error,
    this.templates = const [],
    this.filterStatus = 'ALL',
    this.searchQuery = '',
    this.categoryFilter = 'ALL',
  });

  WhatsAppTemplatesState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? templates,
    String? filterStatus,
    String? searchQuery,
    String? categoryFilter,
    bool clearError = false,
  }) {
    return WhatsAppTemplatesState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      templates: templates ?? this.templates,
      filterStatus: filterStatus ?? this.filterStatus,
      searchQuery: searchQuery ?? this.searchQuery,
      categoryFilter: categoryFilter ?? this.categoryFilter,
    );
  }
}

class WhatsAppTemplatesNotifier extends Notifier<WhatsAppTemplatesState> {
  @override
  WhatsAppTemplatesState build() {
    return const WhatsAppTemplatesState();
  }

  WhatsAppService get _service => ref.read(whatsappServiceProvider);

  Future<void> fetchTemplates() async {
    final integrationStatus = ref.read(whatsappIntegrationProvider);
    if (integrationStatus.hasValue && integrationStatus.value == false) {
      state = state.copyWith(
        isLoading: false,
        error: 'WhatsApp is not connected for this company',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null, clearError: true);

    try {
      final response = await _service.fetchTemplates();
      debugPrint(
        '[WhatsAppTemplatesNotifier] fetchTemplates response: $response',
      );
      if (response['success'] == true) {
        final List<dynamic> list = response['data']?['templates'] ?? [];
        final List<Map<String, dynamic>> parsedList = list
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        state = state.copyWith(isLoading: false, templates: parsedList);
      } else {
        state = state.copyWith(
          isLoading: false,
          error: response['message'] ?? 'Failed to load templates',
        );
      }
    } catch (e) {
      debugPrint('[WhatsAppTemplatesNotifier] fetchTemplates error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void setFilterStatus(String status) {
    state = state.copyWith(filterStatus: status);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setCategoryFilter(String category) {
    state = state.copyWith(categoryFilter: category);
  }

  Future<void> createTemplate(Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.createTemplate(body);
      await fetchTemplates();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }
}

final whatsappTemplatesProvider =
    NotifierProvider<WhatsAppTemplatesNotifier, WhatsAppTemplatesState>(() {
      return WhatsAppTemplatesNotifier();
    });

// --- AUTOMATIONS PROVIDER ---

class WhatsAppAutomationsState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> incomingLeadsRules;
  final List<Map<String, dynamic>>
  eventRules; // Combined status & visits backend outputs

  const WhatsAppAutomationsState({
    this.isLoading = false,
    this.error,
    this.incomingLeadsRules = const [],
    this.eventRules = const [],
  });

  WhatsAppAutomationsState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? incomingLeadsRules,
    List<Map<String, dynamic>>? eventRules,
    bool clearError = false,
  }) {
    return WhatsAppAutomationsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      incomingLeadsRules: incomingLeadsRules ?? this.incomingLeadsRules,
      eventRules: eventRules ?? this.eventRules,
    );
  }
}

class WhatsAppAutomationsNotifier extends Notifier<WhatsAppAutomationsState> {
  @override
  WhatsAppAutomationsState build() {
    return const WhatsAppAutomationsState();
  }

  WhatsAppService get _service => ref.read(whatsappServiceProvider);

  /// Persists automation-to-source mappings to Hive after every fetch/CRUD.
  Future<void> _cacheSourceMappings() async {
    final mappings = state.incomingLeadsRules.map((rule) {
      final id = rule['_id'] ?? rule['id'] ?? '';
      final sources = (rule['leadSources'] as List?)
              ?.map((s) => s.toString())
              .toList() ??
          [];
      return {'automationId': id, 'sources': sources};
    }).toList();
    final box = await Hive.openBox('authBox');
    await box.put('automationSourceMappings', jsonEncode(mappings));
  }

  Future<void> fetchIncomingLeadsRules() async {
    final integrationStatus = ref.read(whatsappIntegrationProvider);
    if (integrationStatus.hasValue && integrationStatus.value == false) {
      state = state.copyWith(
        isLoading: false,
        error: 'WhatsApp is not connected for this company',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null, clearError: true);
    try {
      final res = await _service.fetchIncomingLeadsAutomations();
      debugPrint(
        '[WhatsAppAutomationsNotifier] fetchIncomingLeadsRules response: $res',
      );
      if (res['success'] == true) {
        final List<dynamic> list = res['data']?['automations'] ?? [];
        final parsed = list.map((e) => Map<String, dynamic>.from(e)).toList();
        state = state.copyWith(isLoading: false, incomingLeadsRules: parsed);
        _cacheSourceMappings();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: res['message'] ?? 'Failed to load incoming leads rules',
        );
      }
    } catch (e) {
      debugPrint(
        '[WhatsAppAutomationsNotifier] fetchIncomingLeadsRules error: $e',
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchEventRules() async {
    final integrationStatus = ref.read(whatsappIntegrationProvider);
    if (integrationStatus.hasValue && integrationStatus.value == false) {
      state = state.copyWith(
        isLoading: false,
        error: 'WhatsApp is not connected for this company',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null, clearError: true);
    try {
      final res = await _service.fetchEventAutomations();
      debugPrint(
        '[WhatsAppAutomationsNotifier] fetchEventRules response: $res',
      );
      if (res['success'] == true) {
        final List<dynamic> list = res['data']?['automations'] ?? [];
        final parsed = list.map((e) => Map<String, dynamic>.from(e)).toList();
        state = state.copyWith(isLoading: false, eventRules: parsed);
        _cacheSourceMappings();
      } else {
        state = state.copyWith(
          isLoading: false,
          error: res['message'] ?? 'Failed to load event rules',
        );
      }
    } catch (e) {
      debugPrint('[WhatsAppAutomationsNotifier] fetchEventRules error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // --- CRUD Incoming Leads Rule ---

  Future<void> createIncomingLeadsRule(Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.createIncomingLeadsAutomation(body);
      await fetchIncomingLeadsRules();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateIncomingLeadsRule(
    String id,
    Map<String, dynamic> body,
  ) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.updateIncomingLeadsAutomation(id, body);
      await fetchIncomingLeadsRules();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleIncomingLeadsRule(String id) async {
    try {
      await _service.toggleIncomingLeadsAutomation(id);
      await fetchIncomingLeadsRules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteIncomingLeadsRule(String id) async {
    try {
      await _service.deleteIncomingLeadsAutomation(id);
      await fetchIncomingLeadsRules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  // --- CRUD Event Rules (Status & Visits) ---

  Future<void> createEventRule(Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.createEventAutomation(body);
      await fetchEventRules();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> updateEventRule(String id, Map<String, dynamic> body) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.updateEventAutomation(id, body);
      await fetchEventRules();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> toggleEventRule(String id, bool isActive) async {
    try {
      await _service.toggleEventAutomation(id, isActive);
      await fetchEventRules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteEventRule(String id) async {
    try {
      await _service.deleteEventAutomation(id);
      await fetchEventRules();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final whatsappAutomationsProvider =
    NotifierProvider<WhatsAppAutomationsNotifier, WhatsAppAutomationsState>(() {
      return WhatsAppAutomationsNotifier();
    });

// --- MARKETING CAMPAIGNS PROVIDER ---

class WhatsAppCampaignsState {
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> campaigns;
  final int totalCount;
  final int currentPage;
  final int totalPages;
  final Map<String, dynamic>
  limits; // messagingLimit, messagesToday, remaining, resetAt

  const WhatsAppCampaignsState({
    this.isLoading = false,
    this.error,
    this.campaigns = const [],
    this.totalCount = 0,
    this.currentPage = 1,
    this.totalPages = 1,
    this.limits = const {},
  });

  WhatsAppCampaignsState copyWith({
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? campaigns,
    int? totalCount,
    int? currentPage,
    int? totalPages,
    Map<String, dynamic>? limits,
    bool clearError = false,
  }) {
    return WhatsAppCampaignsState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      campaigns: campaigns ?? this.campaigns,
      totalCount: totalCount ?? this.totalCount,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      limits: limits ?? this.limits,
    );
  }
}

class WhatsAppCampaignsNotifier extends Notifier<WhatsAppCampaignsState> {
  @override
  WhatsAppCampaignsState build() {
    return const WhatsAppCampaignsState();
  }

  WhatsAppService get _service => ref.read(whatsappServiceProvider);

  Future<void> fetchCampaigns({int page = 1}) async {
    final integrationStatus = ref.read(whatsappIntegrationProvider);
    if (integrationStatus.hasValue && integrationStatus.value == false) {
      state = state.copyWith(
        isLoading: false,
        error: 'WhatsApp is not connected for this company',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null, clearError: true);
    try {
      final res = await _service.fetchCampaigns(page: page);
      if (res['success'] == true) {
        final List<dynamic> list = res['data']?['campaigns'] ?? [];
        final parsedList = list
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        state = state.copyWith(
          isLoading: false,
          campaigns: page == 1
              ? parsedList
              : [...state.campaigns, ...parsedList],
          totalCount: res['data']?['total'] ?? 0,
          currentPage: res['data']?['page'] ?? page,
          totalPages:
              ((res['data']?['total'] ?? 0) / (res['data']?['limit'] ?? 20))
                  .ceil(),
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: res['message'] ?? 'Failed to load campaigns',
        );
      }
    } catch (e) {
      debugPrint('[WhatsAppCampaignsNotifier] fetchCampaigns error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> fetchCampaignsSilent({int page = 1}) async {
    final integrationStatus = ref.read(whatsappIntegrationProvider);
    if (integrationStatus.hasValue && integrationStatus.value == false) {
      return;
    }

    try {
      final res = await _service.fetchCampaigns(page: page);
      if (res['success'] == true) {
        final List<dynamic> list = res['data']?['campaigns'] ?? [];
        final parsedList = list
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        state = state.copyWith(
          campaigns: parsedList,
          totalCount: res['data']?['total'] ?? 0,
          currentPage: res['data']?['page'] ?? page,
          totalPages:
              ((res['data']?['total'] ?? 0) / (res['data']?['limit'] ?? 20))
                  .ceil(),
        );
      }
    } catch (e) {
      debugPrint('[WhatsAppCampaignsNotifier] fetchCampaignsSilent error: $e');
    }
  }

  Future<void> fetchMessagingLimit() async {
    try {
      final res = await _service.fetchMessagingLimit();
      if (res['success'] == true) {
        state = state.copyWith(
          limits: Map<String, dynamic>.from(res['data'] ?? {}),
        );
      }
    } catch (e) {
      debugPrint('[CampaignsNotifier] Error fetching messaging limit: $e');
    }
  }

  Future<void> updateMessagingLimit(int limit) async {
    try {
      final res = await _service.updateMessagingLimit(limit);
      if (res['success'] == true) {
        await fetchMessagingLimit();
      }
    } catch (e) {
      debugPrint('[CampaignsNotifier] Error updating messaging limit: $e');
    }
  }

  Future<void> createCampaign(
    Map<String, dynamic> fields, {
    File? file,
    List<String>? leadIds,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _service.createCampaign(fields, file: file, leadIds: leadIds);
      await fetchCampaigns(page: 1);
      await fetchMessagingLimit();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      rethrow;
    }
  }

  Future<void> triggerCampaignSend(String id) async {
    try {
      await _service.triggerCampaignSend(id);
      await fetchCampaigns(page: 1);
      await fetchMessagingLimit();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> updateCampaignStatus(String id, String status) async {
    try {
      await _service.updateCampaignStatus(id, status);
      await fetchCampaigns(page: 1);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteCampaign(String id) async {
    try {
      await _service.deleteCampaign(id);
      await fetchCampaigns(page: 1);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final whatsappCampaignsProvider =
    NotifierProvider<WhatsAppCampaignsNotifier, WhatsAppCampaignsState>(() {
      return WhatsAppCampaignsNotifier();
    });
