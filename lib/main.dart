import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // ✅ Added for login user info
import 'role_router.dart'; // RoleRouter handles login vs home
import 'utils/theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kIsWeb) {
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: false);
    }
    print('✅ Firebase initialized!');
  } catch (e) {
    if (e.toString().contains('duplicate-app')) {
      print('⚠️ Firebase already initialized, continuing...');
    } else {
      print('❌ Firebase error: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPRISE',
      theme: appTheme,
      debugShowCheckedModeBanner: false,
      home: const RoleRouter(), // ✅ Always start here
    );
  }
}
