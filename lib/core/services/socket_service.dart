import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:socket_io_client/socket_io_client.dart' as oi;
import 'auth_service.dart';

class SocketService {
  oi.Socket? socket;
  final _incomingMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageStatusController = StreamController<Map<String, dynamic>>.broadcast();
  final _conversationIncomingController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get incomingMessageStream => _incomingMessageController.stream;
  Stream<Map<String, dynamic>> get messageStatusStream => _messageStatusController.stream;
  Stream<Map<String, dynamic>> get conversationIncomingStream => _conversationIncomingController.stream;

  bool get isConnected => socket?.connected ?? false;

  Future<void> initSocket() async {
    if (socket != null) return;

    final box = await Hive.openBox('authBox');
    final accessToken = box.get('accessToken');
    if (accessToken == null) {
      debugPrint('[SocketService] No access token found, skipping connection.');
      return;
    }

    final String socketUrl = AuthService.baseUrl;
    debugPrint('[SocketService] Connecting to $socketUrl...');

    try {
      socket = oi.io(socketUrl, oi.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setAuth({'token': accessToken})
        .setExtraHeaders({'Authorization': 'Bearer $accessToken'})
        .build());

      socket!.onConnect((_) {
        debugPrint('[SocketService] Connected successfully.');
        
        // Auto-join company room if company ID exists
        final userDataJson = box.get('user_data');
        if (userDataJson != null) {
          try {
            final Map<String, dynamic> userData = jsonDecode(userDataJson);
            final companyId = userData['company'];
            if (companyId != null && companyId.isNotEmpty) {
              joinCompany(companyId);
            }
          } catch (e) {
            debugPrint('[SocketService] Error decoding user data: $e');
          }
        }
      });

      socket!.onDisconnect((_) {
        debugPrint('[SocketService] Disconnected.');
      });

      socket!.onConnectError((data) {
        debugPrint('[SocketService] Connect error: $data');
      });

      // --- Register Incoming WebSocket Listeners ---

      socket!.on('whatsapp:incoming', (data) {
        debugPrint('[SocketService] event: whatsapp:incoming, data: $data');
        if (data is Map<String, dynamic>) {
          _conversationIncomingController.add(data);
        } else if (data is String) {
          _conversationIncomingController.add(jsonDecode(data));
        }
      });

      socket!.on('whatsapp:message:new', (data) {
        debugPrint('[SocketService] event: whatsapp:message:new, data: $data');
        Map<String, dynamic> msgData = {};
        if (data is Map<String, dynamic>) {
          msgData = data;
          _incomingMessageController.add(data);
        } else if (data is String) {
          msgData = jsonDecode(data);
          _incomingMessageController.add(msgData);
        }
      });

      socket!.on('whatsapp:message:status', (data) {
        debugPrint('[SocketService] event: whatsapp:message:status, data: $data');
        if (data is Map<String, dynamic>) {
          _messageStatusController.add(data);
        } else if (data is String) {
          _messageStatusController.add(jsonDecode(data));
        }
      });

      socket!.connect();
    } catch (e) {
      debugPrint('[SocketService] Socket initialization error: $e');
    }
  }

  void joinCompany(String companyId) {
    if (socket == null) return;
    debugPrint('[SocketService] Joining company room: $companyId');
    socket!.emit('join:company', {'companyId': companyId});
  }

  void joinConversation(String conversationId) {
    if (socket == null) return;
    debugPrint('[SocketService] Joining conversation room: $conversationId');
    socket!.emit('join:whatsapp:conversation', {'conversationId': conversationId});
  }

  void leaveConversation(String conversationId) {
    if (socket == null) return;
    debugPrint('[SocketService] Leaving conversation room: $conversationId');
    socket!.emit('leave:whatsapp:conversation', {'conversationId': conversationId});
  }

  void disconnect() {
    socket?.disconnect();
    socket = null;
  }

  void dispose() {
    disconnect();
    _incomingMessageController.close();
    _messageStatusController.close();
    _conversationIncomingController.close();
  }
}
