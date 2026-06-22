// lib/screens/student/student_login.dart
//
// STUDENT LOGIN — Updated to route "Continue as Guest" through the
//                 GuestAccessGatewayScreen (3 options: Visit / Sign Up / Log In).
//

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../auth_service.dart';
import '../../services/activity_logger.dart' as activity_log;
import '../guest/guest_access_gateway_screen.dart';
import '../student/student_home_screen.dart';
import 'student_change_password_screen.dart';

class StudentLogin extends StatefulWidget {
  const StudentLogin({super.key});

  @override
  State<StudentLogin> createState() => _StudentLoginState();
}

class _StudentLoginState extends State<StudentLogin> {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading       = false;
  bool _obscurePassword = true;

  final AuthService _auth = AuthService();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login ──────────────────────────────────────────────
  Future<void> _login() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Please enter email and password');
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      _showError('Please enter a valid email address');
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
  final user = await _auth.loginWithEmail(email, password);

  if (user != null) {
    final role = await _auth.getUserRole(user.uid);
    await activity_log.ActivityLogger.log(
      action: 'Student login',
      module: 'Authentication',
      severity: 'security',
      details: {'uid': user.uid, 'email': email, 'role': role},
    );
  }

  if (!mounted) return;

  if (user == null) {
    _showError('Invalid email or password');
  } else {
    final mustChange = await _auth.needsPasswordChange(user.uid);

    if (!mounted) return;

    if (mustChange) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => StudentChangePasswordScreen(),
        ),
        (route) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const StudentHomeScreen(),
        ),
        (route) => false,
      );
    }
  }
} on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Login failed. Please try again.';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address';
          break;
        case 'too-many-requests':
          message = 'Too many attempts. Please wait and try again.';
          break;
      }
      // currentUser is null on a failed sign-in, so ActivityLogger would log
      // 'Unknown' as the user — record the attempted email in details instead.
      await activity_log.ActivityLogger.log(
        action: 'Failed student login attempt',
        module: 'Authentication',
        severity: 'warning',
        details: {'email': email, 'reason': e.code},
      );
      _showError(message);
    } catch (_) {
      if (mounted) _showError('An error occurred. Please try again.');
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  // ── Guest access → Gateway ─────────────────────────────
  void _openGuestGateway() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const GuestAccessGatewayScreen(),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: GoogleFonts.beVietnamPro(fontSize: 13)),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // ── Background image ─────────────────────────────
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg_pattern.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: Colors.grey[200]),
            ),
          ),
          // ── Gradient overlay ─────────────────────────────
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.62),
                    Colors.black.withOpacity(0.18),
                  ],
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // UPRISE logo
                      Row(children: [
                        Container(
                          width: 38, height: 38,
                          decoration: const BoxDecoration(
                              color: Color(0xFFFF6B00),
                              shape: BoxShape.circle),
                          child: const Icon(Icons.local_fire_department,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Text('UPRISE',
                            style: GoogleFonts.beVietnamPro(
                                color: const Color(0xFFFF6B00),
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: 1.8)),
                      ]),

                      const SizedBox(height: 24),

                      Text('Student Login',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),

                      const SizedBox(height: 18),

                      // ── Login card ──────────────────────────
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.96),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              offset: const Offset(0, 18),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 8),

                            // Email
                            TextField(
                              controller: _emailCtrl,
                              keyboardType:
                                  TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email Address',
                                labelStyle: GoogleFonts.beVietnamPro(
                                    fontSize: 14),
                                prefixIcon: const Icon(
                                    Icons.email_outlined,
                                    size: 20),
                              ),
                            ),

                            const SizedBox(height: 18),

                            // Password
                            TextField(
                              controller: _passwordCtrl,
                              obscureText: _obscurePassword,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                labelStyle: GoogleFonts.beVietnamPro(
                                    fontSize: 14),
                                prefixIcon: const Icon(
                                    Icons.lock_outline, size: 20),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                  ),
                                  onPressed: () {
                                    if (!mounted) return;
                                    setState(() => _obscurePassword =
                                        !_obscurePassword);
                                  },
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed:
                                    _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFFF6B00),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22, height: 22,
                                        child:
                                            CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ))
                                    : Text('Login',
                                        style: GoogleFonts.beVietnamPro(
                                            fontSize: 15,
                                            fontWeight:
                                                FontWeight.w700)),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // ── Continue as Guest → Gateway ────
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _openGuestGateway,
                                icon: const Icon(
                                    Icons.explore_outlined,
                                    size: 18),
                                label: Text('Continue as Guest',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w600)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.black54,
                                  side: const BorderSide(
                                      color: Color(0xFFDDDDDD)),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Small hint below card
                      Center(
                        child: Text(
                          'Guests can visit, sign up, or log in\nfrom the Continue as Guest option.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              color: Colors.white54,
                              height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}