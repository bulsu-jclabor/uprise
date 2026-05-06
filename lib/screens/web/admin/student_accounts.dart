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
import 'package:firebase_core/firebase_core.dart';
import '../../theme/app_theme.dart';

class StudentAccounts extends StatefulWidget {
  @override
  _StudentAccountsState createState() => _StudentAccountsState();
}

class _StudentAccountsState extends State<StudentAccounts> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  String _courseFilter = 'All';

  File? _uploadedFile;
  String _selectedFileName = '';
  bool _isUploading = false;

  final _formKey = GlobalKey<FormState>();
  final _manualIdController = TextEditingController();
  final _manualNameController = TextEditingController();
  String _manualCourse = 'BSIT';
  final _manualYearController = TextEditingController();
  final _manualEmailController = TextEditingController();
  String _manualStatus = 'pending';

  // Fixed column widths (total ~990, horizontal scroll will kick in if needed)
  final double _colId = 120;
  final double _colName = 200;
  final double _colCourse = 100;
  final double _colYear = 100;
  final double _colEmail = 220;
  final double _colStatus = 100;
  final double _colActions = 150;
  double get _totalWidth => _colId + _colName + _colCourse + _colYear + _colEmail + _colStatus + _colActions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
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
                    Text('Student Accounts',
                        style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
                    SizedBox(height: 4),
                    Text('Manage and verify student accounts. Batch import via Excel/CSV or add manually.',
                        style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showUploadDialog,
                  icon: Icon(Icons.upload_file),
                  label: Text('Batch Import'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.primaryDark,
                    foregroundColor: UpriseColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),

          // Filter Bar
          Container(
            margin: EdgeInsets.symmetric(horizontal: 24),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    _buildStatusTab('All', _statusFilter == 'All'),
                    SizedBox(width: 8),
                    _buildStatusTab('Pending', _statusFilter == 'pending'),
                    SizedBox(width: 8),
                    _buildStatusTab('Verified', _statusFilter == 'verified'),
                  ],
                ),
                SizedBox(width: 24),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: UpriseColors.mediumGray),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: DropdownButton<String>(
                    value: _courseFilter,
                    underline: const SizedBox(),
                    icon: Icon(Icons.filter_list, size: 18, color: UpriseColors.darkGray),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Courses')),
                      DropdownMenuItem(value: 'BSIT', child: Text('BSIT')),
                      DropdownMenuItem(value: 'BSIS', child: Text('BSIS')),
                      DropdownMenuItem(value: 'BLIS', child: Text('BLIS')),
                    ],
                    onChanged: (val) => setState(() => _courseFilter = val!),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 260,
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID, or email...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                      prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                      filled: true,
                      fillColor: UpriseColors.lightGray,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 16),
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
                  label: Text('Add Manually'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.white,
                    foregroundColor: UpriseColors.primaryDark,
                    side: BorderSide(color: UpriseColors.primaryDark),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Table area – simple horizontal scroll + vertical list
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: UpriseColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: UpriseColors.mediumGray),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: _totalWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Table header
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                          color: UpriseColors.lightGray,
                        ),
                        child: Row(
                          children: [
                            SizedBox(width: _colId, child: Text('STUDENT ID', style: _headerStyle())),
                            SizedBox(width: _colName, child: Text('FULL NAME', style: _headerStyle())),
                            SizedBox(width: _colCourse, child: Text('COURSE', style: _headerStyle())),
                            SizedBox(width: _colYear, child: Text('YEAR', style: _headerStyle())),
                            SizedBox(width: _colEmail, child: Text('EMAIL', style: _headerStyle())),
                            SizedBox(width: _colStatus, child: Text('STATUS', style: _headerStyle())),
                            SizedBox(width: _colActions, child: Text('ACTIONS', style: _headerStyle())),
                          ],
                        ),
                      ),
                      // Table rows (dynamic height, vertical scrolling)
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('students')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return SizedBox(
                              height: 200,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.people_outline, size: 64, color: UpriseColors.mediumGray),
                                    SizedBox(height: 16),
                                    Text('No students found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
                                  ],
                                ),
                              ),
                            );
                          }

                          var docs = snapshot.data!.docs;
                          // Apply filters
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

                          if (docs.isEmpty) {
                            return SizedBox(
                              height: 200,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.filter_alt_off, size: 64, color: UpriseColors.mediumGray),
                                    SizedBox(height: 16),
                                    Text('No students match filters', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
                                  ],
                                ),
                              ),
                            );
                          }

                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(), // Let parent handle vertical scroll
                            itemCount: docs.length,
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final status = data['status'] ?? 'pending';
                              Color statusColor = status == 'verified' ? UpriseColors.success : UpriseColors.warning;
                              return Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(width: _colId, child: Text(data['studentId'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
                                    SizedBox(width: _colName, child: Text(data['fullName'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500))),
                                    SizedBox(width: _colCourse, child: Text(data['course'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
                                    SizedBox(width: _colYear, child: Text(data['yearLevel'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
                                    SizedBox(width: _colEmail, child: Text(data['email'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13))),
                                    SizedBox(
                                      width: _colStatus,
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
                                    SizedBox(
                                      width: _colActions,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.key, size: 18, color: UpriseColors.primaryDark),
                                            onPressed: () => _showPasswordDialog(data['studentId'], data['tempPassword']),
                                            tooltip: 'View Password',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.email, size: 18, color: UpriseColors.primaryDark),
                                            onPressed: () => _resendCredentials(docs[index].id, data['email'], data['studentId'], data['tempPassword']),
                                            tooltip: 'Resend Credentials',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.verified_outlined, size: 18, color: UpriseColors.success),
                                            onPressed: status != 'verified' ? () => _verifyStudent(docs[index].id) : null,
                                            tooltip: 'Verify',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 18, color: UpriseColors.error),
                                            onPressed: () => _deleteStudent(docs[index].id, data['email']),
                                            tooltip: 'Delete',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label == 'All' ? 'All' : label.toLowerCase()),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? null : Border.all(color: UpriseColors.mediumGray),
        ),
        child: Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? UpriseColors.white : UpriseColors.darkGray,
          ),
        ),
      ),
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray, letterSpacing: 0.5);
  }

  // ---------- Credentials helpers ----------
  void _showPasswordDialog(String studentId, String? password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Student Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student ID: $studentId', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Password: ', style: GoogleFonts.beVietnamPro()),
            SelectableText(
              password ?? 'No password stored. Use "Resend Credentials" to generate a new one.',
              style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w500, color: UpriseColors.primaryDark),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Close')),
        ],
      ),
    );
  }

  Future<void> _resendCredentials(String docId, String email, String studentId, String? existingPassword) async {
    String password = existingPassword ?? _generateRandomPassword();
    await FirebaseFirestore.instance.collection('students').doc(docId).update({'tempPassword': password});
    await _sendCredentialsEmail(email, studentId, password);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Credentials resent to $email')));
  }

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
                await FirebaseFirestore.instance.collection('students').doc(docId).delete();
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

  // ---------- Upload dialog ----------
  void _showUploadDialog() {
    _selectedFileName = '';
    _uploadedFile = null;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.upload_file, color: UpriseColors.primaryDark),
                SizedBox(width: 8),
                Text('Batch Import Students', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
              ],
            ),
            content: Container(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
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
                          child: Text(_selectedFileName.isEmpty ? 'No file selected' : _selectedFileName,
                              style: GoogleFonts.beVietnamPro(fontSize: 14)),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            FilePickerResult? result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['xlsx', 'xls', 'csv'],
                            );
                            if (result != null) {
                              setState(() {
                                _uploadedFile = File(result.files.single.path!);
                                _selectedFileName = result.files.single.name;
                              });
                              setDialogState(() {});
                            }
                          },
                          child: Text('Browse'),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Supported: Excel (.xlsx, .xls) or CSV. Columns: Student ID, Full Name, Course, Year Level, Email',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                  ),
                  if (_isUploading) ...[
                    SizedBox(height: 16),
                    LinearProgressIndicator(color: UpriseColors.primaryDark),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
              ElevatedButton(
                onPressed: _isUploading || _uploadedFile == null
                    ? null
                    : () async {
                        setState(() => _isUploading = true);
                        try {
                          List<Map<String, String>> students = await _parseFile(_uploadedFile!);
                          if (students.isEmpty) throw Exception('No valid data');
                          int success = 0, failed = 0;
                          for (var student in students) {
                            try {
                              await _createStudentAccount(student);
                              success++;
                            } catch (e) {
                              failed++;
                            }
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Upload complete: $success created, $failed failed')),
                          );
                          setState(() {
                            _uploadedFile = null;
                            _selectedFileName = '';
                          });
                          Navigator.pop(context);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        } finally {
                          setState(() => _isUploading = false);
                        }
                      },
                style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
                child: Text('Upload & Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- File parsing ----------
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

  // ---------- Account creation & email ----------
  Future<void> _createStudentAccount(Map<String, String> student) async {
    String email = student['email']!;
    String studentId = student['studentId']!;
    String fullName = student['fullName']!;
    String password = _generateRandomPassword();

    FirebaseApp secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(name: 'secondaryApp', options: Firebase.app().options);
    } catch (e) {
      secondaryApp = Firebase.app('secondaryApp');
    }
    FirebaseAuth secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
    UserCredential userCred;
    try {
      userCred = await secondaryAuth.createUserWithEmailAndPassword(email: email, password: password);
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
      'tempPassword': password,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': userCred.user!.uid,
    });
    await secondaryAuth.signOut();
    await _sendCredentialsEmail(email, studentId, password);
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%&*';
    String random = List.generate(12, (index) => chars[DateTime.now().millisecondsSinceEpoch % chars.length]).join();
    return random;
  }

  Future<void> _sendCredentialsEmail(String email, String studentId, String password) async {
    // REPLACE WITH YOUR SMTP CREDENTIALS
    final smtpServer = gmail('your-email@gmail.com', 'your-app-password');
    final message = Message()
      ..from = Address('your-email@gmail.com', 'UPRISE Admin')
      ..recipients.add(email)
      ..subject = 'Welcome to UPRISE - Your Student Credentials'
      ..html = '''
        <h2 style="color:#BE4700;">UPRISE Student Account</h2>
        <p><strong>Student ID:</strong> $studentId</p>
        <p><strong>Email:</strong> $email</p>
        <p><strong>Password:</strong> $password</p>
        <p>Login at: <a href="https://your-app.com/login">UPRISE Portal</a></p>
        <p>Please change your password after first login.</p>
      ''';
    try {
      await send(message, smtpServer);
    } catch (e) {
      print('Email send failed: $e');
    }
  }

  void _showManualAddDialog() {
    _manualIdController.clear();
    _manualNameController.clear();
    _manualCourse = 'BSIT';
    _manualYearController.clear();
    _manualEmailController.clear();
    _manualStatus = 'pending';

    showDialog(
      context: context,
      barrierDismissible: false,
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
                    TextFormField(controller: _manualIdController, decoration: InputDecoration(labelText: 'Student ID'), validator: (v) => v!.isEmpty ? 'Required' : null),
                    SizedBox(height: 12),
                    TextFormField(controller: _manualNameController, decoration: InputDecoration(labelText: 'Full Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _manualCourse,
                      items: ['BSIT', 'BSIS', 'BLIS'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setDialogState(() => _manualCourse = v!),
                      decoration: InputDecoration(labelText: 'Course'),
                    ),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _manualYearController.text.isNotEmpty ? _manualYearController.text : null,
                      items: ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year'].map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                      onChanged: (v) => _manualYearController.text = v!,
                      decoration: InputDecoration(labelText: 'Year Level'),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    SizedBox(height: 12),
                    TextFormField(controller: _manualEmailController, decoration: InputDecoration(labelText: 'Email'), validator: (v) => v!.isEmpty || !v.contains('@') ? 'Valid email required' : null),
                    SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _manualStatus,
                      items: ['pending', 'verified'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                      onChanged: (v) => setDialogState(() => _manualStatus = v!),
                      decoration: InputDecoration(labelText: 'Status'),
                    ),
                    if (_errorMessage != null) Text(_errorMessage!, style: TextStyle(color: UpriseColors.error)),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: _isCreating ? null : () => Navigator.pop(context), child: Text('Cancel')),
              ElevatedButton(
                onPressed: _isCreating
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          setDialogState(() => _isCreating = true);
                          try {
                            final student = {
                              'studentId': _manualIdController.text.trim(),
                              'fullName': _manualNameController.text.trim(),
                              'course': _manualCourse,
                              'yearLevel': _manualYearController.text.trim(),
                              'email': _manualEmailController.text.trim(),
                            };
                            await _createStudentAccount(student);
                            if (_manualStatus == 'verified') {
                              final query = await FirebaseFirestore.instance.collection('students').where('email', isEqualTo: student['email']).get();
                              if (query.docs.isNotEmpty) await query.docs.first.reference.update({'status': 'verified'});
                            }
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Student account created')));
                            setState(() {});
                          } catch (e) {
                            setDialogState(() => _errorMessage = e.toString());
                          } finally {
                            setDialogState(() => _isCreating = false);
                          }
                        }
                      },
                child: _isCreating ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportToCSV() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('students').get();
      var docs = snapshot.docs;
      // Apply same filters
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
        docs = docs.where((doc) => (doc.data() as Map)['status'] == _statusFilter).toList();
      }
      if (_courseFilter != 'All') {
        docs = docs.where((doc) => (doc.data() as Map)['course'] == _courseFilter).toList();
      }
      List<List<dynamic>> rows = [['Student ID', 'Full Name', 'Course', 'Year Level', 'Email', 'Status']];
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        rows.add([data['studentId'] ?? '', data['fullName'] ?? '', data['course'] ?? '', data['yearLevel'] ?? '', data['email'] ?? '', data['status'] ?? 'pending']);
      }
      String csv = const ListToCsvConverter().convert(rows);
      final file = File('${Directory.systemTemp.path}/students_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Student list export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
    }
  }
}