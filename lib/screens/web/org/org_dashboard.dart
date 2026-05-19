// lib/screens/web/org/org_dashboard.dart
//
// KEY FIXES vs previous version:
//  1. `const OrgDashboard({super.key})` → `OrgDashboard({super.key})`
//     StatefulWidgets with non-trivial initState cannot be const.
//     The "Const class cannot remove fields" hot-reload error is gone.
//  2. _buildMenuAndScreens() is called only inside setState() after the
//     Firestore data arrives, so _screens is never accessed before it is set.
//  3. All other logic is identical to the original.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
import 'adviser_approvals.dart';
import 'adviser_signing.dart';

// ============================================================
// COLOR SCHEME
// ============================================================
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
}

// ============================================================
// MAIN DASHBOARD
// ============================================================

// ✅ FIX: NOT const — StatefulWidget with initState logic cannot be const.
//   Before:  const OrgDashboard({super.key});
//   After:          OrgDashboard({super.key});
class OrgDashboard extends StatefulWidget {
  OrgDashboard({super.key}); // <-- const removed

  @override
  State<OrgDashboard> createState() => _OrgDashboardState();
}

class _OrgDashboardState extends State<OrgDashboard> {
  int     _selectedIndex  = 0;
  // Settings is appended as the LAST screen in _screens after _buildMenuAndScreens.
  // _settingsIndex is set there so we always know which index it is.
  int     _settingsIndex  = -1;
  String  _orgId          = '';
  String  _orgName        = '';
  String  _orgShortName   = '';
  String  _orgEmail       = '';
  String  _orgRole        = 'officer'; // 'officer' | 'adviser'
  bool    _isLoading      = true;
  String? _loadError;

  final TextEditingController _searchController = TextEditingController();
  String _globalSearchQuery = '';

  List<Map<String, dynamic>> _menuItems = [];
  List<Widget>               _screens   = [];

  @override
  void initState() {
    super.initState();
    _loadOrgData();
    _searchController.addListener(
      () => setState(() => _globalSearchQuery = _searchController.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Load org data ─────────────────────────────────────────
  Future<void> _loadOrgData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _loadError = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return; // AuthGate will redirect

      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        if (mounted) setState(() => _loadError = 'User record not found. Please sign in again.');
        return;
      }

      final userData = userDoc.data()!;
      final orgId    = userData['orgId']  as String?;
      final orgRole  = (userData['orgRole'] as String?)?.toLowerCase() ?? 'officer';

      if (orgId == null || orgId.isEmpty) {
        if (mounted) setState(() => _loadError =
            'This account is not linked to an organization.\nContact your administrator.');
        return;
      }

      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations').doc(orgId).get();

      if (!orgDoc.exists) {
        if (mounted) setState(() =>
            _loadError = 'Organization data not found. Contact your administrator.');
        return;
      }

      final orgData = orgDoc.data()!;
      if (mounted) {
        setState(() {
          _orgId        = orgId;
          _orgRole      = orgRole;
          _orgName      = orgData['name']      as String? ?? 'Organization';
          _orgShortName = orgData['shortName'] as String? ?? 'ORG';
          _orgEmail     = orgData['email']     as String? ?? '';
          _buildMenuAndScreens();
          _isLoading    = false;
        });
      }
    } catch (e, st) {
      debugPrint('OrgDashboard load error: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = 'Unable to load dashboard.\nPlease refresh or sign in again.';
          _isLoading = false;
        });
      }
    }
  }

  // ── Build navigation items & screens by role ──────────────
  void _buildMenuAndScreens() {
    final officerItems = [
      _item(Icons.dashboard_outlined,              'Dashboard',
            DashboardHome(orgId: _orgId, orgName: _orgName, orgRole: _orgRole, searchQuery: _globalSearchQuery)),
      _item(Icons.description_outlined,            'Event Proposals',
            OrgEventProposalsScreen(orgId: _orgId)),
      _item(Icons.calendar_month_outlined,         'Events & Schedules',
            OrgEventsScheduleScreen(orgId: _orgId)),
      _item(Icons.qr_code_scanner_outlined,        'Attendance & QR',
            OrgAttendanceQRScreen(orgId: _orgId)),
      _item(Icons.card_membership_outlined,        'Certificates',
            OrgCertificatesScreen(orgId: _orgId)),
      _item(Icons.bar_chart_outlined,              'Event Analytics',
            OrgEventAnalyticsScreen(orgId: _orgId)),
      _item(Icons.campaign_outlined,               'Announcements',
            OrgAnnouncementsScreen(orgId: _orgId)),
      _item(Icons.wifi_tethering_outlined,         'Broadcast',
            OrgBroadcastScreen(orgId: _orgId)),
      _item(Icons.people_outline,                  'Org Profile',
            OrgProfileScreen(orgId: _orgId, orgName: _orgName, orgShortName: _orgShortName, orgEmail: _orgEmail)),
      _item(Icons.mail_outline,                    'Letter Request',
            OrgLetterRequestScreen(orgId: _orgId)),
      _item(Icons.summarize_outlined,              'Reports',
            OrgReportsScreen(orgId: _orgId)),
      _item(Icons.account_balance_wallet_outlined, 'Finance',
            OrgFinanceScreen(orgId: _orgId)),
      _item(Icons.shopping_bag_outlined,           'Merchandise',
            OrgMerchandiseScreen(orgId: _orgId)),
    ];

    final adviserItems = [
      _item(Icons.dashboard_outlined,             'Dashboard',
            DashboardHome(orgId: _orgId, orgName: _orgName, orgRole: _orgRole, searchQuery: _globalSearchQuery)),
      _item(Icons.pending_actions_outlined,        'Pending Approvals',
            AdviserApprovalsScreen(orgId: _orgId)),
      _item(Icons.calendar_month_outlined,         'Events & Schedules',
            OrgEventsScheduleScreen(orgId: _orgId)),
      _item(Icons.assignment_turned_in_outlined,   'Sign Documents',
            AdviserSigningScreen(orgId: _orgId)),
      _item(Icons.people_outline,                  'Org Profile',
            OrgProfileScreen(orgId: _orgId, orgName: _orgName, orgShortName: _orgShortName, orgEmail: _orgEmail)),
      _item(Icons.summarize_outlined,              'Reports',
            OrgReportsScreen(orgId: _orgId)),
    ];

    final raw = _orgRole == 'adviser' ? adviserItems : officerItems;
    _menuItems     = raw.map((e) => {'icon': e['icon'], 'label': e['label']}).toList();
    _screens       = raw.map((e) => e['screen'] as Widget).toList();

    // ── Append Settings as a hidden-from-nav screen ──────────
    // It doesn't appear in the sidebar list; it's activated via the
    // Settings action button at the bottom of the sidebar.
    _screens.add(OrgSettingsScreen(
      orgId:        _orgId,
      orgName:      _orgName,
      orgShortName: _orgShortName,
      orgEmail:     _orgEmail,
    ));
    _settingsIndex = _screens.length - 1;

    _selectedIndex = 0; // reset so index never goes out of range
  }

  Map<String, dynamic> _item(IconData icon, String label, Widget screen) =>
      {'icon': icon, 'label': label, 'screen': screen};

  // ── Logout ────────────────────────────────────────────────
  Future<void> _logout() async => FirebaseAuth.instance.signOut();
  // AuthGate's StreamBuilder detects signOut and rebuilds to LandingPage.

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(ctx); _logout(); },
            style: ElevatedButton.styleFrom(backgroundColor: OrgColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  // ── Settings ──────────────────────────────────────────────
  // No Navigator.push — just flip to the embedded settings screen.
  void _openSettings() => setState(() => _selectedIndex = _settingsIndex);

  // ─────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // ── Loading ───────────────────────────────────────────
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: OrgColors.lightGray,
        body: Center(child: CircularProgressIndicator(color: OrgColors.primaryDark)),
      );
    }

    // ── Error ─────────────────────────────────────────────
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: OrgColors.lightGray,
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: OrgColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: OrgColors.error),
                const SizedBox(height: 16),
                Text('Unable to load dashboard',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 18, fontWeight: FontWeight.bold, color: OrgColors.charcoal)),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loadOrgData,
                    style: ElevatedButton.styleFrom(backgroundColor: OrgColors.primaryDark),
                    child: const Text('Retry'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(onPressed: _logout, child: const Text('Sign out')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Dashboard ─────────────────────────────────────────
    final bool isSettings = _selectedIndex == _settingsIndex;

    return Scaffold(
      backgroundColor: OrgColors.lightGray,
      body: Row(
        children: [
          _Sidebar(
            selectedIndex:    _selectedIndex,
            menuItems:        _menuItems,
            orgShortName:     _orgShortName,
            orgRole:          _orgRole,
            isSettingsActive: isSettings,
            onSelect:         (i) => setState(() => _selectedIndex = i),
            onLogout:         _confirmLogout,
            onSettings:       _openSettings,
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  // Show 'Settings' when the settings screen is active;
                  // otherwise show the normal nav-item label.
                  title:            isSettings
                      ? 'Settings'
                      : _menuItems[_selectedIndex]['label'] as String,
                  searchController: _searchController,
                  orgShortName:     _orgShortName,
                  orgId:            _orgId,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _screens,
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

// ============================================================
// SIDEBAR
// ============================================================
class _Sidebar extends StatefulWidget {
  final int selectedIndex;
  final List<Map<String, dynamic>> menuItems;
  final String orgShortName;
  final String orgRole;
  final bool isSettingsActive;       // ← new
  final ValueChanged<int> onSelect;
  final VoidCallback onLogout;
  final VoidCallback onSettings;

  const _Sidebar({
    required this.selectedIndex,
    required this.menuItems,
    required this.orgShortName,
    required this.orgRole,
    required this.isSettingsActive,  // ← new
    required this.onSelect,
    required this.onLogout,
    required this.onSettings,
  });

  @override
  State<_Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<_Sidebar> {
  int? _hoverIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [OrgColors.primaryDark, OrgColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          // Logo + app name
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.school, color: Colors.white, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'UPRISE',
                  style: GoogleFonts.beVietnamPro(
                    color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold, letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.orgRole == 'adviser' ? 'Adviser Portal' : 'Officer Portal',
            style: GoogleFonts.beVietnamPro(
                color: Colors.white.withOpacity(0.65), fontSize: 11),
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: widget.menuItems.length,
              itemBuilder: (context, i) {
                final item       = widget.menuItems[i];
                final isSelected = widget.selectedIndex == i;
                final isHover    = _hoverIndex == i;
                return MouseRegion(
                  onEnter: (_) => setState(() => _hoverIndex = i),
                  onExit:  (_) => setState(() => _hoverIndex = null),
                  child: GestureDetector(
                    onTap: () => widget.onSelect(i),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.white.withOpacity(0.22)
                            : isHover
                                ? Colors.white.withOpacity(0.10)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(item['icon'] as IconData, color: Colors.white, size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: GoogleFonts.beVietnamPro(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.2)),
          // Settings button — highlights when the settings screen is active
          _SidebarAction(
            icon:     Icons.settings_outlined,
            label:    'Settings',
            onTap:    widget.onSettings,
            isActive: widget.isSettingsActive,
          ),
          _SidebarAction(icon: Icons.logout, label: 'Logout', onTap: widget.onLogout),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SidebarAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  const _SidebarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  State<_SidebarAction> createState() => _SidebarActionState();
}

class _SidebarActionState extends State<_SidebarAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit:  (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: widget.isActive
                ? Colors.white.withOpacity(0.22)
                : _hover
                    ? Colors.white.withOpacity(0.10)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(widget.icon,
                  color: widget.isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.75),
                  size: 18),
              const SizedBox(width: 12),
              Text(widget.label,
                  style: GoogleFonts.beVietnamPro(
                    color: widget.isActive
                        ? Colors.white
                        : Colors.white.withOpacity(0.75),
                    fontSize: 13,
                    fontWeight: widget.isActive
                        ? FontWeight.w600
                        : FontWeight.w400,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TOP BAR
// ============================================================
class _TopBar extends StatefulWidget {
  final String title;
  final TextEditingController searchController;
  final String orgShortName;
  final String orgId;

  const _TopBar({
    required this.title,
    required this.searchController,
    required this.orgShortName,
    required this.orgId,
  });

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late final Stream<String> _clockStream;

  @override
  void initState() {
    super.initState();
    _clockStream = Stream.periodic(
      const Duration(minutes: 1),
      (_) => _formatted(),
    );
  }

  String _formatted() =>
      DateFormat('EEE, MMM d, yyyy • h:mm a').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: OrgColors.white,
        border: Border(bottom: BorderSide(color: OrgColors.primaryLight)),
      ),
      child: Row(
        children: [
          Text(
            widget.title,
            style: GoogleFonts.beVietnamPro(
              fontSize: 20, fontWeight: FontWeight.w700, color: OrgColors.charcoal,
            ),
          ),
          const Spacer(),
          // Live clock
          StreamBuilder<String>(
            stream: _clockStream,
            initialData: _formatted(),
            builder: (_, snap) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(children: [
                const Icon(Icons.access_time, size: 14, color: OrgColors.primaryDark),
                const SizedBox(width: 6),
                Text(snap.data!,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: OrgColors.darkGray)),
              ]),
            ),
          ),
          const SizedBox(width: 16),
          // Search
          SizedBox(
            width: 240, height: 40,
            child: TextField(
              controller: widget.searchController,
              decoration: InputDecoration(
                hintText: 'Search events, proposals...',
                hintStyle: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: OrgColors.darkGray),
                prefixIcon: const Icon(Icons.search, size: 18, color: OrgColors.darkGray),
                filled: true,
                fillColor: OrgColors.lightGray,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          _NotificationBell(orgId: widget.orgId),
          const SizedBox(width: 12),
          const CircleAvatar(
            backgroundColor: OrgColors.lightGray,
            radius: 18,
            child: Icon(Icons.business, color: OrgColors.primaryDark, size: 20),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.orgShortName,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
              Text('Organization',
                  style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// NOTIFICATION BELL
// ============================================================
class _NotificationBell extends StatelessWidget {
  final String orgId;
  const _NotificationBell({required this.orgId});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.uid)
          .where('orgId', isEqualTo: orgId)
          .orderBy('createdAt', descending: true)
          .limit(30)
          .snapshots(),
      builder: (context, snapshot) {
        final docs   = snapshot.data?.docs ?? [];
        final unread = docs
            .where((d) => (d.data() as Map)['isRead'] == false)
            .length;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_none, color: OrgColors.darkGray),
              onPressed: () => _showPanel(context, docs),
            ),
            if (unread > 0)
              Positioned(
                right: 6, top: 6,
                child: Container(
                  width: 17, height: 17,
                  decoration: const BoxDecoration(
                      color: OrgColors.error, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showPanel(BuildContext context, List<QueryDocumentSnapshot> docs) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SizedBox(
        height: 460,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
              child: Row(
                children: [
                  Text('Notifications',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  if (docs.any((d) => (d.data() as Map)['isRead'] == false))
                    TextButton(
                      onPressed: () => _markAll(ctx, docs),
                      child: const Text('Mark all read'),
                    ),
                  IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: docs.isEmpty
                  ? Center(
                      child: Text('No notifications',
                          style: GoogleFonts.beVietnamPro(
                              color: OrgColors.darkGray)))
                  : ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final data   = docs[i].data() as Map<String, dynamic>;
                        final isRead = data['isRead'] == true;
                        final ts     = data['createdAt'] as Timestamp?;
                        return ListTile(
                          leading: Icon(
                            isRead
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: isRead
                                ? OrgColors.darkGray
                                : OrgColors.primaryDark,
                          ),
                          title: Text(
                            data['title'] as String? ?? 'Notification',
                            style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 13),
                          ),
                          subtitle: Text(data['body'] as String? ?? '',
                              style: const TextStyle(fontSize: 12)),
                          trailing: ts == null
                              ? null
                              : Text(
                                  DateFormat('MM/dd HH:mm').format(ts.toDate()),
                                  style: const TextStyle(
                                      fontSize: 10, color: OrgColors.darkGray)),
                          onTap: isRead ? null : () => _markOne(docs[i].id),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markOne(String id) async {
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(id)
        .update({'isRead': true});
  }

  Future<void> _markAll(
      BuildContext ctx, List<QueryDocumentSnapshot> docs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final d in docs) {
      if ((d.data() as Map)['isRead'] != true) {
        batch.update(d.reference, {'isRead': true});
      }
    }
    await batch.commit();
    if (ctx.mounted) Navigator.pop(ctx);
  }
}

// ============================================================
// DASHBOARD HOME
// ============================================================
class DashboardHome extends StatelessWidget {
  final String orgId;
  final String orgName;
  final String orgRole;
  final String searchQuery;

  const DashboardHome({
    super.key,
    required this.orgId,
    required this.orgName,
    required this.orgRole,
    required this.searchQuery,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Organization Dashboard',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: OrgColors.charcoal)),
          const SizedBox(height: 4),
          Text('Welcome back. Here is the latest status for $orgName.',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14, color: OrgColors.darkGray)),
          const SizedBox(height: 28),
          _StatsRow(orgId: orgId),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 5,
                child: Column(children: [
                  _RecentProposals(
                    orgId: orgId,
                    isAdviser: orgRole == 'adviser',
                    searchQuery: searchQuery,
                  ),
                  const SizedBox(height: 20),
                  _TopMerch(orgId: orgId),
                ]),
              ),
              const SizedBox(width: 20),
              Expanded(flex: 3, child: _ActivityTimeline(orgId: orgId)),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// STAT CARDS ROW
// ============================================================
class _StatsRow extends StatelessWidget {
  final String orgId;
  const _StatsRow({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _StatCard(
        label: 'Total Events',
        icon: Icons.event, iconColor: OrgColors.info,
        stream: FirebaseFirestore.instance.collection('events')
            .where('orgId', isEqualTo: orgId)
            .where('status', isEqualTo: 'approved')
            .snapshots(),
      )),
      const SizedBox(width: 16),
      Expanded(child: _StatCard(
        label: 'Pending Proposals',
        icon: Icons.pending_actions, iconColor: OrgColors.warning,
        stream: FirebaseFirestore.instance.collection('event_proposals')
            .where('orgId', isEqualTo: orgId)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
      )),
      const SizedBox(width: 16),
      Expanded(child: _StatCard(
        label: 'Members',
        icon: Icons.people, iconColor: OrgColors.success,
        stream: FirebaseFirestore.instance.collection('users')
            .where('orgId', isEqualTo: orgId)
            .where('role', isEqualTo: 'org')
            .snapshots(),
      )),
      const SizedBox(width: 16),
      Expanded(child: _MerchSalesCard(orgId: orgId)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        String value;
        if (snap.hasError)                                         value = '—';
        else if (snap.connectionState == ConnectionState.waiting)  value = '…';
        else                                                       value = '${snap.data!.docs.length}';
        return _card(value);
      },
    );
  }

  Widget _card(String value) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OrgColors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: OrgColors.primaryLight),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: OrgColors.darkGray)),
        Icon(icon, size: 20, color: iconColor),
      ]),
      const SizedBox(height: 10),
      Text(value,
          style: GoogleFonts.beVietnamPro(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: OrgColors.charcoal)),
    ]),
  );
}

class _MerchSalesCard extends StatelessWidget {
  final String orgId;
  const _MerchSalesCard({required this.orgId});

  Future<String> _sales() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('products').where('orgId', isEqualTo: orgId).get();
      double sum = 0;
      for (final d in snap.docs) {
        final data = d.data();
        sum += ((data['price'] as num?)?.toDouble() ?? 0) *
               ((data['sold']  as num?)?.toDouble() ?? 0);
      }
      return '₱${sum.toStringAsFixed(0)}';
    } catch (_) { return '₱0'; }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _sales(),
      builder: (_, snap) {
        final value = snap.data ?? '…';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OrgColors.primaryLight),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Merch Sales',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 12, color: OrgColors.darkGray)),
              const Icon(Icons.shopping_cart, size: 20, color: OrgColors.primaryDark),
            ]),
            const SizedBox(height: 10),
            Text(value,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: OrgColors.charcoal)),
          ]),
        );
      },
    );
  }
}

// ============================================================
// RECENT PROPOSALS
// ============================================================
class _RecentProposals extends StatelessWidget {
  final String orgId;
  final bool isAdviser;
  final String searchQuery;
  const _RecentProposals(
      {required this.orgId,
      required this.isAdviser,
      required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(children: [
            Text('Recent Proposals',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: OrgColors.charcoal)),
            const Spacer(),
          ]),
        ),
        const Divider(height: 1),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('event_proposals')
              .where('orgId', isEqualTo: orgId)
              .orderBy('submittedAt', descending: true)
              .limit(10)
              .snapshots(),
          builder: (_, snap) {
            if (snap.hasError) {
              return _empty('Failed to load. Check Firestore indexes.');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            var docs = snap.data!.docs;
            if (searchQuery.isNotEmpty) {
              docs = docs.where((d) {
                final title =
                    ((d.data() as Map)['title'] as String? ?? '').toLowerCase();
                return title.contains(searchQuery);
              }).toList();
            }
            if (docs.isEmpty) {
              return _empty(searchQuery.isEmpty
                  ? 'No proposals yet.'
                  : 'No results for "$searchQuery".');
            }
            final shown = docs.take(5).toList();
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: shown.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final data   = shown[i].data() as Map<String, dynamic>;
                final status = data['status'] as String? ?? 'pending';
                return ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: OrgColors.primaryDark),
                  title: Text(data['title'] as String? ?? 'Untitled',
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                      'Submitted: ${_fmtTs(data['submittedAt'])}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: _StatusChip(status),
                );
              },
            );
          },
        ),
      ]),
    );
  }

  Widget _empty(String msg) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
        child: Text(msg,
            style: const TextStyle(
                color: OrgColors.darkGray, fontSize: 13))),
  );

  String _fmtTs(dynamic ts) {
    if (ts == null) return 'Unknown';
    if (ts is Timestamp) return DateFormat('MMM dd, yyyy').format(ts.toDate());
    return ts.toString();
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg;
    switch (status.toLowerCase()) {
      case 'approved': bg = OrgColors.success.withOpacity(0.15); break;
      case 'rejected': bg = OrgColors.error.withOpacity(0.15);   break;
      default:         bg = OrgColors.warning.withOpacity(0.15);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: const TextStyle(fontSize: 11)),
    );
  }
}

// ============================================================
// TOP MERCH
// ============================================================
class _TopMerch extends StatelessWidget {
  final String orgId;
  const _TopMerch({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Text('Top Merchandise',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: OrgColors.charcoal)),
        ),
        const Divider(height: 1),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('products')
              .where('orgId', isEqualTo: orgId)
              .orderBy('sold', descending: true)
              .limit(3)
              .snapshots(),
          builder: (_, snap) {
            if (snap.hasError) {
              return _msg('Failed to load. Check Firestore indexes.');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) return _msg('No merchandise yet.');
            return Column(
              children: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return ListTile(
                  leading: const Icon(Icons.shopping_bag,
                      color: OrgColors.primaryDark),
                  title: Text(data['name'] as String? ?? 'Item',
                      style: const TextStyle(fontSize: 13)),
                  subtitle: Text('Sold: ${data['sold'] ?? 0}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Text('₱${data['price'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  Widget _msg(String s) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
        child:
            Text(s, style: const TextStyle(color: OrgColors.darkGray, fontSize: 13))),
  );
}

// ============================================================
// ACTIVITY TIMELINE
// ============================================================
class _ActivityTimeline extends StatelessWidget {
  final String orgId;
  const _ActivityTimeline({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(children: [
            const Icon(Icons.access_time, size: 18, color: OrgColors.primaryDark),
            const SizedBox(width: 8),
            Text('Activity Timeline',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: OrgColors.charcoal)),
          ]),
        ),
        const Divider(height: 1),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('activity_logs')
              .where('orgId', isEqualTo: orgId)
              .orderBy('timestamp', descending: true)
              .limit(8)
              .snapshots(),
          builder: (_, snap) {
            if (snap.hasError) {
              return _msg('Failed to load. Check Firestore indexes.');
            }
            if (snap.connectionState == ConnectionState.waiting) {
              return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()));
            }
            final docs = snap.data!.docs;
            if (docs.isEmpty) return _msg('No recent activity.');
            return Column(
              children: docs.map((doc) {
                final data   = doc.data() as Map<String, dynamic>;
                final action = data['action'] as String? ?? 'Activity';
                final module = data['module'] as String? ?? '';
                final ts     = data['timestamp'] as Timestamp?;
                return ListTile(
                  leading: Icon(Icons.circle, size: 10, color: _color(action)),
                  title: Text(action,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text(module,
                      style: const TextStyle(
                          fontSize: 11, color: OrgColors.darkGray)),
                  trailing: Text(_ago(ts),
                      style: const TextStyle(
                          fontSize: 10, color: OrgColors.darkGray)),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  Widget _msg(String s) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
        child:
            Text(s, style: const TextStyle(color: OrgColors.darkGray, fontSize: 13))),
  );

  Color _color(String a) {
    if (a.contains('proposal')) return OrgColors.warning;
    if (a.contains('approv'))   return OrgColors.success;
    if (a.contains('error'))    return OrgColors.error;
    return OrgColors.primaryDark;
  }

  String _ago(Timestamp? ts) {
    if (ts == null) return 'Just now';
    final d = DateTime.now().difference(ts.toDate());
    if (d.inMinutes < 1)  return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24)   return '${d.inHours}h ago';
    if (d.inDays < 7)     return '${d.inDays}d ago';
    return '${(d.inDays / 7).floor()}w ago';
  }
}

