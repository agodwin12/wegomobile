// lib/models/services/service_request_model.dart
// ✅ FIXED: Robust type parsing to handle API response mismatches

import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// REQUEST STATUS ENUM
/// ═══════════════════════════════════════════════════════════════════════

enum RequestStatus {
  pending,
  accepted,
  rejected,
  inProgress,
  paymentPending,
  paymentConfirmationPending,
  paymentConfirmed,
  completed,
  cancelled,
  expired;

  String get displayName {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.accepted:
        return 'Accepted';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.inProgress:
        return 'In Progress';
      case RequestStatus.paymentPending:
        return 'Payment Pending';
      case RequestStatus.paymentConfirmationPending:
        return 'Confirming Payment';
      case RequestStatus.paymentConfirmed:
        return 'Payment Confirmed';
      case RequestStatus.completed:
        return 'Completed';
      case RequestStatus.cancelled:
        return 'Cancelled';
      case RequestStatus.expired:
        return 'Expired';
    }
  }

  static RequestStatus fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'pending':
        return RequestStatus.pending;
      case 'accepted':
        return RequestStatus.accepted;
      case 'rejected':
        return RequestStatus.rejected;
      case 'inprogress':
        return RequestStatus.inProgress;
      case 'paymentpending':
        return RequestStatus.paymentPending;
      case 'paymentconfirmationpending':
        return RequestStatus.paymentConfirmationPending;
      case 'paymentconfirmed':
        return RequestStatus.paymentConfirmed;
      case 'completed':
        return RequestStatus.completed;
      case 'cancelled':
      case 'canceled':
        return RequestStatus.cancelled;
      case 'expired':
        return RequestStatus.expired;
      default:
        debugPrint('⚠️ Unknown status: $value, defaulting to pending');
        return RequestStatus.pending;
    }
  }

  // Status checks
  bool get isPending => this == RequestStatus.pending;
  bool get isAccepted => this == RequestStatus.accepted;
  bool get isActive => this == RequestStatus.accepted || this == RequestStatus.inProgress;
  bool get isInProgress => this == RequestStatus.inProgress;
  bool get needsPayment => this == RequestStatus.paymentPending;
  bool get needsConfirmation => this == RequestStatus.paymentConfirmationPending;
  bool get isCompleted => this == RequestStatus.completed;
  bool get isCancelled => this == RequestStatus.cancelled;
  bool get isFinished => isCompleted || isCancelled || this == RequestStatus.expired;
  bool get canCancel => isPending || isAccepted;
  bool get canRate => this == RequestStatus.completed;

  // Status color for UI
  String get colorHex {
    switch (this) {
      case RequestStatus.pending:
        return '#FFA500'; // Orange
      case RequestStatus.accepted:
      case RequestStatus.inProgress:
        return '#2196F3'; // Blue
      case RequestStatus.paymentPending:
      case RequestStatus.paymentConfirmationPending:
        return '#FF9800'; // Amber
      case RequestStatus.paymentConfirmed:
      case RequestStatus.completed:
        return '#4CAF50'; // Green
      case RequestStatus.rejected:
      case RequestStatus.cancelled:
        return '#F44336'; // Red
      case RequestStatus.expired:
        return '#9E9E9E'; // Gray
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// NEEDED WHEN ENUM
/// ═══════════════════════════════════════════════════════════════════════

enum NeededWhen {
  asap,
  today,
  tomorrow,
  scheduled;

  String get displayName {
    switch (this) {
      case NeededWhen.asap:
        return 'ASAP';
      case NeededWhen.today:
        return 'Today';
      case NeededWhen.tomorrow:
        return 'Tomorrow';
      case NeededWhen.scheduled:
        return 'Scheduled';
    }
  }

  static NeededWhen fromString(String value) {
    switch (value.toLowerCase()) {
      case 'asap':
        return NeededWhen.asap;
      case 'today':
        return NeededWhen.today;
      case 'tomorrow':
        return NeededWhen.tomorrow;
      case 'scheduled':
        return NeededWhen.scheduled;
      default:
        return NeededWhen.scheduled;
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// PAYMENT METHOD ENUM
/// ═══════════════════════════════════════════════════════════════════════

enum PaymentMethod {
  mtn,
  orange,
  cash;

  String get displayName {
    switch (this) {
      case PaymentMethod.mtn:
        return 'MTN Mobile Money';
      case PaymentMethod.orange:
        return 'Orange Money';
      case PaymentMethod.cash:
        return 'Cash';
    }
  }

  static PaymentMethod fromString(String value) {
    switch (value.toLowerCase().replaceAll('_', '')) {
      case 'mtn':
      case 'mtnmobilemoney':
        return PaymentMethod.mtn;
      case 'orange':
      case 'orangemoney':
        return PaymentMethod.orange;
      case 'cash':
        return PaymentMethod.cash;
      default:
        return PaymentMethod.cash;
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// SERVICE REQUEST MODEL
/// ═══════════════════════════════════════════════════════════════════════

class ServiceRequest {
  final int id;
  final String requestId; // SRV-YYYYMMDD-XXXXX
  final int listingId;
  final String customerId; // ✅ Changed from int to String (UUID)
  final String? customerType;
  final String providerId; // ✅ Changed from int to String (UUID)
  final String? providerType;
  final String description;
  final NeededWhen neededWhen;
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final String serviceLocation;
  final double? latitude;
  final double? longitude;
  final double? customerBudget;
  final List<String> photos;
  final RequestStatus status;
  final String? providerResponse;
  final String? rejectionReason;
  final DateTime? acceptedAt;
  final DateTime? rejectedAt; // ✅ Added missing field
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? workSummary;
  final double? hoursWorked;
  final double? materialsCost;
  final double? finalAmount;
  final List<String>? afterPhotos;
  final PaymentMethod? paymentMethod;
  final String? paymentProofUrl;
  final String? paymentReference;
  final DateTime? paymentMarkedAt; // ✅ Changed from paymentProofUploadedAt
  final DateTime? paymentConfirmedAt;
  final double? commissionPercentage; // ✅ Added field
  final double? commissionAmount;
  final double? providerNetAmount; // ✅ Changed from providerEarnings
  final String? cancellationReason;
  final String? cancelledBy; // ✅ Changed from int to String (UUID)
  final DateTime? cancelledAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Nested data
  final Map<String, dynamic>? customer;
  final Map<String, dynamic>? provider;
  final Map<String, dynamic>? listing;

  ServiceRequest({
    required this.id,
    required this.requestId,
    required this.listingId,
    required this.customerId,
    this.customerType,
    required this.providerId,
    this.providerType,
    required this.description,
    required this.neededWhen,
    this.scheduledDate,
    this.scheduledTime,
    required this.serviceLocation,
    this.latitude,
    this.longitude,
    this.customerBudget,
    required this.photos,
    required this.status,
    this.providerResponse,
    this.rejectionReason,
    this.acceptedAt,
    this.rejectedAt,
    this.startedAt,
    this.completedAt,
    this.workSummary,
    this.hoursWorked,
    this.materialsCost,
    this.finalAmount,
    this.afterPhotos,
    this.paymentMethod,
    this.paymentProofUrl,
    this.paymentReference,
    this.paymentMarkedAt,
    this.paymentConfirmedAt,
    this.commissionPercentage,
    this.commissionAmount,
    this.providerNetAmount,
    this.cancellationReason,
    this.cancelledBy,
    this.cancelledAt,
    this.expiresAt,
    required this.createdAt,
    required this.updatedAt,
    this.customer,
    this.provider,
    this.listing,
  });

  /// ═══════════════════════════════════════════════════════════════════════
  /// TYPE PARSING HELPERS
  /// ═══════════════════════════════════════════════════════════════════════

  static int _parseInt(dynamic value, {int defaultValue = 0}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? defaultValue;
    if (value is double) return value.toInt();
    return defaultValue;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        debugPrint('❌ Error parsing datetime: $value - $e');
        return null;
      }
    }
    return null;
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String && value.isNotEmpty) {
      // Handle comma-separated string or JSON array string
      if (value.startsWith('[')) {
        // It's a JSON array string, needs proper parsing
        return [];
      }
      return value.split(',').map((e) => e.trim()).toList();
    }
    return [];
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// JSON SERIALIZATION
  /// ═══════════════════════════════════════════════════════════════════════

  factory ServiceRequest.fromJson(Map<String, dynamic> json) {
    try {
      return ServiceRequest(
        id: _parseInt(json['id']),
        requestId: json['request_id']?.toString() ?? '',
        listingId: _parseInt(json['listing_id']),
        customerId: json['customer_id']?.toString() ?? '', // ✅ UUID as String
        customerType: json['customer_type']?.toString(),
        providerId: json['provider_id']?.toString() ?? '', // ✅ UUID as String
        providerType: json['provider_type']?.toString(),
        description: json['description']?.toString() ?? '',
        neededWhen: NeededWhen.fromString(json['needed_when']?.toString() ?? 'asap'),
        scheduledDate: _parseDateTime(json['scheduled_date']),
        scheduledTime: json['scheduled_time']?.toString(),
        serviceLocation: json['service_location']?.toString() ?? '',
        latitude: _parseDouble(json['latitude']),
        longitude: _parseDouble(json['longitude']),
        customerBudget: _parseDouble(json['customer_budget']),
        photos: _parseStringList(json['photos']),
        status: RequestStatus.fromString(json['status']?.toString() ?? 'pending'),
        providerResponse: json['provider_response']?.toString(),
        rejectionReason: json['rejection_reason']?.toString(),
        acceptedAt: _parseDateTime(json['accepted_at']),
        rejectedAt: _parseDateTime(json['rejected_at']),
        startedAt: _parseDateTime(json['started_at']),
        completedAt: _parseDateTime(json['completed_at']),
        workSummary: json['work_summary']?.toString(),
        hoursWorked: _parseDouble(json['hours_worked']),
        materialsCost: _parseDouble(json['materials_cost']),
        finalAmount: _parseDouble(json['final_amount']),
        afterPhotos: json['after_photos'] != null
            ? _parseStringList(json['after_photos'])
            : null,
        paymentMethod: json['payment_method'] != null
            ? PaymentMethod.fromString(json['payment_method'].toString())
            : null,
        paymentProofUrl: json['payment_proof_url']?.toString(),
        paymentReference: json['payment_reference']?.toString(),
        paymentMarkedAt: _parseDateTime(json['payment_marked_at']),
        paymentConfirmedAt: _parseDateTime(json['payment_confirmed_at']),
        commissionPercentage: _parseDouble(json['commission_percentage']),
        commissionAmount: _parseDouble(json['commission_amount']),
        providerNetAmount: _parseDouble(json['provider_net_amount']),
        cancellationReason: json['cancellation_reason']?.toString(),
        cancelledBy: json['cancelled_by']?.toString(),
        cancelledAt: _parseDateTime(json['cancelled_at']),
        expiresAt: _parseDateTime(json['expires_at']),
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        updatedAt: _parseDateTime(json['updated_at']) ?? DateTime.now(),
        customer: json['customer'] as Map<String, dynamic>?,
        provider: json['provider'] as Map<String, dynamic>?,
        listing: json['listing'] as Map<String, dynamic>?,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [SERVICE_REQUEST_MODEL] Error parsing JSON: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON data: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'request_id': requestId,
      'listing_id': listingId,
      'customer_id': customerId,
      'customer_type': customerType,
      'provider_id': providerId,
      'provider_type': providerType,
      'description': description,
      'needed_when': neededWhen.name,
      'scheduled_date': scheduledDate?.toIso8601String(),
      'scheduled_time': scheduledTime,
      'service_location': serviceLocation,
      'latitude': latitude,
      'longitude': longitude,
      'customer_budget': customerBudget,
      'photos': photos,
      'status': status.name,
      'provider_response': providerResponse,
      'rejection_reason': rejectionReason,
      'accepted_at': acceptedAt?.toIso8601String(),
      'rejected_at': rejectedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'work_summary': workSummary,
      'hours_worked': hoursWorked,
      'materials_cost': materialsCost,
      'final_amount': finalAmount,
      'after_photos': afterPhotos,
      'payment_method': paymentMethod?.name,
      'payment_proof_url': paymentProofUrl,
      'payment_reference': paymentReference,
      'payment_marked_at': paymentMarkedAt?.toIso8601String(),
      'payment_confirmed_at': paymentConfirmedAt?.toIso8601String(),
      'commission_percentage': commissionPercentage,
      'commission_amount': commissionAmount,
      'provider_net_amount': providerNetAmount,
      'cancellation_reason': cancellationReason,
      'cancelled_by': cancelledBy,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'customer': customer,
      'provider': provider,
      'listing': listing,
    };
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// HELPER METHODS
  /// ═══════════════════════════════════════════════════════════════════════

  /// Get customer name from nested data
  String get customerName {
    if (customer == null) return 'Customer';
    final firstName = customer!['first_name'] ?? customer!['firstName'] ?? '';
    final lastName = customer!['last_name'] ?? customer!['lastName'] ?? '';
    return '$firstName $lastName'.trim();
  }

  /// Get provider name from nested data
  String get providerName {
    if (provider == null) return 'Provider';
    final firstName = provider!['first_name'] ?? provider!['firstName'] ?? '';
    final lastName = provider!['last_name'] ?? provider!['lastName'] ?? '';
    return '$firstName $lastName'.trim();
  }

  /// Get listing title from nested data
  String get listingTitle {
    if (listing == null) return 'Service';
    return listing!['title']?.toString() ?? 'Service';
  }

  /// Get service category from nested data
  String get categoryName {
    if (listing == null) return '';
    return listing!['category_name']?.toString() ?? '';
  }

  /// Get scheduled datetime display
  String get scheduledDisplay {
    if (scheduledDate != null && scheduledTime != null) {
      return '${_formatDate(scheduledDate!)} at $scheduledTime';
    }
    return neededWhen.displayName;
  }

  /// Get timing display (when needed)
  String get timingDisplay {
    switch (neededWhen) {
      case NeededWhen.asap:
        return '⚡ ASAP';
      case NeededWhen.today:
        return '📅 Today';
      case NeededWhen.tomorrow:
        return '📅 Tomorrow';
      case NeededWhen.scheduled:
        return scheduledDisplay;
    }
  }

  /// Get duration display (if service started)
  String get durationDisplay {
    if (startedAt == null) return '';

    final end = completedAt ?? DateTime.now();
    final duration = end.difference(startedAt!);

    if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    }
    return '${duration.inMinutes}m';
  }

  /// Get payment amount display
  String get paymentAmountDisplay {
    if (finalAmount == null) return 'Amount pending';
    return '${finalAmount!.toStringAsFixed(0)} FCFA';
  }

  /// Get cost breakdown display
  String get costBreakdown {
    if (finalAmount == null) return '';

    final buffer = StringBuffer();
    buffer.write('Total: ${finalAmount!.toStringAsFixed(0)} FCFA');

    if (hoursWorked != null) {
      buffer.write('\n• Hours: $hoursWorked hrs');
    }
    if (materialsCost != null && materialsCost! > 0) {
      buffer.write('\n• Materials: ${materialsCost!.toStringAsFixed(0)} FCFA');
    }
    if (commissionAmount != null) {
      buffer.write('\n• Platform Fee: ${commissionAmount!.toStringAsFixed(0)} FCFA');
    }
    if (providerNetAmount != null) {
      buffer.write('\n• Provider Earnings: ${providerNetAmount!.toStringAsFixed(0)} FCFA');
    }

    return buffer.toString();
  }

  /// Get status action text (for buttons)
  String get actionText {
    switch (status) {
      case RequestStatus.pending:
        return 'Waiting for Response';
      case RequestStatus.accepted:
        return 'Start Service';
      case RequestStatus.inProgress:
        return 'Complete Service';
      case RequestStatus.paymentPending:
        return 'Upload Payment';
      case RequestStatus.paymentConfirmationPending:
        return 'Confirm Payment';
      case RequestStatus.paymentConfirmed:
        return 'Mark Complete';
      case RequestStatus.completed:
        return 'Rate Service';
      default:
        return '';
    }
  }

  /// Check if request is expired
  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Get time until expiry
  String get expiryDisplay {
    if (expiresAt == null) return '';

    final now = DateTime.now();
    if (now.isAfter(expiresAt!)) return 'Expired';

    final remaining = expiresAt!.difference(now);
    if (remaining.inHours > 24) {
      return 'Expires in ${remaining.inDays} days';
    } else if (remaining.inHours > 0) {
      return 'Expires in ${remaining.inHours} hours';
    } else {
      return 'Expires in ${remaining.inMinutes} minutes';
    }
  }

  /// Format date helper
  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// Get relative time (e.g., "2 hours ago")
  String get relativeTime {
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

  /// ═══════════════════════════════════════════════════════════════════════
  /// COPY WITH
  /// ═══════════════════════════════════════════════════════════════════════

  ServiceRequest copyWith({
    int? id,
    String? requestId,
    int? listingId,
    String? customerId,
    String? customerType,
    String? providerId,
    String? providerType,
    String? description,
    NeededWhen? neededWhen,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? serviceLocation,
    double? latitude,
    double? longitude,
    double? customerBudget,
    List<String>? photos,
    RequestStatus? status,
    String? providerResponse,
    String? rejectionReason,
    DateTime? acceptedAt,
    DateTime? rejectedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? workSummary,
    double? hoursWorked,
    double? materialsCost,
    double? finalAmount,
    List<String>? afterPhotos,
    PaymentMethod? paymentMethod,
    String? paymentProofUrl,
    String? paymentReference,
    DateTime? paymentMarkedAt,
    DateTime? paymentConfirmedAt,
    double? commissionPercentage,
    double? commissionAmount,
    double? providerNetAmount,
    String? cancellationReason,
    String? cancelledBy,
    DateTime? cancelledAt,
    DateTime? expiresAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? customer,
    Map<String, dynamic>? provider,
    Map<String, dynamic>? listing,
  }) {
    return ServiceRequest(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      listingId: listingId ?? this.listingId,
      customerId: customerId ?? this.customerId,
      customerType: customerType ?? this.customerType,
      providerId: providerId ?? this.providerId,
      providerType: providerType ?? this.providerType,
      description: description ?? this.description,
      neededWhen: neededWhen ?? this.neededWhen,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      serviceLocation: serviceLocation ?? this.serviceLocation,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      customerBudget: customerBudget ?? this.customerBudget,
      photos: photos ?? this.photos,
      status: status ?? this.status,
      providerResponse: providerResponse ?? this.providerResponse,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      workSummary: workSummary ?? this.workSummary,
      hoursWorked: hoursWorked ?? this.hoursWorked,
      materialsCost: materialsCost ?? this.materialsCost,
      finalAmount: finalAmount ?? this.finalAmount,
      afterPhotos: afterPhotos ?? this.afterPhotos,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentProofUrl: paymentProofUrl ?? this.paymentProofUrl,
      paymentReference: paymentReference ?? this.paymentReference,
      paymentMarkedAt: paymentMarkedAt ?? this.paymentMarkedAt,
      paymentConfirmedAt: paymentConfirmedAt ?? this.paymentConfirmedAt,
      commissionPercentage: commissionPercentage ?? this.commissionPercentage,
      commissionAmount: commissionAmount ?? this.commissionAmount,
      providerNetAmount: providerNetAmount ?? this.providerNetAmount,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customer: customer ?? this.customer,
      provider: provider ?? this.provider,
      listing: listing ?? this.listing,
    );
  }

  @override
  String toString() {
    return 'ServiceRequest(id: $id, requestId: $requestId, status: ${status.displayName})';
  }
}

/// ═══════════════════════════════════════════════════════════════════════
/// REQUEST LIST RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class RequestListResponse {
  final bool success;
  final String message;
  final List<ServiceRequest> requests;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  RequestListResponse({
    required this.success,
    required this.message,
    required this.requests,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  factory RequestListResponse.fromJson(Map<String, dynamic> json) {
    try {
      final data = json['data'];

      // ✅ Parse as direct array
      List<ServiceRequest> requestsList = [];

      if (data is List) {
        debugPrint('🔵 Parsing ${data.length} requests from array');
        requestsList = data
            .map((item) {
          try {
            return ServiceRequest.fromJson(item as Map<String, dynamic>);
          } catch (e) {
            debugPrint('⚠️ Error parsing request item: $e');
            return null;
          }
        })
            .where((item) => item != null)
            .cast<ServiceRequest>()
            .toList();
      } else if (data is Map<String, dynamic>) {
        // Single request wrapped in object
        requestsList = [ServiceRequest.fromJson(data)];
      }

      // Handle pagination if present
      final pagination = json['pagination'] as Map<String, dynamic>?;

      return RequestListResponse(
        success: json['success'] as bool? ?? true,
        message: json['message'] as String? ?? '',
        requests: requestsList,
        total: pagination?['total'] as int? ?? requestsList.length,
        page: pagination?['page'] as int? ?? 1,
        limit: pagination?['limit'] as int? ?? requestsList.length,
        totalPages: pagination?['total_pages'] as int? ??
            pagination?['totalPages'] as int? ?? 1,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [REQUEST_LIST_RESPONSE] Error parsing: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('JSON: $json');
      rethrow;
    }
  }

  bool get hasMore => page < totalPages;
}

/// ═══════════════════════════════════════════════════════════════════════
/// SINGLE REQUEST RESPONSE MODEL
/// ═══════════════════════════════════════════════════════════════════════

class SingleRequestResponse {
  final bool success;
  final String message;
  final ServiceRequest request;

  SingleRequestResponse({
    required this.success,
    required this.message,
    required this.request,
  });

  factory SingleRequestResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'];

    ServiceRequest requestData;
    if (data is Map<String, dynamic> && data.containsKey('request')) {
      requestData = ServiceRequest.fromJson(data['request'] as Map<String, dynamic>);
    } else if (data is Map<String, dynamic>) {
      requestData = ServiceRequest.fromJson(data);
    } else {
      throw Exception('Invalid response format for SingleRequestResponse');
    }

    return SingleRequestResponse(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      request: requestData,
    );
  }
}