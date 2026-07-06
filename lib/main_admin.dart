import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'screens/web/admin/admin_landing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MaterialApp(
    title: 'UPRISE Admin',
    debugShowCheckedModeBanner: false,
    home: AdminLandingPage(),
  ));
}
