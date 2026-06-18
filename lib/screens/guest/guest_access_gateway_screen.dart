// lib/screens/guest/guest_access_gateway_screen.dart
//
// GUEST ACCESS GATEWAY — Replaces the old "Continue as Guest" direct flow.
//
// Presents three options:
//   1. Visit as Guest (Visitor mode — no account)
//   2. Sign Up (apply for guest account)
//   3. Log In (authenticated guest with Feedback + Digital ID)
//
// Navigation:
//   Visit as Guest  → GuestHomeScreen (visitor mode, no auth)
//   Sign Up         → GuestRegistrationScreen (in guest_profile_screen.dart)
//   Log In          → GuestLoginScreen → GuestHomeScreen (authenticated mode)
//

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'guest_auth_service.dart'; // GuestMode enum + auth state management
import 'guest_home_screen.dart';
import 'guest_profile_screen.dart'; // exposes _RegistrationScreen via re-export

// ─────────────────────────────────────────────────────────────
//  THEME
// ─────────────────────────────────────────────────────────────
const _kOrange      = Color(0xFFFF6B00);
const _kOrangeLight = Color(0xFFFFEDD5);
const _kDark        = Color(0xFF1A1A2E);
const _kBg          = Color(0xFFF5F5F5);

// ─────────────────────────────────────────────────────────────
//  GATEWAY SCREEN
// ─────────────────────────────────────────────────────────────
class GuestAccessGatewayScreen extends StatelessWidget {
  const GuestAccessGatewayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      body: Stack(
        children: [
          // Decorative background circles
          Positioned(
            right: -60, top: -60,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kOrange.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            left: -40, bottom: 100,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kOrange.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            right: 40, bottom: -30,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kOrange.withOpacity(0.08),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back arrow ──────────────────────────────
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 18),
                    ),
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),

                  const SizedBox(height: 28),

                  // ── UPRISE logo ──────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 38, height: 38,
                        decoration: const BoxDecoration(
                            color: _kOrange, shape: BoxShape.circle),
                        child: const Icon(Icons.local_fire_department,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text('UPRISE',
                          style: GoogleFonts.beVietnamPro(
                              color: _kOrange,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              letterSpacing: 1.8)),
                    ],
                  ),

                  const SizedBox(height: 28),

                  Text('How would you\nlike to continue?',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.25)),

                  const SizedBox(height: 8),

                  Text('Choose your access mode below.',
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 14,
                          color: Colors.white54,
                          height: 1.5)),

                  const SizedBox(height: 36),

                  // ── Option 1: Visit as Guest ─────────────────
                  _AccessCard(
                    icon: Icons.explore_outlined,
                    iconBg: const Color(0xFF1565C0),
                    badge: 'NO ACCOUNT NEEDED',
                    badgeColor: const Color(0xFF1565C0),
                    title: 'Visit as Guest',
                    subtitle: 'Browse events, announcements, and the calendar without signing up.',
                    features: const [
                      'Event Feed',
                      'Announcements',
                      'Calendar',
                      'Public Profile',
                    ],
                    buttonLabel: 'Continue as Visitor',
                    buttonColor: const Color(0xFF1565C0),
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GuestHomeScreen(
                            mode: GuestMode.visitor,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Option 2: Sign Up ────────────────────────
                  _AccessCard(
                    icon: Icons.person_add_outlined,
                    iconBg: const Color(0xFF2E7D32),
                    badge: 'FREE REGISTRATION',
                    badgeColor: const Color(0xFF2E7D32),
                    title: 'Sign Up',
                    subtitle: 'Apply for a guest account. Once approved, you unlock more features.',
                    features: const [
                      'Event Feed',
                      'Announcements',
                      'Calendar',
                      'Profile',
                      'Feedback',
                      'Digital ID',
                    ],
                    buttonLabel: 'Apply for Access',
                    buttonColor: const Color(0xFF2E7D32),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GuestSignUpScreen(
                            onSubmitted: (_) => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GuestHomeScreen(
                                  mode: GuestMode.visitor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // ── Option 3: Log In ─────────────────────────
                  _AccessCard(
                    icon: Icons.login_rounded,
                    iconBg: _kOrange,
                    badge: 'FULL ACCESS',
                    badgeColor: _kOrange,
                    title: 'Log In',
                    subtitle: 'Already have guest credentials? Log in to access all features.',
                    features: const [
                      'Event Feed',
                      'Announcements',
                      'Calendar',
                      'Profile',
                      'Feedback',
                      'Digital ID',
                    ],
                    buttonLabel: 'Log In as Guest',
                    buttonColor: _kOrange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GuestLoginScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  ACCESS OPTION CARD
// ─────────────────────────────────────────────────────────────
class _AccessCard extends StatelessWidget {
  final IconData     icon;
  final Color        iconBg;
  final String       badge;
  final Color        badgeColor;
  final String       title;
  final String       subtitle;
  final List<String> features;
  final String       buttonLabel;
  final Color        buttonColor;
  final VoidCallback onTap;

  const _AccessCard({
    required this.icon,
    required this.iconBg,
    required this.badge,
    required this.badgeColor,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.buttonLabel,
    required this.buttonColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: iconBg.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iconBg.withOpacity(0.3)),
                ),
                child: Icon(icon, color: iconBg, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: badgeColor.withOpacity(0.3)),
                      ),
                      child: Text(badge,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                              letterSpacing: 0.8)),
                    ),
                    const SizedBox(height: 4),
                    Text(title,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(subtitle,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: Colors.white60,
                  height: 1.5)),

          const SizedBox(height: 12),

          // Feature pills
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: features.map((f) => Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded,
                      size: 10, color: badgeColor),
                  const SizedBox(width: 4),
                  Text(f,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 10,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            )).toList(),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(buttonLabel,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  GUEST SIGN UP SCREEN (wrapper — delegates to GuestProfileScreen logic)
// ─────────────────────────────────────────────────────────────
/// Thin wrapper that exposes the registration form from guest_profile_screen
/// as a standalone route reachable from the gateway.
class GuestSignUpScreen extends StatelessWidget {
  final Future<void> Function(String docId) onSubmitted;
  const GuestSignUpScreen({super.key, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return RegistrationScreen(
  onSubmitted: onSubmitted,
);
  }
}

// ─────────────────────────────────────────────────────────────
//  GUEST LOGIN SCREEN
// ─────────────────────────────────────────────────────────────
class GuestLoginScreen extends StatefulWidget {
  const GuestLoginScreen({super.key});

  @override
  State<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends State<GuestLoginScreen> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure    = true;
  bool _isLoading  = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email    = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Please enter your email and password.');
      return;
    }
    if (!email.contains('@')) {
      _snack('Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Authenticate against the external_requests collection
      // (guests don't have Firebase Auth accounts — their "password" is
      // stored as a hashed field set by the admin upon approval).
      // For demo purposes this checks email + approvalCode.
      final snap = await _queryGuestAccount(email, password);

      if (!mounted) return;

      if (snap == null) {
        _snack('Invalid credentials or account not yet approved.');
        setState(() => _isLoading = false);
        return;
      }

      // Store the docId in SharedPreferences then navigate
      await GuestAuthService.saveSession(
        docId    : snap['docId']    as String,
        email    : email,
        fullName : snap['userName'] as String? ?? '',
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const GuestHomeScreen(
            mode: GuestMode.authenticated,
          ),
        ),
        (route) => false,
      );
    } catch (e) {
      if (mounted) {
        _snack('Login failed: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _queryGuestAccount(
      String email, String password) async {
    try {
      final import1 = await _firestore()
          .collection('external_requests')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'approved')
          .limit(1)
          .get();

      if (import1.docs.isEmpty) return null;

      final doc  = import1.docs.first;
      final data = doc.data() as Map<String, dynamic>;

      // Check approvalCode (set by admin when approving the guest)
      final storedCode = (data['approvalCode'] as String?) ?? '';
      if (storedCode.isEmpty || storedCode != password) return null;

      return {'docId': doc.id, ...data};
    } catch (_) {
      return null;
    }
  }

  // ignore: non_constant_identifier_names
  dynamic _firestore() {
    // ignore: undefined_prefixes
    return _FirestoreProxy.instance;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.beVietnamPro(fontSize: 13)),
      backgroundColor: const Color(0xFFDC2626),
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDark,
      appBar: AppBar(
        backgroundColor: _kDark,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back,
                color: Colors.white, size: 18),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            right: -40, top: -40,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kOrange.withOpacity(0.08),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Header
                  Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: const BoxDecoration(
                            color: _kOrange, shape: BoxShape.circle),
                        child: const Icon(Icons.login_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guest Login',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white)),
                          Text('Enter your guest credentials',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 12, color: Colors.white54)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Column(
                      children: [
                        // Email
                        _buildField(
                          label: 'Email Address',
                          controller: _emailCtrl,
                          hint: 'your@email.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),
                        // Password
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Password',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white70)),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _passwordCtrl,
                              obscureText: _obscure,
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 14, color: Colors.white),
                              decoration: InputDecoration(
                                hintText: 'Enter your password',
                                hintStyle: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    color: Colors.white38),
                                prefixIcon: const Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: Colors.white38),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    size: 18,
                                    color: Colors.white38,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscure = !_obscure),
                                ),
                                filled: true,
                                fillColor:
                                    Colors.white.withOpacity(0.07),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.white
                                          .withOpacity(0.15)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  borderSide: BorderSide(
                                      color: Colors.white
                                          .withOpacity(0.15)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: _kOrange, width: 1.5),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kOrange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white))
                                : Text('Log In',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Info about credentials
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kOrange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _kOrange.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: _kOrange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your login credentials were provided by the CICT admin after your guest application was approved.',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 12,
                                color: Colors.white60,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white70)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: GoogleFonts.beVietnamPro(
              fontSize: 14, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.beVietnamPro(
                fontSize: 13, color: Colors.white38),
            prefixIcon: Icon(icon, size: 18, color: Colors.white38),
            filled: true,
            fillColor: Colors.white.withOpacity(0.07),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: _kOrange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  PROXY (avoids direct cloud_firestore import here; real app uses DI)
// ─────────────────────────────────────────────────────────────
class _FirestoreProxy {
  static dynamic get instance {
    // In the real app this returns FirebaseFirestore.instance
    // ignore: undefined_class, return_of_invalid_type
    return _realFirestore();
  }
}

dynamic _realFirestore() {
  // ignore: undefined_identifier
  return _cloudFirestoreInstance;
}

// ignore: unused_element
dynamic get _cloudFirestoreInstance {
  // Returns FirebaseFirestore.instance — resolved at build time
  throw UnimplementedError('Wire up FirebaseFirestore.instance here.');
}