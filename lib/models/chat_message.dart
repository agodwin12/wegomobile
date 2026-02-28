// lib/models/chat_message.dart

class ChatMessage {
  final String id;
  final String tripId;
  final String text;
  final String fromUserId;
  final ChatMessageSender? sender;
  final DateTime? readAt;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.tripId,
    required this.text,
    required this.fromUserId,
    this.sender,
    this.readAt,
    required this.createdAt,
  });

  // Check if message is from current user
  bool isFromMe(String currentUserId) {
    return fromUserId == currentUserId;
  }

  // Check if message is read
  bool get isRead => readAt != null;

  // Factory constructor from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      text: json['text'] as String,
      fromUserId: json['fromUserId'] as String,
      sender: json['sender'] != null
          ? ChatMessageSender.fromJson(json['sender'] as Map<String, dynamic>)
          : null,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'text': text,
      'fromUserId': fromUserId,
      'sender': sender?.toJson(),
      'readAt': readAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? tripId,
    String? text,
    String? fromUserId,
    ChatMessageSender? sender,
    DateTime? readAt,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      text: text ?? this.text,
      fromUserId: fromUserId ?? this.fromUserId,
      sender: sender ?? this.sender,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, from: ${sender?.name ?? fromUserId}, text: $text)';
  }
}

class ChatMessageSender {
  final String uuid;
  final String name;
  final String? avatar;
  final String userType;

  ChatMessageSender({
    required this.uuid,
    required this.name,
    this.avatar,
    required this.userType,
  });

  factory ChatMessageSender.fromJson(Map<String, dynamic> json) {
    return ChatMessageSender(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      avatar: json['avatar'] as String?,
      userType: json['userType'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'name': name,
      'avatar': avatar,
      'userType': userType,
    };
  }
}