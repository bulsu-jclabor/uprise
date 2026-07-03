// lib/screens/student/student_webinar_code_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/student/app_colors.dart';

class StudentWebinarCodeScreen extends StatefulWidget {
  const StudentWebinarCodeScreen({super.key});

  @override
  State<StudentWebinarCodeScreen> createState() => _StudentWebinarCodeScreenState();
}

class _StudentWebinarCodeScreenState extends State<StudentWebinarCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  Future<void> _submitCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter the webinar code');
      return;
    }

    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Please login first');
      }

      final codeDoc = await FirebaseFirestore.instance
          .collection('webinar_codes')
          .doc(code)
          .get();

      if (!codeDoc.exists) {
        throw Exception('❌ Invalid webinar code. Please check and try again.');
      }

      final data = codeDoc.data()!;

      if (data['isActive'] != true) {
        throw Exception('⏰ This webinar code is no longer active.');
      }

      final eventId = data['eventId'];

      final registration = await FirebaseFirestore.instance
          .collection('registrations')
          .where('userId', isEqualTo: user.uid)
          .where('eventId', isEqualTo: eventId)
          .get();

      if (registration.docs.isEmpty) {
        throw Exception('📝 You are not registered for this webinar.');
      }

      final existingAttendance = await FirebaseFirestore.instance
          .collection('attendances')
          .where('eventId', isEqualTo: eventId)
          .where('studentId', isEqualTo: user.uid)
          .get();

      if (existingAttendance.docs.isNotEmpty) {
        throw Exception('✅ You have already checked in to this webinar.');
      }

      await FirebaseFirestore.instance.collection('attendances').add({
        'eventId': eventId,
        'studentId': user.uid,
        'studentName': user.displayName ?? '',
        'studentEmail': user.email ?? '',
        'timestamp': FieldValue.serverTimestamp(),
        'method': 'webinar_code',
        'code': code,
        'status': 'present',
        'webinarCode': code,
      });

      await FirebaseFirestore.instance
          .collection('webinar_codes')
          .doc(code)
          .update({
            'usedBy': FieldValue.arrayUnion([user.uid]),
          });

      setState(() {
        _successMessage = '✅ Attendance recorded successfully!';
        _isLoading = false;
        _codeController.clear();
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.pop(context);
      });

    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Webinar Code',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primaryDark.withOpacity(0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Enter the 6-digit webinar code shown on your organization\'s screen.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryDark,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.qr_code_scanner_rounded,
                  size: 64,
                  color: AppColors.primaryDark,
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Text(
                'Enter Webinar Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'Input the 6-digit code displayed on your screen',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 40),
              
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _errorMessage != null 
                        ? Colors.red 
                        : _successMessage != null
                            ? Colors.green
                            : AppColors.primaryDark.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: TextField(
                  controller: _codeController,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                    color: Colors.black87,
                  ),
                  maxLength: 6,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    hintText: '— — — — — —',
                    hintStyle: TextStyle(
                      fontSize: 24,
                      color: Colors.grey.shade400,
                      letterSpacing: 8,
                    ),
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    suffixIcon: _codeController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear_rounded,
                              color: AppColors.primaryDark,
                            ),
                            onPressed: () {
                              _codeController.clear();
                              setState(() {
                                _errorMessage = null;
                                _successMessage = null;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {
                    _errorMessage = null;
                    _successMessage = null;
                  }),
                  onSubmitted: (_) => _submitCode(),
                ),
              ),
              
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 4),
                  child: Text(
                    '${_codeController.text.length}/6',
                    style: TextStyle(
                      fontSize: 12,
                      color: _codeController.text.length == 6
                          ? Colors.green
                          : Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (_successMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _successMessage!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const Spacer(),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Submit Code',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 16,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Ask your organization if you don\'t see the code',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}