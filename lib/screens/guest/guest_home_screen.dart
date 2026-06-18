// lib/screens/guest/guest_home_screen.dart
//
// GUEST SHELL — Supports two modes:
//   GuestMode.visitor       → 4 tabs: Home | Announcements | Events | Calendar
//   GuestMode.authenticated → 6 tabs: adds Feedback + Digital ID
//
// The mode is passed at construction and stored in GuestAuthService.
//

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../student/student_login.dart';
import 'guest_auth_service.dart';
import 'guest_announcements_screen.dart';
import 'guest_events_screen.dart';
import 'guest_calendar_screen.dart';
import 'guest_profile_screen.dart';
import 'guest_feedback_screen.dart';
import 'guest_digital_id_screen.dart';

export 'guest_auth_service.dart' show GuestMode;

// ─────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFFFF6B00);
const _kPrimaryBg = Color(0xFFFFF3EB);

// ─────────────────────────────────────────────────────────────
//  SHELL
// ─────────────────────────────────────────────────────────────
class GuestHomeScreen extends StatefulWidget {
  final GuestMode mode;

  const GuestHomeScreen({
    super.key,
    this.mode = GuestMode.visitor,
  });

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  int _currentIndex = 0;

  // Visitor tabs (4)
  static const _visitorTabs = [
    _NavItem(Icons.home_outlined,            Icons.home_rounded,             'Home'),
    _NavItem(Icons.campaign_outlined,         Icons.campaign_rounded,          'Announcements'),
    _NavItem(Icons.calendar_today_outlined,   Icons.calendar_today_rounded,    'Events'),
    _NavItem(Icons.date_range_outlined,       Icons.date_range_rounded,        'Calendar'),
  ];

  // Authenticated tabs (6)
  static const _authTabs = [
    _NavItem(Icons.home_outlined,            Icons.home_rounded,             'Home'),
    _NavItem(Icons.campaign_outlined,         Icons.campaign_rounded,          'News'),
    _NavItem(Icons.calendar_today_outlined,   Icons.calendar_today_rounded,    'Events'),
    _NavItem(Icons.date_range_outlined,       Icons.date_range_rounded,        'Calendar'),
    _NavItem(Icons.rate_review_outlined,      Icons.rate_review_rounded,       'Feedback'),
    _NavItem(Icons.badge_outlined,            Icons.badge_rounded,             'ID'),
  ];

  List<_NavItem> get _tabs =>
      widget.mode == GuestMode.authenticated ? _authTabs : _visitorTabs;

  List<Widget> _buildScreens() {
    final isAuth = widget.mode == GuestMode.authenticated;
    return [
      _GuestHomeContent(
        mode:          widget.mode,
        onEventsTap:   () => setState(() => _currentIndex = 2),
        onNewsTap:     () => setState(() => _currentIndex = 1),
        onCalendarTap: () => setState(() => _currentIndex = 3),
        onSignInTap:   () => _showSignInPrompt(context),
      ),
      const GuestAnnouncementsScreen(),
      const GuestEventsScreen(),
      const GuestCalendarScreen(),
      if (isAuth) const GuestFeedbackScreen(),
      if (isAuth) const GuestDigitalIdScreen(),
    ];
  }

  void _showSignInPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SignInPromptSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();
    // Clamp in case mode changes
    if (_currentIndex >= screens.length) _currentIndex = 0;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: _GuestBottomNav(
        items:        _tabs,
        currentIndex: _currentIndex,
        onTap:        (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BOTTOM NAV
// ─────────────────────────────────────────────────────────────
class _GuestBottomNav extends StatelessWidget {
  final List<_NavItem>    items;
  final int               currentIndex;
  final ValueChanged<int> onTap;

  const _GuestBottomNav({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(items.length, (i) {
              final item     = items[i];
              final isActive = currentIndex == i;

              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? _kPrimary.withOpacity(0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          isActive ? item.activeIcon : item.icon,
                          color: isActive ? _kPrimary : Colors.black38,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400,
                          color: isActive ? _kPrimary : Colors.black38,
                        ),
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

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  const _NavItem(this.icon, this.activeIcon, this.label);
}

// ─────────────────────────────────────────────────────────────
//  HOME CONTENT
// ─────────────────────────────────────────────────────────────
class _GuestHomeContent extends StatelessWidget {
  final GuestMode    mode;
  final VoidCallback onEventsTap;
  final VoidCallback onNewsTap;
  final VoidCallback onCalendarTap;
  final VoidCallback onSignInTap;

  const _GuestHomeContent({
    required this.mode,
    required this.onEventsTap,
    required this.onNewsTap,
    required this.onCalendarTap,
    required this.onSignInTap,
  });

  bool get _isAuth => mode == GuestMode.authenticated;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── App Bar ──────────────────────────────────────────
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(
                    color: _kPrimary, shape: BoxShape.circle),
                child: const Icon(Icons.local_fire_department,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 8),
              Text('UPRISE',
                  style: GoogleFonts.beVietnamPro(
                      color: _kPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 1.4)),
            ],
          ),
          actions: [
            if (!_isAuth)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: onSignInTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Sign In',
                        style: GoogleFonts.beVietnamPro(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            if (_isAuth)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFF059669).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 12, color: Color(0xFF059669)),
                      const SizedBox(width: 4),
                      Text('GUEST',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF059669),
                              letterSpacing: 0.6)),
                    ],
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child:
                Container(height: 1, color: const Color(0xFFF0F0F0)),
          ),
        ),

        // ── Banner ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _isAuth
              ? _AuthenticatedBanner()
              : _VisitorBanner(onSignIn: onSignInTap),
        ),

        // ── Quick Access ─────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 10),
            child: Text('Quick Access',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
          ),
        ),

        SliverToBoxAdapter(
          child: _QuickActions(
            isAuth:            _isAuth,
            onEventsTap:       onEventsTap,
            onAnnouncementsTap: onNewsTap,
            onCalendarTap:     onCalendarTap,
          ),
        ),

        // ── Locked features (visitor only) ───────────────────
        if (!_isAuth) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 10),
              child: Text('Available to CICT Students',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87)),
            ),
          ),
          SliverToBoxAdapter(
            child: _LockedFeaturesGrid(onSignIn: onSignInTap),
          ),
        ],

        // ── Authenticated guest extra features ───────────────
        if (_isAuth) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 26, 16, 10),
              child: Text('Your Features',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87)),
            ),
          ),
          SliverToBoxAdapter(
            child: _AuthFeatureTiles(),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  VISITOR BANNER
// ─────────────────────────────────────────────────────────────
class _VisitorBanner extends StatelessWidget {
  final VoidCallback onSignIn;
  const _VisitorBanner({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 120, height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withOpacity(0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _kPrimary.withOpacity(0.4), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.explore_outlined,
                          size: 12, color: _kPrimary),
                      const SizedBox(width: 4),
                      Text('VISITOR MODE',
                          style: GoogleFonts.beVietnamPro(
                              color: _kPrimary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Welcome to UPRISE',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Text('Browse public events & announcements.',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white54,
                        fontSize: 12,
                        height: 1.4)),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onSignIn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text('Sign In as CICT Student →',
                        style: GoogleFonts.beVietnamPro(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
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

// ─────────────────────────────────────────────────────────────
//  AUTHENTICATED BANNER
// ─────────────────────────────────────────────────────────────
class _AuthenticatedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final svc = GuestAuthService();
    final name = svc.fullName ?? 'Guest';
    final first = name.split(' ').first;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6B00), Color(0xFFFF9A4D)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20, top: -20,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded,
                          size: 12, color: Colors.white),
                      const SizedBox(width: 4),
                      Text('VERIFIED GUEST',
                          style: GoogleFonts.beVietnamPro(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text('Welcome back, $first!',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                    'You have full guest access. Check out your\nDigital ID and leave feedback on events.',
                    style: GoogleFonts.beVietnamPro(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  QUICK ACTIONS
// ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final bool         isAuth;
  final VoidCallback onEventsTap;
  final VoidCallback onAnnouncementsTap;
  final VoidCallback onCalendarTap;

  const _QuickActions({
    required this.isAuth,
    required this.onEventsTap,
    required this.onAnnouncementsTap,
    required this.onCalendarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _QuickActionTile(
            icon: Icons.calendar_today_rounded,
            label: 'Public\nEvents',
            color: _kPrimary,
            onTap: onEventsTap,
          ),
          const SizedBox(width: 12),
          _QuickActionTile(
            icon: Icons.campaign_rounded,
            label: 'Announce-\nments',
            color: const Color(0xFF1565C0),
            onTap: onAnnouncementsTap,
          ),
          const SizedBox(width: 12),
          _QuickActionTile(
            icon: Icons.date_range_rounded,
            label: 'Calendar',
            color: const Color(0xFF2E7D32),
            onTap: onCalendarTap,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: color.withOpacity(0.15), width: 1),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  AUTH FEATURE TILES  (for authenticated home)
// ─────────────────────────────────────────────────────────────
class _AuthFeatureTiles extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _FeatureTile(
              icon: Icons.rate_review_outlined,
              color: const Color(0xFF6A1B9A),
              label: 'Event Feedback',
              sub: 'Rate events you attended',
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _FeatureTile(
              icon: Icons.badge_outlined,
              color: _kPrimary,
              label: 'Digital ID',
              sub: 'Your verified guest card',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final String       sub;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
            const SizedBox(height: 2),
            Text(sub,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  LOCKED FEATURES GRID  (visitor)
// ─────────────────────────────────────────────────────────────
class _LockedFeaturesGrid extends StatelessWidget {
  final VoidCallback onSignIn;
  const _LockedFeaturesGrid({required this.onSignIn});

  static const _features = [
    _LockedFeature(
      icon: Icons.badge_outlined,
      label: 'Digital ID',
      description: 'Your student identity card',
      color: Color(0xFFFF6B00),
    ),
    _LockedFeature(
      icon: Icons.groups_outlined,
      label: 'Organizations',
      description: 'CICT org directory',
      color: Color(0xFF1565C0),
    ),
    _LockedFeature(
      icon: Icons.workspace_premium_outlined,
      label: 'Certificates',
      description: 'Event certificates',
      color: Color(0xFF6A1B9A),
    ),
    _LockedFeature(
      icon: Icons.rate_review_outlined,
      label: 'Feedback',
      description: 'Rate events you attended',
      color: Color(0xFF2E7D32),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.6,
        children: _features
            .map((f) => _LockedTile(feature: f, onSignIn: onSignIn))
            .toList(),
      ),
    );
  }
}

class _LockedFeature {
  final IconData icon;
  final String   label;
  final String   description;
  final Color    color;
  const _LockedFeature({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });
}

class _LockedTile extends StatelessWidget {
  final _LockedFeature feature;
  final VoidCallback   onSignIn;
  const _LockedTile({required this.feature, required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onSignIn,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFEEEEEE)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: feature.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(feature.icon, size: 20, color: feature.color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(feature.label,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  const SizedBox(height: 2),
                  Row(
                    children: const [
                      Icon(Icons.lock_outline_rounded,
                          size: 10, color: Colors.grey),
                      SizedBox(width: 3),
                      Text('Sign in',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  SIGN IN PROMPT SHEET
// ─────────────────────────────────────────────────────────────
class _SignInPromptSheet extends StatelessWidget {
  const _SignInPromptSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2)),
          ),
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
                color: _kPrimaryBg, shape: BoxShape.circle),
            child: const Icon(Icons.school_rounded,
                size: 34, color: _kPrimary),
          ),
          const SizedBox(height: 16),
          Text('CICT Student Access',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87)),
          const SizedBox(height: 8),
          Text(
              'Sign in with your CICT credentials\nto unlock full access.',
              textAlign: TextAlign.center,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: Colors.grey, height: 1.5)),
          const SizedBox(height: 24),
          _SheetFeatureRow(
              icon: Icons.badge_outlined, text: 'Digital ID & Profile'),
          const SizedBox(height: 8),
          _SheetFeatureRow(
              icon: Icons.groups_outlined,
              text: 'Organizations & Clubs'),
          const SizedBox(height: 8),
          _SheetFeatureRow(
              icon: Icons.workspace_premium_outlined,
              text: 'Certificates & Merch'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const StudentLogin()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: Text('Sign In as CICT Student',
                  style: GoogleFonts.beVietnamPro(
                      fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue as Guest',
                style: GoogleFonts.beVietnamPro(
                    color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _SheetFeatureRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _SheetFeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: _kPrimaryBg,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, size: 16, color: _kPrimary),
        ),
        const SizedBox(width: 12),
        Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87)),
        const Spacer(),
        const Icon(Icons.check_circle_rounded,
            size: 16, color: Color(0xFF2E7D32)),
      ],
    );
  }
}