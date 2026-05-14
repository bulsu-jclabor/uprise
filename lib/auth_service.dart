import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> registerWithEmail(
    String email,
    String password,
    String fullName, {
    String role = 'student',
    String? orgId, // required when role == 'org'
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      final Map<String, dynamic> data = {
        'uid': result.user!.uid,
        'email': email,
        'fullName': fullName,
        'role': role,
        'createdAt': Timestamp.now(),
      };
      if (orgId != null && orgId.isNotEmpty) data['orgId'] = orgId;
      await _firestore.collection('users').doc(result.user!.uid).set(data);
      return result.user;
    } catch (e) {
      print('❌ Registration error: $e');
      return null;
    }
  }

  Future<User?> loginWithEmail(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email, password: password,
      );
      return result.user;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      print('❌ Login error: $e');
      return null;
    }
  }

  Future<String?> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['role'] as String? ?? 'student';
      }
      return 'student';
    } catch (e) {
      return 'student';
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.exists ? doc.data() as Map<String, dynamic>? : null;
    } catch (e) {
      return null;
    }
  }

  Future<void> logout() async => await _auth.signOut();

  Future<bool> needsPasswordChange(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        return data?['isFirstLogin'] ?? false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Stream<User?> get user => _auth.authStateChanges();
}