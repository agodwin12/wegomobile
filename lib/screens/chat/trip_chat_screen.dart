// lib/presentation/screens/chat/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/chat_message.dart';
import '../../../utils/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../service/chat_service.dart';

// Wrapper to ensure provider is available
class ChatScreen extends StatelessWidget {
  final String tripId;
  final String otherUserName;
  final String? otherUserAvatar;

  const ChatScreen({
    super.key,
    required this.tripId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  Widget build(BuildContext context) {
    // Get the ChatService from the parent context
    final chatService = Provider.of<ChatService>(context, listen: false);

    return ChangeNotifierProvider.value(
      value: chatService,
      child: _ChatScreenContent(
        tripId: tripId,
        otherUserName: otherUserName,
        otherUserAvatar: otherUserAvatar,
      ),
    );
  }
}

// The actual chat screen implementation
class _ChatScreenContent extends StatefulWidget {
  final String tripId;
  final String otherUserName;
  final String? otherUserAvatar;

  const _ChatScreenContent({
    required this.tripId,
    required this.otherUserName,
    this.otherUserAvatar,
  });

  @override
  State<_ChatScreenContent> createState() => _ChatScreenContentState();
}

class _ChatScreenContentState extends State<_ChatScreenContent> with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  String? _currentUserId;
  bool _isLoading = true;
  bool _isSending = false;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    print('\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('💬 [CHAT_SCREEN] Initializing...');
    print('   Trip ID: ${widget.tripId}');
    print('   Other User: ${widget.otherUserName}');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    WidgetsBinding.instance.addObserver(this);
    _initializeChat();
    _setupMessageListener();

    // Listen to text changes for typing indicator
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    print('🗑️ [CHAT_SCREEN] Disposing...');
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();

    // Leave chat room
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.leaveChat(widget.tripId);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Mark messages as read when returning to screen
      _markMessagesAsRead();
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Get current user ID
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString('user_id');

      if (_currentUserId == null) {
        print('❌ [CHAT_SCREEN] No user ID found');
        return;
      }

      // Join chat and load messages
      final chatService = Provider.of<ChatService>(context, listen: false);
      await chatService.joinChat(widget.tripId);

      // Mark messages as read
      await _markMessagesAsRead();

      setState(() {
        _isLoading = false;
      });

      // Scroll to bottom after messages load
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });

      print('✅ [CHAT_SCREEN] Chat initialized successfully\n');
    } catch (e) {
      print('❌ [CHAT_SCREEN] Initialization error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _setupMessageListener() {
    final chatService = Provider.of<ChatService>(context, listen: false);

    // Listen for new messages
    chatService.newMessageStream.listen((message) {
      if (message.tripId == widget.tripId) {
        print('📩 [CHAT_SCREEN] New message received: ${message.text}');

        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: true);
        });

        // Mark as read if not from current user
        if (!message.isFromMe(_currentUserId ?? '')) {
          _markMessagesAsRead();
        }
      }
    });
  }

  void _onTextChanged() {
    final text = _messageController.text.trim();

    if (text.isNotEmpty && !_isTyping) {
      // Start typing
      _isTyping = true;
      _sendTypingIndicator(true);

      // Cancel previous timer
      _typingTimer?.cancel();

      // Set timer to stop typing after 3 seconds
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isTyping = false;
        _sendTypingIndicator(false);
      });
    } else if (text.isEmpty && _isTyping) {
      // Stop typing
      _isTyping = false;
      _sendTypingIndicator(false);
      _typingTimer?.cancel();
    } else if (text.isNotEmpty) {
      // Reset timer if still typing
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _isTyping = false;
        _sendTypingIndicator(false);
      });
    }
  }

  void _sendTypingIndicator(bool isTyping) {
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.sendTypingIndicator(widget.tripId, isTyping);
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();

    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      print('📤 [CHAT_SCREEN] Sending message: $text');

      final chatService = Provider.of<ChatService>(context, listen: false);
      final success = await chatService.sendMessage(widget.tripId, text);

      if (success) {
        // Clear input
        _messageController.clear();

        // Stop typing indicator
        _isTyping = false;
        _sendTypingIndicator(false);
        _typingTimer?.cancel();

        // Scroll to bottom
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(animated: true);
        });

        print('✅ [CHAT_SCREEN] Message sent successfully\n');
      } else {
        _showErrorSnackBar('Failed to send message');
      }
    } catch (e) {
      print('❌ [CHAT_SCREEN] Send error: $e');
      _showErrorSnackBar('Failed to send message');
    } finally {
      setState(() {
        _isSending = false;
      });
    }
  }

  Future<void> _markMessagesAsRead() async {
    final chatService = Provider.of<ChatService>(context, listen: false);
    await chatService.markAsRead(widget.tripId);
  }

  void _scrollToBottom({bool animated = false}) {
    if (!_scrollController.hasClients) return;

    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
        title: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryGold,
              child: widget.otherUserAvatar != null
                  ? ClipOval(
                child: Image.network(
                  widget.otherUserAvatar!,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                ),
              )
                  : _buildDefaultAvatar(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.otherUserName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Consumer<ChatService>(
                    builder: (context, chatService, _) {
                      final isTyping = chatService.isTyping(widget.tripId);
                      return Text(
                        isTyping ? 'Typing...' : 'Active',
                        style: TextStyle(
                          fontSize: 12,
                          color: isTyping
                              ? AppColors.primaryGold
                              : Colors.white70,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryGold,
        ),
      )
          : Column(
        children: [
          // Messages list
          Expanded(
            child: Consumer<ChatService>(
              builder: (context, chatService, _) {
                final messages = chatService.getMessages(widget.tripId);

                if (messages.isEmpty) {
                  return _buildEmptyState();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.isFromMe(_currentUserId ?? '');

                    // Show date separator if needed
                    bool showDateSeparator = false;
                    if (index == 0) {
                      showDateSeparator = true;
                    } else {
                      final prevMessage = messages[index - 1];
                      showDateSeparator = !_isSameDay(
                        prevMessage.createdAt,
                        message.createdAt,
                      );
                    }

                    return Column(
                      children: [
                        if (showDateSeparator)
                          _buildDateSeparator(message.createdAt),
                        _buildMessageBubble(message, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // Typing indicator
          Consumer<ChatService>(
            builder: (context, chatService, _) {
              final isTyping = chatService.isTyping(widget.tripId);

              if (!isTyping) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildTypingDot(delay: 0),
                          const SizedBox(width: 4),
                          _buildTypingDot(delay: 150),
                          const SizedBox(width: 4),
                          _buildTypingDot(delay: 300),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Input area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Text(
      widget.otherUserName.isNotEmpty
          ? widget.otherUserName[0].toUpperCase()
          : '?',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryGold.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              size: 40,
              color: AppColors.primaryGold,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start the conversation!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    String dateText;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      dateText = 'Today';
    } else if (messageDate == yesterday) {
      dateText = 'Yesterday';
    } else {
      dateText = DateFormat('MMM dd, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade300)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              dateText,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade300)),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    final time = DateFormat('HH:mm').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryGold,
              child: Text(
                widget.otherUserName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isMe ? Colors.black : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMe ? 20 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMe ? Colors.white60 : Colors.black45,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: message.isRead
                              ? AppColors.primaryGold
                              : Colors.white60,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot({required int delay}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, -4 * (1 - (value - 0.5).abs() * 2)),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.black54,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Loop animation
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                textCapitalization: TextCapitalization.sentences,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                decoration: InputDecoration(
                  hintText: tr('chat.typeMessage'),
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: Colors.black38,
                    fontSize: 15,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    AppColors.primaryGold,
                    AppColors.primaryYellow,
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGold.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isSending
                  ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                ),
              )
                  : const Icon(
                Icons.send,
                color: Colors.black,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
}