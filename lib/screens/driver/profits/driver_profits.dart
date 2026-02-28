import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation bar/bottom_navigation.dart';


// Main wrapper that handles navigation between screens for Earnings
class EarningsMainScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String? accessToken;

  const EarningsMainScreen({
    super.key,
    this.user,
    this.accessToken,
  });

  @override
  State<EarningsMainScreen> createState() => _EarningsMainScreenState();
}

class _EarningsMainScreenState extends State<EarningsMainScreen> {
  int currentTabIndex = 2; // Start with Earnings tab selected

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _getSelectedScreen(),
      bottomNavigationBar: WegoBottomNavigation(
        currentIndex: currentTabIndex,
        onTabSelected: (index) {
          setState(() => currentTabIndex = index);
        },
      ),
    );
  }

  Widget _getSelectedScreen() {
    switch (currentTabIndex) {
      case 0:
        return _buildHomeScreen(); // Placeholder for now
      case 1:
        return _buildCoursesScreen(); // Placeholder for now
      case 2:
        return EarningsScreen(
          user: widget.user,
          accessToken: widget.accessToken,
        );
      case 3:
        return _buildAlertsScreen(); // Placeholder for now
      case 4:
        return _buildProfileScreen(); // Placeholder for now
      default:
        return EarningsScreen(
          user: widget.user,
          accessToken: widget.accessToken,
        );
    }
  }

  // Placeholder screens - you'll replace these with actual screen widgets later
  Widget _buildHomeScreen() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.home_outlined, size: 64, color: Color(0xFFFFDC71)),
            SizedBox(height: 16),
            Text(
              'Accueil Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This screen will show the dashboard'),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursesScreen() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car_outlined, size: 64, color: Color(0xFFFFDC71)),
            SizedBox(height: 16),
            Text(
              'Courses Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This screen will show trip history'),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsScreen() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_outlined, size: 64, color: Color(0xFFFFDC71)),
            SizedBox(height: 16),
            Text(
              'Alertes Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This screen will show notifications'),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileScreen() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_outline, size: 64, color: Color(0xFFFFDC71)),
            SizedBox(height: 16),
            Text(
              'Profil Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This screen will show driver profile'),
          ],
        ),
      ),
    );
  }
}

// Earnings Screen Content
class EarningsScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String? accessToken;

  const EarningsScreen({
    super.key,
    this.user,
    this.accessToken,
  });

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  bool isLoading = true;
  String selectedPeriod = 'Cette semaine';
  Map<String, dynamic>? earningsData;
  List<Map<String, dynamic>> earningsHistory = [];
  List<Map<String, dynamic>> payoutHistory = [];

  @override
  void initState() {
    super.initState();
    print('EarningsScreen: initState called');
    _fetchEarningsData();
  }

  Future<void> _fetchEarningsData() async {
    print('EarningsScreen: Starting to fetch earnings data');
    try {
      setState(() => isLoading = true);

      // Simulate API delay
      print('EarningsScreen: Simulating API delay...');
      await Future.delayed(const Duration(seconds: 1));

      // Sample earnings data - replace with actual API call
      final sampleEarningsData = {
        'currentBalance': 125750,
        'totalEarnings': 485000,
        'thisWeek': {
          'total': 125750,
          'trips': 48,
          'averagePerTrip': 2620,
          'onlineHours': 42.5,
          'ratePerHour': 2958,
          'growth': 15.2,
        },
        'thisMonth': {
          'total': 485000,
          'trips': 156,
          'averagePerTrip': 3109,
          'onlineHours': 168,
          'ratePerHour': 2887,
          'growth': 8.7,
        },
        'breakdown': {
          'tripEarnings': 98600,
          'bonuses': 15400,
          'tips': 8750,
          'promotions': 3000,
        },
        'paymentMethods': {
          'orangeMoney': 67230,
          'mtnMoney': 45520,
          'cash': 13000,
        },
        'weeklyData': [
          {'day': 'Lun', 'amount': 18500},
          {'day': 'Mar', 'amount': 22300},
          {'day': 'Mer', 'amount': 19800},
          {'day': 'Jeu', 'amount': 25200},
          {'day': 'Ven', 'amount': 21600},
          {'day': 'Sam', 'amount': 28450},
          {'day': 'Dim', 'amount': 15900},
        ],
      };

      // Sample earnings history
      final sampleEarningsHistory = List.generate(30, (index) {
        final date = DateTime.now().subtract(Duration(days: index));
        return {
          'date': date,
          'amount': 15000 + (index * 300) + (index % 7 * 1000),
          'trips': 5 + (index % 3),
          'onlineHours': 6.5 + (index % 3),
          'tips': 500 + (index * 50),
          'bonuses': index % 5 == 0 ? 2000 : 0,
        };
      });

      // Sample payout history
      final samplePayoutHistory = [
        {
          'id': 'PO-001',
          'date': DateTime.now().subtract(const Duration(days: 7)),
          'amount': 98500,
          'method': 'Orange Money',
          'status': 'Completed',
          'processingTime': '2 min',
        },
        {
          'id': 'PO-002',
          'date': DateTime.now().subtract(const Duration(days: 14)),
          'amount': 87200,
          'method': 'MTN Money',
          'status': 'Completed',
          'processingTime': '5 min',
        },
        {
          'id': 'PO-003',
          'date': DateTime.now().subtract(const Duration(days: 21)),
          'amount': 105800,
          'method': 'Orange Money',
          'status': 'Completed',
          'processingTime': '3 min',
        },
      ];

      if (mounted) {
        setState(() {
          earningsData = sampleEarningsData;
          earningsHistory = sampleEarningsHistory;
          payoutHistory = samplePayoutHistory;
          isLoading = false;
        });
        print('EarningsScreen: Earnings data loaded successfully');
        print('EarningsScreen: Current balance: ${earningsData!['currentBalance']} FCFA');
      }

    } catch (e) {
      print('EarningsScreen: Error fetching earnings data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Erreur lors du chargement des gains');
      }
    }
  }

  void _requestPayout() {
    print('EarningsScreen: Payout requested');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Demander un retrait'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Solde disponible: ${earningsData!['currentBalance']} FCFA'),
            const SizedBox(height: 16),
            const TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant à retirer',
                suffixText: 'FCFA',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Méthode de paiement',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'orange', child: Text('Orange Money')),
                DropdownMenuItem(value: 'mtn', child: Text('MTN Mobile Money')),
              ],
              onChanged: (value) {},
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showSuccessSnackBar('Demande de retrait envoyée');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFDC71),
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    print('EarningsScreen: Showing ERROR snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    print('EarningsScreen: Showing SUCCESS snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  String _formatAmount(num amount) {
    String str = amount.toString();
    String result = '';
    int count = 0;

    for (int i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        result = ',$result';
      }
      result = '${str[i]}$result';
      count++;
    }

    return '$result FCFA';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Aujourd\'hui';
    } else if (difference.inDays == 1) {
      return 'Hier';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} jours';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    print('EarningsScreen: Building widget - Loading: $isLoading, Period: $selectedPeriod');

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildPeriodTabs(),
          Expanded(
            child: _buildMainContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFFDC71),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.attach_money,
              color: Colors.black,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mes gains',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Suivez vos revenus et retraits',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              print('EarningsScreen: Export button tapped');
              _showSuccessSnackBar('Export des données en cours...');
            },
            icon: const Icon(Icons.file_download, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTabs() {
    final periods = ['Aujourd\'hui', 'Cette semaine', 'Ce mois', 'Tout temps'];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: periods.length,
        itemBuilder: (context, index) {
          final period = periods[index];
          final isSelected = selectedPeriod == period;

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(period),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedPeriod = period;
                });
                print('EarningsScreen: Period changed to $period');
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFFFFDC71),
              checkmarkColor: Colors.black,
              labelStyle: TextStyle(
                color: isSelected ? Colors.black : Colors.grey.shade600,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFFFDC71) : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent() {
    if (isLoading) {
      print('EarningsScreen: Displaying loading spinner');
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFDC71)),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFFFFDC71),
      onRefresh: _fetchEarningsData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBalanceCard(),
            const SizedBox(height: 20),
            _buildStatsGrid(),
            const SizedBox(height: 20),
            _buildEarningsBreakdown(),
            const SizedBox(height: 20),
            _buildWeeklyChart(),
            const SizedBox(height: 20),
            _buildPaymentMethodsBreakdown(),
            const SizedBox(height: 20),
            _buildRecentPayouts(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFFFDC71),
            const Color(0xFFFFDC71).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Solde disponible',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Disponible',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _formatAmount(earningsData!['currentBalance']),
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _requestPayout,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: const Color(0xFFFFDC71),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Demander un retrait',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final stats = selectedPeriod == 'Cette semaine'
        ? earningsData!['thisWeek']
        : earningsData!['thisMonth'];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildStatCard(
          title: 'Total gains',
          value: _formatAmount(stats['total']),
          growth: stats['growth'],
          icon: Icons.trending_up,
          color: Colors.green,
        ),
        _buildStatCard(
          title: 'Courses',
          value: '${stats['trips']}',
          subtitle: 'terminées',
          icon: Icons.directions_car,
          color: Colors.blue,
        ),
        _buildStatCard(
          title: 'Moyenne/course',
          value: _formatAmount(stats['averagePerTrip']),
          icon: Icons.calculate,
          color: Colors.purple,
        ),
        _buildStatCard(
          title: 'Temps en ligne',
          value: '${stats['onlineHours']}h',
          subtitle: '${_formatAmount(stats['ratePerHour'])}/h',
          icon: Icons.access_time,
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    String? subtitle,
    double? growth,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (growth != null) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+${growth.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsBreakdown() {
    final breakdown = earningsData!['breakdown'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Répartition des gains',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildBreakdownItem(
            'Courses',
            breakdown['tripEarnings'],
            Colors.blue.shade600,
            Icons.directions_car,
          ),
          _buildBreakdownItem(
            'Bonus',
            breakdown['bonuses'],
            Colors.green.shade600,
            Icons.star,
          ),
          _buildBreakdownItem(
            'Pourboires',
            breakdown['tips'],
            const Color(0xFFFFDC71),
            Icons.thumb_up,
          ),
          _buildBreakdownItem(
            'Promotions',
            breakdown['promotions'],
            Colors.purple.shade600,
            Icons.local_offer,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, num amount, Color color, IconData icon) {
    final total = earningsData!['breakdown'].values.fold(0, (a, b) => a + b);
    final percentage = (amount / total * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatAmount(amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: amount / total,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    final weeklyData = earningsData!['weeklyData'] as List;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gains cette semaine',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyData.map((data) {
                final maxAmount = weeklyData.map((d) => d['amount'] as num).reduce((a, b) => a > b ? a : b);
                final height = (data['amount'] as num) / maxAmount * 100;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                '${((data['amount'] as num) / 1000).toStringAsFixed(0)}k',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: 24,
                      height: height,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFDC71),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      data['day'],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodsBreakdown() {
    final methods = earningsData!['paymentMethods'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Paiements reçus par méthode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentMethodItem(
            'Orange Money',
            methods['orangeMoney'],
            Colors.orange.shade600,
            Icons.phone_android,
          ),
          _buildPaymentMethodItem(
            'MTN Mobile Money',
            methods['mtnMoney'],
            Colors.yellow.shade700,
            Icons.smartphone,
          ),
          _buildPaymentMethodItem(
            'Espèces',
            methods['cash'],
            Colors.green.shade600,
            Icons.payments,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodItem(String method, num amount, Color color, IconData icon) {
    final total = earningsData!['paymentMethods'].values.fold(0, (a, b) => a + b);
    final percentage = (amount / total * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      method,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatAmount(amount),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: amount / total,
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPayouts() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Retraits récents',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  print('EarningsScreen: View all payouts tapped');
                },
                child: const Text(
                  'Voir tout',
                  style: TextStyle(
                    color: Color(0xFFFFDC71),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...payoutHistory.take(3).map((payout) => _buildPayoutItem(payout)).toList(),
        ],
      ),
    );
  }

  Widget _buildPayoutItem(Map<String, dynamic> payout) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.check_circle,
              color: Colors.green.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      payout['id'],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        payout['status'],
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${payout['method']} • ${_formatDate(payout['date'])}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatAmount(payout['amount']),
            style: TextStyle(
              color: Colors.green.shade600,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}