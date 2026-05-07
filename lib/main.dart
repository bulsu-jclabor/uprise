import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'role_router.dart';
import 'utils/theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      home: RoleRouter(),
    );
  }
}