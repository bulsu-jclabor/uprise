// lib/screens/student/student_home_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uprise/models/event_model.dart';
import '../../providers/event_provider.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/student/announcements_feed.dart';
import '../../widgets/student/profile_summary.dart';
import '../../widgets/student/countdown_widget.dart';
import '../../widgets/student/app_colors.dart';
import 'student_events_screen.dart';
import 'student_organizations_screen.dart';
import 'student_certificates_screen.dart';
import 'student_profile_screen.dart';
import 'student_announcements_screen.dart';
import 'student_notifications_screen.dart';
import 'student_merchandise_screen.dart';
import 'student_feedback_prompt.dart';


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
                        color: isSelected ? AppColors.primaryDark : Colors.grey,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? AppColors.primaryDark : Colors.grey,
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
  
  final GlobalKey<_HomeContentState> _homeKey = GlobalKey<_HomeContentState>();

  @override
  void initState() {
    super.initState();
    _loadUserName();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowFeedbackPrompt(context);
    });
  }

  Future<void> _loadUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('students')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final firstName = (data['firstName'] ?? '').toString().trim();
          final middleName = (data['middleName'] ?? '').toString().trim();

          final greetingName = [firstName, middleName]
              .where((p) => p.isNotEmpty)
              .join(' ');

          setState(() {
            _userName = greetingName.isNotEmpty
                ? greetingName
                : (user.displayName ?? user.email?.split('@').first ?? 'Student');
          });
        }
      } catch (_) {
        // Keep default name
      }
    }
  }

  void _refreshUserName() async {
    await _loadUserName();
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
  
  // ⭐ REGISTERED EVENTS STATE ⭐
  Set<String> _registeredEventIds = {};
  bool _loadingRegistered = true;

  @override
  void initState() {
    super.initState();
    _loadOrgData();
    _loadRegisteredEvents();
    
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

  // ⭐ LOAD ONLY THIS STUDENT'S REGISTERED EVENTS ⭐
  Future<void> _loadRegisteredEvents() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _registeredEventIds = {};
        _loadingRegistered = false;
      });
      return;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .get();

      final ids = snap.docs
          .map((doc) => doc['eventId'] as String)
          .toSet();

      debugPrint('✅ Registered event IDs: $ids');
      debugPrint('✅ Number of registered events: ${ids.length}');

      setState(() {
        _registeredEventIds = ids;
        _loadingRegistered = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading registrations: $e');
      setState(() {
        _registeredEventIds = {};
        _loadingRegistered = false;
      });
    }
  }

  // ⭐ GET EARLIEST REGISTERED EVENT - Only future events ⭐
  Future<EventModel?> _getEarliestRegisteredEvent() async {
    if (_registeredEventIds.isEmpty) {
      debugPrint('📌 No registered events');
      return null;
    }

    final eventIds = _registeredEventIds.toList();
    debugPrint('📌 Event IDs count: ${eventIds.length}');
    
    // If less than or equal to 30, query directly
    if (eventIds.length <= 30) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('events')
            .where(FieldPath.documentId, whereIn: eventIds)
            .where('date', isGreaterThanOrEqualTo: Timestamp.now())
            .orderBy('date')
            .limit(1)
            .get();
        
        if (snap.docs.isEmpty) {
          debugPrint('📌 No future events found');
          return null;
        }
        
        final event = EventModel.fromFirestore(snap.docs.first);
        debugPrint('✅ Earliest future event found: ${event.title} - ${event.date}');
        debugPrint('✅ Event ID: ${event.id}');
        return event;
      } catch (e) {
        debugPrint('❌ Error querying events (direct): $e');
        // FALLBACK: Query without date filter
        try {
          final snap = await FirebaseFirestore.instance
              .collection('events')
              .where(FieldPath.documentId, whereIn: eventIds)
              .get();
          
          if (snap.docs.isEmpty) return null;
          
          final now = DateTime.now();
          final futureEvents = snap.docs
              .map((doc) => EventModel.fromFirestore(doc))
              .where((event) => event.fullDateTime.isAfter(now))
              .toList();
          
          if (futureEvents.isEmpty) {
            debugPrint('📌 No future events found (fallback)');
            return null;
          }
          
          futureEvents.sort((a, b) => a.fullDateTime.compareTo(b.fullDateTime));
          final event = futureEvents.first;
          debugPrint('✅ Earliest future event (fallback): ${event.title} - ${event.date}');
          return event;
        } catch (e2) {
          debugPrint('❌ Error querying events (fallback): $e2');
          return null;
        }
      }
    }

    // If more than 30, query in batches
    final allEvents = <EventModel>[];
    for (var i = 0; i < eventIds.length; i += 30) {
      final end = (i + 30 < eventIds.length) ? i + 30 : eventIds.length;
      final batch = eventIds.sublist(i, end);
      
      if (batch.isEmpty) continue;
      
      try {
        final snap = await FirebaseFirestore.instance
            .collection('events')
            .where(FieldPath.documentId, whereIn: batch)
            .where('date', isGreaterThanOrEqualTo: Timestamp.now())
            .get();
        
        for (final doc in snap.docs) {
          allEvents.add(EventModel.fromFirestore(doc));
        }
      } catch (e) {
        debugPrint('❌ Error querying batch: $e');
        // FALLBACK: Query without date filter for this batch
        try {
          final snap = await FirebaseFirestore.instance
              .collection('events')
              .where(FieldPath.documentId, whereIn: batch)
              .get();
          
          for (final doc in snap.docs) {
            allEvents.add(EventModel.fromFirestore(doc));
          }
        } catch (e2) {
          debugPrint('❌ Error querying batch (fallback): $e2');
        }
      }
    }

    // Filter future events in code
    final now = DateTime.now();
    final futureEvents = allEvents
        .where((event) => event.fullDateTime.isAfter(now))
        .toList();
    
    if (futureEvents.isEmpty) {
      debugPrint('📌 No future events found in batches');
      return null;
    }
    
    futureEvents.sort((a, b) => a.fullDateTime.compareTo(b.fullDateTime));
    final earliest = futureEvents.first;
    debugPrint('✅ Earliest future event: ${earliest.title} - ${earliest.date}');
    return earliest;
  }

  void refreshData() {
    setState(() {});
    _loadRegisteredEvents();
  }

  Future<void> _loadOrgData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _orgLoading = false);
      return;
    }
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (!studentDoc.exists) {
        setState(() => _orgLoading = false);
        return;
      }

      final orgId = studentDoc.data()?['orgId'] as String?;
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

  void _navigateToEventDetail(EventModel event) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EventDetailScreen(
          event: event,
          onRegistered: () {
            refreshData();
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
                    color: AppColors.primaryDark,
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
              IconButton(
                icon: Icon(
                  Icons.shopping_cart_outlined,
                  color: AppColors.primaryDark,
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
              
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('notifications')
                    .where('userId', isEqualTo: user?.uid)
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
                          color: AppColors.primaryDark,
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
                    label: 'Certificates',
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

          // ⭐ COUNTDOWN SECTION - Only for THIS STUDENT's future registered events ⭐
          SliverToBoxAdapter(
            child: _loadingRegistered
                ? Container(
                    height: 180,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(
                      child: SizedBox(
                        height: 30,
                        width: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  )
                : _registeredEventIds.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: FutureBuilder<EventModel?>(
                          future: _getEarliestRegisteredEvent(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Container(
                                height: 180,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    height: 30,
                                    width: 30,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryDark,
                                    ),
                                  ),
                                ),
                              );
                            }

                            // ✅ If no future events, don't show anything
                            if (snapshot.hasError || snapshot.data == null) {
                              return const SizedBox.shrink();
                            }

                            final event = snapshot.data!;
                            return CountdownWidget(event: event);
                          },
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
                      foregroundColor: AppColors.primaryDark,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDark,
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
                      
                      final eventData = EventModel.fromFirestore(doc);
                      
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
                              Container(
                                height: 90,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primaryDark,
                                      AppColors.primaryLight,
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
                      foregroundColor: AppColors.primaryDark,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primaryDark,
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
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryDark.withOpacity(0.25),
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