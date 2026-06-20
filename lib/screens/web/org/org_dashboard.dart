// lib/screens/web/org/org_dashboard.dart
//
// Redesigned to match AdminDashboard pattern exactly:
//  - Gradient welcome header card with icon
//  - 5-column stat cards (icon top-left, count top-right, label bottom)
//  - Line chart with semester dropdown + month pills
//  - Upcoming events panel + Recent activity panel (bottom row)
//  - Sidebar: NAVIGATION label, animated selection, dot indicator, logout button
//  - Top bar: title+subtitle, datetime pill, search, notification PopupMenu, org avatar
//  - Unified "org" role — no officer/adviser split

import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../auth/change_password_screen.dart';
import 'org_event_proposals.dart';
import 'org_events_schedule.dart';
import 'org_attendance_qr.dart';
import 'org_certificates.dart';
import 'org_event_analytics.dart';
import 'org_announcements.dart';
import 'org_broadcast.dart';
import 'org_profile.dart';
import 'org_letter_request.dart';
import 'org_reports.dart';
import 'org_finance.dart';
import 'org_merchandise.dart';
import 'org_settings.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (copied from report.dart for the countdown)
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 100;

  static const Color primary = Color(0xFFEA580C);
  static const Color primaryBg = Color(0xFFFEF3C7);

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// OrgColors (your existing theme)
// ─────────────────────────────────────────────────────────────────────────────
class OrgColors {
  static const Color primaryDark = Color(0xFFBE4700);
  static const Color primaryLight = Color(0xFFD47A00);
  static const Color accent = Color(0xFFDA6937);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FB);
  static const Color lightGray = Color(0xFFF8F9FB);
  static const Color border = Color(0xFFE8ECF0);
  static const Color borderSoft = Color(0xFFE2E6EA);
  static const Color darkGray = Color(0xFF64748B);
  static const Color textFaint = Color(0xFF9AA5B4);
  static const Color charcoal = Color(0xFF1A202C);
  static const Color textMid = Color(0xFF374151);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFFB923C);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color info = Color(0xFF2563EB);
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown widget (stateful – updates itself, no parent rebuild)
// ─────────────────────────────────────────────────────────────────────────────
class _CountdownCard extends StatefulWidget {
  final DateTime eventDate;
  final String eventLabel;
  const _CountdownCard({
    required this.eventDate,
    required this.eventLabel,
  });

  @override
  State<_CountdownCard> createState() => _CountdownCardState();
}

class _CountdownCardState extends State<_CountdownCard> {
  Duration _remaining = Duration.zero;
  Timer? _timer;

  void _updateRemaining() {
    final diff = widget.eventDate.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
  }

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  @override
  void didUpdateWidget(covariant _CountdownCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventDate != widget.eventDate) {
      _updateRemaining();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = _remaining == Duration.zero;
    final d = _remaining.inDays;
    final h = _remaining.inHours % 24;
    final m = _remaining.inMinutes % 60;
    final s = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _DS.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: _DS.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expired
                    ? '${widget.eventLabel} has started!'
                    : 'Countdown to: ${widget.eventLabel}',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: OrgColors.charcoal,
                ),
              ),
              Text(
                DateFormat('MMMM d, yyyy — h:mm a').format(widget.eventDate),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: OrgColors.darkGray,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!expired)
            Row(
              children: [
                _CountUnit(value: d, label: 'DAYS'),
                _Colon(),
                _CountUnit(value: h, label: 'HRS'),
                _Colon(),
                _CountUnit(value: m, label: 'MIN'),
                _Colon(),
                _CountUnit(value: s, label: 'SEC'),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: OrgColors.success.withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Event Started!',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OrgColors.success,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 48,
        height: 42,
        decoration: BoxDecoration(
          color: _DS.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          value.toString().padLeft(2, '0'),
          style: GoogleFonts.beVietnamPro(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 9,
          color: OrgColors.darkGray,
          letterSpacing: 0.5,
        ),
      ),
    ],
  );
}

class _Colon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      ':',
      style: GoogleFonts.beVietnamPro(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _DS.primary,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sidebar nav items
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _navItems = [
  {'label': 'Dashboard', 'icon': Icons.dashboard_rounded},
  {'label': 'Event Proposals', 'icon': Icons.description_rounded},
  {'label': 'Events & Schedules', 'icon': Icons.calendar_month_rounded},
  {'label': 'Attendance QR', 'icon': Icons.qr_code_scanner_rounded},
  {'label': 'Certificates', 'icon': Icons.verified_rounded},
  {'label': 'Event Analytics', 'icon': Icons.bar_chart_rounded},
  {'label': 'Announcements', 'icon': Icons.campaign_rounded},
  {'label': 'Broadcast', 'icon': Icons.wifi_tethering_rounded},
  {'label': 'Org Profile', 'icon': Icons.people_rounded},
  {'label': 'Letter Request', 'icon': Icons.mail_rounded},
  {'label': 'Reports', 'icon': Icons.summarize_rounded},
  {'label': 'Finance', 'icon': Icons.account_balance_wallet_rounded},
  {'label': 'Merchandise', 'icon': Icons.shopping_bag_rounded},
  {'label': 'Settings', 'icon': Icons.settings_rounded},
];

// ─────────────────────────────────────────────────────────────────────────────
// OrgDashboard shell
// ─────────────────────────────────────────────────────────────────────────────
class OrgDashboard extends StatefulWidget {
  const OrgDashboard({super.key});

  @override
  State<OrgDashboard> createState() => _OrgDashboardState();
}

class _OrgDashboardState extends State<OrgDashboard> {
  int _selectedIndex = 0;
  String _orgId = '';
  String _orgName = '';
  String _orgShortName = '';
  String _orgEmail = '';
  String? _orgLogoUrl;
  bool _isLoading = true;
  String? _loadError;
  String _currentDateTime = '';
  bool _sidebarOpen = false;

  final TextEditingController _searchController = TextEditingController();
  int _unreadNotifications = 0;
  List<Map<String, dynamic>> _notifications = [];

  late List<Widget> _screens;
  bool _screensBuilt = false;

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    _loadOrgData();
  }

  void _updateDateTime() {
    if (!mounted) return;
    setState(() {
      _currentDateTime = DateFormat(
        'EEE, MMM d, yyyy  \u2022  h:mm a',
      ).format(DateTime.now());
    });
    Future.delayed(const Duration(seconds: 60), _updateDateTime);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrgData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          setState(() {
            _loadError = 'User record not found. Please sign in again.';
            _isLoading = false;
          });
        }
        return;
      }

      final userData = userDoc.data()!;
      final orgId =
          (userData['orgId'] as String?) ??
          (userData['organizationId'] as String?);

      final bool needsChange =
          (userData['isFirstLogin'] == true) ||
          (userData['mustChangePassword'] == true) ||
          (userData['needsPasswordChange'] == true) ||
          (userData['firstLogin'] == true);

      if (needsChange) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) =>
                ChangePasswordScreen(userId: user.uid, isFirstLogin: true),
          ),
        );
        return;
      }

      if (orgId == null || orgId.isEmpty) {
        if (mounted) {
          setState(() {
            _loadError =
                'This account is not linked to an organization.\nContact your administrator.';
            _isLoading = false;
          });
        }
        return;
      }

      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();

      if (!orgDoc.exists) {
        if (mounted) {
          setState(() {
            _loadError =
                'Organization data not found. Contact your administrator.';
            _isLoading = false;
          });
        }
        return;
      }

      final orgData = orgDoc.data()!;
      if (mounted) {
        setState(() {
          _orgId = orgId;
          _orgName = orgData['name'] as String? ?? 'Organization';
          _orgShortName = orgData['shortName'] as String? ?? 'ORG';
          _orgEmail = orgData['email'] as String? ?? '';
          _orgLogoUrl = orgData['logoUrl'] as String?;
          _buildScreens();
          _isLoading = false;
        });
        _fetchUnreadNotifications();
      }
    } catch (e, st) {
      debugPrint('OrgDashboard load error: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError =
              'Unable to load dashboard.\nPlease refresh or sign in again.';
          _isLoading = false;
        });
      }
    }
  }

  void _buildScreens() {
    _screens = [
      _OrgDashboardHome(orgId: _orgId, orgName: _orgName),
      OrgEventProposalsScreen(orgId: _orgId),
      OrgEventsScheduleScreen(orgId: _orgId),
      EventManagementScreen(orgId: _orgId),
      OrgCertificatesScreen(orgId: _orgId),
      OrgEventAnalyticsScreen(orgId: _orgId),
      OrgAnnouncementsScreen(orgId: _orgId),
      OrgBroadcastScreen(orgId: _orgId),
      OrgProfileScreen(
        orgId: _orgId,
        orgName: _orgName,
        orgShortName: _orgShortName,
        orgEmail: _orgEmail,
      ),
      OrgLetterRequestScreen(orgId: _orgId),
      OrgReportsScreen(orgId: _orgId),
      OrgFinanceScreen(orgId: _orgId),
      OrgMerchandiseScreen(orgId: _orgId),
    ];
    _screensBuilt = true;
  }

  Future<void> _fetchUnreadNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .get();
      if (mounted) {
        final all = snap.docs
            .map((d) => {
                  'id': d.id,
                  'title': d.data()['title'] ?? 'New Notification',
                  'message': d.data()['body'] ?? d.data()['message'] ?? '',
                  'isRead': d.data()['isRead'] ?? false,
                  'timestamp': d.data()['createdAt'],
                })
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
      }
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
            _notifications[idx] =
                Map<String, dynamic>.from(_notifications[idx])
                  ..['isRead'] = true;
            _unreadNotifications =
                _notifications.where((n) => n['isRead'] == false).length;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _markAllNotificationsAsRead() async {
    final unread =
        _notifications.where((n) => n['isRead'] == false).toList();
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

  Future<void> _logout() async => FirebaseAuth.instance.signOut();

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
                      color: OrgColors.errorBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: OrgColors.error,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Confirm Logout',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: OrgColors.charcoal,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Are you sure you want to sign out from the organization portal?',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  color: OrgColors.darkGray,
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
                      side: const BorderSide(color: OrgColors.borderSoft),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_DS.radiusSm),
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
                        color: OrgColors.textMid,
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
                      backgroundColor: OrgColors.error,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_DS.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      'Sign Out',
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
    if (_selectedIndex < _navItems.length - 1) {
      return _navItems[_selectedIndex]['label'] as String;
    }
    return 'Dashboard';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: OrgColors.surface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: OrgColors.primaryDark.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: OrgColors.primaryDark,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: OrgColors.primaryDark,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Loading dashboard\u2026',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  color: OrgColors.darkGray,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: OrgColors.surface,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: OrgColors.white,
              borderRadius: BorderRadius.circular(_DS.radiusLg),
              border: Border.all(color: OrgColors.border),
              boxShadow: _DS.cardShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: OrgColors.errorBg,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    size: 30,
                    color: OrgColors.error,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to Load Dashboard',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: OrgColors.charcoal,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _loadError!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    color: OrgColors.darkGray,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _loadOrgData,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: Text(
                      'Try Again',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OrgColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_DS.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: OrgColors.borderSoft),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(_DS.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Sign Out',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: OrgColors.textMid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: OrgColors.surface,
      body: Stack(
        children: [
          Row(
            children: [
              if (!isMobile) _buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    _buildTopBar(isMobile),
                    Expanded(
                      child: _selectedIndex == -1
                          ? OrgSettingsScreen(
                              orgId: _orgId,
                              orgName: _orgName,
                              orgShortName: _orgShortName,
                              orgEmail: _orgEmail,
                            )
                          : (_screensBuilt
                                ? _screens[_selectedIndex]
                                : const SizedBox()),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 256,
      decoration: const BoxDecoration(
        color: OrgColors.primaryDark,
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
          Container(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(46),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.school_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
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
                      'Organization Portal',
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
                  onTap: () =>
                      setState(() => _selectedIndex = isSettings ? -1 : index),
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
                            decoration: const BoxDecoration(
                              color: OrgColors.accent,
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
                    'Sign Out',
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

  Widget _buildTopBar(bool isMobile) {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth < 720 ? 12.0 : 28.0;
    final isSmallMobile = screenWidth < 480;

    return Container(
      height: 68,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      decoration: BoxDecoration(
        color: OrgColors.white,
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
          if (isMobile)
            GestureDetector(
              onTap: () => setState(() => _sidebarOpen = !_sidebarOpen),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: OrgColors.lightGray,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: OrgColors.border),
                ),
                child: const Icon(Icons.menu_rounded, color: OrgColors.darkGray, size: 18),
              ),
            ),
          Row(
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: OrgColors.primaryDark,
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
                      fontSize: isSmallMobile ? 14 : 16,
                      fontWeight: FontWeight.w800,
                      color: OrgColors.charcoal,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (!isSmallMobile)
                    Text(
                      _orgName,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 10.5,
                        color: OrgColors.textFaint,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const Spacer(),
          if (!isSmallMobile) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(_DS.radiusPill),
                border: Border.all(color: OrgColors.primaryDark.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 12, color: OrgColors.primaryDark),
                  const SizedBox(width: 6),
                  Text(
                    _currentDateTime.length > 20
                        ? _currentDateTime.substring(0, 20)
                        : _currentDateTime,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      color: OrgColors.primaryDark,
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
          ],
          if (screenWidth >= 600)
            SizedBox(
              width: 220,
              height: 36,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.beVietnamPro(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search…',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.textFaint),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: OrgColors.textFaint),
                  filled: true,
                  fillColor: OrgColors.lightGray,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: OrgColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: OrgColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: OrgColors.primaryDark, width: 1.5),
                  ),
                ),
              ),
            )
          else if (screenWidth >= 480)
            SizedBox(
              width: 110,
              height: 36,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.beVietnamPro(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.textFaint),
                  prefixIcon: const Icon(Icons.search_rounded, size: 15, color: OrgColors.textFaint),
                  filled: true,
                  fillColor: OrgColors.lightGray,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: OrgColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: OrgColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: OrgColors.primaryDark, width: 1.5),
                  ),
                ),
              ),
            ),
          if (screenWidth >= 480) const SizedBox(width: 12),
          PopupMenuButton<String>(
            offset: const Offset(-318, 54),
            onOpened: _fetchUnreadNotifications,
            constraints: const BoxConstraints(maxWidth: 360, minWidth: 360),
            color: Colors.white,
            elevation: 12,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: OrgColors.border, width: 0.5),
            ),
            padding: EdgeInsets.zero,
            tooltip: '',
            itemBuilder: (ctx) => [
              PopupMenuItem<String>(
                enabled: false,
                padding: EdgeInsets.zero,
                height: 0,
                child: _OrgNotificationPanel(
                  notifications: List.from(_notifications),
                  onMarkRead: _markNotificationAsRead,
                  onMarkAllRead: _markAllNotificationsAsRead,
                ),
              ),
            ],
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _unreadNotifications > 0
                        ? OrgColors.primaryDark.withAlpha(12)
                        : OrgColors.lightGray,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _unreadNotifications > 0
                          ? OrgColors.primaryDark.withAlpha(60)
                          : OrgColors.border,
                    ),
                  ),
                  child: Icon(
                    _unreadNotifications > 0
                        ? Icons.notifications_rounded
                        : Icons.notifications_none_rounded,
                    color: _unreadNotifications > 0 ? OrgColors.primaryDark : OrgColors.darkGray,
                    size: 18,
                  ),
                ),
                if (_unreadNotifications > 0)
                  Positioned(
                    right: -3,
                    top: -3,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: OrgColors.error,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadNotifications > 9 ? '9+' : '$_unreadNotifications',
                        style: GoogleFonts.beVietnamPro(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (screenWidth >= 480) ...[
            Container(width: 1, height: 28, color: OrgColors.border),
            const SizedBox(width: 10),
          ],
          if (screenWidth >= 480)
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: OrgColors.primaryDark.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: OrgColors.primaryDark.withAlpha(50)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _orgLogoUrl != null
                      ? Image.network(
                          _orgLogoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _orgShortName.isNotEmpty ? _orgShortName[0].toUpperCase() : 'O',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: OrgColors.primaryDark,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _orgShortName.isNotEmpty ? _orgShortName[0].toUpperCase() : 'O',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: OrgColors.primaryDark,
                            ),
                          ),
                        ),
                ),
                if (screenWidth >= 600) ...[
                  const SizedBox(width: 10),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _orgShortName,
                        style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: OrgColors.charcoal,
                        ),
                      ),
                      Text(
                        'Organization',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 10,
                          color: OrgColors.textFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: OrgColors.primaryDark.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  _orgShortName.isNotEmpty
                      ? _orgShortName[0].toUpperCase()
                      : 'O',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OrgColors.primaryDark,
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
// Org Dashboard Home (with countdown – no timer updates here)
// ─────────────────────────────────────────────────────────────────────────────
class _OrgDashboardHome extends StatefulWidget {
  final String orgId;
  final String orgName;
  const _OrgDashboardHome({required this.orgId, required this.orgName});

  @override
  State<_OrgDashboardHome> createState() => _OrgDashboardHomeState();
}

class _OrgDashboardHomeState extends State<_OrgDashboardHome> {
  // Existing variables
  String _selectedSemester = '';
  String _selectedMonth = '';
  List<int> _chartData = List.filled(12, 0);
  bool _chartLoading = true;
  int? _hoveredChartIndex;

  // Countdown – only store the event data, no timer here!
  DateTime? _eventDate;
  String _eventLabel = '';
  bool _eventLoaded = false;

  // Existing streams
  late final Stream<QuerySnapshot> _approvedEventsStream;
  late final Stream<QuerySnapshot> _pendingProposalsStream;
  late final Stream<QuerySnapshot> _membersStream;
  late final Stream<QuerySnapshot> _upcomingEventsStream;
  StreamSubscription<QuerySnapshot>? _chartDataSubscription;

  int get _ayFirstYear {
    final parts = _selectedSemester.split(' ').last.split('-');
    return int.tryParse(parts.first) ?? DateTime.now().year;
  }

  String _getCurrentAY() {
    final now = DateTime.now();
    if (now.month >= 7) return 'AY ${now.year}-${now.year + 1}';
    return 'AY ${now.year - 1}-${now.year}';
  }

  List<String> get _semesterOptions {
    final y = _ayFirstYear;
    return ['AY ${y - 1}-$y', 'AY $y-${y + 1}', 'AY ${y + 1}-${y + 2}'];
  }

  String _monthLabel(int index) {
    const m = ['JUL','AUG','SEP','OCT','NOV','DEC','JAN','FEB','MAR','APR','MAY','JUN'];
    return m[index];
  }

  @override
  void initState() {
    super.initState();
    _selectedSemester = _getCurrentAY();
    final currentMonthIdx = (DateTime.now().month - 7 + 12) % 12;
    _selectedMonth = _monthLabel(currentMonthIdx);
    final now = DateTime.now();

    _approvedEventsStream = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('orgId', isEqualTo: widget.orgId)
        .where('status', isEqualTo: 'approved')
        .snapshots();

    _pendingProposalsStream = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('orgId', isEqualTo: widget.orgId)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    _membersStream = FirebaseFirestore.instance
        .collection('users')
        .where('orgId', isEqualTo: widget.orgId)
        .where('role', isEqualTo: 'org')
        .snapshots();

    _upcomingEventsStream = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('orgId', isEqualTo: widget.orgId)
        .where('status', isEqualTo: 'approved')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
        .orderBy('date')
        .snapshots();

    _setupChartListener();

    // Load the next event for countdown (no timer inside)
    _loadEventDate();
  }

  @override
  void dispose() {
    _chartDataSubscription?.cancel();
    super.dispose();
  }

  // Load event date – only sets state, no timer
  Future<void> _loadEventDate() async {
    try {
      final now = DateTime.now();
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('orgId', isEqualTo: widget.orgId)
          .where('status', isEqualTo: 'approved')
          .get();

      DateTime? nextDate;
      String nextLabel = '';
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        if (ts == null) continue;
        final date = ts.toDate();
        if (date.isBefore(now)) continue;
        if (nextDate == null || date.isBefore(nextDate)) {
          nextDate = date;
          nextLabel = data['title']?.toString() ?? 'Upcoming Event';
        }
      }

      if (nextDate != null) {
        setState(() {
          _eventDate = nextDate;
          _eventLabel = nextLabel;
          _eventLoaded = true;
        });
      } else {
        setState(() => _eventLoaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _eventLoaded = true);
    }
  }

  // Chart helper methods
  void _updateHoveredChartIndex(Offset localPosition, Size size) {
    const lp = 44.0, rp = 16.0, tp = 24.0, bp = 28.0;
    final cw = size.width - lp - rp;
    final ch = size.height - tp - bp;
    if (_chartData.isEmpty) return;

    double maxVal = _chartData.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxVal == 0) maxVal = 5;

    int? nearestIndex;
    double nearestDistance = double.infinity;
    for (var i = 0; i < _chartData.length; i++) {
      final point = Offset(
        lp + (i / (_chartData.length - 1)) * cw,
        tp + ch - (_chartData[i] / maxVal) * ch,
      );
      final distance = (localPosition - point).distance;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    final newIndex = (nearestIndex != null && nearestDistance <= 24)
        ? nearestIndex
        : null;
    if (_hoveredChartIndex != newIndex && mounted) {
      setState(() => _hoveredChartIndex = newIndex);
    }
  }

  void _clearHoveredChartIndex() {
    if (_hoveredChartIndex != null && mounted) {
      setState(() => _hoveredChartIndex = null);
    }
  }

  List<Offset> _calculateChartPoints(Size size) {
    const lp = 44.0, rp = 16.0, tp = 24.0, bp = 28.0;
    final cw = size.width - lp - rp;
    final ch = size.height - tp - bp;
    if (_chartData.isEmpty) return [];
    double maxVal = _chartData.reduce((a, b) => a > b ? a : b).toDouble();
    if (maxVal == 0) maxVal = 5;
    return List.generate(_chartData.length, (i) => Offset(
      lp + (i / (_chartData.length - 1)) * cw,
      tp + ch - (_chartData[i] / maxVal) * ch,
    ));
  }

  void _setupChartListener() {
    _chartDataSubscription?.cancel();
    setState(() => _chartLoading = true);
    final y = _ayFirstYear;
    final startDate = DateTime(y, 7, 1);
    final endDate = DateTime(y + 1, 7, 1);

    var query = FirebaseFirestore.instance
        .collection('event_proposals')
        .where('orgId', isEqualTo: widget.orgId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('date', isLessThan: Timestamp.fromDate(endDate));

    _chartDataSubscription = query.snapshots().listen(
      (snap) {
        final counts = List.filled(12, 0);
        for (final doc in snap.docs) {
          final ts = doc.data()['date'] as Timestamp?;
          if (ts == null) continue;
          final idx = (ts.toDate().month - 7 + 12) % 12;
          counts[idx]++;
        }
        if (mounted) {
          setState(() {
            _chartData = counts;
            _chartLoading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _chartLoading = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeHeader(),
          const SizedBox(height: 20),
          _buildStatCards(),
          const SizedBox(height: 20),
          _buildChartCard(),
          const SizedBox(height: 20),
          // Countdown card – now stateful, doesn't cause parent rebuild
          if (_eventLoaded && _eventDate != null)
            _CountdownCard(
              eventDate: _eventDate!,
              eventLabel: _eventLabel,
            ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildUpcomingEvents()),
              const SizedBox(width: 16),
              Expanded(child: _buildRecentProposals()),
              const SizedBox(width: 16),
              Expanded(child: _buildRecentActivity()),
            ],
          ),
        ],
      ),
    );
  }

  // ── Welcome header ────────────────────────────────────────────────
  Widget _buildWelcomeHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: OrgColors.primaryDark,
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
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
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.orgName,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Organization Dashboard  •  Welcome back.',
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
                      border: Border.all(color: Colors.white.withAlpha(35)),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
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

  // ── Stat cards ────────────────────────────────────────────────────
  Widget _buildStatCards() {
    Widget streamCard({
      required String label,
      required IconData icon,
      required Color color,
      required Stream<QuerySnapshot> stream,
    }) {
      return StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (_, snap) {
          final loading = snap.connectionState == ConnectionState.waiting;
          final count = snap.hasData ? snap.data!.docs.length : 0;
          return _StatCardWidget(
            label: label,
            icon: icon,
            color: color,
            count: count,
            loading: loading,
          );
        },
      );
    }

    return Row(
      children: [
        Expanded(
          child: streamCard(
            label: 'Active Events',
            icon: Icons.event_rounded,
            color: OrgColors.info,
            stream: _approvedEventsStream,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: streamCard(
            label: 'Pending Proposals',
            icon: Icons.pending_actions_rounded,
            color: OrgColors.warning,
            stream: _pendingProposalsStream,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: streamCard(
            label: 'Members',
            icon: Icons.people_rounded,
            color: OrgColors.success,
            stream: _membersStream,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: streamCard(
            label: 'Upcoming Events',
            icon: Icons.upcoming_rounded,
            color: OrgColors.primaryDark,
            stream: _upcomingEventsStream,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(child: _MerchSalesStatCard(orgId: widget.orgId)),
      ],
    );
  }

  // ── Chart card ────────────────────────────────────────────────────
  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: OrgColors.border),
        boxShadow: _DS.cardShadow,
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
                    'Proposals Activity Overview',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: OrgColors.accent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Event proposals per month this semester (real-time)',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: OrgColors.textFaint,
                    ),
                  ),
                ],
              ),
              Container(
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: OrgColors.borderSoft),
                  borderRadius: BorderRadius.circular(_DS.radiusSm),
                  color: OrgColors.lightGray,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _semesterOptions.contains(_selectedSemester)
                        ? _selectedSemester
                        : _semesterOptions[1],
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: OrgColors.textMid,
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: OrgColors.textFaint,
                    ),
                    items: _semesterOptions
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _selectedSemester = v;
                          _setupChartListener();
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Chart
          SizedBox(
            height: 230,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                final chartSize = Size(constraints.maxWidth, constraints.maxHeight);
                final points = _calculateChartPoints(chartSize);
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  onHover: (e) => _updateHoveredChartIndex(e.localPosition, chartSize),
                  onExit: (_) => _clearHoveredChartIndex(),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (d) => _updateHoveredChartIndex(d.localPosition, chartSize),
                    child: Stack(
                      children: [
                        _chartLoading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: OrgColors.primaryDark,
                                  strokeWidth: 2,
                                ),
                              )
                            : CustomPaint(
                                painter: _LineChartPainter(
                                  data: _chartData.map((e) => e.toDouble()).toList(),
                                  months: List.generate(12, _monthLabel),
                                  selectedMonth: _selectedMonth,
                                  hoveredIndex: _hoveredChartIndex,
                                ),
                                size: Size.infinite,
                              ),
                        if (!_chartLoading &&
                            _hoveredChartIndex != null &&
                            _hoveredChartIndex! < points.length)
                          Positioned(
                            left: (points[_hoveredChartIndex!].dx - 80).clamp(0.0, chartSize.width - 160),
                            top: (points[_hoveredChartIndex!].dy - 72).clamp(10.0, chartSize.height - 90),
                            child: Container(
                              width: 160,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(20),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                                border: Border.all(color: OrgColors.border),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    List.generate(12, _monthLabel)[_hoveredChartIndex!],
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: OrgColors.primaryDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_chartData[_hoveredChartIndex!]} proposal(s)',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 11,
                                      color: OrgColors.darkGray,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Tap a dot for details',
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 10,
                                      color: OrgColors.textFaint,
                                    ),
                                  ),
                                ],
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
        ],
      ),
    );
  }

  // ── Upcoming events ───────────────────────────────────────────────
  Widget _buildUpcomingEvents() {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: OrgColors.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('event_proposals')
              .where('orgId', isEqualTo: widget.orgId)
              .where('status', isEqualTo: 'approved')
              .where(
                'date',
                isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime.now()),
              )
              .orderBy('date')
              .limit(4)
              .snapshots(),
          builder: (_, snap) {
            final showViewAll = snap.hasData && snap.data!.docs.length >= 4;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Upcoming Events',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OrgColors.accent,
                      ),
                    ),
                    if (showViewAll)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: OrgColors.primaryDark.withAlpha(20),
                          borderRadius: BorderRadius.circular(_DS.radiusPill),
                        ),
                        child: Text(
                          'View All',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: OrgColors.primaryDark,
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
                      child: CircularProgressIndicator(
                        color: OrgColors.primaryDark,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (!snap.hasData || snap.data!.docs.isEmpty)
                  _emptyPlaceholder(
                    Icons.calendar_today_outlined,
                    'No upcoming events',
                  )
                else
                  Column(
                    children: snap.data!.docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return _EventRow(
                        date: d['date'] is Timestamp
                            ? (d['date'] as Timestamp).toDate().toIso8601String()
                            : d['date'],
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

  // ── Recent activity ───────────────────────────────────────────────
  Widget _buildRecentActivity() {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: OrgColors.border),
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
                color: OrgColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('activity_logs')
                  .where('orgId', isEqualTo: widget.orgId)
                  .orderBy('timestamp', descending: true)
                  .limit(6)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: OrgColors.primaryDark,
                        strokeWidth: 2,
                      ),
                    ),
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

  Widget _buildRecentProposals() {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: OrgColors.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('event_proposals')
              .where('orgId', isEqualTo: widget.orgId)
              .snapshots(),
          builder: (_, snap) {
            final showViewAll = snap.hasData && snap.data!.docs.length > 5;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Proposals',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: OrgColors.accent,
                      ),
                    ),
                    if (showViewAll)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: OrgColors.primaryDark.withAlpha(20),
                          borderRadius: BorderRadius.circular(_DS.radiusPill),
                        ),
                        child: Text(
                          'View All',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: OrgColors.primaryDark,
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
                      child: CircularProgressIndicator(
                        color: OrgColors.primaryDark,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (!snap.hasData || snap.data!.docs.isEmpty)
                  _emptyPlaceholder(
                    Icons.description_rounded,
                    'No proposals yet',
                  )
                else ...[
                  ...((snap.data!.docs.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return {
                      'title': d['title'] ?? 'Untitled',
                      'status': d['status'] ?? 'pending',
                      'submittedAt': d['submittedAt'] as Timestamp?,
                    };
                  }).toList()
                    ..sort((a, b) {
                      final ta = a['submittedAt'] as Timestamp?;
                      final tb = b['submittedAt'] as Timestamp?;
                      if (ta == null && tb == null) return 0;
                      if (ta == null) return 1;
                      if (tb == null) return -1;
                      return tb.compareTo(ta);
                    }))
                    .take(5)
                    .map((proposal) => _ProposalRow(
                          title: proposal['title'] as String,
                          status: proposal['status'] as String,
                          submittedAt: proposal['submittedAt'] as Timestamp?,
                        ))),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopMerchandise() {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: OrgColors.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Top Merchandise',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OrgColors.accent,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: OrgColors.primaryDark.withAlpha(20),
                    borderRadius: BorderRadius.circular(_DS.radiusPill),
                  ),
                  child: Text(
                    'View All',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: OrgColors.primaryDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('products')
                  .where('orgId', isEqualTo: widget.orgId)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(
                        color: OrgColors.primaryDark,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }
                if (!snap.hasData || snap.data!.docs.isEmpty) {
                  return _emptyPlaceholder(
                    Icons.shopping_bag_rounded,
                    'No merchandise yet',
                  );
                }
                final products =
                    snap.data!.docs.map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      return {
                        'name': d['name'] ?? 'Unnamed',
                        'sold': (d['sold'] as num?)?.toInt() ?? 0,
                        'price': (d['price'] as num?)?.toDouble() ?? 0.0,
                      };
                    }).toList()..sort(
                      (a, b) => (b['sold'] as int).compareTo(a['sold'] as int),
                    );
                return Column(
                  children: products.take(5).map((product) {
                    return _MerchRow(
                      name: product['name'] as String,
                      sold: product['sold'] as int,
                      price: product['price'] as double,
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
              child: Icon(icon, size: 26, color: OrgColors.textFaint),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: OrgColors.textFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stat card widget ────────────────────────────────────────────────────────
class _StatCardWidget extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final int count;
  final bool loading;

  const _StatCardWidget({
    required this.label,
    required this.icon,
    required this.color,
    required this.count,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: OrgColors.border),
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
                    color: OrgColors.charcoal,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11,
              color: OrgColors.darkGray,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Merch sales card (FutureBuilder) ────────────────────────────────────────
class _MerchSalesStatCard extends StatelessWidget {
  final String orgId;
  const _MerchSalesStatCard({required this.orgId});

  Future<String> _sales() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products')
          .where('orgId', isEqualTo: orgId)
          .get();
      double sum = 0;
      for (final d in snap.docs) {
        final data = d.data();
        sum +=
            ((data['price'] as num?)?.toDouble() ?? 0) *
            ((data['sold'] as num?)?.toDouble() ?? 0);
      }
      return '\u20B1${sum.toStringAsFixed(0)}';
    } catch (_) {
      return '\u20B10';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _sales(),
      builder: (_, snap) {
        final loading = snap.connectionState == ConnectionState.waiting;
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(_DS.radiusMd),
            border: Border.all(color: OrgColors.border),
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
                      color: OrgColors.primaryDark.withAlpha(26),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shopping_cart_rounded,
                      color: OrgColors.primaryDark,
                      size: 20,
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: OrgColors.primaryDark,
                      ),
                    )
                  else
                    Text(
                      snap.data ?? '\u20B10',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: OrgColors.charcoal,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Merch Sales',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  color: OrgColors.darkGray,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Line chart painter ──────────────────────────────────────────────────────
class _LineChartPainter extends CustomPainter {
  final List<double> data;
  final List<String> months;
  final String selectedMonth;
  final int? hoveredIndex;

  const _LineChartPainter({
    required this.data,
    required this.months,
    required this.selectedMonth,
    this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const lp = 44.0, rp = 16.0, tp = 24.0, bp = 28.0;
    final cw = size.width - lp - rp;
    final ch = size.height - tp - bp;

    double maxVal = data.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) maxVal = 5;

    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;
    for (int i = 0; i <= 4; i++) {
      final y = tp + (i / 4) * ch;
      canvas.drawLine(Offset(lp, y), Offset(lp + cw, y), gridPaint);
      final val = (maxVal * (1 - i / 4)).toInt();
      _drawText(
        canvas,
        '$val',
        Offset(lp - 8, y - 6),
        fontSize: 10,
        color: OrgColors.textFaint,
        align: TextAlign.right,
      );
    }

    final points = <Offset>[];
    for (int i = 0; i < data.length; i++) {
      points.add(
        Offset(
          lp + (i / (data.length - 1)) * cw,
          tp + ch - (data[i] / maxVal) * ch,
        ),
      );
    }

    // Area fill
    final areaPath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final c1 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final c2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            OrgColors.primaryDark.withAlpha(71),
            OrgColors.primaryDark.withAlpha(5),
          ],
        ).createShader(Rect.fromLTWH(0, tp, size.width, ch)),
    );

    // Line
    final linePath = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final c1 = Offset(
        (points[i - 1].dx + points[i].dx) / 2,
        points[i - 1].dy,
      );
      final c2 = Offset((points[i - 1].dx + points[i].dx) / 2, points[i].dy);
      linePath.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, points[i].dx, points[i].dy);
    }
    canvas.drawPath(
      linePath,
      Paint()
        ..color = OrgColors.primaryDark
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Data points
    for (int i = 0; i < points.length; i++) {
      final isSelected = months[i] == selectedMonth;
      final isHovered = hoveredIndex == i;
      if (isSelected || isHovered) {
        canvas.drawLine(
          Offset(points[i].dx, points[i].dy),
          Offset(points[i].dx, tp + ch),
          Paint()
            ..color = OrgColors.primaryDark.withAlpha(40)
            ..strokeWidth = 1.5,
        );
        canvas.drawCircle(
          points[i],
          10,
          Paint()..color = OrgColors.primaryDark.withAlpha(30),
        );
      }
      canvas.drawCircle(
        points[i],
        isSelected || isHovered ? 6 : 4,
        Paint()..color = OrgColors.white,
      );
      canvas.drawCircle(
        points[i],
        isSelected || isHovered ? 6 : 4,
        Paint()
          ..color = isSelected || isHovered ? OrgColors.accent : OrgColors.primaryDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (isSelected || isHovered) {
        _drawText(
          canvas,
          '${data[i].toInt()}',
          Offset(points[i].dx, points[i].dy - 18),
          fontSize: 12,
          color: OrgColors.primaryDark,
          fontWeight: FontWeight.bold,
        );
      }
      _drawText(
        canvas,
        months[i],
        Offset(points[i].dx, size.height - 16),
        fontSize: 11,
        color: isSelected || isHovered ? OrgColors.primaryDark : OrgColors.textFaint,
        fontWeight: isSelected || isHovered ? FontWeight.bold : FontWeight.normal,
      );
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    double fontSize = 12,
    Color color = const Color(0xFF64748B),
    FontWeight fontWeight = FontWeight.normal,
    TextAlign align = TextAlign.center,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.beVietnamPro(
          fontSize: fontSize,
          color: color,
          fontWeight: fontWeight,
        ),
      ),
      textAlign: align,
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(position.dx - tp.width / 2, position.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.data != data ||
      old.selectedMonth != selectedMonth ||
      old.hoveredIndex != hoveredIndex;
}

// ── Event row ──────────────────────────────────────────────────────────────
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
              color: OrgColors.primaryDark.withAlpha(20),
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
                    color: OrgColors.primaryDark,
                  ),
                ),
                Text(
                  d.day,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: OrgColors.primaryDark,
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
                    color: OrgColors.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 11,
                      color: OrgColors.textFaint,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        location ?? 'TBA',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          color: OrgColors.textFaint,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: OrgColors.textFaint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      time ?? 'TBA',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: OrgColors.textFaint,
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

// ── Activity row ────────────────────────────────────────────────────────────
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
    if (l.contains('proposal') || l.contains('pending')) {
      return OrgColors.warning;
    }
    if (l.contains('verified') || l.contains('created')) {
      return OrgColors.success;
    }
    if (l.contains('deleted') || l.contains('error')) {
      return OrgColors.error;
    }
    return OrgColors.primaryDark;
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
                    color: OrgColors.charcoal,
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
                        color: OrgColors.darkGray,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Text(
                  _timeAgo(),
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    color: OrgColors.textFaint,
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

class _ProposalRow extends StatelessWidget {
  final String title;
  final String status;
  final Timestamp? submittedAt;
  const _ProposalRow({
    required this.title,
    required this.status,
    this.submittedAt,
  });

  String _formatDate() {
    if (submittedAt == null) return 'No date';
    return DateFormat('MMM dd, yyyy').format(submittedAt!.toDate());
  }

  Color _statusColor() {
    final lower = status.toLowerCase();
    if (lower.contains('approved')) return OrgColors.success;
    if (lower.contains('rejected')) return OrgColors.error;
    if (lower.contains('pending')) return OrgColors.warning;
    return OrgColors.primaryDark;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OrgColors.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatDate(),
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: OrgColors.textFaint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor().withAlpha(31),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        status.toUpperCase(),
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 10,
                          color: _statusColor(),
                          fontWeight: FontWeight.w700,
                        ),
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
// Org Notification Panel
// ─────────────────────────────────────────────────────────────────────────────
class _OrgNotificationPanel extends StatefulWidget {
  final List<Map<String, dynamic>> notifications;
  final Future<void> Function(String id) onMarkRead;
  final Future<void> Function() onMarkAllRead;

  const _OrgNotificationPanel({
    required this.notifications,
    required this.onMarkRead,
    required this.onMarkAllRead,
  });

  @override
  State<_OrgNotificationPanel> createState() => _OrgNotificationPanelState();
}

class _OrgNotificationPanelState extends State<_OrgNotificationPanel> {
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
        _notifs[idx] = Map<String, dynamic>.from(_notifs[idx])..['isRead'] = true;
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
      cursor: isRead ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isRead ? null : () => _markRead(n['id'] as String),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isRead ? Colors.white : const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isRead
                  ? OrgColors.border
                  : OrgColors.primaryLight.withAlpha(100),
            ),
            boxShadow: isRead
                ? []
                : [
                    BoxShadow(
                      color: OrgColors.primaryDark.withAlpha(8),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isRead
                      ? OrgColors.lightGray
                      : OrgColors.primaryDark.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: OrgColors.primaryDark.withAlpha(isRead ? 15 : 30),
                  ),
                ),
                child: Icon(
                  isRead
                      ? Icons.notifications_outlined
                      : Icons.notifications_active_rounded,
                  size: 17,
                  color: isRead ? OrgColors.textFaint : OrgColors.primaryDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!isRead)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6, top: 1),
                            decoration: const BoxDecoration(
                              color: OrgColors.primaryDark,
                              shape: BoxShape.circle,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            n['title']?.toString() ?? 'Notification',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12.5,
                              fontWeight:
                                  isRead ? FontWeight.w500 : FontWeight.w700,
                              color: isRead
                                  ? OrgColors.darkGray
                                  : OrgColors.charcoal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_timeAgo(n['timestamp']).isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isRead
                                  ? const Color(0xFFF1F5F9)
                                  : OrgColors.primaryDark.withAlpha(15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _timeAgo(n['timestamp']),
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 9,
                                color: isRead
                                    ? OrgColors.textFaint
                                    : OrgColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      n['message']?.toString() ?? '',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11.5,
                        color: isRead ? OrgColors.textFaint : OrgColors.darkGray,
                        height: 1.5,
                      ),
                      maxLines: 2,
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
      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Text(
          groupKey,
          style: GoogleFonts.beVietnamPro(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF9AA5B4),
            letterSpacing: 0.8,
          ),
        ),
      ));
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: OrgColors.primaryDark,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.notifications_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Notifications',
                  style: GoogleFonts.beVietnamPro(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(40),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withAlpha(60)),
                    ),
                    child: Text(
                      '$unreadCount new',
                      style: GoogleFonts.beVietnamPro(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (unreadCount > 0)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _markAll,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Mark all read',
                          style: GoogleFonts.beVietnamPro(
                            color: Colors.white.withAlpha(220),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                      color: OrgColors.lightGray,
                      shape: BoxShape.circle,
                      border: Border.all(color: OrgColors.border),
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
                      color: OrgColors.textMid,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "You're all caught up!",
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: OrgColors.textFaint,
                    ),
                  ),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildGroupedItems(),
                ),
              ),
            ),
          // Footer
          Container(height: 1, color: const Color(0xFFF1F5F9)),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFC),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Text(
              _notifs.isEmpty
                  ? 'No notifications'
                  : '$unreadCount unread • ${_notifs.length} total',
              style: GoogleFonts.beVietnamPro(
                fontSize: 10,
                color: OrgColors.textFaint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _MerchRow extends StatelessWidget {
  final String name;
  final int sold;
  final double price;
  const _MerchRow({
    required this.name,
    required this.sold,
    required this.price,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OrgColors.charcoal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Sold: $sold',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: OrgColors.textFaint,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '\u20B1${price.toStringAsFixed(0)}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: OrgColors.textFaint,
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