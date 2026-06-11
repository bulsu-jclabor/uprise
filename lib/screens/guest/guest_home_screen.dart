// lib/screens/guest/guest_home_screen.dart
//
// GUEST MODE – public-only access
// Tabs: Home | Announcements | Events | QR Attendance
// Blocked: Organizations (internal), Certificates, Profile/Digital ID
//

import 'package:flutter/material.dart';

import '../student/student_login.dart';
import 'guest_announcements_screen.dart';
import 'guest_events_screen.dart';
import 'guest_qr_attendance_screen.dart';
import 'guest_profile_screen.dart';

// ─────────────────────────────────────────────────────────────
//  THEME CONSTANTS
// ─────────────────────────────────────────────────────────────
const _kPrimary   = Color(0xFFFF6B00);
const _kPrimaryBg = Color(0xFFFFF3EB);

// ─────────────────────────────────────────────────────────────
//  GUEST SHELL
// ─────────────────────────────────────────────────────────────
class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
  _GuestHomeContent(),
  GuestAnnouncementsScreen(),
  GuestEventsScreen(),
  GuestQrAttendanceScreen(),
  GuestProfileScreen(),
];

  void switchTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _GuestBottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  BOTTOM NAV
// ─────────────────────────────────────────────────────────────
class _GuestBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _GuestBottomNav({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
  _NavItem(Icons.home_outlined, Icons.home_rounded, 'Home'),
  _NavItem(Icons.campaign_outlined, Icons.campaign_rounded, 'Announcements'),
  _NavItem(Icons.calendar_today_outlined, Icons.calendar_today_rounded, 'Events'),
  _NavItem(Icons.qr_code_scanner_outlined, Icons.qr_code_scanner_rounded, 'Attendance'),
  _NavItem(Icons.person_outline, Icons.person, 'Profile'),
];

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
            children: List.generate(_items.length, (i) {
              final item    = _items[i];
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
  const _GuestHomeContent();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── App Bar ──
        SliverAppBar(
          floating: true,
          backgroundColor: Colors.white,
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(
                  color: _kPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 17,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'UPRISE',
                style: TextStyle(
                  color: _kPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => _showSignInPrompt(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: const Color(0xFFF0F0F0)),
          ),
        ),

        // ── Banner ──
        SliverToBoxAdapter(
          child: _GuestBanner(onSignIn: () => _showSignInPrompt(context)),
        ),

        // ── Quick Access ──
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 22, 16, 10),
            child: Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: _QuickActions(
            onEventsTap: () {
              final s = context.findAncestorStateOfType<_GuestHomeScreenState>();
              if (s != null) s.switchTab(2);
            },
            onAnnouncementsTap: () {
              final s = context.findAncestorStateOfType<_GuestHomeScreenState>();
              if (s != null) s.switchTab(1);
            },
            onAttendanceTap: () {
              final s = context.findAncestorStateOfType<_GuestHomeScreenState>();
              if (s != null) s.switchTab(3);
            },
          ),
        ),

        // ── Locked features heading ──
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 26, 16, 10),
            child: Text(
              'Available to CICT Students',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: _LockedFeaturesGrid(
              onSignIn: () => _showSignInPrompt(context)),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  void _showSignInPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SignInPromptSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  GUEST BANNER
// ─────────────────────────────────────────────────────────────
class _GuestBanner extends StatelessWidget {
  final VoidCallback onSignIn;
  const _GuestBanner({required this.onSignIn});

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
          // Decorative orange circle
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: -30,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kPrimary.withOpacity(0.08),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Guest badge
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
                    children: const [
                      Icon(Icons.person_outline_rounded,
                          size: 12, color: _kPrimary),
                      SizedBox(width: 4),
                      Text(
                        'GUEST MODE',
                        style: TextStyle(
                          color: _kPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to UPRISE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Browse public events & announcements.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onSignIn,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kPrimary,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withOpacity(0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Sign In as CICT Student →',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
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
}

// ─────────────────────────────────────────────────────────────
//  QUICK ACTIONS
// ─────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  final VoidCallback onEventsTap;
  final VoidCallback onAnnouncementsTap;
  final VoidCallback onAttendanceTap;

  const _QuickActions({
    required this.onEventsTap,
    required this.onAnnouncementsTap,
    required this.onAttendanceTap,
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
            icon: Icons.qr_code_scanner_rounded,
            label: 'QR\nAttendance',
            color: const Color(0xFF2E7D32),
            onTap: onAttendanceTap,
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData    icon;
  final String      label;
  final Color       color;
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
//  LOCKED FEATURES
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
      icon: Icons.shopping_bag_outlined,
      label: 'Merchandise',
      description: 'Org merch store',
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
                  Text(
                    feature.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: const [
                      Icon(Icons.lock_outline_rounded,
                          size: 10, color: Colors.grey),
                      SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Sign in',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey),
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
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 22),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: _kPrimaryBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              size: 34,
              color: _kPrimary,
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'CICT Student Access',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Sign in with your CICT credentials\nto unlock full access.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.5),
          ),

          const SizedBox(height: 24),

          // Feature list
          _SheetFeatureRow(
              icon: Icons.badge_outlined,       text: 'Digital ID & Profile'),
          const SizedBox(height: 8),
          _SheetFeatureRow(
              icon: Icons.groups_outlined,       text: 'Organizations & Clubs'),
          const SizedBox(height: 8),
          _SheetFeatureRow(
              icon: Icons.workspace_premium_outlined, text: 'Certificates & Merch'),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const StudentLogin()),
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
              child: const Text(
                'Sign In as CICT Student',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ),

          const SizedBox(height: 10),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continue as Guest',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: _kPrimary),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.black87),
        ),
        const Spacer(),
        const Icon(Icons.check_circle_rounded,
            size: 16, color: Color(0xFF2E7D32)),
      ],
    );
  }
}