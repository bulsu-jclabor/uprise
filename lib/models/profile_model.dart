import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const kOrange = Color(0xFFFF6B00);
const kBg = Color(0xFFF5F5F5);

class ProfileModel extends ChangeNotifier {
  String fullName = '';
  String studentId = '';
  String email = '';
  String mobile = '';
  String address = '';
  String photoUrl = ''; // ✅ Added for profile image

  ProfileModel() {
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      email = user.email ?? '';

      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        fullName = data['fullName'] ?? '';
        studentId = data['studentId'] ?? '';
        mobile = data['mobile'] ?? '';
        address = data['address'] ?? '';
        photoUrl = data['photoUrl'] ?? ''; // ✅ Load image URL if available
      }
      notifyListeners();
    }
  }
}
