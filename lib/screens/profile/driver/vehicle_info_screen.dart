// lib/screens/profile/driver/vehicle_info_screen.dart
// WEGO - Vehicle Info Screen (READ-ONLY)
// Drivers can view their vehicle details but cannot edit

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/profile_provider.dart';
import '../../../models/vehicle_model.dart';

class VehicleInfoScreen extends StatefulWidget {
  const VehicleInfoScreen({Key? key}) : super(key: key);

  @override
  State<VehicleInfoScreen> createState() => _VehicleInfoScreenState();
}

class _VehicleInfoScreenState extends State<VehicleInfoScreen> {
  @override
  void initState() {
    super.initState();
    _loadVehicleInfo();
  }

  Future<void> _loadVehicleInfo() async {
    final provider = context.read<ProfileProvider>();
    await provider.loadVehicle(); // ✅ CORRECT method name
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Vehicle Information',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingVehicle) { // ✅ CORRECT property name
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFDC71)),
              ),
            );
          }

          if (provider.vehicle == null) {
            return _buildNoVehicle();
          }

          return RefreshIndicator(
            onRefresh: _loadVehicleInfo,
            color: const Color(0xFFFFDC71),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Banner
                  _buildInfoBanner(),

                  const SizedBox(height: 24),

                  // Vehicle Image/Icon
                  _buildVehicleHeader(provider.vehicle!),

                  const SizedBox(height: 24),

                  // Vehicle Details
                  _buildVehicleDetails(provider.vehicle!),

                  const SizedBox(height: 24),

                  // Insurance Status
                  _buildInsuranceSection(provider.vehicle!),

                  const SizedBox(height: 24),

                  // Registration Details
                  _buildRegistrationDetails(provider.vehicle!),

                  const SizedBox(height: 32),

                  // Request Changes Button
                  _buildRequestChangesButton(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NO VEHICLE STATE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildNoVehicle() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_car_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Vehicle Registered',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your vehicle information will appear here\nonce it has been registered',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _contactSupport,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDC71),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(Icons.support_agent),
            label: const Text(
              'Contact Support',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // INFO BANNER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFDC71).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFDC71).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFFFDC71),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.black,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'View Only',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'To update vehicle information, please contact support',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VEHICLE HEADER
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildVehicleHeader(Vehicle vehicle) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFDC71),
                width: 3,
              ),
            ),
            child: Text(
              vehicle.getVehicleEmoji(),
              style: const TextStyle(fontSize: 60),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            vehicle.getFullName(), // brand model (year)
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            vehicle.getVehicleTypeDisplayName().toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VEHICLE DETAILS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildVehicleDetails(Vehicle vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        _buildDetailCard(
          icon: Icons.directions_car,
          label: 'Brand',
          value: vehicle.brand, // ✅ CORRECT: brand not make
        ),
        _buildDetailCard(
          icon: Icons.car_rental,
          label: 'Model',
          value: vehicle.model,
        ),
        _buildDetailCard(
          icon: Icons.calendar_today,
          label: 'Year',
          value: vehicle.year,
        ),
        _buildDetailCard(
          icon: Icons.palette,
          label: 'Color',
          value: vehicle.color,
        ),
        _buildDetailCard(
          icon: Icons.confirmation_number,
          label: 'License Plate',
          value: vehicle.getFormattedLicensePlate(),
        ),
        _buildDetailCard(
          icon: Icons.category,
          label: 'Vehicle Type',
          value: vehicle.getVehicleTypeDisplayName(),
        ),
        _buildDetailCard(
          icon: Icons.airline_seat_recline_normal,
          label: 'Seating Capacity',
          value: '${vehicle.capacity} passengers', // ✅ CORRECT: capacity not seatingCapacity
        ),
      ],
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFDC71).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFDC71),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // INSURANCE SECTION
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildInsuranceSection(Vehicle vehicle) {
    final hasInsurance = vehicle.insuranceNumber != null;
    final insuranceStatus = vehicle.getInsuranceStatus();
    final isExpired = vehicle.isInsuranceExpired();
    final isExpiringSoon = vehicle.isInsuranceExpiringSoon();

    Color statusColor;
    IconData statusIcon;

    if (!hasInsurance) {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
    } else if (isExpired) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (isExpiringSoon) {
      statusColor = Colors.orange;
      statusIcon = Icons.warning;
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Insurance Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: statusColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      statusIcon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          insuranceStatus,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getInsuranceMessage(insuranceStatus),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (hasInsurance) ...[
                const Divider(height: 24),
                _buildInfoRow(
                  'Insurance Number',
                  vehicle.insuranceNumber ?? 'N/A',
                  Icons.confirmation_number,
                ),
                if (vehicle.insuranceExpiry != null) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    'Expiry Date',
                    DateFormat('dd MMM yyyy').format(vehicle.insuranceExpiry!),
                    Icons.calendar_today,
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _getInsuranceMessage(String status) {
    switch (status) {
      case 'Valid':
        return 'Your insurance is active and valid';
      case 'Expiring Soon':
        return 'Please renew your insurance soon';
      case 'Expired':
        return 'Your insurance has expired. Please contact support';
      case 'Not Set':
        return 'No insurance information available';
      default:
        return 'Insurance status unknown';
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // REGISTRATION DETAILS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRegistrationDetails(Vehicle vehicle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Registration Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildInfoRow(
                'Registered',
                DateFormat('dd MMM yyyy').format(vehicle.createdAt),
                Icons.event,
              ),
              const Divider(height: 24),
              _buildInfoRow(
                'Last Updated',
                DateFormat('dd MMM yyyy').format(vehicle.updatedAt),
                Icons.update,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REQUEST CHANGES BUTTON
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRequestChangesButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _contactSupport,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFFFDC71),
          side: const BorderSide(color: Color(0xFFFFDC71), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.support_agent, size: 24),
        label: const Text(
          'Request Vehicle Update',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CONTACT SUPPORT
  // ═══════════════════════════════════════════════════════════════════

  void _contactSupport() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Vehicle Update'),
        content: const Text(
          'To update your vehicle information, please contact our support team. They will guide you through the verification process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to support screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Navigate to Contact Support'),
                  backgroundColor: Color(0xFFFFDC71),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDC71),
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }
}