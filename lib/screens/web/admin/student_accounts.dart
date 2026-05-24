// ignore_for_file: unused_field, duplicate_ignore, use_build_context_synchronously, deprecated_member_use
import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:csv/csv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../theme/app_theme.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (mirrors org_management.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm  = 8;
  static const double radiusMd  = 12;
  static const double radiusLg  = 16;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
          : null,
      labelStyle: GoogleFonts.beVietnamPro(
          fontSize: 13, color: const Color(0xFF64748B)),
      hintStyle: GoogleFonts.beVietnamPro(
          fontSize: 13, color: const Color(0xFF9AA5B4)),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide:
            const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide:
            const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide:
            BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide:
            BorderSide(color: UpriseColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide:
            BorderSide(color: UpriseColors.error, width: 1.5),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────

Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: UpriseColors.primaryDark),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: UpriseColors.primaryDark,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Divider(
                color: const Color(0xFFE2E6EA), thickness: 1)),
      ],
    ),
  );
}

// Status badge — mirrors org_management
Widget _statusBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'verified': _BadgeStyle(
        const Color(0xFFECFDF5), const Color(0xFF059669), 'VERIFIED'),
    'pending': _BadgeStyle(
        const Color(0xFFFFFBEB), const Color(0xFFD97706), 'PENDING'),
    'suspended': _BadgeStyle(
        const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'SUSPENDED'),
  };
  final s = styles[status.toLowerCase()] ??
      _BadgeStyle(const Color(0xFFF3F4F6), const Color(0xFF6B7280),
          status.toUpperCase());
  return Container(
    padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: s.bg,
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Text(
      s.label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: s.fg,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class StudentAccounts extends StatefulWidget {
  const StudentAccounts({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _StudentAccountsState createState() => _StudentAccountsState();
}

class _StudentAccountsState extends State<StudentAccounts> {
  final TextEditingController _searchController =
      TextEditingController();
  String _statusFilter = 'All';
  String _courseFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, verified = 0;
        if (snapshot.hasData) {
          total = snapshot.data!.docs.length;
          for (final doc in snapshot.data!.docs) {
            final status =
                (doc.data() as Map)['status'] ?? 'pending';
            if (status == 'pending') pending++;
            if (status == 'verified') verified++;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(
              label: 'Total Students',
              value: '$total',
              icon: Icons.school_rounded,
              color: UpriseColors.primaryDark,
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Verified',
              value: '$verified',
              icon: Icons.verified_rounded,
              color: const Color(0xFF059669),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Pending',
              value: '$pending',
              icon: Icons.pending_rounded,
              color: const Color(0xFFD97706),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Unverified',
              value: '${total - verified - pending}',
              icon: Icons.block_rounded,
              color: const Color(0xFF6B7280),
            ),
          ]),
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.beVietnamPro(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search by name, ID, or email…',
                  hintStyle: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: const Color(0xFF9AA5B4)),
                  prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: Color(0xFF9AA5B4)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E6EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E6EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: UpriseColors.primaryDark,
                        width: 1.5),
                  ),
                ),
                onChanged: (_) =>
                    setState(() => _currentPage = 1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _statusFilter,
            items: const [
              'All',
              'Verified',
              'Pending',
              'Suspended'
            ],
            hint: 'Status',
            icon: Icons.tune_rounded,
            onChanged: (v) => setState(() {
              _statusFilter = v!;
              _currentPage = 1;
            }),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _courseFilter,
            items: const [
              'All',
              'BSIT',
              'BSIS',
              'BLIS'
            ],
            hint: 'Course',
            icon: Icons.school_outlined,
            onChanged: (v) => setState(() {
              _courseFilter = v!;
              _currentPage = 1;
            }),
          ),
          const SizedBox(width: 10),
          _ExportStudentsButton(
            statusFilter: _statusFilter,
            courseFilter: _courseFilter,
            searchTerm: _searchController.text.trim(),
          ),
          const SizedBox(width: 10),
          _ToolbarButton(
            label: 'Email Queue',
            icon: Icons.email_outlined,
            onPressed: _showEmailQueueDialog,
            outlined: true,
          ),
          const SizedBox(width: 10),
          // Batch import
          _ToolbarButton(
            label: 'Batch Import',
            icon: Icons.upload_file_rounded,
            onPressed: _showBatchImportDialog,
            outlined: true,
          ),
          const SizedBox(width: 10),
          // Add manually
          _ToolbarButton(
            label: 'Add Student',
            icon: Icons.person_add_rounded,
            onPressed: _showManualAddDialog,
          ),
        ],
      ),
    );
  }

  void _showEmailQueueDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: 720,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                const Icon(Icons.email_outlined, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Queued Credential Emails', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ]),
              const SizedBox(height: 8),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('email_queue').orderBy('createdAt', descending: false).snapshots(),
                builder: (c, snap) {
                  if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                  if (!snap.hasData || snap.data!.docs.isEmpty) return Padding(padding: const EdgeInsets.all(24), child: Text('No queued emails', style: GoogleFonts.beVietnamPro()));
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: snap.data!.docs.length,
                      itemBuilder: (_, i) {
                        final doc = snap.data!.docs[i];
                        final data = doc.data() as Map<String, dynamic>;
                        return ListTile(
                          title: Text(data['to_email'] ?? '—', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('Student ID: ${data['student_id'] ?? ''} • Attempts: ${data['attempts'] ?? 0}', style: GoogleFonts.beVietnamPro(fontSize: 12)),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            TextButton(
                              onPressed: () async {
                                final sent = await _sendCredentialsEmail(data['to_email'], data['student_id'], data['password']);
                                if (sent) {
                                  await doc.reference.delete();
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to ${data['to_email']}'), backgroundColor: const Color(0xFF059669)));
                                } else {
                                  await doc.reference.update({'attempts': (data['attempts'] ?? 0) + 1, 'updatedAt': FieldValue.serverTimestamp()});
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed for ${data['to_email']}, will retry later.'), backgroundColor: const Color(0xFFF59E0B)));
                                }
                              },
                              child: const Text('Retry'),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                await doc.reference.delete();
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed ${data['to_email']} from queue.')));
                              },
                              child: const Text('Delete'),
                            ),
                          ]),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('students')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
              child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data!.docs;

        // Filters
        final term =
            _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['fullName'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(term) ||
                (data['studentId'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(term) ||
                (data['email'] ?? '')
                    .toString()
                    .toLowerCase()
                    .contains(term);
          }).toList();
        }
        if (_statusFilter != 'All') {
          docs = docs
              .where((d) =>
                  (d.data() as Map)['status'] ==
                  _statusFilter.toLowerCase())
              .toList();
        }
        if (_courseFilter != 'All') {
          docs = docs
              .where((d) =>
                  (d.data() as Map)['course'] == _courseFilter)
              .toList();
        }

        final totalPages =
            docs.isEmpty ? 1 : (docs.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end =
            (start + _pageSize).clamp(0, docs.length);
        final pageDocs = docs.isEmpty
            ? <QueryDocumentSnapshot>[]
            : docs.sublist(start, end);

        return Container(
          margin:
              const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(
            children: [
              // Table header
              _buildTableHeader(),
              // Table body
              Expanded(
                child: docs.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: pageDocs.length,
                        itemBuilder: (_, i) {
                          final data = pageDocs[i].data()
                              as Map<String, dynamic>;
                          return _buildStudentRow(
                            docId: pageDocs[i].id,
                            data: data,
                            isLast:
                                i == pageDocs.length - 1,
                          );
                        },
                      ),
              ),
              // Footer pagination
              _buildFooter(
                  docs.length, totalPages, start, end),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(14)),
        border: Border(
            bottom:
                BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: _headerCell('STUDENT ID')),
        Expanded(flex: 3, child: _headerCell('FULL NAME')),
        Expanded(flex: 2, child: _headerCell('COURSE')),
        Expanded(flex: 1, child: _headerCell('YEAR')),
        Expanded(flex: 3, child: _headerCell('EMAIL')),
        Expanded(flex: 1, child: _headerCell('STATUS')),
        Expanded(
            flex: 2,
            child: Align(
                alignment: Alignment.centerRight,
                child: _headerCell('ACTIONS'))),
      ]),
    );
  }

  Widget _headerCell(String text) => Text(
        text,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF64748B),
          letterSpacing: 0.7,
        ),
      );

  Widget _buildStudentRow({
    required String docId,
    required Map<String, dynamic> data,
    required bool isLast,
  }) {
    final status = (data['status'] ?? 'pending') as String;
    return InkWell(
      hoverColor: const Color(0xFFF8F9FB),
      onTap: () => _showStudentDetailDialog(docId, data),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(
                      color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // Student ID
            Expanded(
              flex: 2,
              child: Text(
                data['studentId'] ?? '—',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: UpriseColors.primaryDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Full name with avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  _StudentAvatar(
                      name: data['fullName'] ?? ''),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      data['fullName'] ?? '—',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A202C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // Course
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark
                      // ignore: deprecated_member_use
                      .withOpacity(0.07),
                  borderRadius:
                      BorderRadius.circular(6),
                ),
                child: Text(
                  data['course'] ?? '—',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: UpriseColors.primaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Year
            Expanded(
              flex: 1,
              child: Text(
                data['yearLevel'] ?? '—',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: const Color(0xFF64748B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Email
            Expanded(
              flex: 3,
              child: Text(
                data['email'] ?? '—',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: const Color(0xFF374151)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Status
            Expanded(
                flex: 1, child: _statusBadge(status)),
            // Actions
            Expanded(
              flex: 2,
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  _ActionIconButton(
                    icon: Icons.key_rounded,
                    tooltip: 'View Credentials',
                    onTap: () => _showPasswordDialog(
                        data['studentId'] ?? '',
                        data['tempPassword']),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.email_outlined,
                    tooltip: 'Resend Credentials',
                    onTap: () => _resendCredentials(
                      docId,
                      data['email'] ?? '',
                      data['studentId'] ?? '',
                      data['tempPassword'],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.verified_outlined,
                    tooltip: status == 'verified'
                        ? 'Already Verified'
                        : 'Verify Student',
                    color: status == 'verified'
                        ? const Color(0xFF9AA5B4)
                        : const Color(0xFF059669),
                    onTap: status != 'verified'
                        ? () => _verifyStudent(docId)
                        : null,
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.delete_outline_rounded,
                    tooltip: 'Delete',
                    color: const Color(0xFFDC2626),
                    onTap: () => _confirmDeleteStudent(
                        docId,
                        data['email'] ?? '',
                        data['fullName'] ?? 'this student'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.school_rounded,
                size: 40,
                color: Color(0xFF9AA5B4)),
          ),
          const SizedBox(height: 16),
          Text(
            'No students found',
            style: GoogleFonts.beVietnamPro(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters or add a new student.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(
      int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage =
        (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage =
        (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible &&
        firstPage > 1) {
      firstPage =
          (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(
        lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
            top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total students',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: const Color(0xFF64748B)),
          ),
          Row(children: [
            _PageButton(
              icon: Icons.chevron_left_rounded,
              enabled: _currentPage > 1,
              onTap: () =>
                  setState(() => _currentPage--),
            ),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumButton(
                  page: p,
                  isActive: p == _currentPage,
                  onTap: () =>
                      setState(() => _currentPage = p),
                )),
            if (lastPage < totalPages) ...[
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 4),
                child: Text('…',
                    style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFF64748B),
                        fontSize: 12)),
              ),
              _PageNumButton(
                page: totalPages,
                isActive: _currentPage == totalPages,
                onTap: () => setState(
                    () => _currentPage = totalPages),
              ),
            ],
            const SizedBox(width: 4),
            _PageButton(
              icon: Icons.chevron_right_rounded,
              enabled: _currentPage < totalPages,
              onTap: () =>
                  setState(() => _currentPage++),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────

  void _showPasswordDialog(
      String studentId, String? password) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(
                    24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
                  borderRadius:
                      const BorderRadius.vertical(
                          top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white
                          // ignore: duplicate_ignore
                          // ignore: deprecated_member_use
                          .withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.key_rounded,
                        color: Colors.white,
                        size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Student Credentials',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20),
                    onPressed: () =>
                        Navigator.pop(ctx),
                  ),
                ]),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _credentialRow(
                      label: 'Student ID',
                      value: studentId.isEmpty
                          ? '—'
                          : studentId,
                      icon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 14),
                    _credentialRow(
                      label: 'Temporary Password',
                      value: password ??
                          'Not stored — use Resend to generate a new one.',
                      icon: Icons.lock_outline_rounded,
                      isPassword: true,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                            color: const Color(
                                0xFFFED7AA)),
                      ),
                      child: Row(children: [
                        const Icon(
                            Icons
                                .info_outline_rounded,
                            size: 15,
                            color:
                                Color(0xFFD97706)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Students are prompted to change their password on first login.',
                            style: GoogleFonts
                                .beVietnamPro(
                              fontSize: 12,
                              color: const Color(
                                  0xFF92400E),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(
                    24, 0, 24, 20),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(ctx),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            UpriseColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape:
                            RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(8)),
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 11),
                      ),
                      child: Text('Done',
                          style: GoogleFonts
                              .beVietnamPro(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight
                                          .w600)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _credentialRow({
    required String label,
    required String value,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon,
              size: 14,
              color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.5)),
        ]),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: const Color(0xFFE2E6EA)),
          ),
          child: SelectableText(
            value,
            style: GoogleFonts.beVietnamPro(
              fontSize: isPassword ? 15 : 14,
              fontWeight: isPassword
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: isPassword
                  ? UpriseColors.primaryDark
                  : const Color(0xFF1A202C),
              letterSpacing: isPassword ? 1.5 : 0,
            ),
          ),
        ),
      ],
    );
  }

  void _showStudentDetailDialog(
      String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(
                    24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
                  borderRadius:
                      const BorderRadius.vertical(
                          top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.15),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['fullName'] ??
                              'Student Details',
                          style:
                              GoogleFonts.beVietnamPro(
                            fontSize: 17,
                            fontWeight:
                                FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          data['studentId'] ?? '',
                          style:
                              GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: Colors.white
                                .withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20),
                    onPressed: () =>
                        Navigator.pop(ctx),
                  ),
                ]),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      Expanded(
                        child: _detailItem(
                            'Student ID',
                            data['studentId'] ?? '—',
                            Icons.badge_outlined),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _detailItem(
                            'Status',
                            (data['status'] ?? 'pending')
                                .toString()
                                .toUpperCase(),
                            Icons.circle_outlined,
                            valueColor: data['status'] ==
                                    'verified'
                                ? const Color(0xFF059669)
                                : const Color(
                                    0xFFD97706)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(
                        child: _detailItem(
                            'Course',
                            data['course'] ?? '—',
                            Icons.school_outlined),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _detailItem(
                            'Year Level',
                            data['yearLevel'] ?? '—',
                            Icons.calendar_today_outlined),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _detailItem(
                        'Email',
                        data['email'] ?? '—',
                        Icons.email_outlined),
                  ],
                ),
              ),
              // Footer actions
              Container(
                padding: const EdgeInsets.fromLTRB(
                    24, 0, 24, 20),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPasswordDialog(
                          data['studentId'] ?? '',
                          data['tempPassword'],
                        );
                      },
                      icon: const Icon(
                          Icons.key_rounded,
                          size: 15),
                      label: Text('Credentials',
                          style:
                              GoogleFonts.beVietnamPro(
                                  fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFE2E6EA)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                                    8)),
                        padding:
                            const EdgeInsets.symmetric(
                                vertical: 11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (data['status'] != 'verified')
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _verifyStudent(docId);
                        },
                        icon: const Icon(
                            Icons.verified_rounded,
                            size: 15),
                        label: Text('Verify',
                            style: GoogleFonts
                                .beVietnamPro(
                                    fontSize: 13,
                                    fontWeight:
                                        FontWeight
                                            .w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                      ),
                    ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value,
      IconData icon,
      {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon,
              size: 13,
              color: const Color(0xFF9AA5B4)),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ??
                const Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }

  Future<void> _resendCredentials(
    String docId,
    String email,
    String studentId,
    String? existingPassword,
  ) async {
    final password =
        existingPassword ?? _generatePassword();
        final sent = await _sendCredentialsEmail(email, studentId, password);
        if (!sent) {
          await _queueCredentialEmail(email, studentId, password);
        }
    await activity_log.ActivityLogger.log(
      action:
          'Resent credentials for student: $studentId ($email)',
      module: 'User Directory',
      severity: 'info',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
                  Text(sent ? 'Credentials resent to $email.' : 'Credentials queued but sending failed for $email.'),
          backgroundColor: sent ? const Color(0xFF059669) : const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _verifyStudent(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(docId)
          .update({'status': 'verified'});
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(docId)
          .get();
      final studentId =
          doc.data()?['studentId'] ?? 'Unknown';
      await activity_log.ActivityLogger.log(
        action:
            'Verified student account: $studentId',
        module: 'User Directory',
        severity: 'info',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Student account verified'),
            backgroundColor:
                const Color(0xFF059669),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: UpriseColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _confirmDeleteStudent(
    String docId,
    String email,
    String name,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 20),
                ),
                const SizedBox(width: 14),
                Text('Delete Student Account',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    )),
              ]),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "$name"? This action cannot be undone.',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                                  8)),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11),
                    ),
                    child: Text('Cancel',
                        style:
                            GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: const Color(
                                    0xFF374151))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final doc =
                            await FirebaseFirestore
                                .instance
                                .collection('students')
                                .doc(docId)
                                .get();
                        final sid =
                            doc.data()?['studentId'] ??
                                'Unknown';
                        await FirebaseFirestore
                            .instance
                            .collection('students')
                            .doc(docId)
                            .delete();
                        await activity_log
                            .ActivityLogger.log(
                          action:
                              'Deleted student: $sid ($email)',
                          module: 'User Directory',
                          severity: 'info',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: const Text(
                                'Student record deleted'),
                            backgroundColor:
                                UpriseColors.primaryDark,
                            behavior: SnackBarBehavior
                                .floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        8)),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor:
                                UpriseColors.error,
                          ));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11),
                    ),
                    child: Text('Delete',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Batch Import Dialog ────────────────────────────────────────────
  void _showBatchImportDialog() {
    XFile? pickedFile;
    String fileName = '';
    bool isUploading = false;
    String? resultMessage;
    bool resultIsError = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          child: SizedBox(
            width: 540,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      24, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark,
                    borderRadius:
                        const BorderRadius.vertical(
                            top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.upload_file_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Batch Import Students',
                        style:
                            GoogleFonts.beVietnamPro(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20),
                      onPressed: isUploading
                          ? null
                          : () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _sectionLabel('Select File',
                          icon: Icons.attach_file_rounded),
                      // File picker zone
                      GestureDetector(
                        onTap: isUploading
                            ? null
                            : () async {
                                final result =
                                    await FilePicker.platform
                                        .pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'xlsx',
                                    'xls',
                                    'csv'
                                  ],
                                );
                                if (result != null) {
                                  setDialogState(() {
                                    if (kIsWeb) {
                                      pickedFile = XFile.fromData(
                                        result.files.single.bytes!,
                                        name: result.files.single.name,
                                        mimeType: 'application/octet-stream',
                                      );
                                    } else {
                                      pickedFile = XFile(result.files.single.path!);
                                    }
                                    fileName = result.files.single.name;
                                    resultMessage = null;
                                  });
                                }
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(
                              20),
                          decoration: BoxDecoration(
                            color: fileName.isEmpty
                                ? const Color(0xFFF8F9FB)
                                : const Color(
                                    0xFFECFDF5),
                            borderRadius:
                                BorderRadius.circular(
                                    10),
                            border: Border.all(
                              color: fileName.isEmpty
                                  ? const Color(
                                      0xFFE2E6EA)
                                  : const Color(
                                      0xFF059669),
                              width: fileName.isEmpty
                                  ? 1
                                  : 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                fileName.isEmpty
                                    ? Icons
                                        .cloud_upload_rounded
                                    : Icons
                                        .check_circle_rounded,
                                size: 36,
                                color: fileName.isEmpty
                                    ? const Color(
                                        0xFF9AA5B4)
                                    : const Color(
                                        0xFF059669),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fileName.isEmpty
                                    ? 'Click to browse or drop your file here'
                                    : fileName,
                                style: GoogleFonts
                                    .beVietnamPro(
                                  fontSize: 13,
                                  fontWeight:
                                      FontWeight.w600,
                                  color: fileName.isEmpty
                                      ? const Color(
                                          0xFF64748B)
                                      : const Color(
                                          0xFF059669),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Supported: .xlsx, .xls, .csv',
                                style: GoogleFonts
                                    .beVietnamPro(
                                  fontSize: 11,
                                  color: const Color(
                                      0xFF9AA5B4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Column guide
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF0F6FF),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(
                                  0xFFBFD7FF)),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                          const Icon(
                              Icons
                                  .info_outline_rounded,
                              size: 15,
                              color:
                                  Color(0xFF2563EB)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Required columns (in order):\nStudent ID · Full Name · Course · Year Level · Email',
                              style: GoogleFonts
                                  .beVietnamPro(
                                fontSize: 12,
                                color: const Color(
                                    0xFF1D4ED8),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ]),
                      ),
                      if (isUploading) ...[
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            backgroundColor: const Color(
                                0xFFE2E6EA),
                            color:
                                UpriseColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('Importing students…',
                            style:
                                GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              color: const Color(
                                  0xFF64748B),
                            )),
                      ],
                      if (resultMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding:
                              const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: resultIsError
                                ? const Color(
                                    0xFFFEF2F2)
                                : const Color(
                                    0xFFECFDF5),
                            borderRadius:
                                BorderRadius.circular(
                                    8),
                            border: Border.all(
                              color: resultIsError
                                  ? const Color(
                                      0xFFFCA5A5)
                                  : const Color(
                                      0xFF6EE7B7),
                            ),
                          ),
                          child: Row(children: [
                            Icon(
                              resultIsError
                                  ? Icons
                                      .error_outline_rounded
                                  : Icons
                                      .check_circle_outline_rounded,
                              size: 16,
                              color: resultIsError
                                  ? const Color(
                                      0xFFDC2626)
                                  : const Color(
                                      0xFF059669),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                resultMessage!,
                                style: GoogleFonts
                                    .beVietnamPro(
                                  fontSize: 12,
                                  color: resultIsError
                                      ? const Color(
                                          0xFF991B1B)
                                      : const Color(
                                          0xFF065F46),
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      24, 0, 24, 20),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color:
                                Color(0xFFE8ECF0))),
                    color: Color(0xFFF8F9FB),
                    borderRadius:
                        BorderRadius.vertical(
                            bottom:
                                Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      TextButton(
                        onPressed: isUploading
                            ? null
                            : () =>
                                Navigator.pop(ctx),
                        child: Text('Cancel',
                            style: GoogleFonts
                                .beVietnamPro(
                              fontSize: 13,
                              color: const Color(
                                  0xFF64748B),
                            )),
                      ),
                      ElevatedButton.icon(
                        onPressed: isUploading ||
                                pickedFile == null
                            ? null
                            : () async {
                                setDialogState(() {
                                  isUploading = true;
                                  resultMessage =
                                      null;
                                });
                                try {
                                  List<
                                      Map<String,
                                          String>> students;
                                  if (kIsWeb) {
                                    students =
                                        await _parseXFile(
                                            pickedFile!);
                                  } else {
                                    students =
                                        await _parseFile(
                                            File(pickedFile!
                                                .path));
                                  }
                                  if (students
                                      .isEmpty) {
                                    throw Exception(
                                        'No valid data found. Check column order.');
                                  }
                                  int success = 0,
                                      failed = 0,
                                      failedEmails = 0;
                                  for (final s in students) {
                                    try {
                                      final cred = await _createStudentAccount(s);
                                      // send credentials email after creation (non-fatal)
                                      try {
                                        final sent = await _sendCredentialsEmail(
                                            cred['email']!, cred['studentId']!, cred['password']!);
                                        if (!sent) {
                                          failedEmails++;
                                          await _queueCredentialEmail(cred['email']!, cred['studentId']!, cred['password']!);
                                        }
                                      } catch (e) {
                                        failedEmails++;
                                        debugPrint("⚠️ Failed to send credentials to ${cred['email']}: $e");
                                      }
                                      success++;
                                    } catch (_) {
                                      failed++;
                                    }
                                  }
                                  setDialogState(
                                      () {
                                    isUploading =
                                        false;
                                    resultMessage =
                                      'Import complete: $success created, $failed skipped.${failedEmails > 0 ? ' $failedEmails credential emails failed to send.' : ''}';
                                    resultIsError =
                                        failed > 0 &&
                                            success ==
                                                0;
                                  });
                                  if (success > 0) {
                                    Future.delayed(
                                      const Duration(
                                          seconds: 2),
                                      () {
                                        if (mounted) {
                                          Navigator.pop(
                                              ctx);
                                          ScaffoldMessenger.of(
                                                  context)
                                              .showSnackBar(SnackBar(
                                            content: Text(
                                                '$success students imported successfully.'),
                                            backgroundColor:
                                                const Color(
                                                    0xFF059669),
                                            behavior:
                                                SnackBarBehavior
                                                    .floating,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                          ));
                                        }
                                      },
                                    );
                                  }
                                } catch (e) {
                                  setDialogState(
                                      () {
                                    isUploading =
                                        false;
                                    resultMessage =
                                        'Error: $e';
                                    resultIsError =
                                        true;
                                  });
                                }
                              },
                        icon: isUploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Colors
                                                .white))
                            : const Icon(
                                Icons
                                    .upload_rounded,
                                size: 16),
                        label: Text(
                          'Upload & Import',
                          style:
                              GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              UpriseColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Manual Add Dialog ─────────────────────────────────────────────
  void _showManualAddDialog() {
    final formKey = GlobalKey<FormState>();
    final idCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    String course = 'BSIT';
    String yearLevel = '1st Year';
    String status = 'pending';
    bool isCreating = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
              horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 520,
            constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height *
                        0.85),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      24, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark,
                    borderRadius:
                        const BorderRadius.vertical(
                            top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.person_add_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Add Student Manually',
                        style:
                            GoogleFonts.beVietnamPro(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20),
                      onPressed: isCreating
                          ? null
                          : () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                // Body
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _sectionLabel(
                              'Student Information',
                              icon: Icons.badge_outlined),
                          // ID + Name row
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: idCtrl,
                                decoration: _DS
                                    .inputDecoration(
                                  'Student ID',
                                  hint:
                                      'e.g., 2021-00001',
                                  icon: Icons
                                      .badge_outlined,
                                ),
                                style: GoogleFonts
                                    .beVietnamPro(
                                        fontSize: 13),
                                validator: (v) => v ==
                                            null ||
                                        v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: nameCtrl,
                                decoration: _DS
                                    .inputDecoration(
                                  'Full Name',
                                  hint:
                                      'e.g., Juan dela Cruz',
                                  icon: Icons
                                      .person_outline,
                                ),
                                style: GoogleFonts
                                    .beVietnamPro(
                                        fontSize: 13),
                                validator: (v) => v ==
                                            null ||
                                        v.trim().isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          // Course + Year row
                          Row(children: [
                            Expanded(
                              child:
                                  DropdownButtonFormField<
                                      String>(
                                value: course,
                                decoration:
                                    _DS.inputDecoration(
                                        'Course'),
                                style: GoogleFonts
                                    .beVietnamPro(
                                  fontSize: 13,
                                  color: const Color(
                                      0xFF1A202C),
                                ),
                                items: const [
                                  'BSIT',
                                  'BSIS',
                                  'BLIS'
                                ]
                                    .map((c) =>
                                        DropdownMenuItem(
                                            value: c,
                                            child:
                                                Text(c)))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() =>
                                        course = v!),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child:
                                  DropdownButtonFormField<
                                      String>(
                                value: yearLevel,
                                decoration:
                                    _DS.inputDecoration(
                                        'Year Level'),
                                style: GoogleFonts
                                    .beVietnamPro(
                                  fontSize: 13,
                                  color: const Color(
                                      0xFF1A202C),
                                ),
                                items: const [
                                  '1st Year',
                                  '2nd Year',
                                  '3rd Year',
                                  '4th Year',
                                  '5th Year'
                                ]
                                    .map((y) =>
                                        DropdownMenuItem(
                                            value: y,
                                            child:
                                                Text(y)))
                                    .toList(),
                                onChanged: (v) =>
                                    setDialogState(() =>
                                        yearLevel = v!),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          // Email
                          TextFormField(
                            controller: emailCtrl,
                            decoration:
                                _DS.inputDecoration(
                              'Email Address',
                              hint:
                                  'e.g., student@university.edu.ph',
                              icon:
                                  Icons.email_outlined,
                            ),
                            style: GoogleFonts
                                .beVietnamPro(
                                    fontSize: 13),
                            keyboardType: TextInputType
                                .emailAddress,
                            validator: (v) {
                              if (v == null ||
                                  v.trim().isEmpty) {
                                return 'Required';
                              }
                              if (!v.contains('@') ||
                                  !v.contains('.')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          // Status
                          DropdownButtonFormField<
                              String>(
                            value: status,
                            decoration:
                                _DS.inputDecoration(
                                    'Initial Status'),
                            style:
                                GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              color: const Color(
                                  0xFF1A202C),
                            ),
                            items: const [
                              'pending',
                              'verified'
                            ]
                                .map((s) =>
                                    DropdownMenuItem(
                                      value: s,
                                      child: Text(s[0]
                                              .toUpperCase() +
                                          s.substring(1)),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(
                                    () => status = v!),
                          ),
                          if (errorMsg != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding:
                                  const EdgeInsets.all(
                                      12),
                              decoration: BoxDecoration(
                                color: const Color(
                                    0xFFFEF2F2),
                                borderRadius:
                                    BorderRadius.circular(
                                        8),
                                border: Border.all(
                                    color: const Color(
                                        0xFFFCA5A5)),
                              ),
                              child: Row(children: [
                                const Icon(
                                    Icons
                                        .error_outline_rounded,
                                    size: 15,
                                    color: Color(
                                        0xFFDC2626)),
                                const SizedBox(
                                    width: 8),
                                Expanded(
                                    child: Text(
                                  errorMsg!,
                                  style: GoogleFonts
                                      .beVietnamPro(
                                          fontSize: 12,
                                          color: const Color(
                                              0xFF991B1B)),
                                )),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(
                      24, 16, 24, 20),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color:
                                Color(0xFFE8ECF0))),
                    color: Color(0xFFF8F9FB),
                    borderRadius:
                        BorderRadius.vertical(
                            bottom:
                                Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: isCreating
                            ? null
                            : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color:
                                  Color(0xFFE2E6EA)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts
                                .beVietnamPro(
                              fontSize: 13,
                              color: const Color(
                                  0xFF374151),
                            )),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isCreating
                            ? null
                            : () async {
                                if (!formKey
                                    .currentState!
                                    .validate()) {
                                  return;
                                }
                                setDialogState(() {
                                  isCreating = true;
                                  errorMsg = null;
                                });
                                try {
                                          final cred = await _createStudentAccount({
                                            'studentId': idCtrl.text.trim(),
                                            'fullName': nameCtrl.text.trim(),
                                            'course': course,
                                            'yearLevel': yearLevel,
                                            'email': emailCtrl.text.trim().toLowerCase(),
                                          });
                                          // send credentials email after creation (manual flow, non-fatal)
                                          try {
                                                  final sent = await _sendCredentialsEmail(
                                                      cred['email']!, cred['studentId']!, cred['password']!);
                                                  if (!sent) {
                                                    await _queueCredentialEmail(cred['email']!, cred['studentId']!, cred['password']!);
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                                        content: Text("Account created but sending credentials failed for ${cred['email']}.") ,
                                                        backgroundColor: const Color(0xFFF59E0B),
                                                        duration: const Duration(seconds: 4),
                                                      ));
                                                    }
                                                  }
                                                } catch (e) {
                                                  await _queueCredentialEmail(cred['email']!, cred['studentId']!, cred['password']!);
                                                  debugPrint("⚠️ Failed to send credentials to ${cred['email']}: $e");
                                                }
                                  // Override status if verified
                                  if (status ==
                                      'verified') {
                                    final q =
                                        await FirebaseFirestore
                                            .instance
                                            .collection(
                                                'students')
                                            .where(
                                              'email',
                                              isEqualTo:
                                                  emailCtrl
                                                      .text
                                                      .trim()
                                                      .toLowerCase(),
                                            )
                                            .get();
                                    if (q.docs
                                        .isNotEmpty) {
                                      await q.docs.first
                                          .reference
                                          .update({
                                        'status':
                                            'verified'
                                      });
                                    }
                                  }
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger
                                            .of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(
                                          'Student account created for ${nameCtrl.text.trim()}.'),
                                      backgroundColor:
                                          const Color(
                                              0xFF059669),
                                      behavior:
                                          SnackBarBehavior
                                              .floating,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  8)),
                                    ));
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    errorMsg =
                                        e.toString();
                                    isCreating = false;
                                  });
                                }
                              },
                        icon: isCreating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child:
                                    CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Colors
                                                .white))
                            : const Icon(
                                Icons.person_add_rounded,
                                size: 16),
                        label: Text(
                          'Create Account',
                          style:
                              GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight:
                                FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              UpriseColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────

  String _generatePassword() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZ0123456789';
    final rng = Random.secure();
    return 'STU-${List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join()}';
  }

  Future<Map<String, String>> _createStudentAccount(
      Map<String, String> student) async {
    final email = student['email']!;
    final studentId = student['studentId']!;
    final fullName = student['fullName']!;
    final password = _generatePassword();

    FirebaseApp secondaryApp;
    try {
      secondaryApp = Firebase.app('secondaryApp');
    } catch (_) {
      secondaryApp = await Firebase.initializeApp(
        name: 'secondaryApp',
        options: Firebase.app().options,
      );
    }
    final secondaryAuth =
        FirebaseAuth.instanceFor(app: secondaryApp);
    UserCredential cred;
    try {
      cred = await secondaryAuth
          .createUserWithEmailAndPassword(
              email: email, password: password);
    } catch (e) {
      await secondaryAuth.signOut();
      if (e.toString().contains('email-already-in-use')) {
        throw Exception(
            'Email already registered: $email');
      }
      throw Exception(
          'Account creation failed: ${e.toString()}');
    }
    await cred.user?.updateDisplayName(fullName);
    await FirebaseFirestore.instance
        .collection('students')
        .doc(cred.user!.uid)
        .set({
      'studentId': studentId,
      'fullName': fullName,
      'course': student['course'],
      'yearLevel': student['yearLevel'],
      'email': email,
      'status': 'pending',
      'tempPassword': password,
      'createdAt': FieldValue.serverTimestamp(),
      'uid': cred.user!.uid,
    });
    await secondaryAuth.signOut();
    await activity_log.ActivityLogger.log(
      action: 'Created student account: $studentId ($email)',
      module: 'User Directory',
      severity: 'info',
    );
    return {'email': email, 'studentId': studentId, 'password': password};
  }

  Future<bool> _sendCredentialsEmail(
    String email,
    String studentId,
    String password,
  ) async {
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
          headers: {
            'Content-Type': 'application/json',
            'origin': 'http://localhost',
          },
          body: jsonEncode({
            'service_id': 'service_s3ke8zd',
            'template_id': 'template_76fn2md',
            'user_id': 'tmx47wQJmb1uMNUpr',
            'template_params': {
              'to_email': email,
              'student_id': studentId,
              'password': password,
            },
          }),
        );
        if (response.statusCode == 200) {
          debugPrint('✅ Email sent to $email (attempt $attempt)');
          return true;
        }
        debugPrint('❌ EmailJS ${response.statusCode}: ${response.body} (attempt $attempt)');
      } catch (e) {
        debugPrint('❌ Failed to send email to $email (attempt $attempt): $e');
      }
      if (attempt < maxAttempts) await Future.delayed(Duration(seconds: attempt));
    }
    return false;
  }

  Future<void> _queueCredentialEmail(String email, String studentId, String password) async {
    try {
      await FirebaseFirestore.instance.collection('email_queue').add({
        'to_email': email,
        'student_id': studentId,
        'password': password,
        'attempts': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Queued credential email for $email');
    } catch (e) {
      debugPrint('Failed to queue credential email for $email: $e');
    }
  }

  Future<List<Map<String, String>>> _parseFile(
      File file) async {
    final List<Map<String, String>> students = [];
    final ext =
        file.path.split('.').last.toLowerCase();
    if (ext == 'csv') {
      final csvString = await file.readAsString();
      final rows =
          const CsvToListConverter().convert(csvString);
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length >= 5) {
          students.add({
            'studentId':
                row[0]?.toString().trim() ?? '',
            'fullName':
                row[1]?.toString().trim() ?? '',
            'course': _normalizeCourse(
                row[2]?.toString().trim() ?? ''),
            'yearLevel':
                row[3]?.toString().trim() ?? '',
            'email':
                row[4]?.toString().trim() ?? '',
          });
        }
      }
    } else {
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        for (int i = 1;
            i < (sheet?.rows.length ?? 0);
            i++) {
          final row = sheet!.rows[i];
          if (row.length >= 5) {
            students.add({
              'studentId': row[0]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
              'fullName': row[1]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
              'course': _normalizeCourse(
                  row[2]
                          ?.value
                          ?.toString()
                          .trim() ??
                      ''),
              'yearLevel': row[3]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
              'email': row[4]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
            });
          }
        }
        break;
      }
    }
    students.removeWhere((s) =>
        s['studentId']!.isEmpty ||
        s['email']!.isEmpty);
    return students;
  }

  Future<List<Map<String, String>>> _parseXFile(
      XFile xfile) async {
    final bytes = await xfile.readAsBytes();
    final name = xfile.name.toLowerCase();
    final List<Map<String, String>> students = [];
    if (name.endsWith('.csv')) {
      final csvString =
          String.fromCharCodes(bytes);
      final rows =
          const CsvToListConverter().convert(csvString);
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length >= 5) {
          students.add({
            'studentId':
                row[0]?.toString().trim() ?? '',
            'fullName':
                row[1]?.toString().trim() ?? '',
            'course': _normalizeCourse(
                row[2]?.toString().trim() ?? ''),
            'yearLevel':
                row[3]?.toString().trim() ?? '',
            'email':
                row[4]?.toString().trim() ?? '',
          });
        }
      }
    } else {
      final excel = Excel.decodeBytes(bytes);
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        for (int i = 1;
            i < (sheet?.rows.length ?? 0);
            i++) {
          final row = sheet!.rows[i];
          if (row.length >= 5) {
            students.add({
              'studentId': row[0]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
              'fullName': row[1]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
              'course': _normalizeCourse(
                  row[2]
                          ?.value
                          ?.toString()
                          .trim() ??
                      ''),
              'yearLevel': row[3]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
              'email': row[4]
                      ?.value
                      ?.toString()
                      .trim() ??
                  '',
            });
          }
        }
        break;
      }
    }
    students.removeWhere((s) =>
        s['studentId']!.isEmpty ||
        s['email']!.isEmpty);
    return students;
  }

  String _normalizeCourse(String course) {
    final upper = course.toUpperCase();
    if (upper.contains('BSIT')) return 'BSIT';
    if (upper.contains('BSIS')) return 'BSIS';
    if (upper.contains('BLIS')) return 'BLIS';
    return 'BSIT';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets (mirrors org_management style)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          color: const Color(
                              0xFF64748B),
                          fontWeight:
                              FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.beVietnamPro(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: const Color(
                              0xFF1A202C))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String hint;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding:
          const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: const Color(0xFFE2E6EA)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: const Color(0xFF374151)),
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s,
                        style: GoogleFonts
                            .beVietnamPro(
                                fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outlined;

  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 15),
        label: Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: UpriseColors.primaryDark,
          side: BorderSide(
              color: UpriseColors.primaryDark),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: UpriseColors.primaryDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

class _ExportStudentsButton extends StatelessWidget {
  final String statusFilter,
      courseFilter,
      searchTerm;
  const _ExportStudentsButton({
    required this.statusFilter,
    required this.courseFilter,
    required this.searchTerm,
  });

  @override
  Widget build(BuildContext context) {
    return AdminExportButton(onSelected: (choice) => _doExport(context, choice));
  }

  Future<void> _doExport(
      BuildContext context, String format) async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('students')
          .orderBy('createdAt', descending: true)
          .get();
      var docs = snap.docs;
      if (statusFilter != 'All') {
        docs = docs
            .where((d) =>
                (d.data())['status'] ==
                statusFilter.toLowerCase())
            .toList();
      }
      if (courseFilter != 'All') {
        docs = docs
            .where((d) =>
                (d.data())['course'] == courseFilter)
            .toList();
      }
      if (searchTerm.isNotEmpty) {
        docs = docs.where((d) {
          final data = d.data();
          return (data['fullName'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(searchTerm) ||
              (data['studentId'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(searchTerm) ||
              (data['email'] ?? '')
                  .toString()
                  .toLowerCase()
                  .contains(searchTerm);
        }).toList();
      }

      if (docs.isEmpty) {
        // ignore: duplicate_ignore
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                const Text('No data to export.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(8)),
          ),
        );
        return;
      }

      String content, fileName;
      final now = DateTime.now()
          .toString()
          .substring(0, 10);

      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln(
            'Student ID,Full Name,Course,Year Level,Email,Status');
        for (final doc in docs) {
          final d = doc.data();
          String esc(String s) =>
              '"${s.replaceAll('"', '""')}"';
          buf.writeln([
            esc(d['studentId'] ?? ''),
            esc(d['fullName'] ?? ''),
            esc(d['course'] ?? ''),
            esc(d['yearLevel'] ?? ''),
            esc(d['email'] ?? ''),
            esc(d['status'] ?? ''),
          ].join(','));
        }
        content = buf.toString();
        fileName = 'students_$now.csv';
        await AdminExportUtil.saveText(
          content,
          fileName,
          mimeType: 'text/csv',
        );
      } else if (format == 'pdf') {
        final rows = docs.map((doc) {
          final d = doc.data();
          return [
            d['studentId'] ?? '',
            d['fullName'] ?? '',
            d['course'] ?? '',
            d['yearLevel'] ?? '',
            d['email'] ?? '',
            d['status'] ?? '',
          ].map((value) => value.toString()).toList();
        }).toList();

        final pdfBytes = await AdminExportPdf.generateTablePdf(
          title: 'Student Accounts Report',
          headers: const ['Student ID', 'Full Name', 'Course', 'Year Level', 'Email', 'Status'],
          rows: rows,
        );

        await AdminExportUtil.saveBytes(
          pdfBytes,
          'students_$now.pdf',
          mimeType: 'application/pdf',
        );
      } else {
        throw UnsupportedError('Unsupported export format: $format');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(8)),
        ),
      );
    }
  }
}

class _StudentAvatar extends StatelessWidget {
  final String name;
  const _StudentAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty
            ? name[0].toUpperCase()
            : '?');
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: UpriseColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon,
              size: 16,
              color: onTap == null
                  ? const Color(0xFFD1D5DB)
                  : (color ??
                      const Color(0xFF64748B))),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 20,
            color: enabled
                ? const Color(0xFF374151)
                : const Color(0xFFD1D5DB)),
      ),
    );
  }
}

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: 2),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive
              ? UpriseColors.primaryDark
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '$page',
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: isActive
                ? FontWeight.w700
                : FontWeight.normal,
            color: isActive
                ? Colors.white
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}