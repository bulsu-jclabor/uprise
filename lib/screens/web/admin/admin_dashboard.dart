import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
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
import '../../../services/notification_service.dart';
import 'reports_management.dart';
import 'settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — mirrors student_accounts.dart exactly
// ─────────────────────────────────────────────────────────────────────────────
class UpriseColors {
  static const Color primaryDark = Color(0xFFBE4700);
  static const Color primaryLight = Color(0xFFD47A00);
  static const Color accent = Color(0xFFDA6937);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF9FAFB);
  static const Color mediumGray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF6B7280);
  static const Color charcoal = Color(0xFF111827);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFFB923C);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
}

class _DS {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 100;

  static final List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar nav items
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _navItems = [
  {'label': 'Dashboard', 'icon': Icons.dashboard_outlined},
  {'label': 'Organization Management', 'icon': Icons.business_outlined},
  {'label': 'Student Accounts', 'icon': Icons.people_outline},
  {'label': 'Adviser Roles', 'icon': Icons.school_outlined},
  {'label': 'Event Proposals', 'icon': Icons.pending_actions_outlined},
  {'label': 'College Event Calendar', 'icon': Icons.calendar_today_outlined},
  {'label': 'Letter Request', 'icon': Icons.mail_outline},
  {'label': 'External Account', 'icon': Icons.link_outlined},
  {'label': 'Reports Management', 'icon': Icons.assessment_outlined},
  {'label': 'Activity Logs', 'icon': Icons.history_outlined},
  {'label': 'Settings', 'icon': Icons.settings_outlined},
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
  // Screens are only actually mounted (and start their Firestore queries)
  // the first time their tab is opened, then kept alive in the IndexedStack
  // from then on — otherwise every screen would fire its queries at once on
  // dashboard load instead of spreading that cost out over time.
  final Set<int> _visitedIndices = {0};
  final AuthService _auth = AuthService();
  final GlobalKey _bellKey = GlobalKey();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];
  String _adminName = 'Admin User';
  String _adminRole = 'Administrator';
  String _currentDateTime = '';
  String? _adminPhotoUrl;
  String? _adminPhotoBase64;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _fetchAdminData();
    _fetchUnreadNotifications();
    _updateDateTime();
    _screens = [
      DashboardHome(onNavigateToCalendar: () => _selectTab(5)),
      const OrganizationManagement(),
      const StudentAccounts(),
      const AdviserRoles(),
      const EventProposals(),
      const EventCalendar(),
      const AdminLetterRequestScreen(),
      const ExternalAccount(),
      const ReportsManagement(),
      const ActivityLogs(),
      AdminSettings(onProfileUpdated: _fetchAdminData), // index 10 — settings
    ];
  }

  void _updateDateTime() {
    setState(() {
      _currentDateTime = DateFormat(
        'EEE, MMM d, yyyy • h:mm a',
      ).format(DateTime.now());
    });
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) _updateDateTime();
    });
  }

  Widget _buildAdminAvatar() {
    final initial = Text(
      _adminName.isNotEmpty ? _adminName[0].toUpperCase() : 'A',
      style: GoogleFonts.beVietnamPro(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: UpriseColors.primaryDark,
      ),
    );
    if (_adminPhotoBase64 != null && _adminPhotoBase64!.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(_adminPhotoBase64!),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(child: initial),
        );
      } catch (_) {
        return Center(child: initial);
      }
    }
    if (_adminPhotoUrl != null && _adminPhotoUrl!.isNotEmpty) {
      return Image.network(
        _adminPhotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(child: initial),
      );
    }
    return Center(child: initial);
  }

  Future<void> _fetchAdminData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Matches the fields admin_settings.dart actually writes to
      // users/{uid}: 'fullName' and 'photoBase64' (there is no separate
      // 'admins' collection anywhere else in the app).
      final uDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = uDoc.data();
      setState(() {
        _adminName = (data?['fullName'] as String?)?.trim().isNotEmpty == true
            ? data!['fullName'] as String
            : (user.displayName ?? 'Admin User');
        _adminRole = data?['role'] ?? 'Administrator';
        _adminPhotoBase64 = data?['photoBase64'] as String?;
        _adminPhotoUrl = data?['photoUrl'] as String? ?? user.photoURL;
      });
    } catch (_) {
      setState(
        () => _adminName =
            FirebaseAuth.instance.currentUser?.displayName ?? 'Admin User',
      );
    }
  }

  Future<void> _fetchUnreadNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      final all = snap.docs
          .map(
            (d) => {
              'id': d.id,
              'title': d.data()['title'] ?? 'New Notification',
              'message': d.data()['body'] ?? d.data()['message'] ?? '',
              'timestamp': d.data()['createdAt'],
              'isRead': d.data()['isRead'] ?? false,
              'type': d.data()['type'],
            },
          )
          .toList();
      all.sort((a, b) {
        final ta = a['timestamp'];
        final tb = b['timestamp'];
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return (tb as Timestamp).compareTo(ta as Timestamp);
      });
      setState(() {
        _notifications = all;
        _unreadNotifications = all.where((n) => n['isRead'] == false).length;
      });
    } catch (_) {}
  }

  Future<void> _markNotificationAsRead(String id) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(id)
          .update({'isRead': true});
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n['id'] == id);
          if (idx != -1) {
            _notifications[idx] = Map<String, dynamic>.from(_notifications[idx])
              ..['isRead'] = true;
            _unreadNotifications = _notifications
                .where((n) => n['isRead'] == false)
                .length;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllNotificationsAsRead() async {
    final unread = _notifications.where((n) => n['isRead'] == false).toList();
    if (unread.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final n in unread) {
        batch.update(
          FirebaseFirestore.instance
              .collection('notifications')
              .doc(n['id'] as String),
          {'isRead': true},
        );
      }
      await batch.commit();
      if (mounted) {
        setState(() {
          _notifications = _notifications
              .map((n) => Map<String, dynamic>.from(n)..['isRead'] = true)
              .toList();
          _unreadNotifications = 0;
        });
      }
    } catch (_) {}
  }

  // Maps a notification's type to the sidebar tab it's about, so clicking
  // one takes the admin straight to where it happened.
  static const Map<String, int> _notificationTypeToTabIndex = {
    'proposal_submission': 4, // EventProposals
    'letter_submission': 6, // AdminLetterRequestScreen
    'letter_resubmission': 6,
    'report_submission': 8, // ReportsManagement
  };

  void _handleNotificationTap(Map<String, dynamic> n) {
    final index = _notificationTypeToTabIndex[n['type']?.toString()];
    if (index != null) _selectTab(index);
  }

  void _selectTab(int index) {
    setState(() {
      _selectedIndex = index;
      _visitedIndices.add(index == -1 ? 10 : index);
    });
  }

  // Reads the bell's real on-screen position (via _bellKey) so any overlay
  // anchored from this can sit consistently right under it, regardless of
  // window width — Flutter's built-in menu-positioning (PopupMenuButton's
  // offset + internal clamping) repositions itself differently depending
  // on how much room is left in the viewport, which is what made the
  // dropdown/"View All" land in inconsistent spots before.
  ({double top, double right, double maxHeight}) _bellAnchor({
    required double preferredHeight,
  }) {
    final bellBox = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;
    double top = 76;
    double right = 28;
    if (bellBox != null) {
      final bellTopLeft = bellBox.localToGlobal(Offset.zero);
      final bellSize = bellBox.size;
      top = bellTopLeft.dy + bellSize.height + 12;
      right = (screenSize.width - (bellTopLeft.dx + bellSize.width) - 6).clamp(
        8.0,
        screenSize.width - 360,
      );
    }
    final maxHeight = (screenSize.height - top - 24).clamp(
      200.0,
      preferredHeight,
    );
    return (top: top, right: right, maxHeight: maxHeight);
  }

  void _showNotificationDropdown() {
    final anchor = _bellAnchor(preferredHeight: 480);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      barrierLabel: 'Notifications',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, anim, secAnim) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(top: anchor.top, right: anchor.right),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8ECF0), width: 0.5),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 360,
                  minWidth: 360,
                  maxHeight: anchor.maxHeight,
                ),
                child: _AdminNotificationPanel(
                  notifications: List.from(_notifications),
                  onMarkRead: _markNotificationAsRead,
                  onMarkAllRead: _markAllNotificationsAsRead,
                  onNotificationTap: _handleNotificationTap,
                  onViewAll: () {
                    Navigator.of(ctx).pop();
                    _showAllNotificationsDialog();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showAllNotificationsDialog() {
    final anchor = _bellAnchor(preferredHeight: 600);
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      barrierLabel: 'Notifications',
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (ctx, anim, secAnim) {
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: EdgeInsets.only(top: anchor.top, right: anchor.right),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE8ECF0), width: 0.5),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 360,
                  minWidth: 360,
                  maxHeight: anchor.maxHeight,
                ),
                child: _AdminNotificationPanel(
                  notifications: List.from(_notifications),
                  onMarkRead: _markNotificationAsRead,
                  onMarkAllRead: _markAllNotificationsAsRead,
                  onNotificationTap: _handleNotificationTap,
                  listMaxHeight: 480,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminLogin()),
      );
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_DS.radiusLg),
        ),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFDC2626),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Confirm Logout',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to logout from the admin panel?',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _logout();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      'Logout',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentTitle() {
    if (_selectedIndex == -1) return 'Settings';
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
                  // IndexedStack keeps every screen's state alive instead of
                  // tearing it down and re-fetching Firestore data from
                  // scratch on every tab switch — that re-fetch was the
                  // cause of the lag on every click.
                  child: IndexedStack(
                    index: _selectedIndex == -1 ? 10 : _selectedIndex,
                    children: List.generate(
                      _screens.length,
                      (i) => _visitedIndices.contains(i)
                          ? _screens[i]
                          : const SizedBox.shrink(),
                    ),
                  ),
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
        color: UpriseColors.primaryDark,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Brand header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  height: 44,
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.school, color: Colors.white, size: 26),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UPRISE',
                      style: GoogleFonts.beVietnamPro(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                    Text(
                      'Admin Panel',
                      style: GoogleFonts.beVietnamPro(
                        color: Colors.white.withAlpha(166),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Divider(
            color: Colors.white.withAlpha(38),
            thickness: 1,
            indent: 20,
            endIndent: 20,
          ),
          const SizedBox(height: 8),

          // Nav label
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'NAVIGATION',
                style: GoogleFonts.beVietnamPro(
                  color: Colors.white.withAlpha(115),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
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
                final isSelected = isSettings
                    ? _selectedIndex == -1
                    : _selectedIndex == index;

                return GestureDetector(
                  onTap: () => _selectTab(isSettings ? -1 : index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white.withAlpha(46)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected
                          ? Border.all(
                              color: Colors.white.withAlpha(64),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withAlpha(166),
                          size: 17,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item['label'] as String,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.beVietnamPro(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withAlpha(191),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 6,
                            height: 6,
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
          Divider(
            color: Colors.white.withAlpha(38),
            thickness: 1,
            indent: 20,
            endIndent: 20,
          ),
          GestureDetector(
            onTap: _confirmLogout,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: Colors.white.withAlpha(191),
                    size: 17,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: GoogleFonts.beVietnamPro(
                      color: Colors.white.withAlpha(191),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFE8ECF0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Page title with accent bar
          Row(
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getCurrentTitle(),
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: UpriseColors.charcoal,
                      letterSpacing: -0.2,
                    ),
                  ),
                  Text(
                    'CICT Organization Management',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 10.5,
                      color: const Color(0xFF9AA5B4),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const Spacer(),

          // Datetime chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(_DS.radiusPill),
              border: Border.all(color: UpriseColors.primaryDark.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: UpriseColors.primaryDark,
                ),
                const SizedBox(width: 6),
                Text(
                  _currentDateTime,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    color: UpriseColors.primaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF4ADE80),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Notification bell
          // A plain InkWell driving our own custom-positioned overlay
          // (same as "View All") instead of PopupMenuButton — Flutter's
          // built-in menu positioning clamps/repositions itself to fit the
          // viewport, which made the dropdown land in inconsistent spots
          // depending on window size instead of staying tucked under the
          // bell every time.
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              _fetchUnreadNotifications();
              _showNotificationDropdown();
            },
            child: KeyedSubtree(
              key: _bellKey,
              child: StreamBuilder<int>(
                // Live count so a new notification updates the badge
                // immediately, without needing to reopen the dropdown.
                stream: FirebaseAuth.instance.currentUser != null
                    ? NotificationService.unreadCountStream(
                        FirebaseAuth.instance.currentUser!.uid,
                      )
                    : const Stream<int>.empty(),
                initialData: _unreadNotifications,
                builder: (context, snapshot) {
                  final unread = snapshot.data ?? _unreadNotifications;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: unread > 0
                              ? UpriseColors.primaryDark.withAlpha(12)
                              : const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: unread > 0
                                ? UpriseColors.primaryDark.withAlpha(60)
                                : const Color(0xFFE8ECF0),
                          ),
                        ),
                        child: Icon(
                          unread > 0
                              ? Icons.notifications_rounded
                              : Icons.notifications_none_rounded,
                          color: unread > 0
                              ? UpriseColors.primaryDark
                              : const Color(0xFF64748B),
                          size: 18,
                        ),
                      ),
                      if (unread > 0)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: Color(0xFFDC2626),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 9 ? '9+' : '$unread',
                              style: GoogleFonts.beVietnamPro(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Divider
          Container(width: 1, height: 28, color: const Color(0xFFE8ECF0)),
          const SizedBox(width: 10),

          // Admin avatar
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: UpriseColors.primaryDark.withAlpha(50),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildAdminAvatar(),
              ),
              const SizedBox(width: 10),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _adminName,
                    style: GoogleFonts.beVietnamPro(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: UpriseColors.charcoal,
                    ),
                  ),
                  Text(
                    _adminRole,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 10,
                      color: const Color(0xFF9AA5B4),
                    ),
                  ),
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
// Replace the entire DashboardHome class with this fixed version:

// Replace the entire DashboardHome class with this fixed version:

class DashboardHome extends StatefulWidget {
  final VoidCallback? onNavigateToCalendar;
  const DashboardHome({super.key, this.onNavigateToCalendar});
  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  int _selectedYear = DateTime.now().year;
  String _selectedMonth = '';
  List<int> _chartData = List.filled(12, 0);
  bool _chartLoading = true;

  late final Stream<QuerySnapshot> _organizationsStream;
  late final Stream<QuerySnapshot> _eventsStream;
  late final Stream<QuerySnapshot> _proposalsStream;
  late final Stream<QuerySnapshot> _reportsStream;
  late final Stream<QuerySnapshot>
  _allEventsStream; // For upcoming events - no date filter in query

  // Plain calendar years — no academic-year offset to keep in sync with.
  List<int> get _yearOptions {
    final y = DateTime.now().year;
    return [y - 1, y, y + 1];
  }

  String _monthLabel(int index) {
    const m = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return m[index];
  }

  // ── Init ──────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _selectedMonth = _monthLabel(DateTime.now().month - 1);

    _organizationsStream = FirebaseFirestore.instance
        .collection('organizations')
        .where('status', isEqualTo: 'active')
        .snapshots();
    _eventsStream = FirebaseFirestore.instance
        .collection('event_proposals')
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

    // SIMPLE QUERY - no date filter to avoid index issues
    _allEventsStream = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('status', isEqualTo: 'approved')
        .snapshots();

    _fetchChartData();
  }

  void _fetchChartData() {
    setState(() {
      _chartLoading = true;
    });
    final startDate = DateTime(_selectedYear, 1, 1);
    final endDate = DateTime(_selectedYear + 1, 1, 1);

    FirebaseFirestore.instance
        .collection('event_proposals')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThan: Timestamp.fromDate(endDate))
        .get()
        .then((snap) {
          final counts = List.filled(12, 0);
          for (final doc in snap.docs) {
            final ts = doc.data()['date'] as Timestamp?;
            if (ts == null) continue;
            final idx = ts.toDate().month - 1;
            counts[idx]++;
          }
          if (mounted) {
            setState(() {
              _chartData = counts;
              _chartLoading = false;
            });
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _chartLoading = false);
        });
  }

  // Helper to filter upcoming events (filter in memory)
  List<QueryDocumentSnapshot> _getUpcomingEvents(QuerySnapshot snap) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final dateField = data['date'];
      if (dateField == null) return false;

      Timestamp ts;
      if (dateField is Timestamp) {
        ts = dateField;
      } else {
        return false;
      }

      final eventDate = ts.toDate();
      final eventDay = DateTime(eventDate.year, eventDate.month, eventDate.day);

      return eventDay.isAfter(today) || eventDay.isAtSameMomentAs(today);
    }).toList()..sort((a, b) {
      final dateA = (a.data() as Map)['date'] as Timestamp?;
      final dateB = (b.data() as Map)['date'] as Timestamp?;
      if (dateA == null || dateB == null) return 0;
      return dateA.toDate().compareTo(dateB.toDate());
    });
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final isTablet = width >= 720 && width < 1200;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(isMobile),
          const SizedBox(height: 20),
          if (isMobile) ...[
            _buildStatCards(isMobile, isTablet),
            const SizedBox(height: 20),
            _buildChartCard(isMobile),
            const SizedBox(height: 20),
            _buildUpcomingEvents(),
            const SizedBox(height: 20),
            _buildRecentActivity(),
            const SizedBox(height: 20),
            _buildTopOrgsCard(isMobile),
          ] else ...[
            _buildStatCards(isMobile, isTablet),
            const SizedBox(height: 20),
            _buildChartCard(isMobile),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildUpcomingEvents()),
                const SizedBox(width: 20),
                Expanded(child: _buildRecentActivity()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(bool isMobile) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: const BoxDecoration(
          color: UpriseColors.primaryDark,
          boxShadow: [
            BoxShadow(
              color: Color(0x40BE4700),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(12),
                ),
              ),
            ),
            Positioned(
              right: 70,
              bottom: -28,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(8),
                ),
              ),
            ),
            Positioned(
              left: -10,
              bottom: -16,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withAlpha(7),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
              child: isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLivePill(),
                        const SizedBox(height: 10),
                        Text(
                          'Administrator Dashboard',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'CICT Organization Management  •  Welcome back.',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12.5,
                            color: Colors.white.withAlpha(180),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withAlpha(35),
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLivePill(),
                              const SizedBox(height: 10),
                              Text(
                                'Administrator Dashboard',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'CICT Organization Management  •  Welcome back.',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 12.5,
                                  color: Colors.white.withAlpha(180),
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withAlpha(35),
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 34,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLivePill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFF4ADE80),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Live Dashboard',
            style: GoogleFonts.beVietnamPro(
              color: Colors.white.withAlpha(220),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCards(bool isMobile, bool isTablet) {
    final cardWidgets = [
      _buildStatCard(
        'Active Orgs',
        _organizationsStream,
        UpriseColors.primaryDark,
        Icons.business_rounded,
      ),
      _buildStatCard(
        'Active Events',
        _eventsStream,
        UpriseColors.success,
        Icons.event_rounded,
      ),
      _buildStatCard(
        'Pending Proposals',
        _proposalsStream,
        UpriseColors.warning,
        Icons.pending_actions_rounded,
      ),
      _buildStatCard(
        'Overdue Reports',
        _reportsStream,
        UpriseColors.error,
        Icons.warning_amber_rounded,
      ),
    ];

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var card in cardWidgets) ...[card, const SizedBox(height: 10)],
        ],
      );
    }

    final width = MediaQuery.of(context).size.width;
    if (isTablet) {
      return SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cardWidgets.length; i++) ...[
                SizedBox(
                  width: math.min(320.0, width * 0.45),
                  child: cardWidgets[i],
                ),
                if (i != cardWidgets.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cardWidgets.length; i++) ...[
          Expanded(child: cardWidgets[i]),
          if (i != cardWidgets.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    Stream<QuerySnapshot> stream,
    Color color,
    IconData icon,
  ) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        final count = snap.hasData ? snap.data!.docs.length : 0;
        final loading = snap.connectionState == ConnectionState.waiting;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (loading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    )
                  else
                    Text(
                      '$count',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingEventsStatCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _allEventsStream,
      builder: (ctx, snap) {
        final upcomingCount = snap.hasData
            ? _getUpcomingEvents(snap.data!).length
            : 0;
        final loading = snap.connectionState == ConnectionState.waiting;

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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: UpriseColors.info.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.upcoming_rounded,
                      color: UpriseColors.info,
                      size: 20,
                    ),
                  ),
                  if (loading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: UpriseColors.info,
                      ),
                    )
                  else
                    Text(
                      '$upcomingCount',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Upcoming Events',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopOrgsCard(bool isMobile) {
    final now = DateTime.now();
    final semesterStart = now.month >= 8
        ? DateTime(now.year, 8, 1)
        : now.month >= 2
        ? DateTime(now.year, 2, 1)
        : DateTime(now.year - 1, 8, 1);

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark.withAlpha(26),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.leaderboard_rounded,
                  color: UpriseColors.primaryDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Top Organizations',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: UpriseColors.accent,
                    ),
                  ),
                  Text(
                    'Most active orgs this semester by approved events',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: const Color(0xFF9AA5B4),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('events')
                .where('status', isEqualTo: 'approved')
                .where(
                  'date',
                  isGreaterThanOrEqualTo: Timestamp.fromDate(semesterStart),
                )
                .get(),
            builder: (ctx, evSnap) {
              if (!evSnap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: UpriseColors.primaryDark,
                    ),
                  ),
                );
              }

              // Count events per orgId
              final counts = <String, int>{};
              final orgNames = <String, String>{};
              for (final doc in evSnap.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                final oid = d['orgId']?.toString() ?? '';
                if (oid.isEmpty) continue;
                counts[oid] = (counts[oid] ?? 0) + 1;
                if (!orgNames.containsKey(oid)) {
                  orgNames[oid] = d['orgName']?.toString() ?? oid;
                }
              }

              if (counts.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No events found this semester.',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: const Color(0xFF9AA5B4),
                      ),
                    ),
                  ),
                );
              }

              final sorted = counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final top = sorted.take(isMobile ? 5 : 8).toList();
              final maxCount = top.first.value.toDouble();

              return Column(
                children: top.asMap().entries.map((entry) {
                  final rank = entry.key + 1;
                  final orgId = entry.value.key;
                  final count = entry.value.value;
                  final name = orgNames[orgId] ?? orgId;
                  final ratio = count / maxCount;

                  final rankColor = rank == 1
                      ? const Color(0xFFEAB308)
                      : rank == 2
                      ? const Color(0xFF94A3B8)
                      : rank == 3
                      ? const Color(0xFFCD7C37)
                      : const Color(0xFFCBD5E1);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          child: Text(
                            '#$rank',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: rankColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircleAvatar(
                            backgroundColor: UpriseColors.primaryDark.withAlpha(
                              26,
                            ),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: UpriseColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF1A202C),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: ratio,
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  color: UpriseColors.primaryDark,
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: UpriseColors.primaryDark.withAlpha(20),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count event${count > 1 ? 's' : ''}',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: UpriseColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(bool isMobile) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity Overview',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UpriseColors.accent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'All event proposals per month this year',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: const Color(0xFF9AA5B4),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: UpriseColors.primaryDark,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Proposals',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E6EA)),
                      borderRadius: BorderRadius.circular(8),
                      color: const Color(0xFFF8F9FB),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: const Color(0xFF374151),
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: Color(0xFF9AA5B4),
                        ),
                        items: _yearOptions
                            .map(
                              (y) =>
                                  DropdownMenuItem(value: y, child: Text('$y')),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null && mounted) {
                            setState(() {
                              _selectedYear = v;
                              _fetchChartData();
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 310,
            child: _chartLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: UpriseColors.primaryDark,
                    ),
                  )
                : _ActivityBarChart(
                    data: _chartData,
                    selectedMonth: _selectedMonth,
                    monthLabel: _monthLabel,
                  ),
          ),
        ],
      ),
    );
  }

  Future<List<_OrgPerformance>> _loadPerformanceSummary() async {
    try {
      final proposalsSnap = await FirebaseFirestore.instance
          .collection('event_proposals')
          .get();
      final ordersSnap = await FirebaseFirestore.instance
          .collection('orders')
          .get();

      // Debug: print counts
      // ignore: avoid_print
      print(
        '[admin_dashboard] proposals: ${proposalsSnap.docs.length}, orders: ${ordersSnap.docs.length}',
      );

      final proposalStats = <String, Map<String, dynamic>>{};
      final orderStats = <String, Map<String, dynamic>>{};
      final orgIds = <String>{};

      for (final doc in proposalsSnap.docs) {
        final data = doc.data();
        final orgId = (data['orgId'] as String?)?.trim() ?? '';
        if (orgId.isEmpty) continue;
        orgIds.add(orgId);
        final orgName = (data['orgName'] as String?)?.trim() ?? '';
        final stat = proposalStats.putIfAbsent(
          orgId,
          () => {'orgName': orgName, 'proposalCount': 0, 'approvedCount': 0},
        );
        if (orgName.isNotEmpty) {
          stat['orgName'] = orgName;
        }
        stat['proposalCount'] = (stat['proposalCount'] as int) + 1;
        if ((data['status'] as String?)?.toLowerCase() == 'approved') {
          stat['approvedCount'] = (stat['approvedCount'] as int) + 1;
        }
      }

      for (final doc in ordersSnap.docs) {
        final data = doc.data();
        final orgId = (data['orgId'] as String?)?.trim() ?? '';
        if (orgId.isEmpty) continue;
        orgIds.add(orgId);
        final stat = orderStats.putIfAbsent(
          orgId,
          () => {'orderCount': 0, 'revenue': 0.0},
        );
        stat['orderCount'] = (stat['orderCount'] as int) + 1;
        final total = (data['total'] is num)
            ? (data['total'] as num).toDouble()
            : 0.0;
        stat['revenue'] = (stat['revenue'] as double) + total;
      }

      final missingOrgIds = orgIds.where((id) {
        final stat = proposalStats[id];
        return stat == null || (stat['orgName'] as String).isEmpty;
      }).toList();
      final orgNameMap = <String, String>{};

      for (var i = 0; i < missingOrgIds.length; i += 10) {
        final batch = missingOrgIds.skip(i).take(10).toList();
        if (batch.isEmpty) continue;
        final orgDocs = await FirebaseFirestore.instance
            .collection('organizations')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        for (final doc in orgDocs.docs) {
          orgNameMap[doc.id] =
              (doc.data()['name'] as String?) ?? 'Organization';
        }
      }

      // Debug: sample orgs
      // ignore: avoid_print
      print(
        '[admin_dashboard] orgIds found: ${orgIds.length}, sample: ${orgIds.take(5).toList()}',
      );

      return orgIds.map((orgId) {
        final proposalStat = proposalStats[orgId];
        final orderStat = orderStats[orgId];
        final orgName =
            (proposalStat?['orgName'] as String?)?.isNotEmpty == true
            ? proposalStat!['orgName'] as String
            : orgNameMap[orgId] ?? 'Organization';
        return _OrgPerformance(
          orgId: orgId,
          orgName: orgName,
          proposals: proposalStat?['proposalCount'] as int? ?? 0,
          approvedEvents: proposalStat?['approvedCount'] as int? ?? 0,
          merchOrders: orderStat?['orderCount'] as int? ?? 0,
          merchRevenue: orderStat?['revenue'] as double? ?? 0.0,
        );
      }).toList();
    } catch (e, s) {
      // ignore: avoid_print
      print('[admin_dashboard] _loadPerformanceSummary error: $e');
      // ignore: avoid_print
      print(s);
      return <_OrgPerformance>[];
    }
  }

  Widget _buildPerformanceSummary() {
    return FutureBuilder<List<_OrgPerformance>>(
      future: _loadPerformanceSummary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_DS.radiusLg),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_DS.radiusLg),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: _emptyPlaceholder(
              Icons.error_outline_rounded,
              'Unable to load performance summary',
            ),
          );
        }

        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_DS.radiusLg),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: _emptyPlaceholder(
              Icons.dashboard_outlined,
              'No performance data available',
            ),
          );
        }

        final topProposals = [...items]
          ..sort((a, b) => b.proposals.compareTo(a.proposals));
        final topApproved = [...items]
          ..sort((a, b) => b.approvedEvents.compareTo(a.approvedEvents));
        final topMerch = [...items]
          ..sort((a, b) => b.merchOrders.compareTo(a.merchOrders));

        return Container(
          width: double.infinity,
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
              Text(
                'Top Performing Organizations',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: UpriseColors.accent,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'A quick glance at top orgs by proposals, approved events, and merchandise orders.',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: const Color(0xFF9AA5B4),
                ),
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth;
                  if (w >= 1000) {
                    final cardWidth = math.min(340.0, (w - 32) / 3);
                    return Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: cardWidth,
                            child: _buildPerformanceMetricCard(
                              title: 'Most Proposals',
                              orgName: topProposals.first.orgName,
                              metric: '${topProposals.first.proposals}',
                              subtitle: 'Total event proposals',
                              color: UpriseColors.primaryDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: cardWidth,
                            child: _buildPerformanceMetricCard(
                              title: 'Most Approved Events',
                              orgName: topApproved.first.orgName,
                              metric: '${topApproved.first.approvedEvents}',
                              subtitle: 'Approved event proposals',
                              color: UpriseColors.success,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: cardWidth,
                            child: _buildPerformanceMetricCard(
                              title: 'Best Merchandise Orders',
                              orgName: topMerch.first.orgName,
                              metric: '${topMerch.first.merchOrders}',
                              subtitle:
                                  '${NumberFormat.currency(symbol: '₱', decimalDigits: 0).format(topMerch.first.merchRevenue)} revenue',
                              color: UpriseColors.info,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (w >= 700) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildPerformanceMetricCard(
                            title: 'Most Proposals',
                            orgName: topProposals.first.orgName,
                            metric: '${topProposals.first.proposals}',
                            subtitle: 'Total event proposals',
                            color: UpriseColors.primaryDark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPerformanceMetricCard(
                            title: 'Most Approved Events',
                            orgName: topApproved.first.orgName,
                            metric: '${topApproved.first.approvedEvents}',
                            subtitle: 'Approved event proposals',
                            color: UpriseColors.success,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPerformanceMetricCard(
                            title: 'Best Merchandise Orders',
                            orgName: topMerch.first.orgName,
                            metric: '${topMerch.first.merchOrders}',
                            subtitle:
                                '${NumberFormat.currency(symbol: '₱', decimalDigits: 0).format(topMerch.first.merchRevenue)} revenue',
                            color: UpriseColors.info,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPerformanceMetricCard(
                        title: 'Most Proposals',
                        orgName: topProposals.first.orgName,
                        metric: '${topProposals.first.proposals}',
                        subtitle: 'Total event proposals',
                        color: UpriseColors.primaryDark,
                      ),
                      const SizedBox(height: 12),
                      _buildPerformanceMetricCard(
                        title: 'Most Approved Events',
                        orgName: topApproved.first.orgName,
                        metric: '${topApproved.first.approvedEvents}',
                        subtitle: 'Approved event proposals',
                        color: UpriseColors.success,
                      ),
                      const SizedBox(height: 12),
                      _buildPerformanceMetricCard(
                        title: 'Best Merchandise Orders',
                        orgName: topMerch.first.orgName,
                        metric: '${topMerch.first.merchOrders}',
                        subtitle:
                            '${NumberFormat.currency(symbol: '₱', decimalDigits: 0).format(topMerch.first.merchRevenue)} revenue',
                        color: UpriseColors.info,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPerformanceMetricCard({
    required String title,
    required String orgName,
    required String metric,
    required String subtitle,
    required Color color,
    double? width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 176),
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
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.star_border_rounded,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              orgName,
              style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: UpriseColors.charcoal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              metric,
              style: GoogleFonts.beVietnamPro(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: UpriseColors.charcoal,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Upcoming events list (filters in memory) ──────────────────────
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
        child: StreamBuilder<QuerySnapshot>(
          stream: _allEventsStream,
          builder: (ctx, snap) {
            final upcomingEvents = snap.hasData
                ? _getUpcomingEvents(snap.data!)
                : <QueryDocumentSnapshot>[];
            final displayEvents = upcomingEvents.take(4).toList();
            final showViewAll = upcomingEvents.length >= 4;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming CICT Events',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: UpriseColors.accent,
                      ),
                    ),
                    if (showViewAll)
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onNavigateToCalendar,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: UpriseColors.primaryDark.withAlpha(20),
                              borderRadius: BorderRadius.circular(
                                _DS.radiusPill,
                              ),
                            ),
                            child: Text(
                              'View All',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: UpriseColors.primaryDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (snap.connectionState == ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snap.hasError)
                  _emptyPlaceholder(
                    Icons.error_outline_rounded,
                    'Error loading events',
                  )
                else if (displayEvents.isEmpty)
                  _emptyPlaceholder(
                    Icons.calendar_today_outlined,
                    'No upcoming events',
                  )
                else
                  Column(
                    children: displayEvents.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final eventDate = d['date'] is Timestamp
                          ? (d['date'] as Timestamp).toDate()
                          : DateTime.now();
                      return _EventRow(
                        date: eventDate.toIso8601String(),
                        title: d['title'] ?? 'Untitled',
                        location: d['location'] ?? 'TBA',
                        time: d['time'] ?? 'TBA',
                      );
                    }).toList(),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

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
            Text(
              'Recent Activity',
              style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: UpriseColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(6)
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (snap.hasError) {
                  return _emptyPlaceholder(
                    Icons.error_outline_rounded,
                    'Error loading activity',
                  );
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _emptyPlaceholder(
                    Icons.history_rounded,
                    'No recent activity',
                  );
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 26, color: const Color(0xFF9AA5B4)),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: const Color(0xFF9AA5B4),
              ),
            ),
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

class _OrgPerformance {
  final String orgId;
  final String orgName;
  final int proposals;
  final int approvedEvents;
  final int merchOrders;
  final double merchRevenue;

  const _OrgPerformance({
    required this.orgId,
    required this.orgName,
    required this.proposals,
    required this.approvedEvents,
    required this.merchOrders,
    required this.merchRevenue,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification panel widget
// ─────────────────────────────────────────────────────────────────────────────
class _AdminNotificationPanel extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(String id) onMarkRead;
  final Future<void> Function() onMarkAllRead;
  final void Function(Map<String, dynamic> n) onNotificationTap;
  final VoidCallback? onViewAll;
  final double listMaxHeight;

  const _AdminNotificationPanel({
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAllRead,
    required this.onNotificationTap,
    this.onViewAll,
    this.listMaxHeight = 400,
  });

  @override
  State<_AdminNotificationPanel> createState() =>
      _AdminNotificationPanelState();
}

class _AdminNotificationPanelState extends State<_AdminNotificationPanel> {
  late List<Map<String, dynamic>> _notifs;

  @override
  void initState() {
    super.initState();
    _notifs = List.from(widget.notifications);
  }

  Future<void> _markRead(String id) async {
    setState(() {
      final idx = _notifs.indexWhere((n) => n['id'] == id);
      if (idx != -1) {
        _notifs[idx] = Map<String, dynamic>.from(_notifs[idx])
          ..['isRead'] = true;
      }
    });
    await widget.onMarkRead(id);
  }

  Future<void> _markAll() async {
    setState(() {
      _notifs = _notifs
          .map((n) => Map<String, dynamic>.from(n)..['isRead'] = true)
          .toList();
    });
    await widget.onMarkAllRead();
  }

  String _timeAgo(dynamic ts) {
    if (ts == null) return '';
    try {
      final dt = (ts as Timestamp).toDate();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  String _dateGroup(dynamic ts) {
    if (ts == null) return 'Older';
    try {
      final dt = (ts as Timestamp).toDate();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final nDay = DateTime(dt.year, dt.month, dt.day);
      final diff = today.difference(nDay).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) return 'This Week';
      return 'Older';
    } catch (_) {
      return 'Older';
    }
  }

  Widget _buildNotifItem(Map<String, dynamic> n) {
    final isRead = n['isRead'] as bool? ?? false;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (!isRead) _markRead(n['id'] as String);
          widget.onNotificationTap(n);
          Navigator.of(context).pop();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFFFF7ED),
            border: const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE8ECF0)),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 16,
                  color: isRead
                      ? const Color(0xFF9AA5B4)
                      : UpriseColors.primaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(right: 6, top: 4),
                          decoration: BoxDecoration(
                            color: isRead
                                ? const Color(0xFFE8ECF0)
                                : UpriseColors.primaryDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            n['title']?.toString() ?? 'Notification',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              color: isRead
                                  ? const Color(0xFF6B7280)
                                  : const Color(0xFF1A202C),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(n['timestamp']),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            color: const Color(0xFF9AA5B4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['message']?.toString() ?? '',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        height: 1.45,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedItems() {
    const groupOrder = ['Today', 'Yesterday', 'This Week', 'Older'];
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final n in _notifs) {
      final key = _dateGroup(n['timestamp']);
      groups.putIfAbsent(key, () => []).add(n);
    }
    final widgets = <Widget>[];
    for (final groupKey in groupOrder) {
      final items = groups[groupKey];
      if (items == null || items.isEmpty) continue;
      widgets.add(
        Container(
          width: double.infinity,
          color: const Color(0xFFF8F9FB),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
          child: Text(
            groupKey,
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      );
      for (final n in items) {
        widgets.add(_buildNotifItem(n));
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifs.where((n) => n['isRead'] == false).length;

    return SizedBox(
      width: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 14),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.beVietnamPro(
                    color: const Color(0xFF1A202C),
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                if (unreadCount > 0)
                  InkWell(
                    onTap: _markAll,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.done_all_rounded,
                            size: 15,
                            color: UpriseColors.primaryDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Mark all as read',
                            style: GoogleFonts.beVietnamPro(
                              color: UpriseColors.primaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Body
          if (_notifs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE8ECF0)),
                    ),
                    child: const Icon(
                      Icons.notifications_off_outlined,
                      size: 24,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No notifications yet',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You're all caught up!",
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: const Color(0xFF9AA5B4),
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: widget.listMaxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildGroupedItems(),
                  ),
                ),
              ),
            ),
          // Footer
          if (_notifs.isNotEmpty && widget.onViewAll != null)
            InkWell(
              onTap: () {
                Navigator.of(context).pop();
                widget.onViewAll!();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Text(
                  'View all notifications',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: UpriseColors.primaryDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity bar chart — monthly proposal counts via fl_chart. A bar per month
// reads more clearly than a line for discrete counts, and fl_chart owns
// touch/tooltip/scaling, so there's no custom hit-testing math to get wrong.
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityBarChart extends StatelessWidget {
  final List<int> data;
  final String selectedMonth;
  final String Function(int) monthLabel;

  const _ActivityBarChart({
    required this.data,
    required this.selectedMonth,
    required this.monthLabel,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 0 : data.reduce((a, b) => a > b ? a : b);
    final maxY = (maxVal < 4 ? 4 : maxVal).toDouble() * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFF1F5F9), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: maxY / 4,
              getTitlesWidget: (v, _) => Text(
                '${v.toInt()}',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 10,
                  color: const Color(0xFF9AA5B4),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (v, _) {
                final label = monthLabel(v.toInt());
                final isSelected = label == selectedMonth;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    label,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? UpriseColors.primaryDark
                          : const Color(0xFF9AA5B4),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1A202C),
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              '${monthLabel(group.x)}\n',
              GoogleFonts.beVietnamPro(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
              children: [
                TextSpan(
                  text: '${rod.toY.toInt()} proposal(s)',
                  style: GoogleFonts.beVietnamPro(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        barGroups: List.generate(data.length, (i) {
          final isSelected = monthLabel(i) == selectedMonth;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i].toDouble(),
                color: isSelected
                    ? UpriseColors.primaryDark
                    : UpriseColors.primaryDark.withAlpha(110),
                width: 35,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
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
      const m = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
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
            width: 48,
            height: 52,
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  d.month,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: UpriseColors.primaryDark,
                  ),
                ),
                Text(
                  d.day,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: UpriseColors.primaryDark,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title ?? 'Untitled',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: Color(0xFF9AA5B4),
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        location ?? 'TBA',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          color: const Color(0xFF9AA5B4),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: Color(0xFF9AA5B4),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      time ?? 'TBA',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: const Color(0xFF9AA5B4),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Activity row — matches StudentAccounts style
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityRow extends StatelessWidget {
  final String title, module;
  final Timestamp? timestamp;
  const _ActivityRow({
    required this.title,
    required this.module,
    this.timestamp,
  });

  String _timeAgo() {
    if (timestamp == null) return 'Just now';
    final diff = DateTime.now().difference(timestamp!.toDate());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  Color _dotColor() {
    final l = title.toLowerCase();
    if (l.contains('proposal') || l.contains('pending'))
      return UpriseColors.warning;
    if (l.contains('verified') || l.contains('created'))
      return UpriseColors.success;
    if (l.contains('deleted') || l.contains('error')) return UpriseColors.error;
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
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _dotColor(),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                if (module.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      module,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 10,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  _timeAgo(),
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    color: const Color(0xFF9AA5B4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
