import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Register
  Future<User?> registerWithEmail(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'uid': result.user!.uid,
        'email': email,
        'name': name,
        'role': 'guest',
        'createdAt': Timestamp.now(),
      });
      
      print('✅ User created in Firestore: ${result.user!.uid}');
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
      print('✅ Login successful: ${result.user!.email}');
      return result.user;
    } catch (e) {
      print('❌ Login error: $e');
      return null;
    }
  }

  // Get role
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        print('✅ Role found: ${doc.get('role')}');
        return doc.get('role');
      } else {
        print('⚠️ No user document found for uid: $uid');
        return 'guest';
      }
    } catch (e) {
      print('❌ Error getting role: $e');
      return 'guest';
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
    print('✅ Logged out');
  }

  // Current user stream
  Stream<User?> get user => _auth.authStateChanges();
}