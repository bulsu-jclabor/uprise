// lib/screens/student/student_home_screen.dart
import 'dart:async';
import 'dart:convert';
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
// Shared style tokens (UI only — no logic here)
// ─────────────────────────────────────────────────────────────
class _UiTokens {
  static const double radius = 12;
  static const Color divider = Color(0xFFE7E7E9);
  static const Color cardBorder = Color(0xFFEDEDEF);
  static const Color mutedText = Color(0xFF6B6B70);
  static const Color headingText = Color(0xFF1B1B1D);

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration card({double radiusOverride = radius}) => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radiusOverride),
    border: Border.all(color: cardBorder, width: 1),
    boxShadow: subtleShadow,
  );
}

// Helper widget to display base64 images
class Base64Image extends StatelessWidget {
  final String base64String;
  final double height;
  final double width;
  final BoxFit fit;

  const Base64Image({
    super.key,
    required this.base64String,
    this.height = 100,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    try {
      // Extract the base64 part if it's a data URL
      String base64Data = base64String;
      if (base64String.startsWith('data:image')) {
        // Find the comma that separates the metadata from the base64 data
        final commaIndex = base64String.indexOf(',');
        if (commaIndex != -1) {
          base64Data = base64String.substring(commaIndex + 1);
        }
      }

      final bytes = base64Decode(base64Data);
      return Image.memory(
        bytes,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: height,
            width: width,
            color: AppColors.primaryDark.withOpacity(0.1),
            child: const Icon(
              Icons.image_not_supported,
              color: Colors.grey,
              size: 40,
            ),
          );
        },
      );
    } catch (e) {
      return Container(
        height: height,
        width: width,
        color: AppColors.primaryDark.withOpacity(0.1),
        child: const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
          size: 40,
        ),
      );
    }
  }
}

// Reusable section header used across Quick Access / Events / Announcements
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primaryDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _UiTokens.headingText,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          ),
      ],
    );
  }
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
        border: const Border(
          top: BorderSide(color: _UiTokens.divider, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = currentIndex == index;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(index),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryDark.withOpacity(0.06)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isSelected ? item.selectedIcon : item.icon,
                          color: isSelected
                              ? AppColors.primaryDark
                              : _UiTokens.mutedText,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primaryDark
                                : _UiTokens.mutedText,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                        ),
                      ],
                    ),
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

          final greetingName = [
            firstName,
            middleName,
          ].where((p) => p.isNotEmpty).join(' ');

          setState(() {
            _userName = greetingName.isNotEmpty
                ? greetingName
                : (user.displayName ??
                      user.email?.split('@').first ??
                      'Student');
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
          BottomNavItem(
            Icons.announcement_outlined,
            Icons.announcement,
            'Announce',
          ),
          BottomNavItem(
            Icons.calendar_today_outlined,
            Icons.calendar_today,
            'Events',
          ),
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

      final ids = snap.docs.map((doc) => doc['eventId'] as String).toSet();

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
        debugPrint(
          '✅ Earliest future event found: ${event.title} - ${event.date}',
        );
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
          debugPrint(
            '✅ Earliest future event (fallback): ${event.title} - ${event.date}',
          );
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

      String? orgId = studentDoc.data()?['orgId'] as String?;
      if (orgId == null || orgId.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        orgId = userDoc.data()?['orgId'] as String?;
      }

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
        builder: (context) =>
            AnnouncementDetailScreen(announcement: announcement),
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'TBA';
    final date = timestamp.toDate();
    return DateFormat('MMM dd, yyyy').format(date);
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
            scrolledUnderElevation: 0,
            bottom: const PreferredSize(
              preferredSize: Size.fromHeight(1),
              child: Divider(height: 1, thickness: 1, color: _UiTokens.divider),
            ),
            title: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 44,
                  width: 44,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.school,
                    color: AppColors.primaryDark,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'UPRISE',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFFBE4700),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primaryDark,
                  size: 22,
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
                  final unreadCount = snapshot.hasData
                      ? snapshot.data!.docs.length
                      : 0;

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.notifications_outlined,
                          color: AppColors.primaryDark,
                          size: 22,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const StudentNotificationsScreen(),
                            ),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFC0392B),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Center(
                              child: Text(
                                unreadCount > 9 ? '9+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 6),
            ],
          ),

          // Offline indicator
          if (_isOffline)
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFFF6EEDD),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 14,
                      color: Color(0xFF8A6D1F),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Offline — showing cached data',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF8A6D1F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Welcome Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GOOD DAY',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: _UiTokens.headingText,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Here\'s what\'s happening on campus today.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quick Access
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: const _SectionHeader(title: 'Quick Access'),
            ),
          ),

          // Quick Access Icons
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickAccessItem(
                    icon: Icons.calendar_today_outlined,
                    label: 'Calendar',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const StudentEventsScreen(initialTabIndex: 0),
                        ),
                      );
                    },
                  ),
                  _QuickAccessItem(
                    icon: Icons.card_membership_outlined,
                    label: 'Certificates',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const StudentCertificatesScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessItem(
                    icon: Icons.groups_outlined,
                    label: 'Orgs',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const StudentOrganizationsScreen(),
                        ),
                      );
                    },
                  ),
                  _QuickAccessItem(
                    icon: Icons.person_outline,
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
                    height: 130,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: _UiTokens.card(),
                    child: const Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    child: FutureBuilder<EventModel?>(
                      future: _getEarliestRegisteredEvent(),
                      builder: (context, snapshot) {
                        debugPrint(
                          '🔍 Countdown FutureBuilder: connectionState=${snapshot.connectionState}, hasData=${snapshot.hasData}, error=${snapshot.error}',
                        );

                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Container(
                            height: 130,
                            decoration: _UiTokens.card(),
                            child: const Center(
                              child: SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          );
                        }

                        if (snapshot.hasError) {
                          return Container(
                            height: 130,
                            decoration: _UiTokens.card(),
                            child: Center(
                              child: Text(
                                'Error: ${snapshot.error}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        if (snapshot.data == null) {
                          debugPrint(
                            '📌 No future events found - hiding countdown',
                          );
                          return const SizedBox.shrink();
                        }

                        final event = snapshot.data!;
                        debugPrint(
                          '✅ Countdown event found: ${event.title} - ${event.date}',
                        );

                        return CountdownWidget(event: event);
                      },
                    ),
                  ),
          ),

          // Upcoming Events Section Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: _SectionHeader(
                title: 'Upcoming Events',
                actionLabel: 'View all',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const StudentEventsScreen(initialTabIndex: 1),
                    ),
                  );
                },
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
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: SkeletonLoader(count: 2, height: 120),
                  );
                }

                if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: UpriseErrorState(message: 'Could not load events.'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: UpriseEmptyState(
                      icon: Icons.calendar_today_outlined,
                      title: 'No upcoming events',
                      subtitle:
                          'Check back later for new events from your organizations.',
                    ),
                  );
                }

                final events = snapshot.data!.docs;

                return SizedBox(
                  height: 240, // Increased height to accommodate date
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final doc = events[index];
                      final eventData = EventModel.fromFirestore(doc);
                      final data = doc.data() as Map<String, dynamic>;

                      // Get the banner URL (base64 data URL)
                      final bannerUrl = data['bannerUrl'] as String? ?? '';
                      final eventDate = data['date'] as Timestamp?;
                      final formattedDate = _formatDate(eventDate);

                      return GestureDetector(
                        onTap: () => _navigateToEventDetail(eventData),
                        child: Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: _UiTokens.card(),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Event Image (cover photo) - Using Base64Image widget
                              bannerUrl.isNotEmpty
                                  ? Base64Image(
                                      base64String: bannerUrl,
                                      height: 100,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      height: 100,
                                      width: double.infinity,
                                      color: AppColors.primaryDark.withOpacity(
                                        0.1,
                                      ),
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                        size: 40,
                                      ),
                                    ),
                              Padding(
                                padding: const EdgeInsets.all(11),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title'] ?? 'Untitled Event',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _UiTokens.headingText,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    // Event Date
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            formattedDate,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    // Event Time
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            data['startTime'] ?? 'TBA',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    // Event Location
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          size: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            data['location'] ?? 'TBA',
                                            style: TextStyle(
                                              fontSize: 10.5,
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
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 10),
              child: _SectionHeader(
                title: 'Announcements',
                actionLabel: 'See all',
                onAction: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentAnnouncementsScreen(),
                    ),
                  );
                },
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

          const SliverToBoxAdapter(child: SizedBox(height: 84)),
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
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primaryDark.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Icon(icon, color: AppColors.primaryDark, size: 24),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: _UiTokens.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
