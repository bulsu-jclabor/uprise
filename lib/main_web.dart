import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/web/admin/admin_login.dart';
import 'screens/web/admin/admin_dashboard.dart';
import 'screens/web/org/org_login.dart';
import 'screens/web/org/org_dashboard.dart'; // we'll create later, for now use AdminDashboard

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyWebAdminApp());
}

class MyWebAdminApp extends StatelessWidget {
  const MyWebAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPRISE - Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B35),
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: const LandingPage(),
    );
  }
}


class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF7ED), Color(0xFFFFFBF5), Color(0xFFFEF3C7)],
            stops: [0.0, 0.4, 1.0],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFFFDE68A).withOpacity(0.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFB45309).withOpacity(0.10),
                      blurRadius: 40,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo – perfectly centered in circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFFAF5EE),
                        border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    RichText(
                      text: TextSpan(children: [
                        TextSpan(
                          text: 'UP',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 28, fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B), letterSpacing: 3,
                          ),
                        ),
                        TextSpan(
                          text: 'RISE',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 28, fontWeight: FontWeight.w800,
                            color: const Color(0xFFD97706), letterSpacing: 3,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CICT Organization Management Portal',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11.5, color: const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Divider with label
                    Row(children: [
                      const Expanded(child: Divider(color: Color(0xFFF1F5F9))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('SELECT YOUR PORTAL',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 10, color: const Color(0xFF94A3B8),
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFF1F5F9))),
                    ]),
                    const SizedBox(height: 16),

                    _PortalButton(
                      label: 'Admin Portal',
                      description: 'Manage system & organizations',
                      icon: Icons.shield_rounded,
                      isPrimary: true,
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => AdminLogin())),
                    ),
                    const SizedBox(height: 10),
                    _PortalButton(
                      label: 'Organization Portal',
                      description: 'Access your org dashboard',
                      icon: Icons.domain_rounded,
                      isPrimary: false,
                      onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const OrganizationLogin())),
                    ),
                    const SizedBox(height: 18),

                    // Badges
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _Badge(label: 'Secure Login', showDot: true),
                        const SizedBox(width: 6),
                        _Badge(label: 'CICT Verified', icon: Icons.verified_rounded),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No account? Contact your System Administrator',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11, color: const Color(0xFF94A3B8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalButton extends StatelessWidget {
  final String label, description;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _PortalButton({
    required this.label, required this.description,
    required this.icon, required this.isPrimary, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFFD97706), Color(0xFFB45309)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isPrimary ? null : const Color(0xFFFFFBF5),
            border: isPrimary
                ? null
                : Border.all(color: const Color(0xFFFDE68A), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withOpacity(0.22)
                      : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18,
                  color: isPrimary ? Colors.white : const Color(0xFFB45309)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: isPrimary ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(description,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 10.5,
                        color: isPrimary
                            ? Colors.white.withOpacity(0.72)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                color: isPrimary
                    ? Colors.white.withOpacity(0.6)
                    : const Color(0xFFD97706)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final bool showDot;
  final IconData? icon;

  const _Badge({required this.label, this.showDot = false, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (showDot) ...[
          Container(width: 5, height: 5,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981), shape: BoxShape.circle)),
          const SizedBox(width: 5),
        ],
        if (icon != null) ...[
          Icon(icon, size: 11, color: const Color(0xFFD97706)),
          const SizedBox(width: 4),
        ],
        Text(label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 10, color: const Color(0xFF94A3B8),
          ),
        ),
      ]),
    );
  }
}

// AuthWrapper – decides which dashboard to show after login
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final user = snapshot.data;
          if (user == null) {
            return const LandingPage();
          }
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
            builder: (context, roleSnapshot) {
              if (roleSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (roleSnapshot.hasData && roleSnapshot.data!.exists) {
                final role = roleSnapshot.data!.get('role') as String?;
                if (role == 'admin') {
                  return const AdminDashboard();
                } else if (role == 'org') {
                  // For now use AdminDashboard, later replace with OrgDashboard
                  return const AdminDashboard(); // Change to OrgDashboard when ready
                }
              }
              // Invalid role → sign out and go to landing
              FirebaseAuth.instance.signOut();
              return const LandingPage();
            },
          );
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}