// lib/screens/student/student_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../widgets/common/bottom_nav_bar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/student/announcements_feed.dart';
import '../../widgets/student/profile_summary.dart';
import 'student_events_screen.dart';
import 'student_organizations_screen.dart';
import 'student_certificates_screen.dart';
import 'student_profile_screen.dart';
import 'student_announcements_screen.dart';
import 'student_notifications_screen.dart';
import 'student_merchandise_screen.dart';

// ─────────────────────────────────────────────────────────────
// Custom Colors - UNIFORM (using default Colors.orange)
// ─────────────────────────────────────────────────────────────
class AppColors {
  static const Color primaryDark = Colors.orange;
  static const Color primaryLight = Color(0xFFFFCC80);
  static const Color accent = Color(0xFFFF9800);
  static const Color background = Color(0xFFF8F9FA);
}

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  String _userName = '';
  
  // Key for the home content to refresh it
  final GlobalKey<_HomeContentState> _homeKey = GlobalKey<_HomeContentState>();

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('students')
            .where('uid', isEqualTo: user.uid)
            .limit(1)
            .get();

        if (snapshot.docs.isNotEmpty) {
          final data = snapshot.docs.first.data();
          setState(() {
            _userName = data['fullName'] ?? user.displayName ?? user.email?.split('@').first ?? 'Student';
          });
        }
      } catch (_) {
        // Keep default name
      }
    }
  }

  // Method to refresh user name when home tab is tapped
  void _refreshUserName() async {
    await _loadUserName();
    // Also refresh the home content if it's mounted
    if (_homeKey.currentState != null) {
      _homeKey.currentState!.refreshData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
          
          // If home tab is tapped (index 0), refresh the name
          if (index == 0) {
            _refreshUserName();
          }
        },
        items: const [
          BottomNavItem(Icons.home_outlined, Icons.home, 'Home'),
          BottomNavItem(Icons.announcement_outlined, Icons.announcement, 'Announcements'),
          BottomNavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Events'),
          BottomNavItem(Icons.groups_outlined, Icons.groups, 'Orgs'),
          BottomNavItem(Icons.card_membership_outlined, Icons.card_membership, 'Certs'),
          BottomNavItem(Icons.person_outline, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  List<Widget> get _screens => [
    _HomeContent(key: _homeKey, userName: _userName),
    const StudentAnnouncementsScreen(),
    const StudentEventsScreen(),
    const StudentOrganizationsScreen(),
    const StudentCertificatesScreen(),
    const StudentProfileScreen(),
  ];
}

class _HomeContent extends StatefulWidget {
  final String userName;
  
  const _HomeContent({super.key, required this.userName});

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  Map<String, dynamic>? _orgData;
  bool _orgLoading = true;
  bool _isOffline = false;
  StreamSubscription<QuerySnapshot>? _cacheMonitor;

  @override
  void initState() {
    super.initState();
    _loadOrgData();
    _cacheMonitor = FirebaseFirestore.instance
        .collection('events')
        .limit(1)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      if (mounted && snap.metadata.isFromCache != _isOffline) {
        setState(() => _isOffline = snap.metadata.isFromCache);
      }
    });
  }

  @override
  void dispose() {
    _cacheMonitor?.cancel();
    super.dispose();
  }

  // Method to refresh data when home tab is tapped
  void refreshData() {
    setState(() {
      // This will trigger a rebuild with the new userName from parent
    });
  }

  Future<void> _loadOrgData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _orgLoading = false);
      return;
    }
    try {
      final studentSnap = await FirebaseFirestore.instance
          .collection('students')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (studentSnap.docs.isEmpty) {
        setState(() => _orgLoading = false);
        return;
      }

      final orgId = studentSnap.docs.first.data()['orgId'] as String?;
      if (orgId == null || orgId.isEmpty) {
        setState(() => _orgLoading = false);
        return;
      }

      final orgSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();

      setState(() {
        _orgData = orgSnap.exists ? orgSnap.data() : null;
        _orgLoading = false;
      });
    } catch (_) {
      setState(() => _orgLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    // Use the userName passed from parent, or fallback
    final userName = widget.userName.isNotEmpty 
        ? widget.userName 
        : user?.displayName ?? user?.email?.split('@').first ?? 'Student';

    return Container(
      color: AppColors.background,
      child: CustomScrollView(
        slivers: [
          // App Bar with Logo
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.white,
            elevation: 0,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 36,
                  width: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'UPRISE',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFBE4700),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: Colors.orange,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentMerchandiseScreen(),
                    ),
                  );
                },
              ),
              IconButton(
                icon: Icon(
                  Icons.notifications_outlined,
                  color: Colors.orange,
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentNotificationsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          
          // Offline indicator
          if (_isOffline)
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFFFFF3CD),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: const Row(
                  children: [
                    Icon(Icons.wifi_off_rounded, size: 14, color: Color(0xFF856404)),
                    SizedBox(width: 6),
                    Text(
                      'Offline — showing cached data',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF856404),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Welcome Section - Uses updated userName
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GOOD DAY,',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Hello, $userName',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ready to explore today\'s campus activities?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Access Section with Label
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),

          // Quick Access Icons (Uniform color - Colors.orange)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickAccessItem(
                    icon: Icons.calendar_today,
                    label: 'Calendar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentEventsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessItem(
                    icon: Icons.event_note,
                    label: 'My Events',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentEventsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessItem(
                    icon: Icons.card_membership,
                    label: 'Certs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentCertificatesScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessItem(
                    icon: Icons.groups,
                    label: 'Orgs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentOrganizationsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // Upcoming Events Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentEventsScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Upcoming Events - Horizontal Scroll Cards
          SliverToBoxAdapter(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('date', isGreaterThanOrEqualTo: Timestamp.now())
                  .orderBy('date', descending: false)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SkeletonLoader(count: 2, height: 110),
                  );
                }

                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: UpriseErrorState(message: 'Could not load events.'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: UpriseEmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: 'No upcoming events',
                      subtitle: 'Check back later for new events from your organizations.',
                    ),
                  );
                }

                final events = snapshot.data!.docs;
                
                return SizedBox(
                  height: 210,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final doc = events[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      Timestamp? timestamp = data['date'];
                      DateTime eventDate;
                      
                      if (timestamp != null) {
                        eventDate = timestamp.toDate();
                      } else {
                        eventDate = DateTime.now();
                      }
                      
                      final monthName = DateFormat('MMM').format(eventDate);
                      final dayNumber = DateFormat('dd').format(eventDate);
                      final formattedTime = data['startTime'] ?? 'TBA';
                      final location = data['location'] ?? 'TBA';
                      final title = data['title'] ?? 'Untitled Event';
                      
                      return Container(
                        width: 220,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                              child: data['bannerUrl'] != null && (data['bannerUrl'] as String).isNotEmpty
                                  ? Image.network(
                                      data['bannerUrl'],
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        height: 100,
                                        color: Colors.orange.withOpacity(0.1),
                                        child: const Icon(Icons.event, color: Colors.orange),
                                      ),
                                    )
                                  : Container(
                                      height: 100,
                                      color: Colors.orange.withOpacity(0.1),
                                      child: const Icon(Icons.event, color: Colors.orange),
                                    ),
                            ),
                            
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$monthName $dayNumber',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 11, color: Colors.grey),
                                      const SizedBox(width: 3),
                                      Expanded(
                                        child: Text(
                                          formattedTime,
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
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
                    },
                  ),
                );
              },
            ),
          ),
          
          // Announcements Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Announcements',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentAnnouncementsScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Announcements Feed
          const SliverToBoxAdapter(
            child: AnnouncementsFeed(),
          ),

          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Quick Access Item (Uniform color - Colors.orange)
// ─────────────────────────────────────────────────────────────
class _QuickAccessItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}