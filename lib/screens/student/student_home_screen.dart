// lib/screens/student/student_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
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

// ─────────────────────────────────────────────────────────────
// Bottom Nav Bar - Integrated
// ─────────────────────────────────────────────────────────────
class BottomNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const BottomNavItem(this.icon, this.selectedIcon, this.label);
}

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<BottomNavItem> items;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;
              
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.selectedIcon : item.icon,
                        color: isSelected ? Colors.orange : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.orange : Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Student Home Screen
// ─────────────────────────────────────────────────────────────
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
          BottomNavItem(Icons.announcement_outlined, Icons.announcement, 'Announce'),
          BottomNavItem(Icons.calendar_today_outlined, Icons.calendar_today, 'Events'),
          BottomNavItem(Icons.groups_outlined, Icons.groups, 'Orgs'),
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

  void _navigateToEventDetail(EventData event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          event: event,
          onRegistered: () {
            // Refresh the home screen when registered
            setState(() {});
          },
          isPastEvent: event.isPast,
        ),
      ),
    );
  }

  void _navigateToAnnouncementDetail(AnnouncementData announcement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnnouncementDetailScreen(
          announcement: announcement,
        ),
      ),
    );
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
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFBE4700),
                  ),
                ),
              ],
            ),
            actions: [
              // ── Shopping Cart ──
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
              
              // ── NOTIFICATION ICON WITH BADGE ──
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('isRead', isEqualTo: false)
                    .snapshots(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  
                  return Stack(
                    alignment: Alignment.center,
                    children: [
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
                      if (unreadCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
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

          // Welcome Section
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
                      color: Colors.grey.shade600,
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
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Access
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Quick Access',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ),

          // Quick Access Icons
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
                          builder: (context) => const StudentEventsScreen(initialTabIndex: 0),
                        ),
                      );
                    },
                  ),
                  _QuickAccessItem(
                    icon: Icons.card_membership,
                    label: 'Certificate',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentEventsScreen(initialTabIndex: 2),
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
                  _QuickAccessItem(
                    icon: Icons.person,
                    label: 'Profile',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentProfileScreen(),
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
                  Text(
                    'Upcoming Events',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StudentEventsScreen(initialTabIndex: 1),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.orange,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
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
                    child: SkeletonLoader(count: 2, height: 120),
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
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final doc = events[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      // Convert to EventData
                      final eventData = EventData.fromFirestore(doc);
                      
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
                      final title = data['title'] ?? 'Untitled Event';
                      final location = data['location'] ?? 'TBA';
                      
                      return GestureDetector(
                        onTap: () => _navigateToEventDetail(eventData),
                        child: Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── ORANGE TOP ──
                              Container(
                                height: 90,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Colors.orange,
                                      Color(0xFFFF8C42),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(14),
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: Colors.white.withOpacity(0.8),
                                      size: 22,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$monthName $dayNumber',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // ── WHITE BOTTOM ──
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            formattedTime,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 3),
                                        Expanded(
                                          child: Text(
                                            location,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey.shade600,
                                            ),
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
                  Text(
                    'Announcements',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
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
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Announcements Feed
          SliverToBoxAdapter(
            child: AnnouncementsFeed(
              onTap: (announcementData) {
                _navigateToAnnouncementDetail(announcementData);
              },
            ),
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
// Quick Access Item
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
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}