// // lib/main.dart
// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'screens/auth/login_screen.dart';
// import 'screens/student/student_home_screen.dart';
// import 'utils/theme.dart';
// import 'firebase_options.dart'; //not sure

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();

//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );

//   runApp(MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'UPRISE',
//       theme: appTheme, // We'll create this
//       debugShowCheckedModeBanner: false,
//       home: StreamBuilder<User?>(
//         stream: FirebaseAuth.instance.authStateChanges(),
//         builder: (context, snapshot) {
//           if (snapshot.connectionState == ConnectionState.active) {
//             final user = snapshot.data;
//             if (user == null) {
//               return const LoginScreen();
//             }
//             // TODO: Check if user needs to change password (first login)
//             return const StudentHomeScreen();
//           }
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         },
//       ),
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_home_screen.dart';
import 'utils/theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Check if Firebase is already initialized
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.active) {
            final user = snapshot.data;
            if (user == null) {
              return const LoginScreen();
            }
            return const StudentHomeScreen();
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }
}