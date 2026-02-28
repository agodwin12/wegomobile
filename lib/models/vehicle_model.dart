// lib/models/vehicle_model.dart
// WEGO - Vehicle Model
// Represents driver vehicle information

class Vehicle {
  final int id;
  final String driverId;
  final String brand;
  final String model;
  final String year;
  final String color;
  final String licensePlate;
  final String? vehicleType;
  final int capacity;
  final String? insuranceNumber;
  final DateTime? insuranceExpiry;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehicle({
    required this.id,
    required this.driverId,
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.licensePlate,
    this.vehicleType,
    required this.capacity,
    this.insuranceNumber,
    this.insuranceExpiry,
    required this.createdAt,
    required this.updatedAt,
  });

  // From JSON (API response)
  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      driverId: json['driver_id'] as String,
      brand: json['brand'] as String,
      model: json['model'] as String,
      year: json['year'].toString(),
      color: json['color'] as String,
      licensePlate: json['license_plate'] as String,
      vehicleType: json['vehicle_type'] as String?,
      capacity: json['capacity'] as int,
      insuranceNumber: json['insurance_number'] as String?,
      insuranceExpiry: json['insurance_expiry'] != null
          ? DateTime.parse(json['insurance_expiry'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // To JSON (for API requests)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driver_id': driverId,
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'license_plate': licensePlate,
      'vehicle_type': vehicleType,
      'capacity': capacity,
      'insurance_number': insuranceNumber,
      'insurance_expiry': insuranceExpiry?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Copy with (for updates)
  Vehicle copyWith({
    int? id,
    String? driverId,
    String? brand,
    String? model,
    String? year,
    String? color,
    String? licensePlate,
    String? vehicleType,
    int? capacity,
    String? insuranceNumber,
    DateTime? insuranceExpiry,
    DateTime? createdAt,
    DateTime? updatedAt, required String insuranceDoc,
  }) {
    return Vehicle(
      id: id ?? this.id,
      driverId: driverId ?? this.driverId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      year: year ?? this.year,
      color: color ?? this.color,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleType: vehicleType ?? this.vehicleType,
      capacity: capacity ?? this.capacity,
      insuranceNumber: insuranceNumber ?? this.insuranceNumber,
      insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Get full vehicle name
  String getFullName() {
    return '$brand $model ($year)';
  }

  // Get formatted license plate
  String getFormattedLicensePlate() {
    return licensePlate.toUpperCase();
  }

  // Check if insurance is expired
  bool isInsuranceExpired() {
    if (insuranceExpiry == null) return false;
    return insuranceExpiry!.isBefore(DateTime.now());
  }

  // Check if insurance is expiring soon (within 30 days)
  bool isInsuranceExpiringSoon() {
    if (insuranceExpiry == null) return false;
    final daysUntilExpiry = insuranceExpiry!.difference(DateTime.now()).inDays;
    return daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  }

  // Get insurance status
  String getInsuranceStatus() {
    if (insuranceExpiry == null) return 'Not Set';
    if (isInsuranceExpired()) return 'Expired';
    if (isInsuranceExpiringSoon()) return 'Expiring Soon';
    return 'Valid';
  }

  // Get vehicle type display name
  String getVehicleTypeDisplayName() {
    if (vehicleType == null) return 'Not Specified';

    switch (vehicleType!.toLowerCase()) {
      case 'sedan':
        return 'Sedan';
      case 'suv':
        return 'SUV';
      case 'van':
        return 'Van';
      case 'hatchback':
        return 'Hatchback';
      case 'pickup':
        return 'Pickup Truck';
      case 'other':
        return 'Other';
      default:
        return vehicleType!;
    }
  }

  // Get vehicle emoji/icon
  String getVehicleEmoji() {
    if (vehicleType == null) return '🚗';

    switch (vehicleType!.toLowerCase()) {
      case 'sedan':
        return '🚗';
      case 'suv':
        return '🚙';
      case 'van':
        return '🚐';
      case 'hatchback':
        return '🚗';
      case 'pickup':
        return '🛻';
      default:
        return '🚗';
    }
  }

  // Check if all required info is provided
  bool isComplete() {
    return brand.isNotEmpty &&
        model.isNotEmpty &&
        year.isNotEmpty &&
        color.isNotEmpty &&
        licensePlate.isNotEmpty &&
        capacity > 0;
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, ${getFullName()}, plate: $licensePlate)';
  }
}

// ═══════════════════════════════════════════════════════════════════
// VEHICLE TYPE ENUM (for form dropdowns)
// ═══════════════════════════════════════════════════════════════════

enum VehicleType {
  sedan('sedan', 'Sedan', '🚗'),
  suv('suv', 'SUV', '🚙'),
  van('van', 'Van', '🚐'),
  hatchback('hatchback', 'Hatchback', '🚗'),
  pickup('pickup', 'Pickup Truck', '🛻'),
  other('other', 'Other', '🚗');

  final String value;
  final String displayName;
  final String emoji;

  const VehicleType(this.value, this.displayName, this.emoji);

  // Get VehicleType from string
  static VehicleType? fromString(String? value) {
    if (value == null) return null;

    try {
      return VehicleType.values.firstWhere(
            (type) => type.value.toLowerCase() == value.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // Get all display names for dropdown
  static List<String> getAllDisplayNames() {
    return VehicleType.values.map((type) => type.displayName).toList();
  }

  // Get all values
  static List<String> getAllValues() {
    return VehicleType.values.map((type) => type.value).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════
// VEHICLE CREATE/UPDATE REQUEST MODEL
// ═══════════════════════════════════════════════════════════════════

class VehicleRequest {
  final String brand;
  final String model;
  final String year;
  final String color;
  final String licensePlate;
  final String? vehicleType;
  final int capacity;
  final String? insuranceNumber;
  final String? insuranceExpiry;

  VehicleRequest({
    required this.brand,
    required this.model,
    required this.year,
    required this.color,
    required this.licensePlate,
    this.vehicleType,
    required this.capacity,
    this.insuranceNumber,
    this.insuranceExpiry,
  });

  // To JSON (for API POST/PUT requests)
  Map<String, dynamic> toJson() {
    return {
      'brand': brand,
      'model': model,
      'year': year,
      'color': color,
      'licensePlate': licensePlate,
      'vehicleType': vehicleType,
      'capacity': capacity,
      'insuranceNumber': insuranceNumber,
      'insuranceExpiry': insuranceExpiry,
    };
  }

  // From Vehicle (for editing)
  factory VehicleRequest.fromVehicle(Vehicle vehicle) {
    return VehicleRequest(
      brand: vehicle.brand,
      model: vehicle.model,
      year: vehicle.year,
      color: vehicle.color,
      licensePlate: vehicle.licensePlate,
      vehicleType: vehicle.vehicleType,
      capacity: vehicle.capacity,
      insuranceNumber: vehicle.insuranceNumber,
      insuranceExpiry: vehicle.insuranceExpiry?.toIso8601String().split('T')[0],
    );
  }

  // Validate
  String? validate() {
    if (brand.trim().isEmpty) return 'Brand is required';
    if (model.trim().isEmpty) return 'Model is required';
    if (year.trim().isEmpty) return 'Year is required';

    final yearInt = int.tryParse(year);
    if (yearInt == null) return 'Year must be a number';
    if (yearInt < 1990 || yearInt > DateTime.now().year + 1) {
      return 'Year must be between 1990 and ${DateTime.now().year + 1}';
    }

    if (color.trim().isEmpty) return 'Color is required';
    if (licensePlate.trim().isEmpty) return 'License plate is required';
    if (capacity < 1 || capacity > 50) return 'Capacity must be between 1 and 50';

    return null; // Valid
  }

  // Check if complete
  bool isComplete() {
    return brand.isNotEmpty &&
        model.isNotEmpty &&
        year.isNotEmpty &&
        color.isNotEmpty &&
        licensePlate.isNotEmpty &&
        capacity > 0;
  }
}
