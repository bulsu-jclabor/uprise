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

class StudentHomeScreen extends StatefulWidget {
  const StudentHomeScreen({super.key});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _screens = [
    const _HomeContent(),
    const StudentAnnouncementsScreen(),
    const StudentEventsScreen(),
    const StudentOrganizationsScreen(),
    const StudentCertificatesScreen(),
    const StudentProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
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
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

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

  Widget _buildOrgCard() {
    if (_orgLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: SizedBox(
          height: 72,
          child: Center(child: LinearProgressIndicator(color: Color(0xFFFF6B00))),
        ),
      );
    }
    if (_orgData == null) return const SizedBox.shrink();

    final orgName = _orgData!['orgName'] ?? _orgData!['name'] ?? 'Your Organization';
    final logoUrl = (_orgData!['logoUrl'] ?? '') as String;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF6B00), Color(0xFFFF8C42)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF6B00).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child: logoUrl.isNotEmpty
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.groups, color: Colors.white, size: 26),
                      )
                    : const Icon(Icons.groups, color: Colors.white, size: 26),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR ORGANIZATION',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Colors.white70,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    orgName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.white,
          title: const Text('UPRISE'),
          actions: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
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
              icon: const Icon(Icons.notifications_outlined),
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

        // Profile Summary
        SliverToBoxAdapter(
          child: ProfileSummary(userEmail: user?.email ?? 'student@cict.bulsu.edu.ph'),
        ),

        // Organization Card
        SliverToBoxAdapter(child: _buildOrgCard()),

        // Upcoming Events Section Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                    foregroundColor: const Color(0xFFFF6B00),
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
        
        // Upcoming Events - Horizontal Scroll Cards (gaya ng design)
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
                height: 250,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final doc = events[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Get event date
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
                      width: 260,
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
                          // Banner/Image
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: data['bannerUrl'] != null && (data['bannerUrl'] as String).isNotEmpty
                                ? Image.network(
                                    data['bannerUrl'],
                                    height: 120,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      height: 120,
                                      color: const Color(0xFFFF6B00).withOpacity(0.1),
                                      child: const Icon(Icons.event, color: Color(0xFFFF6B00)),
                                    ),
                                  )
                                : Container(
                                    height: 120,
                                    color: const Color(0xFFFF6B00).withOpacity(0.1),
                                    child: const Icon(Icons.event, color: Color(0xFFFF6B00)),
                                  ),
                          ),
                          
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Date
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFF6B00).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '$monthName $dayNumber',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFFF6B00),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // Title
                                Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                // Time
                                Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      formattedTime,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                // Location
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        location,
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
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
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Announcements',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
    );
  }
}