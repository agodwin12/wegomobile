// lib/models/user_profile_model.dart
// WEGO - User Profile Model (COMPLETE & FIXED)
// ✅ Proper null safety for all fields

class UserProfile {
  final String uuid;
  final String userType;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String phone;
  final bool phoneVerified;
  final bool emailVerified;
  final String? avatarUrl;          // ✅ Nullable
  final String? civility;           // ✅ Nullable
  final String? birthDate;          // ✅ Nullable
  final String? address;            // ✅ Nullable
  final String? city;               // ✅ Nullable
  final bool isVerified;
  final bool isServiceProvider;
  final DateTime? createdAt;        // ✅ Nullable
  final DateTime? updatedAt;        // ✅ Nullable
  final UserStats? stats;           // ✅ Nullable

  UserProfile({
    required this.uuid,
    required this.userType,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.phoneVerified,
    required this.emailVerified,
    this.avatarUrl,
    this.civility,
    this.birthDate,
    this.address,
    this.city,
    required this.isVerified,
    required this.isServiceProvider,
    this.createdAt,
    this.updatedAt,
    this.stats,
  });

  // ✅ FIXED: Proper null-safe JSON parsing
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uuid: json['uuid'] as String? ?? '',
      userType: json['userType'] as String? ?? 'passenger',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
      fullName: json['fullName'] as String? ?? 'User',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      emailVerified: json['emailVerified'] as bool? ?? false,
      avatarUrl: json['avatarUrl'] as String?,           // ✅ Nullable
      civility: json['civility'] as String?,             // ✅ Nullable
      birthDate: json['birthDate'] as String?,           // ✅ Nullable
      address: json['address'] as String?,               // ✅ Nullable
      city: json['city'] as String?,                     // ✅ Nullable
      isVerified: json['isVerified'] as bool? ?? false,
      isServiceProvider: json['isServiceProvider'] as bool? ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      stats: json['stats'] != null
          ? UserStats.fromJson(json['stats'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'userType': userType,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'phoneVerified': phoneVerified,
      'emailVerified': emailVerified,
      'avatarUrl': avatarUrl,
      'civility': civility,
      'birthDate': birthDate,
      'address': address,
      'city': city,
      'isVerified': isVerified,
      'isServiceProvider': isServiceProvider,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'stats': stats?.toJson(),
    };
  }

  // Helper: Get user initials for avatar
  String getInitials() {
    final first = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final last = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    return first + last;
  }

  // Helper: Format phone number
  String getFormattedPhone() {
    if (phone.isEmpty) return 'No phone';
    // Format: +237 6XX XXX XXX
    if (phone.startsWith('+237') && phone.length == 13) {
      return '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7, 10)} ${phone.substring(10)}';
    }
    return phone;
  }

  // Helper: Check if driver
  bool get isDriver => userType == 'driver';

  // Helper: Check if passenger
  bool get isPassenger => userType == 'passenger';

  // Helper: Get role display name
  String get role {
    switch (userType) {
      case 'driver':
        return 'Driver';
      case 'passenger':
        return 'Passenger';
      case 'partner':
        return 'Partner';
      case 'employee':
        return 'Employee';
      default:
        return 'User';
    }
  }

  // Helper: Copy with
  UserProfile copyWith({
    String? uuid,
    String? userType,
    String? firstName,
    String? lastName,
    String? fullName,
    String? email,
    String? phone,
    bool? phoneVerified,
    bool? emailVerified,
    String? avatarUrl,
    String? civility,
    String? birthDate,
    String? address,
    String? city,
    bool? isVerified,
    bool? isServiceProvider,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserStats? stats,
  }) {
    return UserProfile(
      uuid: uuid ?? this.uuid,
      userType: userType ?? this.userType,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      emailVerified: emailVerified ?? this.emailVerified,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      civility: civility ?? this.civility,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      city: city ?? this.city,
      isVerified: isVerified ?? this.isVerified,
      isServiceProvider: isServiceProvider ?? this.isServiceProvider,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      stats: stats ?? this.stats,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// USER STATS MODEL
// ═══════════════════════════════════════════════════════════════════

class UserStats {
  final int totalRidesAsPassenger;
  final int totalRidesAsDriver;
  final String? averageRatingAsDriver;    // ✅ Nullable
  final int totalRatingsAsDriver;
  final int activeListings;
  final int completedServices;
  final String? averageRatingAsProvider;  // ✅ Nullable
  final int totalRatingsAsProvider;
  final int totalRides;
  final int totalServices;
  final Earnings? earnings;               // ✅ Nullable

  UserStats({
    required this.totalRidesAsPassenger,
    required this.totalRidesAsDriver,
    this.averageRatingAsDriver,
    required this.totalRatingsAsDriver,
    required this.activeListings,
    required this.completedServices,
    this.averageRatingAsProvider,
    required this.totalRatingsAsProvider,
    required this.totalRides,
    required this.totalServices,
    this.earnings,
  });

  // ✅ FIXED: Proper null-safe JSON parsing
  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalRidesAsPassenger: json['totalRidesAsPassenger'] as int? ?? 0,
      totalRidesAsDriver: json['totalRidesAsDriver'] as int? ?? 0,
      averageRatingAsDriver: json['averageRatingAsDriver'] as String?,  // ✅ Nullable
      totalRatingsAsDriver: json['totalRatingsAsDriver'] as int? ?? 0,
      activeListings: json['activeListings'] as int? ?? 0,
      completedServices: json['completedServices'] as int? ?? 0,
      averageRatingAsProvider: json['averageRatingAsProvider'] as String?,  // ✅ Nullable
      totalRatingsAsProvider: json['totalRatingsAsProvider'] as int? ?? 0,
      totalRides: json['totalRides'] as int? ?? 0,
      totalServices: json['totalServices'] as int? ?? 0,
      earnings: json['earnings'] != null
          ? Earnings.fromJson(json['earnings'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRidesAsPassenger': totalRidesAsPassenger,
      'totalRidesAsDriver': totalRidesAsDriver,
      'averageRatingAsDriver': averageRatingAsDriver,
      'totalRatingsAsDriver': totalRatingsAsDriver,
      'activeListings': activeListings,
      'completedServices': completedServices,
      'averageRatingAsProvider': averageRatingAsProvider,
      'totalRatingsAsProvider': totalRatingsAsProvider,
      'totalRides': totalRides,
      'totalServices': totalServices,
      'earnings': earnings?.toJson(),
    };
  }

  // Helper: Get overall rating (driver or provider, whichever is available)
  String? getOverallRating() {
    if (averageRatingAsDriver != null) return averageRatingAsDriver;
    if (averageRatingAsProvider != null) return averageRatingAsProvider;
    return null;
  }

  // Helper: Get total ratings
  int getTotalRatings() {
    return totalRatingsAsDriver + totalRatingsAsProvider;
  }
}

// ═══════════════════════════════════════════════════════════════════
// EARNINGS MODEL
// ═══════════════════════════════════════════════════════════════════

class Earnings {
  final String totalEarningsFromRides;
  final String totalEarningsFromServices;
  final String commissionOwed;
  final String netEarnings;
  final String totalEarnings;

  Earnings({
    required this.totalEarningsFromRides,
    required this.totalEarningsFromServices,
    required this.commissionOwed,
    required this.netEarnings,
    required this.totalEarnings,
  });

  // ✅ FIXED: Proper null-safe JSON parsing
  factory Earnings.fromJson(Map<String, dynamic> json) {
    return Earnings(
      totalEarningsFromRides: json['totalEarningsFromRides'] as String? ?? '0.00',
      totalEarningsFromServices: json['totalEarningsFromServices'] as String? ?? '0.00',
      commissionOwed: json['commissionOwed'] as String? ?? '0.00',
      netEarnings: json['netEarnings'] as String? ?? '0.00',
      totalEarnings: json['totalEarnings'] as String? ?? '0.00',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalEarningsFromRides': totalEarningsFromRides,
      'totalEarningsFromServices': totalEarningsFromServices,
      'commissionOwed': commissionOwed,
      'netEarnings': netEarnings,
      'totalEarnings': totalEarnings,
    };
  }

  // Helper: Get total as double
  double getTotalAsDouble() {
    return double.tryParse(totalEarnings) ?? 0.0;
  }

  // Helper: Get formatted total
  String getFormattedTotal() {
    return '$totalEarnings FCFA';
  }
}