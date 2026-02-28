// lib/screens/profile/driver/driver_documents_screen.dart
// WEGO - Driver Documents Screen (READ-ONLY)
// Drivers can view their license and CNI documents

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import '../../../providers/profile_provider.dart';
import '../../../models/driver_document_model.dart';

class DriverDocumentsScreen extends StatefulWidget {
  const DriverDocumentsScreen({Key? key}) : super(key: key);

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final provider = context.read<ProfileProvider>();
    await provider.loadDocuments(); // ✅ CORRECT method name
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
          'My Documents',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingDocuments) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFDC71)),
              ),
            );
          }

          if (provider.documents == null) {
            return _buildNoDocuments();
          }

          final docs = provider.documents!;

          return RefreshIndicator(
            onRefresh: _loadDocuments,
            color: const Color(0xFFFFDC71),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Info Banner
                _buildInfoBanner(),

                const SizedBox(height: 24),

                // Verification Status Card
                _buildVerificationStatusCard(docs),

                const SizedBox(height: 24),

                // Driver's License Section
                const Text(
                  'Driver\'s License',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                _buildLicenseCard(docs),

                const SizedBox(height: 24),

                // CNI Section
                const Text(
                  'National ID Card (CNI)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                _buildCNICard(docs),

                const SizedBox(height: 32),

                // Request Update Button
                _buildRequestUpdateButton(),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NO DOCUMENTS STATE
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildNoDocuments() {
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
              Icons.description_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Documents Found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your documents will appear here\nonce they have been uploaded',
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
                  'To update or upload new documents, please contact support',
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
  // VERIFICATION STATUS CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildVerificationStatusCard(DriverDocument docs) {
    final statusText = docs.getVerificationStatusDisplay();
    final isVerified = docs.isVerified;

    Color statusColor;
    IconData statusIcon;

    if (isVerified) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (docs.verificationStatus?.toLowerCase() == 'pending') {
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    } else if (docs.verificationStatus?.toLowerCase() == 'rejected') {
      statusColor = Colors.red;
      statusIcon = Icons.cancel;
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusIcon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verification Status',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                if (docs.verifiedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Verified on ${DateFormat('dd MMM yyyy').format(docs.verifiedAt!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // LICENSE CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildLicenseCard(DriverDocument docs) {
    final hasLicense = docs.licenseUrl != null;

    if (!hasLicense) {
      return _buildNoDocumentCard(
        'No driver\'s license uploaded',
        Icons.credit_card,
      );
    }

    return GestureDetector(
      onTap: () => _viewDocument(
        'Driver\'s License',
        docs.licenseUrl,
        docs.licenseNumber,
        docs.licenseExpiry,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Document Thumbnail
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  docs.licenseUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.credit_card,
                    size: 40,
                    color: Color(0xFFFFDC71),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Document Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Driver\'s License',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (docs.licenseNumber != null) ...[
                    Text(
                      'No: ${docs.licenseNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  if (docs.licenseExpiry != null) ...[
                    Row(
                      children: [
                        Icon(
                          docs.isLicenseExpired ? Icons.error : Icons.calendar_today,
                          size: 14,
                          color: docs.isLicenseExpired ? Colors.red : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          docs.isLicenseExpired
                              ? 'Expired: ${DateFormat('dd MMM yyyy').format(docs.licenseExpiry!)}'
                              : 'Expires: ${DateFormat('dd MMM yyyy').format(docs.licenseExpiry!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: docs.isLicenseExpired ? Colors.red : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // View Icon
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // CNI CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildCNICard(DriverDocument docs) {
    final hasCNI = docs.cniUrl != null;

    if (!hasCNI) {
      return _buildNoDocumentCard(
        'No CNI uploaded',
        Icons.badge,
      );
    }

    return GestureDetector(
      onTap: () => _viewDocument(
        'National ID Card (CNI)',
        docs.cniUrl,
        docs.cniNumber,
        null,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Document Thumbnail
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  docs.cniUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.badge,
                    size: 40,
                    color: Color(0xFFFFDC71),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 16),

            // Document Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'National ID Card',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (docs.cniNumber != null) ...[
                    Text(
                      'No: ${docs.cniNumber}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // View Icon
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // NO DOCUMENT CARD
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildNoDocumentCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 40,
            color: Colors.grey[400],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // VIEW DOCUMENT
  // ═══════════════════════════════════════════════════════════════════

  void _viewDocument(
      String title,
      String? url,
      String? documentNumber,
      DateTime? expiryDate,
      ) {
    if (url == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          title: title,
          url: url,
          documentNumber: documentNumber,
          expiryDate: expiryDate,
          createdAt: context.read<ProfileProvider>().documents!.createdAt,
          updatedAt: context.read<ProfileProvider>().documents!.updatedAt,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  // REQUEST UPDATE BUTTON
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildRequestUpdateButton() {
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
          'Request Document Update',
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
        title: const Text('Request Document Update'),
        content: const Text(
          'To upload or update your documents, please contact our support team. They will guide you through the verification process.',
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

// ═══════════════════════════════════════════════════════════════════
// DOCUMENT VIEWER SCREEN
// ═══════════════════════════════════════════════════════════════════

class DocumentViewerScreen extends StatelessWidget {
  final String title;
  final String url;
  final String? documentNumber;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DocumentViewerScreen({
    Key? key,
    required this.title,
    required this.url,
    this.documentNumber,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: () => _downloadDocument(context),
          ),

        ],
      ),
      body: Column(
        children: [
          // Document Image
          Expanded(
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
          ),

          // Document Details
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Document Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Document Number
                  if (documentNumber != null) ...[
                    _buildDetailRow(
                      'Document Number',
                      documentNumber!,
                      Icons.confirmation_number,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Expiry Date
                  if (expiryDate != null) ...[
                    _buildDetailRow(
                      'Expiry Date',
                      DateFormat('dd MMM yyyy').format(expiryDate!),
                      Icons.calendar_today,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Uploaded Date
                  _buildDetailRow(
                    'Uploaded',
                    DateFormat('dd MMM yyyy').format(createdAt),
                    Icons.upload_file,
                  ),

                  const SizedBox(height: 12),

                  // Last Updated
                  _buildDetailRow(
                    'Last Updated',
                    DateFormat('dd MMM yyyy').format(updatedAt),
                    Icons.update,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[400]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _downloadDocument(BuildContext context) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading...'),
          duration: Duration(seconds: 1),
        ),
      );

      final response = await http.get(Uri.parse(url));
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to: ${file.path}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Download failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

}