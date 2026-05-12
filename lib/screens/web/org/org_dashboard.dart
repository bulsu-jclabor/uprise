import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Constants (matches your existing theme) ───────────────────────────
class OrgColors {
  static const primary = Color(0xFFD97706);
  static const primaryDark = Color(0xFFB45309);
  static const sidebarBg = Color(0xFFD97706);
  static const sidebarSelected = Color(0xFFB45309);
  static const white = Color(0xFFFFFFFF);
  static const lightGray = Color(0xFFF8FAFC);
  static const mediumGray = Color(0xFFE2E8F0);
  static const darkGray = Color(0xFF64748B);
  static const charcoal = Color(0xFF1E293B);
  static const slate = Color(0xFF475569);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);
  static const info = Color(0xFF3B82F6);
  static const purple = Color(0xFF8B5CF6);
}

// ─── Nav Item Model ───────────────────────────────────────────────────────────
class NavItem {
  final String label;
  final IconData icon;
  NavItem(this.label, this.icon);
}

// ─── Main Dashboard ───────────────────────────────────────────────────────────
class OrgDashboard extends StatefulWidget {
  const OrgDashboard({super.key});
  @override
  State<OrgDashboard> createState() => _OrgDashboardState();
}

class _OrgDashboardState extends State<OrgDashboard> {
  int _selectedNav = 0;
  final TextEditingController _searchCtrl = TextEditingController();

  final List<NavItem> _navItems = [
    NavItem('Dashboard', Icons.dashboard_rounded),
    NavItem('Event Proposals', Icons.description_outlined),
    NavItem('Events and Schedules', Icons.calendar_month_outlined),
    NavItem('Attendance & QR Scan', Icons.qr_code_scanner_outlined),
    NavItem('Certificates', Icons.card_membership_outlined),
    NavItem('Event Analytics', Icons.bar_chart_rounded),
    NavItem('Announcements', Icons.campaign_outlined),
    NavItem('Broadcast', Icons.wifi_tethering_rounded),
    NavItem('Organization Profile', Icons.people_outline_rounded),
    NavItem('Letter Request', Icons.mail_outline_rounded),
    NavItem('Reports', Icons.summarize_outlined),
    NavItem('Finance', Icons.account_balance_wallet_outlined),
    NavItem('Merchandise', Icons.shopping_bag_outlined),
  ];

  // Fetch org info for logged-in user
  Future<Map<String, dynamic>> _fetchOrgInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return {};
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final orgId = userDoc.data()?['orgId'] as String?;
    if (orgId == null) return {};
    final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(orgId).get();
    return {
      ...?orgDoc.data(),
      'orgId': orgId,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _fetchOrgInfo(),
      builder: (context, snapshot) {
        final orgData = snapshot.data ?? {};
        final orgId = orgData['orgId'] as String? ?? '';
        final shortName = orgData['shortName'] as String? ?? 'ORG';
        final orgName = orgData['name'] as String? ?? 'Organization';

        return Scaffold(
          backgroundColor: OrgColors.lightGray,
          body: Row(
            children: [
              // ── Sidebar ──
              _Sidebar(
                navItems: _navItems,
                selected: _selectedNav,
                onSelect: (i) => setState(() => _selectedNav = i),
                orgName: orgName,
              ),
              // ── Main Content ──
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      searchCtrl: _searchCtrl,
                      shortName: shortName,
                    ),
                    Expanded(
                      child: _selectedNav == 0
                          ? _DashboardContent(orgId: orgId, orgName: orgName)
                          : _PlaceholderContent(label: _navItems[_selectedNav].label),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Sidebar ──────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final List<NavItem> navItems;
  final int selected;
  final ValueChanged<int> onSelect;
  final String orgName;

  const _Sidebar({
    required this.navItems,
    required this.selected,
    required this.onSelect,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: OrgColors.sidebarBg,
      child: Column(
        children: [
          // Logo area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: OrgColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.school_rounded,
                        color: OrgColors.primaryDark,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'UPRISE',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: OrgColors.white,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          // Nav items
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: navItems.length,
              itemBuilder: (_, i) {
                final isSelected = i == selected;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? OrgColors.sidebarSelected
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          navItems[i].icon,
                          size: 18,
                          color: OrgColors.white,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            navItems[i].label,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12.5,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: OrgColors.white,
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
          const Divider(color: Colors.white24, height: 1),
          // Settings & Logout
          _SidebarFooterItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {},
          ),
          _SidebarFooterItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            onTap: () => FirebaseAuth.instance.signOut(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SidebarFooterItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SidebarFooterItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: OrgColors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: OrgColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final TextEditingController searchCtrl;
  final String shortName;

  const _TopBar({required this.searchCtrl, required this.shortName});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: OrgColors.white,
        border: Border(bottom: BorderSide(color: OrgColors.mediumGray)),
      ),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search events, proposals...',
                  hintStyle: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    color: OrgColors.darkGray,
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: OrgColors.darkGray,
                  ),
                  filled: true,
                  fillColor: OrgColors.lightGray,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Bell
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined,
                    color: OrgColors.charcoal),
                onPressed: () {},
              ),
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                    color: OrgColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          // User info
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                shortName,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: OrgColors.charcoal,
                ),
              ),
              Text(
                'Organization',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  color: OrgColors.darkGray,
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 18,
            backgroundColor: OrgColors.mediumGray,
            child: Icon(Icons.person, color: OrgColors.darkGray, size: 20),
          ),
        ],
      ),
    );
  }
}

// ─── Dashboard Content ────────────────────────────────────────────────────────
class _DashboardContent extends StatelessWidget {
  final String orgId;
  final String orgName;

  const _DashboardContent({required this.orgId, required this.orgName});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Organization Dashboard',
            style: GoogleFonts.beVietnamPro(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: OrgColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Welcome back. Here is the latest status for the $orgName.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: OrgColors.darkGray,
            ),
          ),
          const SizedBox(height: 20),

          // Stat cards row
          _StatsRow(orgId: orgId),
          const SizedBox(height: 20),

          // Bottom two columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _RecentProposals(orgId: orgId),
                    const SizedBox(height: 20),
                    _TopMerch(orgId: orgId),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              // Right column
              Expanded(
                flex: 3,
                child: _ActivityTimeline(orgId: orgId),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Stats Row ────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final String orgId;
  const _StatsRow({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where('organizationId', isEqualTo: orgId)
          .snapshots(),
      builder: (context, eventsSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('event_proposals')
              .where('organizationId', isEqualTo: orgId)
              .snapshots(),
          builder: (context, proposalsSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('merchandise')
                  .where('organizationId', isEqualTo: orgId)
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, merchSnap) {
                // Upcoming events
                int upcomingEvents = 0;
                int recentEventDelta = 0;
                if (eventsSnap.hasData) {
                  final now = DateTime.now();
                  final upcoming = eventsSnap.data!.docs.where((d) {
                    final data = d.data() as Map;
                    final ts = data['startDate'] as Timestamp?;
                    return ts != null && ts.toDate().isAfter(now);
                  }).toList();
                  upcomingEvents = upcoming.length;
                  // This week
                  recentEventDelta = upcoming.where((d) {
                    final data = d.data() as Map;
                    final ts = data['startDate'] as Timestamp?;
                    return ts != null &&
                        ts.toDate().isBefore(now.add(const Duration(days: 7)));
                  }).length;
                }

                // Pending proposals
                int pendingProposals = 0;
                int urgentProposals = 0;
                if (proposalsSnap.hasData) {
                  pendingProposals = proposalsSnap.data!.docs
                      .where((d) =>
                          (d.data() as Map)['status'] == 'pending')
                      .length;
                  urgentProposals = proposalsSnap.data!.docs
                      .where((d) =>
                          (d.data() as Map)['priority'] == 'urgent')
                      .length;
                }

                // Attendance avg
                double attendanceAvg = 0;
                if (eventsSnap.hasData) {
                  final docs = eventsSnap.data!.docs;
                  final withAttendance = docs.where((d) =>
                      (d.data() as Map)['attendanceRate'] != null);
                  if (withAttendance.isNotEmpty) {
                    final total = withAttendance.fold<double>(
                        0,
                        (sum, d) =>
                            sum +
                            ((d.data() as Map)['attendanceRate'] as num)
                                .toDouble());
                    attendanceAvg = total / withAttendance.length;
                  }
                }

                // Active merch
                int activeMerch = 0;
                if (merchSnap.hasData) {
                  activeMerch = merchSnap.data!.docs.length;
                }

                return Row(
                  children: [
                    _StatCard(
                      label: 'Upcoming Events',
                      value: '$upcomingEvents',
                      sub: '+$recentEventDelta this week',
                      icon: Icons.calendar_today_outlined,
                      iconColor: OrgColors.info,
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      label: 'Pending Proposals',
                      value: '$pendingProposals',
                      sub: urgentProposals > 0
                          ? '$urgentProposals urgent'
                          : 'All on track',
                      icon: Icons.description_outlined,
                      iconColor: OrgColors.error,
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      label: 'Attendance Avg',
                      value: attendanceAvg > 0
                          ? '${attendanceAvg.toStringAsFixed(0)}%'
                          : '—',
                      sub: attendanceAvg >= 80
                          ? 'High engagement'
                          : attendanceAvg > 0
                              ? 'Needs attention'
                              : 'No data yet',
                      icon: Icons.people_outline_rounded,
                      iconColor: OrgColors.success,
                    ),
                    const SizedBox(width: 16),
                    _StatCard(
                      label: 'Active Merch',
                      value: '$activeMerch',
                      sub: '$activeMerch campaigns',
                      icon: Icons.shopping_cart_outlined,
                      iconColor: OrgColors.purple,
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OrgColors.mediumGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: OrgColors.darkGray,
                  ),
                ),
                Icon(icon, size: 20, color: iconColor),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.beVietnamPro(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: OrgColors.charcoal,
                height: 1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              sub,
              style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                color: OrgColors.darkGray,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Recent Proposals ─────────────────────────────────────────────────────────
class _RecentProposals extends StatelessWidget {
  final String orgId;
  const _RecentProposals({required this.orgId});

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return OrgColors.success;
      case 'needs revision': return OrgColors.error;
      case 'awaiting review': return OrgColors.warning;
      case 'pending': return OrgColors.warning;
      case 'rejected': return OrgColors.error;
      default: return OrgColors.darkGray;
    }
  }

  String _statusLabel(String status) => status.toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.mediumGray),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Proposals',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OrgColors.charcoal,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    'View All',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: OrgColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('event_proposals')
                .where('organizationId', isEqualTo: orgId)
                .orderBy('createdAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No proposals yet',
                      style: GoogleFonts.beVietnamPro(
                        color: OrgColors.darkGray,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = data['title'] as String? ?? 'Untitled Proposal';
                  final submittedBy = data['submittedBy'] as String? ?? '';
                  final status = data['status'] as String? ?? 'pending';
                  final ts = data['createdAt'] as Timestamp?;
                  final when = ts != null
                      ? _relativeTime(ts.toDate())
                      : 'Recently';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: OrgColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: OrgColors.primary,
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
                                  fontWeight: FontWeight.w600,
                                  color: OrgColors.charcoal,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Submitted $when${submittedBy.isNotEmpty ? ' by $submittedBy' : ''}',
                                style: GoogleFonts.beVietnamPro(
                                  fontSize: 11,
                                  color: OrgColors.darkGray,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _StatusBadge(status: status),
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

  String _relativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    return '${diff.inDays} days ago';
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color _color() {
    switch (status.toLowerCase()) {
      case 'approved': return OrgColors.success;
      case 'needs revision': return OrgColors.error;
      case 'awaiting review': return OrgColors.warning;
      case 'pending': return OrgColors.warning;
      case 'rejected': return OrgColors.error;
      default: return OrgColors.darkGray;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.beVietnamPro(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ─── Top Merch ────────────────────────────────────────────────────────────────
class _TopMerch extends StatelessWidget {
  final String orgId;
  const _TopMerch({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Top Merch',
              style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: OrgColors.charcoal,
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('merchandise')
                .where('organizationId', isEqualTo: orgId)
                .orderBy('soldCount', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No merchandise yet',
                      style: GoogleFonts.beVietnamPro(
                        color: OrgColors.darkGray,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }
              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? 'Item';
                  final sold = data['soldCount'] as int? ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: OrgColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.shopping_cart_outlined,
                            size: 18,
                            color: OrgColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: OrgColors.charcoal,
                            ),
                          ),
                        ),
                        Text(
                          '$sold Sold',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: OrgColors.charcoal,
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
}

// ─── Activity Timeline ────────────────────────────────────────────────────────
class _ActivityTimeline extends StatelessWidget {
  final String orgId;
  const _ActivityTimeline({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 18, color: OrgColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Activity Timeline',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: OrgColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('activity_logs')
                .where('orgId', isEqualTo: orgId)
                .orderBy('timestamp', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'No recent activity',
                      style: GoogleFonts.beVietnamPro(
                        color: OrgColors.darkGray,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              String? lastSection;

              return Column(
                children: [
                  ...docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final title = data['action'] as String? ?? 'Activity';
                    final description = data['details']?.toString() ?? '';
                    final ts = data['timestamp'] as Timestamp?;
                    final date = ts?.toDate();
                    final section = _sectionLabel(date);
                    final isNewSection = section != lastSection;
                    lastSection = section;
                    final dotColor = _dotColor(data['severity'] as String?);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isNewSection)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              section,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: OrgColors.darkGray,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    margin: const EdgeInsets.only(top: 3),
                                    decoration: BoxDecoration(
                                      color: dotColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
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
                                        fontWeight: FontWeight.w600,
                                        color: OrgColors.charcoal,
                                      ),
                                    ),
                                    if (description.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        description,
                                        style: GoogleFonts.beVietnamPro(
                                          fontSize: 11,
                                          color: OrgColors.darkGray,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextButton(
                      onPressed: () {},
                      child: Text(
                        'Load more activities',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: OrgColors.primary,
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
    );
  }

  Color _dotColor(String? severity) {
    switch (severity) {
      case 'error': return OrgColors.error;
      case 'warning': return OrgColors.warning;
      case 'success': return OrgColors.success;
      default: return OrgColors.info;
    }
  }

  String _sectionLabel(DateTime? date) {
    if (date == null) return 'RECENTLY';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      final h = date.hour;
      final m = date.minute.toString().padLeft(2, '0');
      final ampm = h >= 12 ? 'PM' : 'AM';
      final hour = h > 12 ? h - 12 : (h == 0 ? 12 : h);
      return '$hour:$m $ampm TODAY';
    }
    if (diff.inDays == 0) return 'TODAY';
    if (diff.inDays == 1) return 'YESTERDAY';
    return '${_monthAbbr(date.month)} ${date.day}, ${date.year}';
  }

  String _monthAbbr(int m) =>
      ['JAN','FEB','MAR','APR','MAY','JUN',
       'JUL','AUG','SEP','OCT','NOV','DEC'][m - 1];
}

// ─── Placeholder for other nav items ─────────────────────────────────────────
class _PlaceholderContent extends StatelessWidget {
  final String label;
  const _PlaceholderContent({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.construction_rounded,
              size: 48, color: OrgColors.mediumGray),
          const SizedBox(height: 16),
          Text(
            label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: OrgColors.charcoal,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This module is coming soon.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              color: OrgColors.darkGray,
            ),
          ),
        ],
      ),
    );
  }
}