import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final Map<String, String> _roleCache = {};

  static void cacheRole(String uid, String role) {
    if (uid.isNotEmpty) {
      _roleCache[uid] = role.toLowerCase();
    }
  }

  static String? getCachedRole(String uid) {
    return uid.isNotEmpty ? _roleCache[uid] : null;
  }

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
        final role = (data?['role'] as String?)?.toLowerCase() ?? 'student';
        cacheRole(uid, role);
        return role;
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
      if (!doc.exists) {
        print('AuthService.needsPasswordChange: user doc not found for uid=$uid');
        return false;
      }
      final data = doc.data() as Map<String, dynamic>? ?? {};
      final bool isFirstLogin = data['isFirstLogin'] == true;
      final bool mustChangePassword = data['mustChangePassword'] == true;
      final bool needsPasswordChange = data['needsPasswordChange'] == true;
      final bool firstLogin = data['firstLogin'] == true;
      final bool result = isFirstLogin || mustChangePassword || needsPasswordChange || firstLogin;
      print('AuthService.needsPasswordChange uid=$uid data=$data result=$result');
      return result;
    } catch (e, st) {
      print('AuthService.needsPasswordChange error uid=$uid: $e\n$st');
      return false;
    }
  }

  Stream<User?> get user => _auth.authStateChanges();
}