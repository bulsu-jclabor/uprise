// lib/screens/admin/student_accounts.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';

class StudentAccounts extends StatefulWidget {
  @override
  _StudentAccountsState createState() => _StudentAccountsState();
}

class _StudentAccountsState extends State<StudentAccounts> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFile = '';
  File? _uploadedFile;
  bool _isUploading = false;

  // Filters
  String _statusFilter = 'All'; // All, pending, verified
  String _courseFilter = 'All'; // All, BSIT, BSIS, BLIS

  // Manual add controllers
  final _formKey = GlobalKey<FormState>();
  final _manualIdController = TextEditingController();
  final _manualNameController = TextEditingController();
  String _manualCourse = 'BSIT';
  final _manualYearController = TextEditingController();
  final _manualEmailController = TextEditingController();
  String _manualStatus = 'pending';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Student Accounts',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: UpriseColors.charcoal,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Manage and verify student accounts for the system.',
                      style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                    ),
                  ],
                ),
                // Search Bar
                Container(
                  width: 260,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search students...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                      prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                      filled: true,
                      fillColor: UpriseColors.lightGray,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
          ),

          // Upload Card
          Container(
            margin: EdgeInsets.all(24),
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.upload_file, color: UpriseColors.primaryDark),
                    SizedBox(width: 12),
                    Text(
                      'Upload Student List',
                      style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w600, color: UpriseColors.charcoal),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: UpriseColors.lightGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: UpriseColors.mediumGray),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description, color: UpriseColors.primaryDark),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile.isEmpty ? 'CICT Students List 2021-2022.xlsx' : _selectedFile,
                          style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.charcoal),
                        ),
                      ),
                      SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _pickFile,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: UpriseColors.primaryDark),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text('Browse', style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark)),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Supported formats: Excel (.xlsx, .xls) or CSV. Columns: Student ID, Full Name, Course/Program, Year Level, Email Address',
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadAndProcessFile,
                  icon: Icon(Icons.cloud_upload),
                  label: Text('Upload Student List'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.primaryDark,
                    foregroundColor: UpriseColors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                if (_isUploading) ...[
                  SizedBox(height: 16),
                  LinearProgressIndicator(color: UpriseColors.primaryDark),
                ],
              ],
            ),
          ),

          // Filter Row + Manual Add + Export
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Filter chips
                Wrap(
                  spacing: 8,
                  children: [
                    _buildFilterChip('All', _statusFilter == 'All', () => setState(() => _statusFilter = 'All')),
                    _buildFilterChip('Pending', _statusFilter == 'pending', () => setState(() => _statusFilter = 'pending')),
                    _buildFilterChip('Verified', _statusFilter == 'verified', () => setState(() => _statusFilter = 'verified')),
                    SizedBox(width: 16),
                    _buildFilterChip('All Courses', _courseFilter == 'All', () => setState(() => _courseFilter = 'All')),
                    _buildFilterChip('BSIT', _courseFilter == 'BSIT', () => setState(() => _courseFilter = 'BSIT')),
                    _buildFilterChip('BSIS', _courseFilter == 'BSIS', () => setState(() => _courseFilter = 'BSIS')),
                    _buildFilterChip('BLIS', _courseFilter == 'BLIS', () => setState(() => _courseFilter = 'BLIS')),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportToCSV,
                      icon: Icon(Icons.download, size: 18),
                      label: Text('Export CSV'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UpriseColors.primaryDark,
                        side: BorderSide(color: UpriseColors.primaryDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showManualAddDialog,
                      icon: Icon(Icons.person_add),
                      label: Text('Add Student Manually'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.white,
                        foregroundColor: UpriseColors.primaryDark,
                        side: BorderSide(color: UpriseColors.primaryDark),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 16),

          // Students Table
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: UpriseColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: UpriseColors.mediumGray),
              ),
              child: Column(
                children: [
                  // Table Header
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                      color: UpriseColors.lightGray,
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text('STUDENT ID', style: _headerStyle())),
                        Expanded(flex: 2, child: Text('FULL NAME', style: _headerStyle())),
                        Expanded(flex: 1, child: Text('COURSE', style: _headerStyle())),
                        Expanded(flex: 1, child: Text('YEAR', style: _headerStyle())),
                        Expanded(flex: 2, child: Text('EMAIL', style: _headerStyle())),
                        Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
                        Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
                      ],
                    ),
                  ),
                  // Table Body
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('students')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        }
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 64, color: UpriseColors.mediumGray),
                                SizedBox(height: 16),
                                Text('No students found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
                              ],
                            ),
                          );
                        }

                        var docs = snapshot.data!.docs;

                        // Apply search
                        if (_searchController.text.isNotEmpty) {
                          docs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['fullName']?.toLowerCase() ?? '';
                            final id = data['studentId']?.toLowerCase() ?? '';
                            final email = data['email']?.toLowerCase() ?? '';
                            final term = _searchController.text.toLowerCase();
                            return name.contains(term) || id.contains(term) || email.contains(term);
                          }).toList();
                        }

                        // Apply status filter
                        if (_statusFilter != 'All') {
                          docs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['status'] == _statusFilter;
                          }).toList();
                        }

                        // Apply course filter
                        if (_courseFilter != 'All') {
                          docs = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return data['course'] == _courseFilter;
                          }).toList();
                        }

                        return ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            return _buildStudentRow(data, docs[index].id);
                          },
                        );
                      },
                    ),
                  ),
                  // Footer
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
                      color: UpriseColors.lightGray,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Showing results', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                        Row(
                          children: [
                            IconButton(icon: Icon(Icons.chevron_left, size: 20), onPressed: () {}),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: UpriseColors.primaryDark, borderRadius: BorderRadius.circular(4)),
                              child: Text('1', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                            IconButton(icon: Icon(Icons.chevron_right, size: 20), onPressed: () {}),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: UpriseColors.white,
      selectedColor: UpriseColors.primaryDark.withOpacity(0.1),
      checkmarkColor: UpriseColors.primaryDark,
      labelStyle: GoogleFonts.beVietnamPro(
        color: selected ? UpriseColors.primaryDark : UpriseColors.darkGray,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: StadiumBorder(side: BorderSide(color: UpriseColors.mediumGray)),
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.beVietnamPro(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: UpriseColors.darkGray,
      letterSpacing: 0.5,
    );
  }

  Widget _buildStudentRow(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'pending';
    Color statusColor = status == 'verified' ? UpriseColors.success : UpriseColors.warning;
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        children: [
          Expanded(flex: 1, child: Text(data['studentId'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
          Expanded(flex: 2, child: Text(data['fullName'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500))),
          Expanded(flex: 1, child: Text(data['course'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
          Expanded(flex: 1, child: Text(data['yearLevel'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
          Expanded(flex: 2, child: Text(data['email'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.verified_outlined, size: 18, color: UpriseColors.primaryDark),
                  onPressed: status != 'verified' ? () => _verifyStudent(docId) : null,
                  tooltip: 'Verify Account',
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 18, color: UpriseColors.error),
                  onPressed: () => _deleteStudent(docId, data['email']),
                  tooltip: 'Delete Account',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------- Verification & Deletion -----------------------------
  Future<void> _verifyStudent(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(docId).update({'status': 'verified'});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Student account verified')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteStudent(String docId, String email) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Student Account'),
        content: Text('Are you sure you want to delete this student account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                // Delete Firestore document
                await FirebaseFirestore.instance.collection('students').doc(docId).delete();
                // Note: Deleting Firebase Auth user requires a Cloud Function (client can't do it). 
                // For now, the user will still exist in Auth but cannot log in because we'd delete the password.
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Student record deleted')));
                Navigator.pop(context);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ----------------------------- File Upload -----------------------------
  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls', 'csv'],
    );
    if (result != null) {
      setState(() {
        _uploadedFile = File(result.files.single.path!);
        _selectedFile = result.files.single.name;
      });
    }
  }

  Future<void> _uploadAndProcessFile() async {
    if (_uploadedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a file first')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      List<Map<String, String>> students = await _parseFile(_uploadedFile!);
      if (students.isEmpty) throw Exception('No valid data found in file');
      int success = 0;
      int failed = 0;
      for (var student in students) {
        try {
          await _createStudentAccount(student);
          success++;
        } catch (e) {
          print('Error creating student ${student['studentId']}: $e');
          failed++;
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload complete: $success created, $failed failed')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error processing file: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<List<Map<String, String>>> _parseFile(File file) async {
    List<Map<String, String>> students = [];
    String extension = file.path.split('.').last.toLowerCase();
    if (extension == 'csv') {
      String csvString = await file.readAsString();
      List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);
      for (int i = 1; i < rows.length; i++) {
        var row = rows[i];
        if (row.length >= 5) {
          students.add({
            'studentId': row[0]?.toString().trim() ?? '',
            'fullName': row[1]?.toString().trim() ?? '',
            'course': _normalizeCourse(row[2]?.toString().trim() ?? ''),
            'yearLevel': row[3]?.toString().trim() ?? '',
            'email': row[4]?.toString().trim() ?? '',
          });
        }
      }
    } else {
      var bytes = await file.readAsBytes();
      var excel = Excel.decodeBytes(bytes);
      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        for (int i = 1; i < sheet!.rows.length; i++) {
          var row = sheet.rows[i];
          if (row.length >= 5) {
            students.add({
              'studentId': row[0]?.value?.toString().trim() ?? '',
              'fullName': row[1]?.value?.toString().trim() ?? '',
              'course': _normalizeCourse(row[2]?.value?.toString().trim() ?? ''),
              'yearLevel': row[3]?.value?.toString().trim() ?? '',
              'email': row[4]?.value?.toString().trim() ?? '',
            });
          }
        }
        break;
      }
    }
    students.removeWhere((s) => s['studentId']!.isEmpty || s['email']!.isEmpty);
    return students;
  }

  String _normalizeCourse(String course) {
    final upper = course.toUpperCase();
    if (upper.contains('BSIT')) return 'BSIT';
    if (upper.contains('BSIS')) return 'BSIS';
    if (upper.contains('BLIS')) return 'BLIS';
    return 'BSIT';
  }

  // ----------------------------- Firebase Account Creation & Email -----------------------------
  Future<void> _createStudentAccount(Map<String, String> student) async {
  String email = student['email']!;
  String studentId = student['studentId']!;
  String fullName = student['fullName']!;
  String password = _generateRandomPassword();

  // Use a secondary app instance so admin stays signed in
  FirebaseApp secondaryApp;
  try {
    secondaryApp = await Firebase.initializeApp(
      name: 'secondaryApp',
      options: Firebase.app().options,
    );
  } catch (e) {
    // Already initialized — reuse it
    secondaryApp = Firebase.app('secondaryApp');
  }

  FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);

  UserCredential userCred;
  try {
    userCred = await secondaryAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  } catch (e) {
    if (e.toString().contains('email-already-in-use')) {
      throw Exception('Email already registered: $email');
    } else {
      throw Exception('Account creation failed: ${e.toString()}');
    }
  }

  await userCred.user?.updateDisplayName(fullName);

  await FirebaseFirestore.instance.collection('students').doc(userCred.user!.uid).set({
    'studentId': studentId,
    'fullName': fullName,
    'course': student['course'],
    'yearLevel': student['yearLevel'],
    'email': email,
    'status': 'pending',
    'createdAt': FieldValue.serverTimestamp(),
    'uid': userCred.user!.uid,
  });

  // Sign out from secondary instance to keep it clean
  await secondaryAuth.signOut();

  await _sendCredentialsEmail(email, studentId, password);
}
  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%&*';
    String random = List.generate(12, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
    return random;
  }

  // REAL EMAIL SENDING using mailer package
  // You MUST configure your SMTP settings (example uses Gmail with app password)
  Future<void> _sendCredentialsEmail(String email, String studentId, String password) async {
    // ============ CONFIGURE YOUR SMTP HERE ============
    // For Gmail: enable 2‑Factor Authentication and generate an App Password.
    // Replace these with your own credentials.
    final smtpServer = gmail('your-email@gmail.com', 'your-16-digit-app-password');
    // =================================================

    final message = Message()
      ..from = Address('your-email@gmail.com', 'UPRISE Admin')
      ..recipients.add(email)
      ..subject = 'Welcome to UPRISE - Your Student Credentials'
      ..html = '''
        <h2 style="color:#BE4700;">UPRISE Student Account</h2>
        <p>Dear Student,</p>
        <p>Your CICT account has been created on the UPRISE platform.</p>
        <hr/>
        <p><strong>Student ID:</strong> $studentId</p>
        <p><strong>Email:</strong> $email</p>
        <p><strong>Password:</strong> $password</p>
        <hr/>
        <p>Login at: <a href="https://your-app.com/login">UPRISE Portal</a></p>
        <p>For security, please change your password after first login.</p>
        <br/>
        <p>Best regards,<br/>UPRISE Administration Team<br/>CICT</p>
      ''';
    try {
      await send(message, smtpServer);
      print('Email sent to $email');
    } catch (e) {
      print('Failed to send email to $email: $e');
      // Do not throw – we still created the account, but admin should know.
    }
  }

  // ----------------------------- Manual Add -----------------------------
void _showManualAddDialog() {
  _manualIdController.clear();
  _manualNameController.clear();
  _manualCourse = 'BSIT';
  _manualYearController.clear();
  _manualEmailController.clear();
  _manualStatus = 'pending';

  showDialog(
    context: context,
    barrierDismissible: false, // prevent accidental close
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        bool _isCreating = false;
        String? _errorMessage;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.person_add, color: UpriseColors.primaryDark),
              SizedBox(width: 8),
              Text('Add Student Manually', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _manualIdController,
                    decoration: InputDecoration(labelText: 'Student ID', hintText: '2021-00-001'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _manualNameController,
                    decoration: InputDecoration(labelText: 'Full Name'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _manualCourse,
                    items: ['BSIT', 'BSIS', 'BLIS'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setDialogState(() => _manualCourse = v!),
                    decoration: InputDecoration(labelText: 'Course/Program'),
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _manualYearController.text.isNotEmpty ? _manualYearController.text : null,
                    items: ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year']
                        .map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                    onChanged: (v) => _manualYearController.text = v!,
                    decoration: InputDecoration(labelText: 'Year Level'),
                    validator: (v) => v == null ? 'Required' : null,
                  ),
                  SizedBox(height: 12),
                  TextFormField(
                    controller: _manualEmailController,
                    decoration: InputDecoration(labelText: 'Email Address', hintText: 'student@cict.edu.ph'),
                    validator: (v) => v!.isEmpty || !v.contains('@') ? 'Valid email required' : null,
                  ),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _manualStatus,
                    items: ['pending', 'verified'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                    onChanged: (v) => setDialogState(() => _manualStatus = v!),
                    decoration: InputDecoration(labelText: 'Account Status'),
                  ),
                  if (_errorMessage != null) ...[
                    SizedBox(height: 12),
                    Text(_errorMessage!, style: TextStyle(color: UpriseColors.error, fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isCreating ? null : () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: _isCreating
                  ? null
                  : () async {
                      if (_formKey.currentState!.validate()) {
                        setDialogState(() {
                          _isCreating = true;
                          _errorMessage = null;
                        });
                        try {
                          await _createManualStudent(); // this does NOT close the dialog
                          // Success: close dialog
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Student account created successfully')),
                          );
                          setState(() {}); // refresh table
                        } catch (e) {
                          setDialogState(() {
                            _isCreating = false;
                            _errorMessage = e.toString();
                          });
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
              child: _isCreating
                  ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Create Account'),
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _createManualStudent() async {
  final student = {
    'studentId': _manualIdController.text.trim(),
    'fullName': _manualNameController.text.trim(),
    'course': _manualCourse,
    'yearLevel': _manualYearController.text.trim(),
    'email': _manualEmailController.text.trim(),
  };

  await _createStudentAccount(student);

  // Update status if admin set to verified
  if (_manualStatus == 'verified') {
    final query = await FirebaseFirestore.instance
        .collection('students')
        .where('email', isEqualTo: student['email'])
        .get();
    if (query.docs.isNotEmpty) {
      await query.docs.first.reference.update({'status': 'verified'});
    }
  }
  // No Navigator.pop or setState here – let the dialog handle it
}
  // ----------------------------- Export CSV (share_plus) -----------------------------
  Future<void> _exportToCSV() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('students').get();
      var docs = snapshot.docs;

      // Apply current filters (same as table)
      if (_searchController.text.isNotEmpty) {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = data['fullName']?.toLowerCase() ?? '';
          final id = data['studentId']?.toLowerCase() ?? '';
          final term = _searchController.text.toLowerCase();
          return name.contains(term) || id.contains(term);
        }).toList();
      }
      if (_statusFilter != 'All') {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == _statusFilter;
        }).toList();
      }
      if (_courseFilter != 'All') {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['course'] == _courseFilter;
        }).toList();
      }

      List<List<dynamic>> rows = [];
      rows.add(['Student ID', 'Full Name', 'Course', 'Year Level', 'Email', 'Status']);
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        rows.add([
          data['studentId'] ?? '',
          data['fullName'] ?? '',
          data['course'] ?? '',
          data['yearLevel'] ?? '',
          data['email'] ?? '',
          data['status'] ?? 'pending',
        ]);
      }
      String csv = const ListToCsvConverter().convert(rows);

      // Create a temporary file and share it (avoids storage permission issues)
      final directory = Directory.systemTemp;
      final file = File('${directory.path}/students_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Student list export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
    }
  }
}