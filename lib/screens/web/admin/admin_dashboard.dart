import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth_service.dart';

// Import your admin sections
import 'organization_management.dart';
import 'student_accounts.dart';
import 'adviser_roles.dart';
import 'event_proposals.dart';
import 'event_calendar.dart';
import 'letter_request.dart';
import 'external_account.dart';
import 'reports_management.dart';
import 'activity_logs.dart';

// ============ COLOR SCHEME (matching React design) ============
class UpriseColors {
  static const Color primaryDark = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent = Color(0xFFF59E0B);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF9FAFB);
  static const Color mediumGray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF6B7280);
  static const Color charcoal = Color(0xFF111827);
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);
}

// ============ ICON PATHS FOR SIDEBAR (simulating React icons) ============
const Map<String, IconData> _sidebarIcons = {
  'Dashboard': Icons.dashboard_outlined,
  'Organization Management': Icons.business_outlined,
  'Student Accounts': Icons.people_outline,
  'Adviser Roles': Icons.school_outlined,
  'Event Proposals': Icons.pending_actions_outlined,
  'College Event Calendar': Icons.calendar_today_outlined,
  'Letter Request': Icons.mail_outline,
  'External Account': Icons.link_outlined,
  'Reports Management': Icons.assessment_outlined,
  'Activity Logs': Icons.history_outlined,
};

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final AuthService _auth = AuthService();
  final TextEditingController _searchController = TextEditingController();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];
  late final Stream<QuerySnapshot> _organizationsStream;
  late final Stream<QuerySnapshot> _eventsStream;
  late final Stream<QuerySnapshot> _proposalsStream;
  late final Stream<QuerySnapshot> _reportsStream;
  late final Stream<QuerySnapshot> _upcomingEventsStream;

  @override
  void initState() {
    super.initState();
    // Initialize streams once to prevent multiple Firestore subscriptions
    _organizationsStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'active')
        .snapshots();
    _eventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .snapshots();
    _proposalsStream = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('status', isEqualTo: 'pending')
        .snapshots();
    _reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'overdue')
        .snapshots();
    _upcomingEventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('date', isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
        .snapshots();
    _fetchUnreadNotifications();
  }

  Future<void> _fetchUnreadNotifications() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: userId)
            .where('isRead', isEqualTo: false)
            .get();
        setState(() {
          _unreadNotifications = snapshot.docs.length;
          _notifications = snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'title': data['title'] ?? 'New Notification',
              'message': data['message'] ?? '',
              'timestamp': data['createdAt'],
              'isRead': data['isRead'] ?? false,
            };
          }).toList();
        });
      }
    } catch (e) {
      // Error silently handled
    }
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      _fetchUnreadNotifications();
    } catch (e) {
      // Error silently handled
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _screens[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ REDESIGNED SIDEBAR WITH ICONS & GRADIENT ============
  Widget _buildSidebar() {
    final titles = [
      'Dashboard',
      'Organization Management',
      'Student Accounts',
      'Adviser Roles',
      'Event Proposals',
      'College Event Calendar',
      'Letter Request',
      'External Account',
      'Reports Management',
      'Activity Logs',
    ];

    return Container(
      width: 260,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [UpriseColors.primaryDark, UpriseColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6.0),
                  child: Image.asset(
                    'lib/assets/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "UPRISE",
                style: GoogleFonts.beVietnamPro(
                  color: UpriseColors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'CICT Organization Management',
            style: GoogleFonts.beVietnamPro(
              color: UpriseColors.white.withOpacity(0.7),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 30),
          Divider(color: UpriseColors.white.withOpacity(0.2), thickness: 1),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: titles.length,
              itemBuilder: (context, index) {
                bool isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected ? UpriseColors.white.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _sidebarIcons[titles[index]],
                          color: UpriseColors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            titles[index],
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.beVietnamPro(
                              color: UpriseColors.white,
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(color: UpriseColors.white.withOpacity(0.2), thickness: 1),
          // Settings
          GestureDetector(
            onTap: () => _showSettingsDialog(),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.settings_outlined, color: UpriseColors.white.withOpacity(0.75), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: GoogleFonts.beVietnamPro(
                      color: UpriseColors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Logout
          GestureDetector(
            onTap: () async {
              await _auth.logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.logout, color: UpriseColors.white.withOpacity(0.75), size: 18),
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: GoogleFonts.beVietnamPro(
                      color: UpriseColors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ============ REDESIGNED TOP BAR WITH SEARCH, NOTIFICATIONS, PROFILE ============
  Widget _buildTopBar() {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        children: [
          Text(
            _getCurrentTitle(),
            style: GoogleFonts.beVietnamPro(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: UpriseColors.charcoal,
            ),
          ),
          const Spacer(),
          // Search bar
          Container(
            width: 260,
            height: 40,
            decoration: BoxDecoration(
              color: UpriseColors.lightGray,
              borderRadius: BorderRadius.circular(20),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search events, students...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Bell / Notifications
          PopupMenuButton<String>(
            offset: const Offset(0, 45),
            onOpened: () async => await _fetchUnreadNotifications(),
            onSelected: (value) async {
              if (value.startsWith('notification_')) {
                await _markNotificationAsRead(value.replaceFirst('notification_', ''));
              }
            },
            icon: Stack(
              children: [
                Icon(Icons.notifications_none, color: UpriseColors.darkGray, size: 22),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: UpriseColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                      child: Text(
                        '$_unreadNotifications',
                        style: GoogleFonts.beVietnamPro(color: UpriseColors.white, fontSize: 8),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              if (_notifications.isEmpty)
                PopupMenuItem(
                  enabled: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No new notifications',
                          style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 12)),
                    ),
                  ),
                )
              else
                ..._notifications.map((notification) => PopupMenuItem(
                      value: 'notification_${notification['id']}',
                      child: Container(
                        width: 280,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification['title'],
                                style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 4),
                            Text(notification['message'],
                                style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                            const SizedBox(height: 4),
                            Text(
                              _formatTimeAgo(notification['timestamp']),
                              style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray),
                            ),
                          ],
                        ),
                      ),
                    )),
              PopupMenuItem(
                value: 'view_all',
                child: Center(
                  child: Text('View All Notifications',
                      style: GoogleFonts.beVietnamPro(color: UpriseColors.accent, fontSize: 12)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // Profile Popup
          PopupMenuButton<String>(
            offset: const Offset(0, 45),
            onSelected: (value) async {
              if (value == 'profile') _showProfileDialog();
              else if (value == 'settings') _showSettingsDialog();
              else if (value == 'logout') {
                await _auth.logout();
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: UpriseColors.lightGray,
                  radius: 18,
                  child: Icon(Icons.person, color: UpriseColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.displayName ?? 'Admin User',
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w600, fontSize: 13, color: UpriseColors.charcoal),
                    ),
                    Text(
                      'Administrator Role',
                      style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray),
                    ),
                  ],
                ),
                Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray, size: 20),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 18, color: UpriseColors.darkGray),
                    const SizedBox(width: 12),
                    Text('My Profile', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18, color: UpriseColors.darkGray),
                    const SizedBox(width: 12),
                    Text('Settings', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18, color: UpriseColors.error),
                    const SizedBox(width: 12),
                    Text('Logout', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.error)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getCurrentTitle() {
    const titles = [
      'Dashboard',
      'Organization Management',
      'Student Accounts',
      'Adviser Roles',
      'Event Proposals',
      'College Event Calendar',
      'Letter Request',
      'External Account',
      'Reports Management',
      'Activity Logs',
    ];
    return titles[_selectedIndex];
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    DateTime date = timestamp.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }

  void _showProfileDialog() {
    final user = FirebaseAuth.instance.currentUser;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final nameController = TextEditingController(text: user?.displayName ?? '');
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.person, color: UpriseColors.primaryDark),
                const SizedBox(width: 8),
                Text('Admin Profile', style: GoogleFonts.beVietnamPro()),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: UpriseColors.lightGray,
                    child: Icon(Icons.person, size: 50, color: UpriseColors.primaryDark),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.person_outline, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: TextEditingController(text: user?.email ?? ''),
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      prefixIcon: Icon(Icons.email_outlined, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (nameController.text.isNotEmpty && user != null) {
                    await user.updateDisplayName(nameController.text);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile updated successfully')),
                    );
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Save Changes', style: GoogleFonts.beVietnamPro()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showSettingsDialog() {
    bool notifications = true;
    bool darkMode = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.settings, color: UpriseColors.primaryDark),
                const SizedBox(width: 8),
                Text('Settings', style: GoogleFonts.beVietnamPro()),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text('Push Notifications', style: GoogleFonts.beVietnamPro(fontSize: 14)),
                    subtitle: Text('Receive notifications about events and updates',
                        style: GoogleFonts.beVietnamPro(fontSize: 12)),
                    value: notifications,
                    onChanged: (value) {
                      setState(() => notifications = value);
                      _saveSetting('notifications', value);
                    },
                    activeColor: UpriseColors.primaryDark,
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: Text('Dark Mode', style: GoogleFonts.beVietnamPro(fontSize: 14)),
                    subtitle: Text('Switch to dark theme', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                    value: darkMode,
                    onChanged: (value) {
                      setState(() => darkMode = value);
                      _saveSetting('darkMode', value);
                    },
                    activeColor: UpriseColors.primaryDark,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _saveSetting(String key, bool value) async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        await FirebaseFirestore.instance
            .collection('user_settings')
            .doc(userId)
            .set({key: value}, SetOptions(merge: true));
      }
    } catch (e) {
      // Error silently handled
    }
  }

  final List<Widget> _screens = [
    const DashboardHome(),
    OrganizationManagement(),
    StudentAccounts(),
    AdviserRoles(),
    EventProposals(),
    EventCalendar(),
    LetterRequest(),
    ExternalAccount(),
    ReportsManagement(),
    ActivityLogs(),
  ];
}

// ============ COMPLETELY REDESIGNED DASHBOARD HOME MATCHING REACT UI ============
class DashboardHome extends StatefulWidget {
  const DashboardHome({Key? key}) : super(key: key);

  @override
  _DashboardHomeState createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  String _selectedSemester = '2nd Semester 2024';
  String _selectedMonth = 'MAR'; // current month abbreviation
  List<int> _chartData = [0, 0, 0, 0, 0, 0];
  bool _chartLoading = true;
  late final Stream<QuerySnapshot> _organizationsStream;
  late final Stream<QuerySnapshot> _eventsStream;
  late final Stream<QuerySnapshot> _proposalsStream;
  late final Stream<QuerySnapshot> _reportsStream;
  late final Stream<QuerySnapshot> _upcomingEventsStream;

  @override
  void initState() {
    super.initState();
    // Initialize streams once to prevent multiple Firestore subscriptions on each rebuild
    _organizationsStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'active')
        .snapshots();
    _eventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .snapshots();
    _proposalsStream = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('status', isEqualTo: 'pending')
        .snapshots();
    _reportsStream = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'overdue')
        .snapshots();
    _upcomingEventsStream = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .where('date', isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
        .snapshots();
    _fetchChartData();
  }

  void _fetchChartData() {
    setState(() => _chartLoading = true);
    // Determine semester date range
    int year = 2024;
    int startMonth, endMonth;
    if (_selectedSemester == '1st Semester 2024') {
      startMonth = 1; // Jan
      endMonth = 6; // Jun
    } else {
      startMonth = 7; // Jul
      endMonth = 12; // Dec
    }
    final startDate = DateTime(year, startMonth, 1);
    final endDate = DateTime(year, endMonth + 1, 1);
    FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'completed')
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThan: endDate.toIso8601String())
        .get()
        .then((snapshot) {
      List<int> monthlyCounts = List.filled(6, 0);
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final dateStr = data['date'];
        if (dateStr != null) {
          try {
            DateTime eventDate = DateTime.parse(dateStr);
            int monthIndex = eventDate.month - startMonth;
            if (monthIndex >= 0 && monthIndex < 6) {
              monthlyCounts[monthIndex]++;
            }
          } catch (e) {}
        }
      }
      setState(() {
        _chartData = monthlyCounts;
        _chartLoading = false;
      });
    }).catchError((e) {
      setState(() => _chartLoading = false);
    });
  }

  @override
  void didUpdateWidget(DashboardHome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchChartData();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Administrator Dashboard',
            style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
          ),
          const SizedBox(height: 8),
          Text(
            "Welcome back. Here's what's happening today in the CICT community.",
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
          ),
          const SizedBox(height: 28),

          // === 5 STAT CARDS ===
          Row(
            children: [
              Expanded(child: _buildStatCard('Active Organizations', _organizationsStream, UpriseColors.primaryDark, Icons.business)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Active Events', _eventsStream, UpriseColors.success, Icons.event)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Pending Proposals', _proposalsStream, UpriseColors.warning, Icons.pending_actions)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Overdue Reports', _reportsStream, UpriseColors.error, Icons.warning_amber)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Upcoming Events', _upcomingEventsStream, UpriseColors.info, Icons.upcoming)),
            ],
          ),
          const SizedBox(height: 28),

          // === CHART SECTION ===
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedSemester,
                          style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w600, color: UpriseColors.charcoal),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Activity overview for current semester',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: UpriseColors.mediumGray),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _selectedSemester,
                        underline: const SizedBox(),
                        icon: Icon(Icons.arrow_drop_down, size: 20),
                        items: const [
                          DropdownMenuItem(value: '1st Semester 2024', child: Text('1st Semester 2024')),
                          DropdownMenuItem(value: '2nd Semester 2024', child: Text('2nd Semester 2024')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedSemester = value;
                              _fetchChartData();
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Month buttons row
                Row(
                  children: List.generate(6, (index) {
                    String month = _getMonthAbbr(index + (_selectedSemester == '1st Semester 2024' ? 1 : 7));
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedMonth = month),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedMonth == month ? UpriseColors.primaryDark : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _selectedMonth == month ? UpriseColors.primaryDark : UpriseColors.mediumGray),
                          ),
                          child: Text(
                            month,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.beVietnamPro(
                              color: _selectedMonth == month ? UpriseColors.white : UpriseColors.darkGray,
                              fontWeight: _selectedMonth == month ? FontWeight.w600 : FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                // Line chart
                SizedBox(
                  height: 220,
                  child: _chartLoading
                      ? const Center(child: CircularProgressIndicator())
                      : CustomPaint(
                          painter: GradientLineChartPainter(
                            data: _chartData.map((e) => e.toDouble()).toList(),
                            months: List.generate(6, (i) => _getMonthAbbr(i + (_selectedSemester == '1st Semester 2024' ? 1 : 7))),
                            selectedMonth: _selectedMonth,
                          ),
                          size: Size(MediaQuery.of(context).size.width - 100, 220),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // === UPCOMING EVENTS & RECENT ACTIVITY (side by side) ===
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildUpcomingEvents()),
              const SizedBox(width: 24),
              Expanded(child: _buildRecentActivity()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, Stream<QuerySnapshot> stream, Color color, IconData icon) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) count = snapshot.data!.docs.length;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const SizedBox(width: 30, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Text(
                      count.toString(),
                      style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(title, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingEvents() {
    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Upcoming CICT Events',
                    style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600, color: UpriseColors.charcoal)),
                TextButton(
                  onPressed: () {},
                  child: Text('View All', style: GoogleFonts.beVietnamPro(color: UpriseColors.accent, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('status', isEqualTo: 'approved')
                  .where('date', isGreaterThanOrEqualTo: DateTime.now().toIso8601String())
                  .orderBy('date')
                  .limit(4)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.calendar_today, size: 48, color: UpriseColors.mediumGray),
                          const SizedBox(height: 12),
                          Text('No upcoming events',
                              style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                final events = snapshot.data!.docs;
                return Column(
                  children: events.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _EventCard(
                      date: data['date'],
                      title: data['title'] ?? 'Untitled Event',
                      location: data['location'] ?? 'TBA',
                      time: data['time'] ?? 'TBA',
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity',
                style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w600, color: UpriseColors.charcoal)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_logs')
                  .orderBy('createdAt', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.history, size: 48, color: UpriseColors.mediumGray),
                          const SizedBox(height: 12),
                          Text('No recent activity',
                              style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13)),
                        ],
                      ),
                    ),
                  );
                }
                final activities = snapshot.data!.docs;
                return Column(
                  children: activities.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return _ActivityCard(
                      title: data['title'] ?? 'Activity',
                      description: data['description'] ?? '',
                      timestamp: data['createdAt'],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthAbbr(int month) {
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    return months[month - 1];
  }
}

// ============ LINE CHART WITH GRADIENT FILL (matching React style) ============
class GradientLineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> months;
  final String selectedMonth;

  GradientLineChartPainter({
    required this.data,
    required this.months,
    required this.selectedMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    double maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 100;

    final double leftPadding = 40;
    final double rightPadding = 20;
    final double topPadding = 30;
    final double bottomPadding = 30;
    final double chartWidth = size.width - leftPadding - rightPadding;
    final double chartHeight = size.height - topPadding - bottomPadding;

    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      double x = leftPadding + (i / (data.length - 1)) * chartWidth;
      double y = topPadding + chartHeight - (data[i] / maxVal) * chartHeight;
      points.add(Offset(x, y));
    }

    // Draw horizontal grid lines
    final gridPaint = Paint()..color = UpriseColors.mediumGray..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      double y = topPadding + (i / 4) * chartHeight;
      canvas.drawLine(Offset(leftPadding, y), Offset(leftPadding + chartWidth, y), gridPaint);
      // Draw label
      final textSpan = TextSpan(
        text: '${(maxVal * (1 - i / 4)).toInt()}',
        style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray),
      );
      final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
      tp.layout();
      tp.paint(canvas, Offset(leftPadding - 24, y - 4));
    }

    // Draw gradient area under the curve
    Path areaPath = Path();
    areaPath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      Offset p1 = points[i - 1];
      Offset p2 = points[i];
      Offset c1 = Offset((p1.dx + p2.dx) / 2, p1.dy);
      Offset c2 = Offset((p1.dx + p2.dx) / 2, p2.dy);
      areaPath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    areaPath.lineTo(points.last.dx, topPadding + chartHeight);
    areaPath.lineTo(points.first.dx, topPadding + chartHeight);
    areaPath.close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [UpriseColors.primaryDark.withOpacity(0.15), UpriseColors.primaryDark.withOpacity(0)],
        ).createShader(Rect.fromLTWH(0, topPadding, size.width, chartHeight)),
    );

    // Draw smooth line
    Path linePath = Path();
    linePath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      Offset p1 = points[i - 1];
      Offset p2 = points[i];
      Offset c1 = Offset((p1.dx + p2.dx) / 2, p1.dy);
      Offset c2 = Offset((p1.dx + p2.dx) / 2, p2.dy);
      linePath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    canvas.drawPath(linePath, Paint()..color = UpriseColors.primaryDark..strokeWidth = 2.5..style = PaintingStyle.stroke);

    // Draw points and month labels
    for (int i = 0; i < points.length; i++) {
      bool isSelected = months[i] == selectedMonth;
      canvas.drawCircle(
        points[i],
        isSelected ? 6 : 4,
        Paint()..color = isSelected ? UpriseColors.accent : UpriseColors.primaryDark,
      );
      if (isSelected) {
        // Draw value above point
        final valueSpan = TextSpan(
          text: '${data[i].toInt()}',
          style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.bold, color: UpriseColors.accent),
        );
        final valueTp = TextPainter(text: valueSpan, textDirection: TextDirection.ltr);
        valueTp.layout();
        valueTp.paint(canvas, Offset(points[i].dx - valueTp.width / 2, points[i].dy - 18));
      }
      // Month label
      final monthSpan = TextSpan(
        text: months[i],
        style: GoogleFonts.beVietnamPro(
          fontSize: 12,
          color: isSelected ? UpriseColors.accent : UpriseColors.darkGray,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
        ),
      );
      final monthTp = TextPainter(text: monthSpan, textDirection: TextDirection.ltr);
      monthTp.layout();
      monthTp.paint(canvas, Offset(points[i].dx - monthTp.width / 2, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// ============ REUSABLE EVENT CARD (matching React style) ============
class _EventCard extends StatelessWidget {
  final String? date;
  final String title;
  final String location;
  final String time;

  const _EventCard({required this.date, required this.title, required this.location, required this.time});

  String _formatDate() {
    if (date == null) return 'TBD';
    try {
      DateTime dt = DateTime.parse(date!);
      const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
      return '${months[dt.month - 1]} ${dt.day}';
    } catch (e) {
      return 'TBD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatted = _formatDate();
    final parts = formatted.split(' ');
    final month = parts[0];
    final day = parts.length > 1 ? parts[1] : '--';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(month,
                    style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
                Text(day,
                    style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.primaryDark)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13, color: UpriseColors.charcoal)),
                const SizedBox(height: 4),
                Text('$location • $time',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============ RECENT ACTIVITY CARD WITH COLORED DOT ============
class _ActivityCard extends StatelessWidget {
  final String title;
  final String description;
  final Timestamp? timestamp;

  const _ActivityCard({required this.title, required this.description, this.timestamp});

  String _getTimeAgo() {
    if (timestamp == null) return 'Just now';
    DateTime date = timestamp!.toDate();
    Duration diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${(diff.inDays / 7).floor()} weeks ago';
  }

  Color _getDotColor() {
    if (title.contains('proposal')) return UpriseColors.warning;
    if (title.contains('verified')) return UpriseColors.success;
    if (title.contains('error')) return UpriseColors.error;
    return UpriseColors.primaryDark;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: _getDotColor(),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500, fontSize: 13, color: UpriseColors.charcoal)),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(description,
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                ],
                const SizedBox(height: 2),
                Text(_getTimeAgo(), style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}