import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:uprise/screens/web/admin/activity_logs.dart';
import '../../../auth_service.dart';
import 'admin_login.dart';
import 'organization_management.dart';
import 'student_accounts.dart';
import 'adviser_roles.dart';
import 'event_proposals.dart';
import 'event_calendar.dart';
import 'letter_request.dart'; 
import 'external_account.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'reports_management.dart';
import 'settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — mirrors student_accounts.dart exactly
// ─────────────────────────────────────────────────────────────────────────────
class UpriseColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF059669);
  static const Color warning      = Color(0xFFD97706);
  static const Color error        = Color(0xFFDC2626);
  static const Color info         = Color(0xFF2563EB);
}

class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusPill = 100;

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar nav items
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _navItems = [
  {'label': 'Dashboard',                'icon': Icons.dashboard_outlined},
  {'label': 'Organization Management',  'icon': Icons.business_outlined},
  {'label': 'Student Accounts',         'icon': Icons.people_outline},
  {'label': 'Adviser Roles',            'icon': Icons.school_outlined},
  {'label': 'Event Proposals',          'icon': Icons.pending_actions_outlined},
  {'label': 'College Event Calendar',   'icon': Icons.calendar_today_outlined},
  {'label': 'Letter Request',           'icon': Icons.mail_outline},
  {'label': 'External Account',         'icon': Icons.link_outlined},
  {'label': 'Reports Management',       'icon': Icons.assessment_outlined},
  {'label': 'Activity Logs',            'icon': Icons.history_outlined},
  {'label': 'Settings',                 'icon': Icons.settings_outlined},
];

// ─────────────────────────────────────────────────────────────────────────────
// AdminDashboard shell
// ─────────────────────────────────────────────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;
  final AuthService _auth = AuthService();
  final TextEditingController _searchController = TextEditingController();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];
  String _adminName = 'Admin User';
  String _adminRole = 'Administrator';
  String _currentDateTime = '';
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
    _fetchUnreadNotifications();
    _updateDateTime();
    _screens = [
      const DashboardHome(),
      const OrganizationManagement(),
      const StudentAccounts(),
      const AdviserRoles(),
      const EventProposals(),
      const EventCalendar(),
      const AdminLetterRequestScreen(),
      const ExternalAccount(),
      const ReportsManagement(),
      const ActivityLogs(),
    ];
  }

  void _updateDateTime() {
    setState(() {
      _currentDateTime = DateFormat('EEE, MMM d, yyyy • h:mm a').format(DateTime.now());
    });
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) _updateDateTime();
    });
  }

  Future<void> _fetchAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _adminName = doc.data()!['name'] ?? user.displayName ?? 'Admin User';
          _adminRole = doc.data()!['role'] ?? 'Administrator';
        });
      } else {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        setState(() {
          _adminName = uDoc.data()?['name'] ?? user.displayName ?? 'Admin User';
        });
      }
    } catch (_) {
      setState(() => _adminName = FirebaseAuth.instance.currentUser?.displayName ?? 'Admin User');
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('isRead', isEqualTo: false)
          .get();
      setState(() {
        _unreadNotifications = snap.docs.length;
        _notifications = snap.docs.map((d) => {
          'id': d.id,
          'title': d.data()['title'] ?? 'New Notification',
          'message': d.data()['message'] ?? '',
          'timestamp': d.data()['createdAt'],
          'isRead': d.data()['isRead'] ?? false,
        }).toList();
      });
    } catch (_) {}
  }

  Future<void> _markNotificationAsRead(String id) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').doc(id).update({'isRead': true});
      _fetchUnreadNotifications();
    } catch (_) {}
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => AdminLogin()));
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusLg)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 14),
                Text('Confirm Logout',
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
              ]),
              const SizedBox(height: 14),
              Text('Are you sure you want to logout from the admin panel?',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E6EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () { Navigator.pop(ctx); _logout(); },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Logout', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentTitle() {
    if (_selectedIndex == -1) return 'Settings';
    const titles = [
      'Dashboard', 'Organization Management', 'Student Accounts', 'Adviser Roles',
      'Event Proposals', 'College Event Calendar', 'Letter Request', 'External Account',
      'Reports Management', 'Activity Logs',
    ];
    return titles[_selectedIndex];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: _selectedIndex == -1
                      ? const AdminSettings()
                      : _screens[_selectedIndex],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar ────────────────────────────────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFA84208), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 20, offset: Offset(4, 0))],
      ),
      child: Column(
        children: [
          // Brand header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(7),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(Icons.school, color: Colors.white, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UPRISE',
                        style: GoogleFonts.beVietnamPro(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
                    Text('Admin Panel',
                        style: GoogleFonts.beVietnamPro(
                            color: Colors.white.withOpacity(0.65), fontSize: 10, fontWeight: FontWeight.w500, letterSpacing: 0.4)),
                  ],
                ),
              ],
            ),
          ),

          Divider(color: Colors.white.withOpacity(0.15), thickness: 1, indent: 20, endIndent: 20),
          const SizedBox(height: 8),

          // Nav label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('NAVIGATION',
                  style: GoogleFonts.beVietnamPro(
                      color: Colors.white.withOpacity(0.45), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ),
          ),

          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _navItems.length,
              itemBuilder: (context, index) {
                final item = _navItems[index];
                final isSettings = item['label'] == 'Settings';
                final isSelected = isSettings ? _selectedIndex == -1 : _selectedIndex == index;

                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = isSettings ? -1 : index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withOpacity(0.18) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(color: Colors.white.withOpacity(0.25), width: 1)
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(item['icon'] as IconData,
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.65),
                            size: 17),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(item['label'] as String,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.beVietnamPro(
                                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.75),
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
                        ),
                        if (isSelected)
                          Container(
                            width: 6, height: 6,
                            decoration: BoxDecoration(
                              color: UpriseColors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Divider + logout
          Divider(color: Colors.white.withOpacity(0.15), thickness: 1, indent: 20, endIndent: 20),
          GestureDetector(
            onTap: _confirmLogout,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded, color: Colors.white.withOpacity(0.75), size: 17),
                  const SizedBox(width: 12),
                  Text('Logout',
                      style: GoogleFonts.beVietnamPro(
                          color: Colors.white.withOpacity(0.75), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
        boxShadow: [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Page title
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_getCurrentTitle(),
                  style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: UpriseColors.charcoal)),
              Text('CICT Organization Management',
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4))),
            ],
          ),

          const Spacer(),

          // Datetime chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(_DS.radiusPill),
              border: Border.all(color: const Color(0xFFE8ECF0)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded, size: 13, color: UpriseColors.primaryDark),
                const SizedBox(width: 6),
                Text(_currentDateTime,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Search
          SizedBox(
            width: 240,
            height: 38,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search…',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 17, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: const Color(0xFFF8F9FB),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8ECF0))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8ECF0))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Notification bell
          PopupMenuButton<String>(
            offset: const Offset(0, 48),
            onOpened: _fetchUnreadNotifications,
            onSelected: (v) async {
              if (v.startsWith('notification_')) {
                await _markNotificationAsRead(v.replaceFirst('notification_', ''));
              }
            },
            icon: Stack(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE8ECF0)),
                  ),
                  child: const Icon(Icons.notifications_none_rounded, color: Color(0xFF64748B), size: 18),
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: 0, top: 0,
                    child: Container(
                      width: 16, height: 16,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                      child: Text('$_unreadNotifications',
                          style: GoogleFonts.beVietnamPro(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text('Notifications',
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 13, color: UpriseColors.charcoal)),
              ),
              if (_notifications.isEmpty)
                PopupMenuItem(
                  enabled: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text('No new notifications',
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4))),
                    ),
                  ),
                ),
              ..._notifications.map((n) => PopupMenuItem(
                value: 'notification_${n['id']}',
                child: SizedBox(
                  width: 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n['title'], style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(n['message'],
                          style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              )),
            ],
          ),
          const SizedBox(width: 12),

          // Admin avatar
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 14, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_adminName,
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w700, fontSize: 13, color: UpriseColors.charcoal)),
                  Text(_adminRole,
                      style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF9AA5B4))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dashboard Home
// ─────────────────────────────────────────────────────────────────────────────
class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});
  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  String _selectedSemester = '';
  String _selectedMonth = 'AUG';
  List<int> _chartData = [0, 0, 0, 0, 0, 0];
  bool _chartLoading = true;

  late final Stream<QuerySnapshot> _organizationsStream;
  late final Stream<QuerySnapshot> _eventsStream;
  late final Stream<QuerySnapshot> _proposalsStream;
  late final Stream<QuerySnapshot> _reportsStream;
  late final Stream<QuerySnapshot> _upcomingEventsStream;

  // ── Semester helpers ──────────────────────────────────────────────
  int get _semesterStartMonth => _selectedSemester.startsWith('1st') ? 8 : 1;
  int get _semesterStartYear  => int.parse(_selectedSemester.split(' ').last.split('-')[0]);

  String _getCurrentSemester() {
    final now = DateTime.now();
    if (now.month >= 8) return '1st Semester AY ${now.year}-${now.year + 1}';
    if (now.month <= 5) return '2nd Semester AY ${now.year - 1}-${now.year}';
    return '2nd Semester AY ${now.year - 1}-${now.year}';
  }

  List<String> get _semesterOptions {
    final ay = _selectedSemester.split(' ').last;
    return ['1st Semester AY $ay', '2nd Semester AY $ay'];
  }

  String _monthLabel(int index) {
    if (_semesterStartMonth == 8) {
      const m = ['AUG', 'SEP', 'OCT', 'NOV', 'DEC', 'JAN'];
      return m[index];
    }
    const m = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN'];
    return m[index];
  }

  // ── Init ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedSemester = _getCurrentSemester();
    _selectedMonth = _monthLabel(0);

    final now = DateTime.now();

    _organizationsStream = FirebaseFirestore.instance
        .collection('organizations').where('status', isEqualTo: 'active').snapshots();
    _eventsStream = FirebaseFirestore.instance
      .collection('event_proposals').where('status', isEqualTo: 'approved').snapshots();
    _proposalsStream = FirebaseFirestore.instance
        .collection('event_proposals').where('status', isEqualTo: 'pending').snapshots();
    _reportsStream = FirebaseFirestore.instance
        .collection('reports').where('status', isEqualTo: 'overdue').snapshots();
    _upcomingEventsStream = FirebaseFirestore.instance
      .collection('event_proposals')
      .where('status', isEqualTo: 'approved')
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
      .orderBy('date').snapshots();

    _fetchChartData();
  }

  void _fetchChartData() {
    setState(() => _chartLoading = true);
    final startYear  = _semesterStartYear;
    final startMonth = _semesterStartMonth;
    final endMonth   = startMonth == 8 ? 12 : 5;
    final endYear    = startMonth == 8 ? startYear : startYear + 1;

    FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'completed')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(startYear, startMonth, 1)))
        .where('date', isLessThan: Timestamp.fromDate(DateTime(endYear, endMonth + 1, 1)))
        .get()
        .then((snap) {
      final counts = List.filled(6, 0);
      for (final doc in snap.docs) {
        final ts = doc.data()['date'] as Timestamp?;
        if (ts == null) continue;
        final m = ts.toDate().month;
        int idx;
        if (startMonth == 8) {
          idx = m >= 8 ? m - 8 : m == 1 ? 5 : -1;
        } else {
          idx = m - 1;
        }
        if (idx >= 0 && idx < 6) counts[idx]++;
      }
      setState(() { _chartData = counts; _chartLoading = false; });
    }).catchError((_) => setState(() => _chartLoading = false));
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _buildWelcomeHeader(),
          const SizedBox(height: 24),

          // Stat cards
          _buildStatCards(),
          const SizedBox(height: 24),

          // Chart card
          _buildChartCard(),
          const SizedBox(height: 24),

          // Bottom row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildUpcomingEvents()),
              const SizedBox(width: 20),
              Expanded(child: _buildRecentActivity()),
            ],
          ),
        ],
      ),
    );
  }

  // ── Welcome header ────────────────────────────────────────────────
  Widget _buildWelcomeHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFA84208), Color(0xFFD97706)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        boxShadow: [
          BoxShadow(color: UpriseColors.primaryDark.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Administrator Dashboard',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text("Welcome back. Here's what's happening in the CICT community today.",
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, color: Colors.white.withOpacity(0.80), height: 1.5)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 36),
          ),
        ],
      ),
    );
  }

  // ── Stat cards ────────────────────────────────────────────────────
  Widget _buildStatCards() {
    final cards = [
      _StatConfig('Active Orgs',       _organizationsStream, UpriseColors.primaryDark, Icons.business_rounded),
      _StatConfig('Active Events',     _eventsStream,        UpriseColors.success,     Icons.event_rounded),
      _StatConfig('Pending Proposals', _proposalsStream,     UpriseColors.warning,     Icons.pending_actions_rounded),
      _StatConfig('Overdue Reports',   _reportsStream,       UpriseColors.error,       Icons.warning_amber_rounded),
      _StatConfig('Upcoming Events',   _upcomingEventsStream, UpriseColors.info,       Icons.upcoming_rounded),
    ];

    return Row(
      children: cards.asMap().entries.map((e) {
        final cfg = e.value;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: e.key == 0 ? 0 : 10),
            child: StreamBuilder<QuerySnapshot>(
              stream: cfg.stream,
              builder: (ctx, snap) {
                final count = snap.hasData ? snap.data!.docs.length : 0;
                return _buildStatCard(cfg, count, snap.connectionState == ConnectionState.waiting);
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatCard(_StatConfig cfg, int count, bool loading) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: cfg.color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 20),
            ),
            if (loading)
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: cfg.color))
            else
              Text('$count',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 28, fontWeight: FontWeight.w800, color: const Color(0xFF1A202C))),
          ]),
          const SizedBox(height: 12),
          Text(cfg.label,
              style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Chart card ────────────────────────────────────────────────────
  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Activity Overview',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
                const SizedBox(height: 3),
                Text('Completed events per month this semester',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF9AA5B4))),
              ]),
              // Semester dropdown
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E6EA)),
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0xFFF8F9FB),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _semesterOptions.contains(_selectedSemester) ? _selectedSemester : null,
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151)),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9AA5B4)),
                    items: _semesterOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() { _selectedSemester = v; _fetchChartData(); });
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Month selector pills
          Row(
            children: List.generate(6, (i) {
              final m = _monthLabel(i);
              final isActive = _selectedMonth == m;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedMonth = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isActive ? UpriseColors.primaryDark : const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isActive ? UpriseColors.primaryDark : const Color(0xFFE2E6EA)),
                    ),
                    child: Text(m,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.beVietnamPro(
                            color: isActive ? Colors.white : const Color(0xFF64748B),
                            fontSize: 12,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 200,
            child: _chartLoading
                ? Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark))
                : CustomPaint(
                    painter: _LineChartPainter(
                      data: _chartData.map((e) => e.toDouble()).toList(),
                      months: List.generate(6, _monthLabel),
                      selectedMonth: _selectedMonth,
                    ),
                    size: Size.infinite,
                  ),
          ),
        ],
      ),
    );
  }

  // ── Upcoming events ───────────────────────────────────────────────
  Widget _buildUpcomingEvents() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Upcoming CICT Events',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(_DS.radiusPill),
                ),
                child: Text('View All',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
              ),
            ]),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('event_proposals')
                  .where('status', isEqualTo: 'approved')
                  .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()))
                  .orderBy('date').limit(4).snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _emptyPlaceholder(Icons.calendar_today_outlined, 'No upcoming events');
                }
                return Column(
                  children: snap.data!.docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return _EventRow(
                      date: d['date'] is Timestamp ? (d['date'] as Timestamp).toDate().toIso8601String() : d['date'],
                      title: d['title'] ?? 'Untitled',
                      location: d['location'] ?? 'TBA',
                      time: d['time'] ?? 'TBA',
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

  // ── Recent activity ───────────────────────────────────────────────
  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Activity',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(6).snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()));
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _emptyPlaceholder(Icons.history_rounded, 'No recent activity');
                }
                return Column(
                  children: snap.data!.docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return _ActivityRow(
                      title: d['action'] ?? 'Activity',
                      module: d['module'] ?? '',
                      timestamp: d['timestamp'] as Timestamp?,
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

  Widget _emptyPlaceholder(IconData icon, String message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: const Color(0xFF9AA5B4)),
            ),
            const SizedBox(height: 12),
            Text(message,
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card config helper
// ─────────────────────────────────────────────────────────────────────────────
class _StatConfig {
  final String label;
  final Stream<QuerySnapshot> stream;
  final Color color;
  final IconData icon;
  const _StatConfig(this.label, this.stream, this.color, this.icon);
}

// ─────────────────────────────────────────────────────────────────────────────
// Line chart painter (refined version)
// ─────────────────────────────────────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> months;
  final String selectedMonth;

  const _LineChartPainter({
    required this.data,
    required this.months,
    required this.selectedMonth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const lp = 44.0, rp = 16.0, tp = 24.0, bp = 28.0;
    final cw = size.width - lp - rp;
    final ch = size.height - tp - bp;

    double maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 5;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = tp + (i / 4) * ch;
      canvas.drawLine(Offset(lp, y), Offset(lp + cw, y), gridPaint);
      final val = (maxVal * (1 - i / 4)).toInt();
      _drawText(canvas, '$val', Offset(lp - 8, y - 6),
          fontSize: 10, color: const Color(0xFF9AA5B4), align: TextAlign.right);
    }

    // Points
    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      points.add(Offset(lp + (i / (data.length - 1)) * cw, tp + ch - (data[i] / maxVal) * ch));
    }

    // Area fill
    final areaPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final c1 = Offset((points[i-1].dx + points[i].dx) / 2, points[i-1].dy);
      final c2 = Offset((points[i-1].dx + points[i].dx) / 2, points[i].dy);
      areaPath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, points[i].dx, points[i].dy);
    }
    areaPath
      ..lineTo(points.last.dx, tp + ch)
      ..lineTo(points.first.dx, tp + ch)
      ..close();
    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [UpriseColors.primaryDark.withOpacity(0.12), UpriseColors.primaryDark.withOpacity(0)],
        ).createShader(Rect.fromLTWH(0, tp, size.width, ch)),
    );

    // Line
    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final c1 = Offset((points[i-1].dx + points[i].dx) / 2, points[i-1].dy);
      final c2 = Offset((points[i-1].dx + points[i].dx) / 2, points[i].dy);
      linePath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(linePath,
        Paint()..color = UpriseColors.primaryDark..strokeWidth = 2.5..style = PaintingStyle.stroke);

    // Points & labels
    for (int i = 0; i < points.length; i++) {
      final isSelected = months[i] == selectedMonth;
      if (isSelected) {
        canvas.drawCircle(points[i], 8,
            Paint()..color = UpriseColors.primaryDark.withOpacity(0.15));
      }
      canvas.drawCircle(points[i], isSelected ? 5 : 4,
          Paint()..color = Colors.white);
      canvas.drawCircle(points[i], isSelected ? 5 : 4,
          Paint()..color = isSelected ? UpriseColors.accent : UpriseColors.primaryDark..style = PaintingStyle.stroke..strokeWidth = 2);

      if (isSelected) {
        _drawText(canvas, '${data[i].toInt()}',
            Offset(points[i].dx, points[i].dy - 16),
            fontSize: 12, color: UpriseColors.primaryDark, fontWeight: FontWeight.bold);
      }
      _drawText(canvas, months[i],
          Offset(points[i].dx, size.height - 16),
          fontSize: 11,
          color: isSelected ? UpriseColors.primaryDark : const Color(0xFF9AA5B4),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal);
    }
  }

  void _drawText(Canvas canvas, String text, Offset position, {
    double fontSize = 12,
    Color color = const Color(0xFF64748B),
    FontWeight fontWeight = FontWeight.normal,
    TextAlign align = TextAlign.center,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.beVietnamPro(fontSize: fontSize, color: color, fontWeight: fontWeight),
      ),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(position.dx - tp.width / 2, position.dy - tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.data != data || old.selectedMonth != selectedMonth;
}

// ─────────────────────────────────────────────────────────────────────────────
// Event row — matches StudentAccounts card style
// ─────────────────────────────────────────────────────────────────────────────
class _EventRow extends StatelessWidget {
  final String? date, title, location, time;
  const _EventRow({this.date, this.title, this.location, this.time});

  ({String month, String day}) _parsedDate() {
    if (date == null) return (month: 'TBD', day: '--');
    try {
      final dt = DateTime.parse(date!);
      const m = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'];
      return (month: m[dt.month - 1], day: '${dt.day}');
    } catch (_) {
      return (month: 'TBD', day: '--');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _parsedDate();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48, height: 52,
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(d.month,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 9, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
                Text(d.day,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 20, fontWeight: FontWeight.w800, color: UpriseColors.primaryDark, height: 1.1)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title ?? 'Untitled',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C)),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 11, color: Color(0xFF9AA5B4)),
                  const SizedBox(width: 3),
                  Flexible(child: Text(location ?? 'TBA',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4)),
                      overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time_rounded, size: 11, color: Color(0xFF9AA5B4)),
                  const SizedBox(width: 3),
                  Text(time ?? 'TBA',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4))),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity row — matches StudentAccounts style
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final String title, module;
  final Timestamp? timestamp;
  const _ActivityRow({required this.title, required this.module, this.timestamp});

  String _timeAgo() {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp!.toDate());
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours  < 24)  return '${diff.inHours}h ago';
    if (diff.inDays   < 7)   return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Color _dotColor() {
    final l = title.toLowerCase();
    if (l.contains('proposal') || l.contains('pending')) return UpriseColors.warning;
    if (l.contains('verified') || l.contains('created')) return UpriseColors.success;
    if (l.contains('deleted')  || l.contains('error'))   return UpriseColors.error;
    return UpriseColors.primaryDark;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8, height: 8,
              decoration: BoxDecoration(color: _dotColor(), shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C))),
                if (module.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(module,
                        style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF64748B))),
                  ),
                ],
                const SizedBox(height: 3),
                Text(_timeAgo(),
                    style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF9AA5B4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}