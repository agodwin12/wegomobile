// lib/models/support_models.dart
// WEGO - Support System Models
// Handles support tickets, FAQs, and problem reports

// ═══════════════════════════════════════════════════════════════════
// SUPPORT TICKET MODEL
// ═══════════════════════════════════════════════════════════════════

class SupportTicket {
  final String id;
  final String userId;
  final String subject;
  final String description;
  final String category;
  final String priority;
  final String status;
  final List<String>? attachments;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final List<TicketMessage>? messages;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    this.attachments,
    this.assignedTo,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.messages,
  });

  // From JSON (API response)
  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as String,
      userId: json['userId'] as String,
      subject: json['subject'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      priority: json['priority'] as String,
      status: json['status'] as String,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'] as List)
          : null,
      assignedTo: json['assignedTo'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.parse(json['resolvedAt'] as String)
          : null,
      messages: json['messages'] != null
          ? (json['messages'] as List)
          .map((m) => TicketMessage.fromJson(m as Map<String, dynamic>))
          .toList()
          : null,
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'subject': subject,
      'description': description,
      'category': category,
      'priority': priority,
      'status': status,
      'attachments': attachments,
      'assignedTo': assignedTo,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
      'messages': messages?.map((m) => m.toJson()).toList(),
    };
  }

  // Copy with
  SupportTicket copyWith({
    String? id,
    String? userId,
    String? subject,
    String? description,
    String? category,
    String? priority,
    String? status,
    List<String>? attachments,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? resolvedAt,
    List<TicketMessage>? messages,
  }) {
    return SupportTicket(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      subject: subject ?? this.subject,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      attachments: attachments ?? this.attachments,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      messages: messages ?? this.messages,
    );
  }

  // Helper: Get status badge color
  String getStatusColor() {
    switch (status.toLowerCase()) {
      case 'open':
      case 'new':
        return '#FFDC71'; // Gold
      case 'in_progress':
      case 'investigating':
        return '#3B82F6'; // Blue
      case 'resolved':
      case 'closed':
        return '#10B981'; // Green
      case 'rejected':
        return '#EF4444'; // Red
      default:
        return '#6B7280'; // Gray
    }
  }

  // Helper: Get priority badge color
  String getPriorityColor() {
    switch (priority.toLowerCase()) {
      case 'urgent':
      case 'critical':
        return '#EF4444'; // Red
      case 'high':
        return '#F59E0B'; // Orange
      case 'medium':
        return '#FFDC71'; // Gold
      case 'low':
        return '#10B981'; // Green
      default:
        return '#6B7280'; // Gray
    }
  }

  // Helper: Get formatted status
  String getFormattedStatus() {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  // Helper: Check if ticket is resolved
  bool get isResolved => status.toLowerCase() == 'resolved' || status.toLowerCase() == 'closed';

  // Helper: Check if ticket is open
  bool get isOpen => status.toLowerCase() == 'open' || status.toLowerCase() == 'new';

  // Helper: Get time since creation
  String getTimeSinceCreation() {
    final duration = DateTime.now().difference(createdAt);

    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''} ago';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''} ago';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Helper: Get resolution time (if resolved)
  String? getResolutionTime() {
    if (resolvedAt == null) return null;

    final duration = resolvedAt!.difference(createdAt);

    if (duration.inDays > 0) {
      return '${duration.inDays} day${duration.inDays > 1 ? 's' : ''}';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hour${duration.inHours > 1 ? 's' : ''}';
    } else {
      return '${duration.inMinutes} minute${duration.inMinutes > 1 ? 's' : ''}';
    }
  }

  @override
  String toString() {
    return 'SupportTicket(id: $id, subject: $subject, status: $status)';
  }
}

// ═══════════════════════════════════════════════════════════════════
// TICKET MESSAGE MODEL
// ═══════════════════════════════════════════════════════════════════

class TicketMessage {
  final String id;
  final String ticketId;
  final String fromUserId;
  final String fromUserName;
  final String message;
  final bool isStaff;
  final List<String>? attachments;
  final DateTime createdAt;

  TicketMessage({
    required this.id,
    required this.ticketId,
    required this.fromUserId,
    required this.fromUserName,
    required this.message,
    required this.isStaff,
    this.attachments,
    required this.createdAt,
  });

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      id: json['id'] as String,
      ticketId: json['ticketId'] as String,
      fromUserId: json['fromUserId'] as String,
      fromUserName: json['fromUserName'] as String,
      message: json['message'] as String,
      isStaff: json['isStaff'] as bool? ?? false,
      attachments: json['attachments'] != null
          ? List<String>.from(json['attachments'] as List)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticketId': ticketId,
      'fromUserId': fromUserId,
      'fromUserName': fromUserName,
      'message': message,
      'isStaff': isStaff,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Helper: Get formatted time
  String getFormattedTime() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  String toString() {
    return 'TicketMessage(from: $fromUserName, isStaff: $isStaff)';
  }
}

// ═══════════════════════════════════════════════════════════════════
// FAQ ITEM MODEL
// ═══════════════════════════════════════════════════════════════════

class FAQItem {
  final int id;
  final String category;
  final String question;
  final String answer;
  final List<String> tags;
  final int viewCount;
  final int helpfulCount;
  bool isExpanded; // Changed from final to mutable
  final DateTime createdAt;
  final DateTime updatedAt;

  FAQItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.tags,
    required this.viewCount,
    required this.helpfulCount,
    this.isExpanded = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FAQItem.fromJson(Map<String, dynamic> json) {
    return FAQItem(
      id: json['id'] as int,
      category: json['category'] as String,
      question: json['question'] as String,
      answer: json['answer'] as String,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      viewCount: json['view_count'] as int? ?? json['viewCount'] as int? ?? 0,
      helpfulCount: json['helpful_count'] as int? ?? json['helpfulCount'] as int? ?? 0,
      isExpanded: false,
      createdAt: DateTime.parse(json['created_at'] as String? ?? json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'question': question,
      'answer': answer,
      'tags': tags,
      'view_count': viewCount,
      'helpful_count': helpfulCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  FAQItem copyWith({
    int? id,
    String? category,
    String? question,
    String? answer,
    List<String>? tags,
    int? viewCount,
    int? helpfulCount,
    bool? isExpanded,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FAQItem(
      id: id ?? this.id,
      category: category ?? this.category,
      question: question ?? this.question,
      answer: answer ?? this.answer,
      tags: tags ?? this.tags,
      viewCount: viewCount ?? this.viewCount,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isExpanded: isExpanded ?? this.isExpanded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// FAQ CATEGORY MODEL
// ═══════════════════════════════════════════════════════════════════

class FAQCategory {
  final String id;
  final String name;
  final String icon;
  final String description;
  final int itemCount;
  final List<FAQItem>? items;

  FAQCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.itemCount,
    this.items,
  });

  factory FAQCategory.fromJson(Map<String, dynamic> json) {
    return FAQCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String,
      description: json['description'] as String,
      itemCount: json['itemCount'] as int? ?? 0,
      items: json['items'] != null
          ? (json['items'] as List)
          .map((item) => FAQItem.fromJson(item as Map<String, dynamic>))
          .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'description': description,
      'itemCount': itemCount,
      'items': items?.map((item) => item.toJson()).toList(),
    };
  }

  @override
  String toString() {
    return 'FAQCategory(name: $name, items: $itemCount)';
  }
}

// ═══════════════════════════════════════════════════════════════════
// PROBLEM REPORT MODEL
// ═══════════════════════════════════════════════════════════════════

class ProblemReport {
  final String? id;
  final String userId;
  final String type; // 'bug', 'feature_request', 'feedback', 'other'
  final String title;
  final String description;
  final String? relatedTripId;
  final String? relatedServiceId;
  final List<String>? screenshots;
  final Map<String, dynamic>? deviceInfo;
  final String status;
  final DateTime? createdAt;

  ProblemReport({
    this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.description,
    this.relatedTripId,
    this.relatedServiceId,
    this.screenshots,
    this.deviceInfo,
    this.status = 'pending',
    this.createdAt,
  });

  factory ProblemReport.fromJson(Map<String, dynamic> json) {
    return ProblemReport(
      id: json['id'] as String?,
      userId: json['userId'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      relatedTripId: json['relatedTripId'] as String?,
      relatedServiceId: json['relatedServiceId'] as String?,
      screenshots: json['screenshots'] != null
          ? List<String>.from(json['screenshots'] as List)
          : null,
      deviceInfo: json['deviceInfo'] as Map<String, dynamic>?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'userId': userId,
      'type': type,
      'title': title,
      'description': description,
      if (relatedTripId != null) 'relatedTripId': relatedTripId,
      if (relatedServiceId != null) 'relatedServiceId': relatedServiceId,
      if (screenshots != null) 'screenshots': screenshots,
      if (deviceInfo != null) 'deviceInfo': deviceInfo,
      'status': status,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }

  // Helper: Get formatted type
  String getFormattedType() {
    switch (type.toLowerCase()) {
      case 'bug':
        return 'Bug Report';
      case 'feature_request':
        return 'Feature Request';
      case 'feedback':
        return 'Feedback';
      default:
        return 'Other';
    }
  }

  // Helper: Get type icon
  String getTypeIcon() {
    switch (type.toLowerCase()) {
      case 'bug':
        return '🐛';
      case 'feature_request':
        return '💡';
      case 'feedback':
        return '💬';
      default:
        return '📝';
    }
  }

  @override
  String toString() {
    return 'ProblemReport(type: $type, title: $title)';
  }
}
