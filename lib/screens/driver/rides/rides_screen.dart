import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../navigation bar/bottom_navigation.dart';


// Main wrapper that handles navigation between screens for Courses
class CoursesMainScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String? accessToken;

  const CoursesMainScreen({
    super.key,
    this.user,
    this.accessToken,
  });

  @override
  State<CoursesMainScreen> createState() => _CoursesMainScreenState();
}

class _CoursesMainScreenState extends State<CoursesMainScreen> {
  int currentTabIndex = 1; // Start with Courses tab selected

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
        return CoursesScreen(
          user: widget.user,
          accessToken: widget.accessToken,
        );
      case 2:
        return _buildEarningsScreen(); // Placeholder for now
      case 3:
        return _buildAlertsScreen(); // Placeholder for now
      case 4:
        return _buildProfileScreen(); // Placeholder for now
      default:
        return CoursesScreen(
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

  Widget _buildEarningsScreen() {
    return const SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_money_outlined, size: 64, color: Color(0xFFFFDC71)),
            SizedBox(height: 16),
            Text(
              'Gains Screen',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('This screen will show earnings details'),
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

// Courses Screen Content
class CoursesScreen extends StatefulWidget {
  final Map<String, dynamic>? user;
  final String? accessToken;

  const CoursesScreen({
    super.key,
    this.user,
    this.accessToken,
  });

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> tripHistory = [];
  String selectedFilter = 'Toutes';

  @override
  void initState() {
    super.initState();
    print('CoursesScreen: initState called');
    _fetchTripHistory();
  }

  Future<void> _fetchTripHistory() async {
    print('CoursesScreen: Starting to fetch trip history');
    try {
      setState(() => isLoading = true);

      // Simulate API delay
      print('CoursesScreen: Simulating API delay...');
      await Future.delayed(const Duration(seconds: 1));

      // Sample trip history data - replace with actual API call
      final sampleTripHistory = List.generate(15, (index) {
        final statuses = ['Terminée', 'Annulée', 'Terminée', 'Terminée'];
        final pickups = [
          'Place de l\'Indépendance',
          'Bastos',
          'Mvan',
          'Omnisports',
          'Tsinga',
          'Essos',
          'Emombo',
          'Nlongkak'
        ];
        final destinations = [
          'Aéroport International',
          'Gare Routière Mvan',
          'Marché Central',
          'Université de Yaoundé I',
          'Carrefour Warda',
          'Rond Point de la Poste',
          'Carrefour Obili',
          'Marché Mokolo'
        ];

        return {
          'id': '#${1000 + index}',
          'passenger': 'Client ${index + 1}',
          'pickup': pickups[index % pickups.length],
          'destination': destinations[index % destinations.length],
          'date': DateTime.now().subtract(Duration(hours: index + 1)),
          'amount': 2500 + (index * 100),
          'status': statuses[index % statuses.length],
          'rating': 4.0 + (index % 2),
          'distance': '${8 + (index % 10)}.${index % 10} km',
          'duration': '${15 + (index % 20)} min',
        };
      });

      if (mounted) {
        setState(() {
          tripHistory = sampleTripHistory;
          isLoading = false;
        });
        print('CoursesScreen: Trip history loaded - ${tripHistory.length} trips');
      }

    } catch (e) {
      print('CoursesScreen: Error fetching trip history: $e');
      if (mounted) {
        setState(() => isLoading = false);
        _showErrorSnackBar('Erreur lors du chargement de l\'historique');
      }
    }
  }

  List<Map<String, dynamic>> get filteredTrips {
    if (selectedFilter == 'Toutes') {
      return tripHistory;
    }
    return tripHistory.where((trip) => trip['status'] == selectedFilter).toList();
  }

  void _showErrorSnackBar(String message) {
    print('CoursesScreen: Showing ERROR snackbar: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
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

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    print('CoursesScreen: Building widget - Loading: $isLoading, Filter: $selectedFilter, Trips: ${tripHistory.length}');

    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildFilterTabs(),
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
              Icons.directions_car,
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
                  'Historique des courses',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                Text(
                  'Consultez vos courses passées',
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
              print('CoursesScreen: Search button tapped');
              // Add search functionality
            },
            icon: const Icon(Icons.search, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = ['Toutes', 'Terminée', 'Annulée'];

    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = selectedFilter == filter;

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  selectedFilter = filter;
                });
                print('CoursesScreen: Filter changed to $filter');
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
      print('CoursesScreen: Displaying loading spinner');
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFDC71)),
        ),
      );
    }

    final trips = filteredTrips;

    if (trips.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFFFFDC71),
      onRefresh: _fetchTripHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: trips.length,
        itemBuilder: (context, index) => _buildTripHistoryItem(trips[index], index),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune course trouvée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Les courses avec le filtre "$selectedFilter" apparaîtront ici',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTripHistoryItem(Map<String, dynamic> trip, int index) {
    final statusColor = trip['status'] == 'Terminée'
        ? Colors.green.shade600
        : Colors.red.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          print('CoursesScreen: Trip ${trip['id']} tapped');
          _showTripDetails(trip);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFDC71).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: Colors.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              trip['id'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                trip['status'],
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${_formatDate(trip['date'])} à ${_formatTime(trip['date'])}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${trip['amount']} FCFA',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (starIndex) {
                          return Icon(
                            Icons.star,
                            color: starIndex < trip['rating']
                                ? const Color(0xFFFFDC71)
                                : Colors.grey.shade300,
                            size: 12,
                          );
                        }),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Route details
              Row(
                children: [
                  Column(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.green.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 2,
                        height: 24,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip['pickup'],
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          trip['destination'],
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        trip['distance'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        trip['duration'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTripDetails(Map<String, dynamic> trip) {
    print('CoursesScreen: Showing details for trip ${trip['id']}');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Détails de la course ${trip['id']}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildDetailRow('Passager', trip['passenger']),
                    _buildDetailRow('Date', '${_formatDate(trip['date'])} à ${_formatTime(trip['date'])}'),
                    _buildDetailRow('Statut', trip['status']),
                    _buildDetailRow('Montant', '${trip['amount']} FCFA'),
                    _buildDetailRow('Distance', trip['distance']),
                    _buildDetailRow('Durée', trip['duration']),
                    _buildDetailRow('Note', '${trip['rating']} ⭐'),
                    const SizedBox(height: 20),
                    const Text(
                      'Itinéraire',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRouteDetail('Départ', trip['pickup'], Colors.green.shade600),
                    const SizedBox(height: 8),
                    _buildRouteDetail('Arrivée', trip['destination'], Colors.red.shade600),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDetail(String label, String location, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              Text(
                location,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}