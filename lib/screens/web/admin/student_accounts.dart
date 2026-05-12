import 'dart:io';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart'; // For XFile
import '../../theme/app_theme.dart';

// ============ ACTIVITY LOGGER (unchanged, works) ============
class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email ?? 'Unknown User';
    await _firestore.collection('activity_logs').add({
      'user': userName,
      'action': action,
      'module': module,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '',
      'details': details,
    });
  }
}

class StudentAccounts extends StatefulWidget {
  const StudentAccounts({super.key});

  @override
  _StudentAccountsState createState() => _StudentAccountsState();
}

class _StudentAccountsState extends State<StudentAccounts> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';      // All, pending, verified
  String _courseFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  // For batch import
  File? _uploadedFile;
  String _selectedFileName = '';
  bool _isUploading = false;

  // For manual add
  final _formKey = GlobalKey<FormState>();
  final _manualIdController = TextEditingController();
  final _manualNameController = TextEditingController();
  String _manualCourse = 'BSIT';
  final _manualYearController = TextEditingController();
  final _manualEmailController = TextEditingController();
  String _manualStatus = 'pending';

  @override
  void dispose() {
    _searchController.dispose();
    _manualIdController.dispose();
    _manualNameController.dispose();
    _manualYearController.dispose();
    _manualEmailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsRow(),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------- HEADER ----------
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Student Accounts',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
                const SizedBox(height: 4),
                Text('Manage and verify student accounts. Batch import via Excel/CSV or add manually.',
                    style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _showUploadDialog,
            icon: const Icon(Icons.upload_file),
            label: const Text('Batch Import'),
            style: ElevatedButton.styleFrom(
              backgroundColor: UpriseColors.primaryDark,
              foregroundColor: UpriseColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- REAL‑TIME STATS ROW ----------
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, verified = 0;
        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (var doc in snapshot.data!.docs) {
            final status = (doc.data() as Map)['status'] ?? 'pending';
            if (status == 'pending') pending++;
            else if (status == 'verified') verified++;
          }
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            _statCard('TOTAL STUDENTS', '$total', UpriseColors.primaryDark),
            const SizedBox(width: 16),
            _statCard('PENDING', '$pending', UpriseColors.warning),
            const SizedBox(width: 16),
            _statCard('VERIFIED', '$verified', UpriseColors.success),
          ]),
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ---------- TOOLBAR ----------
  Widget _buildToolbar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return Column(
              children: [
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID, or email...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                      prefixIcon: const Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                      filled: true,
                      fillColor: UpriseColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: UpriseColors.mediumGray),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (_) => setState(() => _currentPage = 1),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildFilterDropdown(
                      label: 'Status', value: _statusFilter,
                      items: const ['All', 'Pending', 'Verified'],
                      onChanged: (val) => setState(() { _statusFilter = val!; _currentPage = 1; }),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _buildCourseDropdown()),
                    const SizedBox(width: 12),
                    _buildExportButton(),
                    const SizedBox(width: 12),
                    _buildManualAddButton(),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by name, ID, or email...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                      prefixIcon: const Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                      filled: true,
                      fillColor: UpriseColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: UpriseColors.mediumGray),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (_) => setState(() => _currentPage = 1),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              _buildFilterDropdown(
                label: 'Status', value: _statusFilter,
                items: const ['All', 'Pending', 'Verified'],
                onChanged: (val) => setState(() { _statusFilter = val!; _currentPage = 1; }),
              ),
              const SizedBox(width: 12),
              _buildCourseDropdown(),
              const SizedBox(width: 12),
              _buildExportButton(),
              const SizedBox(width: 12),
              _buildManualAddButton(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((item) {
                final display = item == 'All' ? 'All' : item;
                return DropdownMenuItem(
                  value: item,
                  child: Text(display, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                );
              }).toList(),
              onChanged: onChanged,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
              icon: Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseDropdown() {
    return _buildFilterDropdown(
      label: 'Course',
      value: _courseFilter,
      items: const ['All', 'BSIT', 'BSIS', 'BLIS'],
      onChanged: (val) => setState(() { _courseFilter = val!; _currentPage = 1; }),
    );
  }

  Widget _buildExportButton() {
    return OutlinedButton.icon(
      onPressed: _exportToCSV,
      icon: const Icon(Icons.download, size: 18),
      label: const Text('Export CSV'),
      style: OutlinedButton.styleFrom(
        foregroundColor: UpriseColors.primaryDark,
        side: BorderSide(color: UpriseColors.primaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildManualAddButton() {
    return ElevatedButton.icon(
      onPressed: _showManualAddDialog,
      icon: const Icon(Icons.person_add),
      label: const Text('Add Manually'),
      style: ElevatedButton.styleFrom(
        backgroundColor: UpriseColors.white,
        foregroundColor: UpriseColors.primaryDark,
        side: BorderSide(color: UpriseColors.primaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ---------- TABLE ----------
  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double w = constraints.maxWidth;
            final double colId      = w * 0.13;
            final double colName    = w * 0.17;
            final double colCourse  = w * 0.08;
            final double colYear    = w * 0.09;
            final double colEmail   = w * 0.24;
            final double colStatus  = w * 0.12;
            final double colActions = w * 0.17;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 400, child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return SizedBox(
                      height: 400,
                      child: Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: UpriseColors.error))));
                }

                var docs = snapshot.data!.docs;

                final term = _searchController.text.trim().toLowerCase();
                if (term.isNotEmpty) {
                  docs = docs.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return (d['fullName']?.toLowerCase() ?? '').contains(term) ||
                        (d['studentId']?.toLowerCase() ?? '').contains(term) ||
                        (d['email']?.toLowerCase() ?? '').contains(term);
                  }).toList();
                }
                if (_statusFilter != 'All') {
                  docs = docs.where((doc) {
                    final status = (doc.data() as Map)['status'] ?? 'pending';
                    return status == _statusFilter.toLowerCase();
                  }).toList();
                }
                if (_courseFilter != 'All') {
                  docs = docs
                      .where((doc) => (doc.data() as Map)['course'] == _courseFilter)
                      .toList();
                }

                Widget header = _buildTableHeader(colId, colName, colCourse, colYear, colEmail, colStatus, colActions);

                if (docs.isEmpty) {
                  return Column(children: [
                    header,
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.filter_alt_off, size: 64, color: UpriseColors.mediumGray),
                            SizedBox(height: 16),
                            Text('No students match the filters', style: TextStyle(color: UpriseColors.darkGray)),
                          ],
                        ),
                      ),
                    ),
                  ]);
                }

                final totalPages = (docs.length / _pageSize).ceil().clamp(1, 99999);
                final safePage = _currentPage.clamp(1, totalPages);
                final start = (safePage - 1) * _pageSize;
                final end = (start + _pageSize).clamp(0, docs.length);
                final pageDocs = docs.sublist(start, end);

                return Column(children: [
                  header,
                  Expanded(
                    child: ListView.builder(
                      itemCount: pageDocs.length,
                      itemBuilder: (context, index) {
                        final doc = pageDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final status = data['status'] ?? 'pending';
                        final bool isPending = status == 'pending';
                        final Color badgeBg = isPending
                            ? Colors.orange.withOpacity(0.15)
                            : UpriseColors.success.withOpacity(0.1);
                        final Color badgeText = isPending
                            ? Colors.orange.shade800
                            : UpriseColors.success;

                        return Container(
                          height: 56,
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
                          ),
                          child: Row(
                            children: [
                              _cell(colId, child: Text(data['studentId'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              _cell(colName, child: Text(data['fullName'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                              _cell(colCourse, child: Text(data['course'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              _cell(colYear, child: Text(data['yearLevel'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              _cell(colEmail, child: Text(data['email'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13), overflow: TextOverflow.ellipsis)),
                              SizedBox(
                                width: colStatus,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: badgeBg,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      status.toUpperCase(),
                                      style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: badgeText),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: colActions,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _iconBtn(
                                      icon: Icons.key,
                                      color: UpriseColors.primaryDark,
                                      tip: 'View Password',
                                      onTap: () => _showPasswordDialog(data['studentId'], data['tempPassword']),
                                    ),
                                    _iconBtn(
                                      icon: Icons.email_outlined,
                                      color: UpriseColors.primaryDark,
                                      tip: 'Resend Credentials',
                                      onTap: () => _resendCredentials(doc.id, data['email'], data['studentId'], data['tempPassword']),
                                    ),
                                    _iconBtn(
                                      icon: Icons.verified_outlined,
                                      color: status != 'verified' ? UpriseColors.success : UpriseColors.mediumGray,
                                      tip: 'Verify',
                                      onTap: status != 'verified' ? () => _verifyStudent(doc.id) : null,
                                    ),
                                    _iconBtn(
                                      icon: Icons.delete_outline,
                                      color: UpriseColors.error,
                                      tip: 'Delete',
                                      onTap: () => _deleteStudent(doc.id, data['email']),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  _buildFooter(docs.length, totalPages, start, end),
                ]);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _cell(double width, {required Widget child}) {
    return SizedBox(width: width, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: child));
  }

  Widget _iconBtn({required IconData icon, required Color color, required String tip, VoidCallback? onTap}) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: Icon(icon, size: 18, color: onTap == null ? UpriseColors.mediumGray : color),
        ),
      ),
    );
  }

  Widget _buildTableHeader(double colId, double colName, double colCourse, double colYear, double colEmail, double colStatus, double colActions) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: UpriseColors.lightGray,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        children: [
          _cell(colId, child: Text('STUDENT ID', style: _headerStyle())),
          _cell(colName, child: Text('FULL NAME', style: _headerStyle())),
          _cell(colCourse, child: Text('COURSE', style: _headerStyle())),
          _cell(colYear, child: Text('YEAR', style: _headerStyle())),
          _cell(colEmail, child: Text('EMAIL', style: _headerStyle())),
          SizedBox(width: colStatus, child: Center(child: Text('STATUS', style: _headerStyle()))),
          SizedBox(width: colActions, child: Center(child: Text('ACTIONS', style: _headerStyle()))),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.6);
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
        color: UpriseColors.lightGray,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total students',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
          Row(children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              color: _currentPage > 1 ? UpriseColors.charcoal : UpriseColors.mediumGray,
              onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
            ),
            ...pages.map((page) => GestureDetector(
                  onTap: () => setState(() => _currentPage = page),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: page == _currentPage ? UpriseColors.primaryDark : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$page',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: page == _currentPage ? Colors.white : UpriseColors.charcoal,
                          fontWeight: page == _currentPage ? FontWeight.w600 : FontWeight.normal,
                        )),
                  ),
                )),
            if (lastPage < totalPages) ...[
              Text('...', style: TextStyle(color: UpriseColors.darkGray)),
              GestureDetector(
                onTap: () => setState(() => _currentPage = totalPages),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text('$totalPages',
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.charcoal)),
                ),
              ),
            ],
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              color: _currentPage < totalPages ? UpriseColors.charcoal : UpriseColors.mediumGray,
              onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
            ),
          ]),
        ],
      ),
    );
  }

  // ---------- ACTIONS WITH ACTIVITY LOGGING ----------
  void _showPasswordDialog(String studentId, String? password) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Student Credentials'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student ID: $studentId', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Password:'),
            const SizedBox(height: 4),
            SelectableText(
              password ?? 'No password stored. Use "Resend Credentials" to generate a new one.',
              style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w500, color: UpriseColors.primaryDark),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _resendCredentials(String docId, String email, String studentId, String? existingPassword) async {
    String password = existingPassword ?? _generateRandomPassword();
    await FirebaseFirestore.instance.collection('students').doc(docId).update({'tempPassword': password});
    await _sendCredentialsEmail(email, studentId, password);
    await ActivityLogger.log(
      action: 'Resent credentials for student: $studentId ($email)',
      module: 'User Directory',
      severity: 'info',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Credentials resent to $email')));
    }
  }

  Future<void> _verifyStudent(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('students').doc(docId).update({'status': 'verified'});
      final doc = await FirebaseFirestore.instance.collection('students').doc(docId).get();
      final studentId = doc.data()?['studentId'] ?? 'Unknown';
      await ActivityLogger.log(
        action: 'Verified student account: $studentId',
        module: 'User Directory',
        severity: 'info',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student account verified')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _deleteStudent(String docId, String email) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Student Account'),
        content: const Text('Are you sure you want to delete this student account? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                final doc = await FirebaseFirestore.instance.collection('students').doc(docId).get();
                final studentId = doc.data()?['studentId'] ?? 'Unknown';
                await FirebaseFirestore.instance.collection('students').doc(docId).delete();
                await ActivityLogger.log(
                  action: 'Deleted student account: $studentId ($email)',
                  module: 'User Directory',
                  severity: 'info',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student record deleted')));
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------- BATCH IMPORT (fixed setState vs setDialogState) ----------
  void _showUploadDialog() {
    _selectedFileName = '';
    _uploadedFile = null;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.upload_file, color: UpriseColors.primaryDark),
              const SizedBox(width: 8),
              Text('Batch Import Students', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            ]),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: UpriseColors.lightGray,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: UpriseColors.mediumGray),
                    ),
                    child: Row(children: [
                      Icon(Icons.description, color: UpriseColors.primaryDark),
                      const SizedBox(width: 12),
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
                            // ✅ Use setDialogState to update dialog state (not outer setState)
                            setDialogState(() {
                              _uploadedFile = File(result.files.single.path!);
                              _selectedFileName = result.files.single.name;
                            });
                          }
                        },
                        child: const Text('Browse'),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supported: Excel (.xlsx, .xls) or CSV. Columns: Student ID, Full Name, Course, Year Level, Email',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                  ),
                  if (_isUploading) ...[
                    const SizedBox(height: 16),
                    LinearProgressIndicator(color: UpriseColors.primaryDark),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: _isUploading || _uploadedFile == null ? null : () async {
                  // Use setState for outer loading indicator, but dialog is still open
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
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Upload complete: $success created, $failed failed')));
                    }
                    setState(() {
                      _uploadedFile = null;
                      _selectedFileName = '';
                    });
                    Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  } finally {
                    setState(() => _isUploading = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
                child: const Text('Upload & Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<Map<String, String>>> _parseFile(File file) async {
    List<Map<String, String>> students = [];
    final extension = file.path.split('.').last.toLowerCase();
    if (extension == 'csv') {
      final csvString = await file.readAsString();
      final rows = const CsvToListConverter().convert(csvString);
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
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
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      for (var table in excel.tables.keys) {
        final sheet = excel.tables[table];
        for (int i = 1; i < sheet!.rows.length; i++) {
          final row = sheet.rows[i];
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

  // ---------- ACCOUNT CREATION & EMAIL (FIXED: secondary app + Firestore mail) ----------
  Future<void> _createStudentAccount(Map<String, String> student) async {
    final email = student['email']!;
    final studentId = student['studentId']!;
    final fullName = student['fullName']!;
    final password = _generateRandomPassword();

    // ✅ FIX #1: Properly check for existing secondary app
    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('secondaryApp');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'secondaryApp',
        options: Firebase.app().options,
      );
    }
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
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
    await ActivityLogger.log(
      action: 'Created student account: $studentId ($email)',
      module: 'User Directory',
      severity: 'info',
    );
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#%&*';
    final random = Random();
    return List.generate(12, (index) => chars[random.nextInt(chars.length)]).join();
  }

  // ✅ FIX #4: Replace SMTP with Firestore mail collection (works with Firebase Extensions or Cloud Function)
  Future<void> _sendCredentialsEmail(String email, String studentId, String password) async {
    try {
      await FirebaseFirestore.instance.collection('mail').add({
        'to': [email],
        'message': {
          'subject': 'UPRISE — Your Student Login Credentials',
          'html': '''
            <div style="font-family:sans-serif;max-width:480px;margin:auto;">
              <div style="background:linear-gradient(135deg,#D97706,#B45309);padding:24px 32px;border-radius:12px 12px 0 0;">
                <h1 style="color:white;margin:0;letter-spacing:2px;font-size:22px;">UPRISE</h1>
                <p style="color:rgba(255,255,255,0.85);margin:4px 0 0;font-size:12px;">CICT Student Portal</p>
              </div>
              <div style="padding:24px 32px;border:1px solid #FDE68A;border-top:none;border-radius:0 0 12px 12px;">
                <p style="color:#1E293B;">Your student account has been created.</p>
                <div style="background:#FFF7ED;border:1px solid #FDE68A;border-radius:8px;padding:16px;margin:16px 0;">
                  <p style="margin:0 0 8px;font-size:11px;color:#92400E;font-weight:700;letter-spacing:1px;">LOGIN CREDENTIALS</p>
                  <table style="font-size:13px;color:#1E293B;width:100%;">
                    <tr><td style="color:#64748B;padding:4px 0;width:100px;">Student ID</td><td style="font-weight:600;">$studentId</td></tr>
                    <tr><td style="color:#64748B;padding:4px 0;">Email</td><td style="font-weight:600;">$email</td></tr>
                    <tr><td style="color:#64748B;padding:4px 0;">Password</td><td style="font-weight:700;font-family:monospace;font-size:15px;color:#B45309;">$password</td></tr>
                  </table>
                </div>
                <p style="color:#94A3B8;font-size:11px;">Please change your password after first login.</p>
              </div>
            </div>
          ''',
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Failed to queue email: $e');
    }
  }

  // ---------- MANUAL ADD DIALOG (FIXED: isCreating/errorMessage moved outside builder) ----------
  void _showManualAddDialog() {
    _manualIdController.clear();
    _manualNameController.clear();
    _manualCourse = 'BSIT';
    _manualYearController.clear();
    _manualEmailController.clear();
    _manualStatus = 'pending';

    // ✅ FIX #2: These belong to the outer function, not inside StatefulBuilder
    bool isCreating = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(children: [
              Icon(Icons.person_add, color: UpriseColors.primaryDark),
              const SizedBox(width: 8),
              Text('Add Student Manually', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            ]),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _manualIdController,
                      decoration: const InputDecoration(labelText: 'Student ID'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _manualNameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _manualCourse,
                      items: const ['BSIT', 'BSIS', 'BLIS']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setDialogState(() => _manualCourse = v!),
                      decoration: const InputDecoration(labelText: 'Course'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _manualYearController.text.isNotEmpty ? _manualYearController.text : null,
                      items: const ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year']
                          .map((y) => DropdownMenuItem(value: y, child: Text(y)))
                          .toList(),
                      onChanged: (v) => _manualYearController.text = v!,
                      decoration: const InputDecoration(labelText: 'Year Level'),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _manualEmailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                      validator: (v) => v!.isEmpty || !v.contains('@') ? 'Valid email required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _manualStatus,
                      items: const ['pending', 'verified'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                      onChanged: (v) => setDialogState(() => _manualStatus = v!),
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(errorMessage!, style: TextStyle(color: UpriseColors.error)),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: isCreating ? null : () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: isCreating
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          // Update dialog state to show loading
                          setDialogState(() => isCreating = true);
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
                              final query = await FirebaseFirestore.instance
                                  .collection('students')
                                  .where('email', isEqualTo: student['email'])
                                  .get();
                              if (query.docs.isNotEmpty) {
                                await query.docs.first.reference.update({'status': 'verified'});
                              }
                            }
                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Student account created')));
                              setState(() {}); // refresh table
                            }
                          } catch (e) {
                            setDialogState(() => errorMessage = e.toString());
                          } finally {
                            setDialogState(() => isCreating = false);
                          }
                        }
                      },
                child: isCreating
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Create Account'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------- EXPORT CSV ----------
  Future<void> _exportToCSV() async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('students').get();
      var docs = snapshot.docs;
      final term = _searchController.text.trim().toLowerCase();
      if (term.isNotEmpty) {
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return (data['fullName']?.toLowerCase() ?? '').contains(term) ||
              (data['studentId']?.toLowerCase() ?? '').contains(term) ||
              (data['email']?.toLowerCase() ?? '').contains(term);
        }).toList();
      }
      if (_statusFilter != 'All') {
        docs = docs.where((doc) => (doc.data() as Map)['status'] == _statusFilter.toLowerCase()).toList();
      }
      if (_courseFilter != 'All') {
        docs = docs.where((doc) => (doc.data() as Map)['course'] == _courseFilter).toList();
      }
      final rows = <List<dynamic>>[
        ['Student ID', 'Full Name', 'Course', 'Year Level', 'Email', 'Status']
      ];
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        rows.add([
          data['studentId'] ?? '',
          data['fullName'] ?? '',
          data['course'] ?? '',
          data['yearLevel'] ?? '',
          data['email'] ?? '',
          data['status'] ?? 'pending'
        ]);
      }
      final csv = const ListToCsvConverter().convert(rows);
      final file = File('${Directory.systemTemp.path}/students_export.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path)], text: 'Student list export');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}