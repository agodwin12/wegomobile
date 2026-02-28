// lib/models/driver_document_model.dart
// WEGO - Driver Document Model

class DriverDocument {
  final int id;
  final String driverId;
  final String? licenseNumber;
  final String? licenseUrl;
  final DateTime? licenseExpiry;
  final String? cniNumber;
  final String? cniUrl;
  final String? verificationStatus;
  final DateTime? verifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  DriverDocument({
    required this.id,
    required this.driverId,
    this.licenseNumber,
    this.licenseUrl,
    this.licenseExpiry,
    this.cniNumber,
    this.cniUrl,
    this.verificationStatus,
    this.verifiedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DriverDocument.fromJson(Map<String, dynamic> json) {
    return DriverDocument(
      id: json['id'] as int,
      driverId: json['driverId'] as String,
      licenseNumber: json['licenseNumber'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
      licenseExpiry: json['licenseExpiry'] != null
          ? DateTime.parse(json['licenseExpiry'] as String)
          : null,
      cniNumber: json['cniNumber'] as String?,
      cniUrl: json['cniUrl'] as String?,
      verificationStatus: json['verificationStatus'] as String?,
      verifiedAt: json['verifiedAt'] != null
          ? DateTime.parse(json['verifiedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'licenseNumber': licenseNumber,
      'licenseUrl': licenseUrl,
      'licenseExpiry': licenseExpiry?.toIso8601String(),
      'cniNumber': cniNumber,
      'cniUrl': cniUrl,
      'verificationStatus': verificationStatus,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  DriverDocument copyWith({
    int? id,
    String? driverId,
    String? licenseNumber,
    String? licenseUrl,
    DateTime? licenseExpiry,
    String? cniNumber,
    String? cniUrl,
    String? verificationStatus,
    DateTime? verifiedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DriverDocument(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseUrl: licenseUrl ?? this.licenseUrl,
      licenseExpiry: licenseExpiry ?? this.licenseExpiry,
      cniNumber: cniNumber ?? this.cniNumber,
      cniUrl: cniUrl ?? this.cniUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isLicenseExpired {
    if (licenseExpiry == null) return false;
    return licenseExpiry!.isBefore(DateTime.now());
  }

  bool get isVerified {
    return verificationStatus?.toLowerCase() == 'verified';
  }

  String getVerificationStatusDisplay() {
    if (verificationStatus == null) return 'Not Verified';
    switch (verificationStatus!.toLowerCase()) {
      case 'verified':
        return 'Verified ✓';
      case 'pending':
        return 'Pending Review';
      case 'rejected':
        return 'Rejected';
      default:
        return verificationStatus!;
    }
  }

  @override
  String toString() {
    return 'DriverDocument(id: $id, status: $verificationStatus)';
  }
}