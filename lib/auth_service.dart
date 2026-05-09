// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';

// class AuthService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;

//   // Register
//   Future<User?> registerWithEmail(String email, String password, String name) async {
//     try {
//       UserCredential result = await _auth.createUserWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
      
//       // Create user document in Firestore
//       await _firestore.collection('users').doc(result.user!.uid).set({
//         'uid': result.user!.uid,
//         'email': email,
//         'name': name,
//         'role': 'guest',
//         'createdAt': Timestamp.now(),
//       });
      
//       return result.user;
//     } catch (e) {
//       return null;
//     }
//   }

//   // Login
//   Future<User?> loginWithEmail(String email, String password) async {
//     try {
//       UserCredential result = await _auth.signInWithEmailAndPassword(
//         email: email,
//         password: password,
//       );
//       return result.user;
//     } catch (e) {
//       return null;
//     }
//   }

//   // Get role
//   Future<String?> getUserRole(String uid) async {
//     try {
//       DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
//       if (doc.exists) {
//         print('✅ Role found: ${doc.get('role')}');
//         return doc.get('role');
//       } else {
//         print('⚠️ No user document found for uid: $uid');
//         return 'guest';
//       }
//     } catch (e) {
//       print('❌ Error getting role: $e');
//       return 'guest';
//     }
//   }

//   // Logout
//   Future<void> logout() async {
//     await _auth.signOut();
//     print('✅ Logged out');
//   }

//   // Current user stream
//   Stream<User?> get user => _auth.authStateChanges();
// }

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register - specify role (default: student)
  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName, {
    String role = 'student', // default role is student
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'fullName': fullName,
        'role': role, // now flexible, defaults to student
        'createdAt': Timestamp.now(),
      });
      
      print('✅ User registered: $email with role: $role');
      return result.user;
    } catch (e) {
      print('❌ Registration error: $e');
      return null;
    }
  }

  // Login
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      print('✅ User logged in: $email');
      return result.user;
    } catch (e) {
      print('❌ Login error: $e');
      return null;
    }
  }

  // Get user role from Firestore
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        final roleValue = data?['role'] as String?;
        print('✅ Role found for $uid: $roleValue');
        return roleValue ?? 'student'; // default to student if missing
      } else {
        print('⚠️ No user document found for uid: $uid');
        return 'student';
      }
    } catch (e) {
      print('❌ Error getting role: $e');
      return 'student';
    }
  }

  // Get current user data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('❌ Error getting user data: $e');
      return null;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    print('✅ Logged out');
  }

  // Check if user needs to change password (first login)
  Future<bool> needsPasswordChange(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['isFirstLogin'] ?? false;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // Current user stream
  Stream<User?> get user => _auth.authStateChanges();
}
