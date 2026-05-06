import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/web/admin/admin_dashboard.dart';

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
      title: 'UPRISE - Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFFFF6B35),
        fontFamily: 'Poppins',
        useMaterial3: true,
      ),
      home: AdminDashboard(),
    );
  }
}