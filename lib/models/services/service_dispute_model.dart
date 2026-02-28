// lib/models/services/service_dispute_model.dart
// Service Dispute Model - Production Ready

/// ═══════════════════════════════════════════════════════════════════════
/// ENUMS
/// ═══════════════════════════════════════════════════════════════════════

enum DisputeStatus {
  open,
  investigating,
  awaitingResponse,
  resolved,
  closed;

  String get displayName {
    switch (this) {
      case DisputeStatus.open:
        return 'Open';
      case DisputeStatus.investigating:
        return 'Investigating';
      case DisputeStatus.awaitingResponse:
        return 'Awaiting Response';
      case DisputeStatus.resolved:
        return 'Resolved';
      case DisputeStatus.closed:
        return 'Closed';
    }
  }

  static DisputeStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'open':
        return DisputeStatus.open;
      case 'investigating':
        return DisputeStatus.investigating;
      case 'awaitingresponse':
        return DisputeStatus.awaitingResponse;
      case 'resolved':
        return DisputeStatus.resolved;
      case 'closed':
        return DisputeStatus.closed;
      default:
        return DisputeStatus.open;
    }
  }

  // Status checks
  bool get isOpen => this == DisputeStatus.open;
  bool get isActive => this == DisputeStatus.open ||
      this == DisputeStatus.investigating ||
      this == DisputeStatus.awaitingResponse;
  bool get isResolved => this == DisputeStatus.resolved;
  bool get isClosed => this == DisputeStatus.closed;
  bool get canRespond => this == DisputeStatus.open ||
      this == DisputeStatus.awaitingResponse;

  // Status color for UI
  String get colorHex {
    switch (this) {
      case DisputeStatus.open:
        return '#F44336'; // Red - urgent
      case DisputeStatus.investigating:
        return '#FF9800'; // Orange - in progress
      case DisputeStatus.awaitingResponse:
        return '#2196F3'; // Blue - waiting
      case DisputeStatus.resolved:
        return '#4CAF50'; // Green - success
      case DisputeStatus.closed:
        return '#9E9E9E'; // Gray - finished
    }
  }
}

enum DisputeType {
  serviceNotProvided,
  serviceQuality,
  paymentIssue,
  behaviorConduct,
  fraudScam,
  other;

  String get displayName {
    switch (this) {
      case DisputeType.serviceNotProvided:
        return 'Service Not Provided';
      case DisputeType.serviceQuality:
        return 'Service Quality Issue';
      case DisputeType.paymentIssue:
        return 'Payment Problem';
      case DisputeType.behaviorConduct:
        return 'Behavior & Conduct';
      case DisputeType.fraudScam:
        return 'Fraud/Scam';
      case DisputeType.other:
        return 'Other';
    }
  }

  static DisputeType fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'servicenotprovided':
        return DisputeType.serviceNotProvided;
      case 'servicequality':
        return DisputeType.serviceQuality;
      case 'paymentissue':
        return DisputeType.paymentIssue;
      case 'behaviorconduct':
        return DisputeType.behaviorConduct;
      case 'fraudscam':
        return DisputeType.fraudScam;
      case 'other':
        return DisputeType.other;
      default:
        return DisputeType.other;
    }
  }
}

enum ResolutionType {
  fullRefund,
  partialRefund,
  noRefund,
  redoService,
  mutualAgreement,
  providerBanned,
  customerBanned;

  String get displayName {
    switch (this) {
      case ResolutionType.fullRefund:
        return 'Full Refund';
      case ResolutionType.partialRefund:
        return 'Partial Refund';
      case ResolutionType.noRefund:
        return 'No Refund';
      case ResolutionType.redoService:
        return 'Redo Service';
      case ResolutionType.mutualAgreement:
        return 'Mutual Agreement';
      case ResolutionType.providerBanned:
        return 'Provider Banned';
      case ResolutionType.customerBanned:
        return 'Customer Banned';
    }
  }

  static ResolutionType fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'fullrefund':
        return ResolutionType.fullRefund;
      case 'partialrefund':
        return ResolutionType.partialRefund;
      case 'norefund':
        return ResolutionType.noRefund;
      case 'redoservice':
        return ResolutionType.redoService;
      case 'mutualagreement':
        return ResolutionType.mutualAgreement;
      case 'providerbanned':
        return ResolutionType.providerBanned;
      case 'customerbanned':
        return ResolutionType.customerBanned;
      default:
        return ResolutionType.mutualAgreement;
    }
  }
}

enum DisputePriority {
  low,
  medium,
  high,
  urgent;

  String get displayName {
    switch (this) {
      case DisputePriority.low:
        return 'Low';
      case DisputePriority.medium:
        return 'Medium';
      case DisputePriority.high:
        return 'High';
      case DisputePriority.urgent:
        return 'Urgent';
    }
  }

  static DisputePriority fromString(String value) {
    switch (value.toLowerCase()) {
      case 'low':
        return DisputePriority.low;
      case 'medium':
        return DisputePriority.medium;
      case 'high':
        return DisputePriority.high;
      case 'urgent':
        return DisputePriority.urgent;
      default:
        return DisputePriority.medium;
    }
  }

  String get colorHex {
    switch (this) {
      case DisputePriority.low:
        return '#4CAF50'; // Green
      case DisputePriority.medium:
        return '#FF9800'; // Orange
      case DisputePriority.high:
        return '#FF5722'; // Deep Orange
      case DisputePriority.urgent:
        return '#F44336'; // Red
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICE DISPUTE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class ServiceDispute {
  final int id;
  final String disputeId; // DSP-YYYYMMDD-XXX
  final int requestId;
  final int filedBy;
  final String filedByType;
  final int defendantId;
  final String defendantType;
  final DisputeType disputeType;
  final String description;
  final String resolutionRequested;
  final double? refundAmount;
  final List<String> evidencePhotos;
  final DisputeStatus status;
  final DisputePriority priority;
  final int? assignedTo;
  final DateTime? assignedAt;
  final String? defendantResponse;
  final List<String>? defendantEvidence;
  final DateTime? defendantRespondedAt;
  final String? investigationNotes;
  final ResolutionType? resolutionType;
  final String? resolutionDetails;
  final int? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Nested data
  final Map<String, dynamic>? filer;
  final Map<String, dynamic>? defendant;
  final Map<String, dynamic>? request;
  final Map<String, dynamic>? assignedEmployee;
  final Map<String, dynamic>? resolver;

  ServiceDispute({
    required this.id,
    required this.disputeId,
    required this.requestId,
    required this.filedBy,
    required this.filedByType,
    required this.defendantId,
    required this.defendantType,
    required this.disputeType,
    required this.description,
    required this.resolutionRequested,
    this.refundAmount,
    required this.evidencePhotos,
    required this.status,
    required this.priority,
    this.assignedTo,
    this.assignedAt,
    this.defendantResponse,
    this.defendantEvidence,
    this.defendantRespondedAt,
    this.investigationNotes,
    this.resolutionType,
    this.resolutionDetails,
    this.resolvedBy,
    this.resolvedAt,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
    this.filer,
    this.defendant,
    this.request,
    this.assignedEmployee,
    this.resolver,
  });

  /// ═══════════════════════════════════════════════════════════════════════
  /// JSON SERIALIZATION
  /// ═══════════════════════════════════════════════════════════════════════

  factory ServiceDispute.fromJson(Map<String, dynamic> json) {
    return ServiceDispute(
      id: json['id'] as int,
      disputeId: json['dispute_id'] as String,
      requestId: json['request_id'] as int,
      filedBy: json['filed_by'] as int,
      filedByType: json['filed_by_type'] as String,
      defendantId: json['defendant_id'] as int,
      defendantType: json['defendant_type'] as String,
      disputeType: DisputeType.fromString(json['dispute_type'] as String),
      description: json['description'] as String,
      resolutionRequested: json['resolution_requested'] as String,
      refundAmount: json['refund_amount'] != null
          ? (json['refund_amount'] as num).toDouble()
          : null,
      evidencePhotos: json['evidence_photos'] != null
          ? List<String>.from(json['evidence_photos'] as List)
          : [],
      status: DisputeStatus.fromString(json['status'] as String),
      priority: DisputePriority.fromString(json['priority'] as String? ?? 'medium'),
      assignedTo: json['assigned_to'] as int?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      defendantResponse: json['defendant_response'] as String?,
      defendantEvidence: json['defendant_evidence'] != null
          ? List<String>.from(json['defendant_evidence'] as List)
          : null,
      defendantRespondedAt: json['defendant_responded_at'] != null
          ? DateTime.parse(json['defendant_responded_at'] as String)
          : null,
      investigationNotes: json['investigation_notes'] as String?,
      resolutionType: json['resolution_type'] != null
          ? ResolutionType.fromString(json['resolution_type'] as String)
          : null,
      resolutionDetails: json['resolution_details'] as String?,
      resolvedBy: json['resolved_by'] as int?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      closedAt: json['closed_at'] != null
          ? DateTime.parse(json['closed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      filer: json['filer'] as Map<String, dynamic>?,
      defendant: json['defendant'] as Map<String, dynamic>?,
      request: json['request'] as Map<String, dynamic>?,
      assignedEmployee: json['assigned_employee'] as Map<String, dynamic>?,
      resolver: json['resolver'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dispute_id': disputeId,
      'request_id': requestId,
      'filed_by': filedBy,
      'filed_by_type': filedByType,
      'defendant_id': defendantId,
      'defendant_type': defendantType,
      'dispute_type': disputeType.name,
      'description': description,
      'resolution_requested': resolutionRequested,
      'refund_amount': refundAmount,
      'evidence_photos': evidencePhotos,
      'status': status.name,
      'priority': priority.name,
      'assigned_to': assignedTo,
      'assigned_at': assignedAt?.toIso8601String(),
      'defendant_response': defendantResponse,
      'defendant_evidence': defendantEvidence,
      'defendant_responded_at': defendantRespondedAt?.toIso8601String(),
      'investigation_notes': investigationNotes,
      'resolution_type': resolutionType?.name,
      'resolution_details': resolutionDetails,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toIso8601String(),
      'closed_at': closedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'filer': filer,
      'defendant': defendant,
      'request': request,
      'assigned_employee': assignedEmployee,
      'resolver': resolver,
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER METHODS
  /// ═══════════════════════════════════════════════════════════════════════

  /// Get filer name
  String get filerName {
    if (filer == null) return 'User';
    return '${filer!['first_name']} ${filer!['last_name']}';
  }

  /// Get defendant name
  String get defendantName {
    if (defendant == null) return 'User';
    return '${defendant!['first_name']} ${defendant!['last_name']}';
  }

  /// Get request ID display
  String get requestIdDisplay {
    if (request == null) return '#$requestId';
    return request!['request_id'] as String? ?? '#$requestId';
  }

  /// Get service title from request
  String get serviceTitle {
    if (request == null || request!['listing'] == null) return 'Service';
    return request!['listing']['title'] as String? ?? 'Service';
  }

  /// Get assigned employee name
  String? get assignedEmployeeName {
    if (assignedEmployee == null) return null;
    return '${assignedEmployee!['first_name']} ${assignedEmployee!['last_name']}';
  }

  /// Get resolver name
  String? get resolverName {
    if (resolver == null) return null;
    return '${resolver!['first_name']} ${resolver!['last_name']}';
  }

  /// Check if has evidence
  bool get hasEvidence => evidencePhotos.isNotEmpty;

  /// Check if defendant has responded
  bool get defendantHasResponded =>
      defendantResponse != null && defendantResponse!.isNotEmpty;

  /// Check if has defendant evidence
  bool get hasDefendantEvidence =>
      defendantEvidence != null && defendantEvidence!.isNotEmpty;

  /// Get evidence count
  int get evidenceCount => evidencePhotos.length;

  /// Get defendant evidence count
  int get defendantEvidenceCount => defendantEvidence?.length ?? 0;

  /// Get total evidence count
  int get totalEvidenceCount => evidenceCount + defendantEvidenceCount;

  /// Check if assigned
  bool get isAssigned => assignedTo != null;

  /// Check if resolved
  bool get isResolved => resolutionType != null;

  /// Get refund display
  String get refundDisplay {
    if (refundAmount == null) return 'No refund';
    return '${refundAmount!.toStringAsFixed(0)} FCFA';
  }

  /// Get short description (first 100 chars)
  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 100)}...';
  }

  /// Get relative time since filed
  String get timeSinceFiled {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  /// Get time since resolved
  String? get timeSinceResolved {
    if (resolvedAt == null) return null;

    final now = DateTime.now();
    final difference = now.difference(resolvedAt!);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return 'Recently';
    }
  }

  /// Get resolution outcome display
  String get resolutionOutcome {
    if (resolutionType == null) return 'Pending resolution';

    final buffer = StringBuffer(resolutionType!.displayName);

    if (refundAmount != null &&
        (resolutionType == ResolutionType.fullRefund ||
            resolutionType == ResolutionType.partialRefund)) {
      buffer.write(' (${refundDisplay})');
    }

    return buffer.toString();
  }

  /// Get action needed text
  String get actionNeeded {
    if (status.isOpen && !isAssigned) {
      return 'Awaiting admin assignment';
    } else if (status == DisputeStatus.awaitingResponse && !defendantHasResponded) {
      return 'Awaiting defendant response';
    } else if (status == DisputeStatus.investigating) {
      return 'Under investigation';
    } else if (status.isResolved) {
      return 'Resolved';
    } else if (status.isClosed) {
      return 'Closed';
    }
    return 'No action needed';
  }

  /// Get formatted date
  String get formattedCreatedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  /// Get resolution summary
  String get resolutionSummary {
    if (!isResolved) return 'Not yet resolved';

    final buffer = StringBuffer();
    buffer.write(resolutionOutcome);

    if (resolutionDetails != null) {
      buffer.write('\n${resolutionDetails}');
    }

    if (resolverName != null) {
      buffer.write('\nResolved by: $resolverName');
    }

    if (timeSinceResolved != null) {
      buffer.write('\nResolved: $timeSinceResolved');
    }

    return buffer.toString();
  }

  /// Check if user is filer
  bool isFiledByUser(int userId) => filedBy == userId;

  /// Check if user is defendant
  bool isDefendantUser(int userId) => defendantId == userId;

  /// Check if user is involved
  bool isUserInvolved(int userId) =>
      isFiledByUser(userId) || isDefendantUser(userId);

  /// ═══════════════════════════════════════════════════════════════════════
  /// COPY WITH
  /// ═══════════════════════════════════════════════════════════════════════

  ServiceDispute copyWith({
    int? id,
    String? disputeId,
    int? requestId,
    int? filedBy,
    String? filedByType,
    int? defendantId,
    String? defendantType,
    DisputeType? disputeType,
    String? description,
    String? resolutionRequested,
    double? refundAmount,
    List<String>? evidencePhotos,
    DisputeStatus? status,
    DisputePriority? priority,
    int? assignedTo,
    DateTime? assignedAt,
    String? defendantResponse,
    List<String>? defendantEvidence,
    DateTime? defendantRespondedAt,
    String? investigationNotes,
    ResolutionType? resolutionType,
    String? resolutionDetails,
    int? resolvedBy,
    DateTime? resolvedAt,
    DateTime? closedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? filer,
    Map<String, dynamic>? defendant,
    Map<String, dynamic>? request,
    Map<String, dynamic>? assignedEmployee,
    Map<String, dynamic>? resolver,
  }) {
    return ServiceDispute(
      id: id ?? this.id,
      disputeId: disputeId ?? this.disputeId,
      requestId: requestId ?? this.requestId,
      filedBy: filedBy ?? this.filedBy,
      filedByType: filedByType ?? this.filedByType,
      defendantId: defendantId ?? this.defendantId,
      defendantType: defendantType ?? this.defendantType,
      disputeType: disputeType ?? this.disputeType,
      description: description ?? this.description,
      resolutionRequested: resolutionRequested ?? this.resolutionRequested,
      refundAmount: refundAmount ?? this.refundAmount,
      evidencePhotos: evidencePhotos ?? this.evidencePhotos,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedAt: assignedAt ?? this.assignedAt,
      defendantResponse: defendantResponse ?? this.defendantResponse,
      defendantEvidence: defendantEvidence ?? this.defendantEvidence,
      defendantRespondedAt: defendantRespondedAt ?? this.defendantRespondedAt,
      investigationNotes: investigationNotes ?? this.investigationNotes,
      resolutionType: resolutionType ?? this.resolutionType,
      resolutionDetails: resolutionDetails ?? this.resolutionDetails,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      closedAt: closedAt ?? this.closedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      filer: filer ?? this.filer,
      defendant: defendant ?? this.defendant,
      request: request ?? this.request,
      assignedEmployee: assignedEmployee ?? this.assignedEmployee,
      resolver: resolver ?? this.resolver,
    );
  }

  @override
  String toString() {
    return 'ServiceDispute(id: $id, disputeId: $disputeId, type: ${disputeType.displayName}, status: ${status.displayName})';
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// DISPUTE LIST RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class DisputeListResponse {
  final bool success;
  final String message;
  final List<ServiceDispute> disputes;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  DisputeListResponse({
    required this.success,
    required this.message,
    required this.disputes,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory DisputeListResponse.fromJson(Map<String, dynamic> json) {
    return DisputeListResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      disputes: (json['data']['disputes'] as List)
          .map((item) => ServiceDispute.fromJson(item as Map<String, dynamic>))
          .toList(),
      total: json['data']['pagination']['total'] as int,
      page: json['data']['pagination']['page'] as int,
      limit: json['data']['pagination']['limit'] as int,
      totalPages: json['data']['pagination']['total_pages'] as int,
    );
  }

  bool get hasMore => page < totalPages;
}

/// ═══════════════════════════════════════════════════════════════════════
/// SINGLE DISPUTE RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class SingleDisputeResponse {
  final bool success;
  final String message;
  final ServiceDispute dispute;

  SingleDisputeResponse({
    required this.success,
    required this.message,
    required this.dispute,
  });

  factory SingleDisputeResponse.fromJson(Map<String, dynamic> json) {
    return SingleDisputeResponse(
      success: json['success'] as bool,
      message: json['message'] as String,
      dispute: ServiceDispute.fromJson(json['data']['dispute'] as Map<String, dynamic>),
    );
  }
}