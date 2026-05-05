import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'login_screen.dart';

// IMPORT THE REAL ADMIN DASHBOARD (not the placeholder)
import 'screens/web/admin/admin_dashboard.dart';

// Placeholder for other dashboards (to be built later)
class OrgDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Organization Dashboard')),
      body: Center(child: Text('Org Dashboard - Web Version (Coming Soon)')),
    );
  }
}

class StudentHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Student Home')),
      body: Center(child: Text('Student Home - Mobile Version (Coming Soon)')),
    );
  }
}

class GuestHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Guest Home')),
      body: Center(child: Text('Guest Home - Mobile Version (Coming Soon)')),
    );
  }
}

class RoleRouter extends StatelessWidget {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _auth.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (!snapshot.hasData) {
          return LoginScreen();
        }
        
        return FutureBuilder<String?>(
          future: _auth.getUserRole(snapshot.data!.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            }
            
            String role = roleSnapshot.data ?? 'guest';
            
            // Web vs Mobile check
            if (role == 'admin' || role == 'org') {
              if (!kIsWeb) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning, size: 64, color: Colors.orange),
                        SizedBox(height: 16),
                        Text('This account requires Web access'),
                        ElevatedButton(
                          onPressed: () => _auth.logout(),
                          child: Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              // USE THE REAL ADMIN DASHBOARD HERE
              if (role == 'admin') {
                return AdminDashboard();  // ← THIS NOW LOADS YOUR REAL DASHBOARD
              } else {
                return OrgDashboard();
              }
            } else {
              if (kIsWeb) {
                return Scaffold(
                  body: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smartphone, size: 64, color: Colors.blue),
                        SizedBox(height: 16),
                        Text('This account requires Mobile access'),
                        ElevatedButton(
                          onPressed: () => _auth.logout(),
                          child: Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return role == 'student' ? StudentHome() : GuestHome();
            }
          },
        );
      },
    );
  }
}