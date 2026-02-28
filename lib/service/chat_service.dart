// lib/services/chat_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:wego_v1/service/socket_service.dart';
import '../models/chat_message.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_services.dart';

class ChatService extends ChangeNotifier {
  final SocketService _socketService;

  // Message storage by trip ID
  final Map<String, List<ChatMessage>> _messagesByTrip = {};

  // Typing indicators by trip ID
  final Map<String, bool> _typingIndicators = {};

  // Unread counts by trip ID
  final Map<String, int> _unreadCounts = {};

  // Current active trip ID
  String? _activeTripId;

  // Stream controllers for real-time updates
  final StreamController<ChatMessage> _newMessageController =
  StreamController<ChatMessage>.broadcast();

  ChatService(this._socketService) {
    _setupSocketListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // GETTERS
  // ═══════════════════════════════════════════════════════════════════

  List<ChatMessage> getMessages(String tripId) {
    return _messagesByTrip[tripId] ?? [];
  }

  bool isTyping(String tripId) {
    return _typingIndicators[tripId] ?? false;
  }

  int getUnreadCount(String tripId) {
    return _unreadCounts[tripId] ?? 0;
  }

  Stream<ChatMessage> get newMessageStream => _newMessageController.stream;

  // ═══════════════════════════════════════════════════════════════════
  // SOCKET EVENT LISTENERS
  // ═══════════════════════════════════════════════════════════════════

  void _setupSocketListeners() {
    print('💬 [CHAT_SERVICE] Setting up socket listeners...');

    // Listen for new messages
    _socketService.on('chat:new_message', (data) {
      print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      print('💬 [CHAT_SERVICE] New message received');
      print('📦 Data: $data');
      print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

      try {
        final tripId = data['tripId'] as String;
        final messageData = data['message'] as Map<String, dynamic>;
        final message = ChatMessage.fromJson(messageData);

        _addMessage(tripId, message);
        _incrementUnreadCount(tripId);

        // Broadcast to stream
        _newMessageController.add(message);

        notifyListeners();
      } catch (e) {
        print('❌ [CHAT_SERVICE] Error handling new message: $e');
      }
    });

    // Listen for message sent confirmation
    _socketService.on('chat:message_sent', (data) {
      print('✅ [CHAT_SERVICE] Message sent confirmation received');

      try {
        final messageData = data['message'] as Map<String, dynamic>;
        final message = ChatMessage.fromJson(messageData);

        print('   Message ID: ${message.id}');
      } catch (e) {
        print('❌ [CHAT_SERVICE] Error handling message sent: $e');
      }
    });

    // Listen for typing indicators
    _socketService.on('chat:typing', (data) {
      try {
        final tripId = data['tripId'] as String;
        final isTyping = data['isTyping'] as bool;

        print('⌨️ [CHAT_SERVICE] Typing indicator: $isTyping for trip $tripId');

        _typingIndicators[tripId] = isTyping;
        notifyListeners();
      } catch (e) {
        print('❌ [CHAT_SERVICE] Error handling typing indicator: $e');
      }
    });

    // Listen for messages marked as read
    _socketService.on('chat:messages_read', (data) {
      try {
        final tripId = data['tripId'] as String;
        final readAt = DateTime.parse(data['readAt'] as String);

        print('✅ [CHAT_SERVICE] Messages marked as read for trip $tripId');

        // Update messages read status
        final messages = _messagesByTrip[tripId];
        if (messages != null) {
          for (var i = 0; i < messages.length; i++) {
            if (messages[i].readAt == null) {
              _messagesByTrip[tripId]![i] = messages[i].copyWith(readAt: readAt);
            }
          }
        }

        notifyListeners();
      } catch (e) {
        print('❌ [CHAT_SERVICE] Error handling messages read: $e');
      }
    });

    // Listen for chat errors
    _socketService.on('chat:error', (data) {
      print('❌ [CHAT_SERVICE] Chat error: ${data['message']}');
    });

    // Listen for join confirmation
    _socketService.on('chat:joined', (data) {
      print('✅ [CHAT_SERVICE] Joined chat room: ${data['tripId']}');
    });

    // Listen for leave confirmation
    _socketService.on('chat:left', (data) {
      print('✅ [CHAT_SERVICE] Left chat room: ${data['tripId']}');
    });

    print('✅ [CHAT_SERVICE] Socket listeners setup complete\n');
  }

  // ═══════════════════════════════════════════════════════════════════
  // CHAT OPERATIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Join a chat room for a trip
  Future<void> joinChat(String tripId) async {
    print('\n🚪 [CHAT_SERVICE] Joining chat for trip: $tripId');

    _activeTripId = tripId;

    // Emit join event
    _socketService.emit('chat:join', {'tripId': tripId});

    // Load message history
    await loadMessages(tripId);

    print('✅ [CHAT_SERVICE] Joined chat successfully\n');
  }

  /// Leave a chat room
  void leaveChat(String tripId) {
    print('\n🚪 [CHAT_SERVICE] Leaving chat for trip: $tripId');

    _socketService.emit('chat:leave', {'tripId': tripId});

    if (_activeTripId == tripId) {
      _activeTripId = null;
    }

    print('✅ [CHAT_SERVICE] Left chat successfully\n');
  }

  /// Load message history from API
  Future<void> loadMessages(String tripId) async {
    try {
      print('\n📥 [CHAT_SERVICE] Loading messages for trip: $tripId');

      // Get access token
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) {
        print('❌ [CHAT_SERVICE] No access token found');
        return;
      }

      final response = await ApiService.get(
        '/chat/$tripId',
        accessToken: token,
      );

      if (response['success'] == true) {
        final messagesData = response['data']['messages'] as List;
        final messages = messagesData
            .map((msg) => ChatMessage.fromJson(msg as Map<String, dynamic>))
            .toList();

        _messagesByTrip[tripId] = messages;

        final unreadCount = response['data']['unreadCount'] as int? ?? 0;
        _unreadCounts[tripId] = unreadCount;

        print('✅ [CHAT_SERVICE] Loaded ${messages.length} messages');
        print('   Unread: $unreadCount\n');

        notifyListeners();
      }
    } catch (e) {
      print('❌ [CHAT_SERVICE] Error loading messages: $e');
      rethrow;
    }
  }

  /// Send a message
  Future<bool> sendMessage(String tripId, String text) async {
    if (text.trim().isEmpty) {
      print('⚠️ [CHAT_SERVICE] Cannot send empty message');
      return false;
    }

    try {
      print('\n📤 [CHAT_SERVICE] Sending message...');
      print('   Trip: $tripId');
      print('   Text: $text\n');

      // Emit via socket for real-time delivery
      _socketService.emit('chat:send', {
        'tripId': tripId,
        'text': text.trim(),
      });

      return true;
    } catch (e) {
      print('❌ [CHAT_SERVICE] Error sending message: $e');
      return false;
    }
  }

  /// Send typing indicator
  void sendTypingIndicator(String tripId, bool isTyping) {
    _socketService.emit('chat:typing', {
      'tripId': tripId,
      'isTyping': isTyping,
    });
  }

  /// Mark messages as read
  Future<void> markAsRead(String tripId) async {
    try {
      print('\n✅ [CHAT_SERVICE] Marking messages as read for trip: $tripId');

      // Emit via socket
      _socketService.emit('chat:mark_read', {'tripId': tripId});

      // Also call REST API for persistence
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token != null) {
        await ApiService.put('/chat/$tripId/read', {}, accessToken: token);
      }

      // Reset unread count
      _unreadCounts[tripId] = 0;

      notifyListeners();

      print('✅ [CHAT_SERVICE] Messages marked as read\n');
    } catch (e) {
      print('❌ [CHAT_SERVICE] Error marking as read: $e');
    }
  }

  /// Get unread count from API
  Future<int> fetchUnreadCount(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('access_token');

      if (token == null) return 0;

      final response = await ApiService.get(
        '/chat/$tripId/unread',
        accessToken: token,
      );

      if (response['success'] == true) {
        final count = response['data']['unreadCount'] as int;
        _unreadCounts[tripId] = count;
        notifyListeners();
        return count;
      }

      return 0;
    } catch (e) {
      print('❌ [CHAT_SERVICE] Error fetching unread count: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // HELPER METHODS
  // ═══════════════════════════════════════════════════════════════════

  void _addMessage(String tripId, ChatMessage message) {
    if (_messagesByTrip[tripId] == null) {
      _messagesByTrip[tripId] = [];
    }

    // Check if message already exists (avoid duplicates)
    final exists = _messagesByTrip[tripId]!.any((m) => m.id == message.id);

    if (!exists) {
      _messagesByTrip[tripId]!.add(message);

      // Sort by creation time
      _messagesByTrip[tripId]!.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
  }

  void _incrementUnreadCount(String tripId) {
    _unreadCounts[tripId] = (_unreadCounts[tripId] ?? 0) + 1;
  }

  /// Clear messages for a trip (e.g., when trip ends)
  void clearMessages(String tripId) {
    _messagesByTrip.remove(tripId);
    _typingIndicators.remove(tripId);
    _unreadCounts.remove(tripId);
    notifyListeners();
  }

  /// Clear all chat data
  void clearAll() {
    _messagesByTrip.clear();
    _typingIndicators.clear();
    _unreadCounts.clear();
    _activeTripId = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════
  // DISPOSE
  // ═══════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    print('🗑️ [CHAT_SERVICE] Disposing...');
    _newMessageController.close();
    super.dispose();
  }
}