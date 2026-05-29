import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_login.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentChangePasswordScreen extends StatefulWidget {
  const StudentChangePasswordScreen({super.key});

  @override
  State<StudentChangePasswordScreen> createState() =>
      _StudentChangePasswordScreenState();
}

class _StudentChangePasswordScreenState
    extends State<StudentChangePasswordScreen> {
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final newPassword = _newPasswordController.text.trim();
  final confirmPassword = _confirmPasswordController.text.trim();

  if (newPassword.isEmpty || confirmPassword.isEmpty) {
    _showError('Please fill in all fields');
    return;
  }
  if (newPassword != confirmPassword) {
    _showError('Passwords do not match');
    return;
  }
  if (newPassword.length < 6) {
    _showError('Password must be at least 6 characters');
    return;
  }

  setState(() => _isLoading = true);

  try {
    // ✅ Update password sa Firebase Auth
    await user.updatePassword(newPassword);

    // ✅ Update Firestore - remove mustChangePassword flag
    final snapshot = await FirebaseFirestore.instance
        .collection('students')
        .where('uid', isEqualTo: user.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await snapshot.docs.first.reference.update({
        'mustChangePassword': false,
        'tempPassword': FieldValue.delete(), // optional: tanggalin temp password
      });
    }

    // ✅ Sign out and go back to login
    await FirebaseAuth.instance.signOut();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password changed! Please login with your new password.'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const StudentLogin()),
        (route) => false,
      );
    }
  } catch (e) {
    _showError('Error: $e');
  }

  setState(() => _isLoading = false);
} 

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change Password')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _changePassword,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save New Password'),
            ),
          ],
        ),
      ),
    );
  }
}
