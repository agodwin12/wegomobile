// lib/models/user_preferences_model.dart
// WEGO - User Preferences Model
// Manages notification and privacy settings

class UserPreferences {
  final String userId;
  final NotificationSettings notifications;
  final PrivacySettings privacy;
  final DateTime updatedAt;

  UserPreferences({
    required this.userId,
    required this.notifications,
    required this.privacy,
    required this.updatedAt,
  });

  // From JSON (API response)
  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['userId'] as String,
      notifications: NotificationSettings.fromJson(
        json['notifications'] as Map<String, dynamic>,
      ),
      privacy: PrivacySettings.fromJson(
        json['privacy'] as Map<String, dynamic>,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'notifications': notifications.toJson(),
      'privacy': privacy.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Copy with
  UserPreferences copyWith({
    String? userId,
    NotificationSettings? notifications,
    PrivacySettings? privacy,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      notifications: notifications ?? this.notifications,
      privacy: privacy ?? this.privacy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserPreferences(userId: $userId, updated: $updatedAt)';
  }
}

// ═══════════════════════════════════════════════════════════════════
// NOTIFICATION SETTINGS
// ═══════════════════════════════════════════════════════════════════

class NotificationSettings {
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;
  final bool rideUpdates;
  final bool serviceUpdates;
  final bool promotions;
  final bool newMessages;
  final bool paymentAlerts;
  final bool systemAlerts;
  final bool doNotDisturb;
  final TimeRange? doNotDisturbSchedule;

  NotificationSettings({
    required this.pushEnabled,
    required this.emailEnabled,
    required this.smsEnabled,
    required this.rideUpdates,
    required this.serviceUpdates,
    required this.promotions,
    required this.newMessages,
    required this.paymentAlerts,
    required this.systemAlerts,
    required this.doNotDisturb,
    this.doNotDisturbSchedule,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      pushEnabled: json['pushEnabled'] as bool? ?? true,
      emailEnabled: json['emailEnabled'] as bool? ?? true,
      smsEnabled: json['smsEnabled'] as bool? ?? false,
      rideUpdates: json['rideUpdates'] as bool? ?? true,
      serviceUpdates: json['serviceUpdates'] as bool? ?? true,
      promotions: json['promotions'] as bool? ?? true,
      newMessages: json['newMessages'] as bool? ?? true,
      paymentAlerts: json['paymentAlerts'] as bool? ?? true,
      systemAlerts: json['systemAlerts'] as bool? ?? true,
      doNotDisturb: json['doNotDisturb'] as bool? ?? false,
      doNotDisturbSchedule: json['doNotDisturbSchedule'] != null
          ? TimeRange.fromJson(json['doNotDisturbSchedule'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'smsEnabled': smsEnabled,
      'rideUpdates': rideUpdates,
      'serviceUpdates': serviceUpdates,
      'promotions': promotions,
      'newMessages': newMessages,
      'paymentAlerts': paymentAlerts,
      'systemAlerts': systemAlerts,
      'doNotDisturb': doNotDisturb,
      'doNotDisturbSchedule': doNotDisturbSchedule?.toJson(),
    };
  }

  NotificationSettings copyWith({
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
    bool? rideUpdates,
    bool? serviceUpdates,
    bool? promotions,
    bool? newMessages,
    bool? paymentAlerts,
    bool? systemAlerts,
    bool? doNotDisturb,
    TimeRange? doNotDisturbSchedule,
  }) {
    return NotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      rideUpdates: rideUpdates ?? this.rideUpdates,
      serviceUpdates: serviceUpdates ?? this.serviceUpdates,
      promotions: promotions ?? this.promotions,
      newMessages: newMessages ?? this.newMessages,
      paymentAlerts: paymentAlerts ?? this.paymentAlerts,
      systemAlerts: systemAlerts ?? this.systemAlerts,
      doNotDisturb: doNotDisturb ?? this.doNotDisturb,
      doNotDisturbSchedule: doNotDisturbSchedule ?? this.doNotDisturbSchedule,
    );
  }

  // Helper: Check if any notification is enabled
  bool get hasAnyEnabled {
    return pushEnabled || emailEnabled || smsEnabled;
  }

  // Helper: Get enabled channels list
  List<String> getEnabledChannels() {
    List<String> channels = [];
    if (pushEnabled) channels.add('Push');
    if (emailEnabled) channels.add('Email');
    if (smsEnabled) channels.add('SMS');
    return channels;
  }
}

// ═══════════════════════════════════════════════════════════════════
// PRIVACY SETTINGS
// ═══════════════════════════════════════════════════════════════════

class PrivacySettings {
  final bool shareLocationWithDriver;
  final bool sharePhoneWithProvider;
  final bool showProfileToOthers;
  final bool shareRideHistory;
  final bool allowMarketingEmails;
  final bool allowDataCollection;
  final bool twoFactorEnabled;

  PrivacySettings({
    required this.shareLocationWithDriver,
    required this.sharePhoneWithProvider,
    required this.showProfileToOthers,
    required this.shareRideHistory,
    required this.allowMarketingEmails,
    required this.allowDataCollection,
    required this.twoFactorEnabled,
  });

  factory PrivacySettings.fromJson(Map<String, dynamic> json) {
    return PrivacySettings(
      shareLocationWithDriver: json['shareLocationWithDriver'] as bool? ?? true,
      sharePhoneWithProvider: json['sharePhoneWithProvider'] as bool? ?? true,
      showProfileToOthers: json['showProfileToOthers'] as bool? ?? true,
      shareRideHistory: json['shareRideHistory'] as bool? ?? false,
      allowMarketingEmails: json['allowMarketingEmails'] as bool? ?? true,
      allowDataCollection: json['allowDataCollection'] as bool? ?? true,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shareLocationWithDriver': shareLocationWithDriver,
      'sharePhoneWithProvider': sharePhoneWithProvider,
      'showProfileToOthers': showProfileToOthers,
      'shareRideHistory': shareRideHistory,
      'allowMarketingEmails': allowMarketingEmails,
      'allowDataCollection': allowDataCollection,
      'twoFactorEnabled': twoFactorEnabled,
    };
  }

  PrivacySettings copyWith({
    bool? shareLocationWithDriver,
    bool? sharePhoneWithProvider,
    bool? showProfileToOthers,
    bool? shareRideHistory,
    bool? allowMarketingEmails,
    bool? allowDataCollection,
    bool? twoFactorEnabled,
  }) {
    return PrivacySettings(
      shareLocationWithDriver: shareLocationWithDriver ?? this.shareLocationWithDriver,
      sharePhoneWithProvider: sharePhoneWithProvider ?? this.sharePhoneWithProvider,
      showProfileToOthers: showProfileToOthers ?? this.showProfileToOthers,
      shareRideHistory: shareRideHistory ?? this.shareRideHistory,
      allowMarketingEmails: allowMarketingEmails ?? this.allowMarketingEmails,
      allowDataCollection: allowDataCollection ?? this.allowDataCollection,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
    );
  }

  // Helper: Get privacy score (0-100)
  int getPrivacyScore() {
    int score = 0;
    if (!shareLocationWithDriver) score += 14;
    if (!sharePhoneWithProvider) score += 14;
    if (!showProfileToOthers) score += 14;
    if (!shareRideHistory) score += 14;
    if (!allowMarketingEmails) score += 14;
    if (!allowDataCollection) score += 15;
    if (twoFactorEnabled) score += 15;
    return score;
  }

  // Helper: Get privacy level
  String getPrivacyLevel() {
    int score = getPrivacyScore();
    if (score >= 70) return 'High';
    if (score >= 40) return 'Medium';
    return 'Low';
  }
}

// ═══════════════════════════════════════════════════════════════════
// TIME RANGE (for Do Not Disturb schedule)
// ═══════════════════════════════════════════════════════════════════

class TimeRange {
  final String startTime; // Format: "22:00"
  final String endTime;   // Format: "08:00"

  TimeRange({
    required this.startTime,
    required this.endTime,
  });

  factory TimeRange.fromJson(Map<String, dynamic> json) {
    return TimeRange(
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  // Helper: Format for display
  String getDisplayRange() {
    return '$startTime - $endTime';
  }

  // Helper: Check if current time is in DND range
  bool isCurrentlyInRange() {
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    final startParts = startTime.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);

    final endParts = endTime.split(':');
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    // Handle overnight range (e.g., 22:00 - 08:00)
    if (startMinutes > endMinutes) {
      return currentMinutes >= startMinutes || currentMinutes <= endMinutes;
    }

    return currentMinutes >= startMinutes && currentMinutes <= endMinutes;
  }

  @override
  String toString() {
    return 'TimeRange($startTime - $endTime)';
  }
}