import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';

import 'screens/web/admin/admin_login.dart';
import 'screens/web/admin/admin_dashboard.dart';

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

  @override
  void initState() {
    super.initState();
    _authStream = _auth.user;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        // LOADING
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // NO USER LOGGED IN
        if (!snapshot.hasData) {
          debugPrint('🔐 No user logged in');
          
          if (!kIsWeb) {
            return StudentLogin();
          }
          return AdminLogin();
        }

        // USER LOGGED IN - Get role then navigate
        final user = snapshot.data!;
        return FutureBuilder<String?>(
          future: _auth.getUserRole(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final String role = (roleSnapshot.data ?? 'guest').toLowerCase();
            debugPrint('📋 Role: $role');

            // Determine which screen to show
            Widget screen;
            
            if (!kIsWeb) {
              // MOBILE
              if (role == 'student') {
                screen = const StudentHomeScreen();
              } else if (role == 'admin') {
                screen = const WrongPlatformScreen(
                  message: 'Admin accounts are only available on Web.',
                  icon: Icons.computer,
                );
              } else if (role == 'org') {
                screen = const WrongPlatformScreen(
                  message: 'Organization accounts are only available on Web.',
                  icon: Icons.business,
                );
              } else {
                screen = StudentLogin();
              }
            } else {
              // WEB
              if (role == 'admin') {
                screen = const AdminDashboard();
              } else if (role == 'org') {
                screen = const OrgDashboard();
              } else if (role == 'student') {
                screen = const WrongPlatformScreen(
                  message: 'Student accounts are only available on Mobile.',
                  icon: Icons.phone_android,
                );
              } else {
                screen = AdminLogin();
              }
            }

            // Use a key to force a new instance when role changes
            return KeyedSubtree(
              key: ValueKey('$user.uid-$role'),
              child: screen,
            );
          },
        );
      },
    );
  }
}

// =====================================================
// WRONG PLATFORM SCREEN
// =====================================================

class WrongPlatformScreen extends StatelessWidget {
  final String message;
  final IconData icon;

  const WrongPlatformScreen({
    super.key,
    required this.message,
    required this.icon,
  });

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
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  await auth.logout();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const RoleRouter()),
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

// =====================================================
// ORG DASHBOARD PLACEHOLDER
// =====================================================

class OrgDashboard extends StatelessWidget {
  const OrgDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Organization Dashboard'),
      ),
      body: const Center(
        child: Text('Org Dashboard - Coming Soon'),
      ),
    );
  }
}