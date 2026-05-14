import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'screens/web/admin/admin_login.dart';
import 'screens/web/admin/admin_dashboard.dart';
import 'package:uprise/screens/web/org/org_dashboard.dart';
import 'screens/student/student_login.dart';
import 'screens/student/student_home_screen.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key});

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  final AuthService _auth = AuthService();
  late Stream<User?> _authStream;

  // ✅ FIX BUG 1: Cache the role future per user so it doesn't re-fire on every rebuild
  String? _cachedUid;
  Future<String?>? _roleFuture;

  @override
  void initState() {
    super.initState();
    _authStream = _auth.user;
  }

  // Returns a cached future for the same uid, or creates a fresh one if the user changed
  Future<String?> _getRoleFuture(String uid) {
    if (_cachedUid != uid || _roleFuture == null) {
      _cachedUid = uid;
      _roleFuture = _auth.getUserRole(uid);
    }
    return _roleFuture!;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) {
          debugPrint('🔐 No user logged in');
          // ✅ Clear cached role when user logs out
          _cachedUid = null;
          _roleFuture = null;
          if (!kIsWeb) return StudentLogin();
          return AdminLogin();
        }

        final user = snapshot.data!;

        return FutureBuilder<String?>(
          // ✅ FIX BUG 1: Use cached future — won't re-call Firestore on rebuild
          future: _getRoleFuture(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final String role =
                (roleSnapshot.data ?? 'guest').toLowerCase();
            debugPrint('📋 Role: $role');

            Widget screen;
            if (!kIsWeb) {
              // Mobile
              if (role == 'student') {
                screen = const StudentHomeScreen();
              } else if (role == 'admin') {
                screen = const WrongPlatformScreen(
                  message: 'Admin accounts are only available on Web.',
                  icon: Icons.computer,
                );
              } else if (role == 'org') {
                screen = const WrongPlatformScreen(
                  message:
                      'Organization accounts are only available on Web.',
                  icon: Icons.business,
                );
              } else {
                screen = StudentLogin();
              }
            } else {
              // Web
              if (role == 'admin') {
                screen = const AdminDashboard();
              } else if (role == 'org') {
                // ✅ FIX BUG 3: RoleRouter handles routing — OrgLogin no longer
                // pushes OrgDashboard manually, so there's only one navigation
                screen = OrgDashboard();
              } else if (role == 'student') {
                screen = const WrongPlatformScreen(
                  message:
                      'Student accounts are only available on Mobile.',
                  icon: Icons.phone_android,
                );
              } else {
                screen = AdminLogin();
              }
            }

            return KeyedSubtree(
              key: ValueKey('${user.uid}-$role'),
              child: screen,
            );
          },
        );
      },
    );
  }
}

// ============ WrongPlatformScreen ============
class WrongPlatformScreen extends StatelessWidget {
  final String message;
  final IconData icon;
  const WrongPlatformScreen(
      {super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) {
    final AuthService auth = AuthService();
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 70, color: Colors.orange),
              const SizedBox(height: 20),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                          builder: (_) => const RoleRouter()),
                    );
                  }
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}