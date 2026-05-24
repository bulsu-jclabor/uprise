import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import 'package:intl/intl.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import 'dart:convert';
import '../../theme/app_theme.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (mirrors student_accounts.dart / org_management.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
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
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
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
            child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
      ],
    ),
  );
}

Widget _statusBadge(String status) {
  const styles = {
    'approved': (Color(0xFFECFDF5), Color(0xFF059669), 'APPROVED'),
    'pending':  (Color(0xFFFFFBEB), Color(0xFFD97706), 'PENDING'),
    'rejected': (Color(0xFFFEF2F2), Color(0xFFDC2626), 'REJECTED'),
    'archived': (Color(0xFFF3F4F6), Color(0xFF6B7280), 'ARCHIVED'),
  };
  final s = styles[status.toLowerCase()];
  final bg    = s?.$1 ?? const Color(0xFFF3F4F6);
  final fg    = s?.$2 ?? const Color(0xFF6B7280);
  final label = s?.$3 ?? status.toUpperCase();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Text(
      label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: fg,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Document model
// ─────────────────────────────────────────────────────────────────────────────
class LetterRequestDocument {
  final String id;
  final String title;
  final String fileName;
  final String fileType;
  final int    fileSize;
  final DateTime uploadDate;
  final String status;
  final String requestedBy;
  final String department;
  final String content;
  final String revisionNotes;

  const LetterRequestDocument({
    required this.id,
    required this.title,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.uploadDate,
    required this.status,
    required this.requestedBy,
    required this.department,
    required this.content,
    required this.revisionNotes,
  });

  factory LetterRequestDocument.fromFirestore(
      String id, Map<String, dynamic> d) {
    return LetterRequestDocument(
      id:            id,
      title:         d['title']         ?? 'Untitled',
      fileName:      d['fileName']      ?? '',
      fileType:      d['fileType']      ?? 'pdf',
      fileSize:      (d['fileSize'] ?? 0) is int
          ? d['fileSize']
          : (d['fileSize'] as num).toInt(),
      uploadDate:    (d['uploadDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status:        d['status']        ?? 'pending',
      requestedBy:   d['requestedBy']   ?? '',
      department:    d['department']    ?? '',
      content:       d['content']       ?? '',
      revisionNotes: d['revisionNotes'] ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class LetterRequest extends StatefulWidget {
  const LetterRequest({super.key});

  @override
  _LetterRequestState createState() => _LetterRequestState();
}

class _LetterRequestState extends State<LetterRequest> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  int    _currentPage  = 1;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────
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

  // ── Stats row ──────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('letter_requests')
          .snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0, archived = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            total++;
            final s = (doc.data() as Map)['status'] ?? 'pending';
            if (s == 'pending')  pending++;
            if (s == 'approved') approved++;
            if (s == 'rejected') rejected++;
            if (s == 'archived') archived++;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(
              label: 'Total Requests',
              value: '$total',
              icon: Icons.description_rounded,
              color: UpriseColors.primaryDark,
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Approved',
              value: '$approved',
              icon: Icons.check_circle_rounded,
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
              label: 'Rejected',
              value: '$rejected',
              icon: Icons.cancel_rounded,
              color: const Color(0xFFDC2626),
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Archived',
              value: '$archived',
              icon: Icons.archive_rounded,
              color: const Color(0xFF6B7280),
            ),
          ]),
        );
      },
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(children: [
        // Search
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by title or requested by…',
                hintStyle: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded,
                    size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E6EA))),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: Color(0xFFE2E6EA))),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: UpriseColors.primaryDark, width: 1.5)),
              ),
              onChanged: (_) => setState(() => _currentPage = 1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _FilterDropdown(
          value: _statusFilter,
          items: const ['All', 'Pending', 'Approved', 'Rejected', 'Archived'],
          hint: 'Status',
          icon: Icons.tune_rounded,
          onChanged: (v) => setState(() {
            _statusFilter = v!;
            _currentPage  = 1;
          }),
        ),
        const SizedBox(width: 10),
        _ExportButton(
          statusFilter: _statusFilter,
          searchTerm:   _searchController.text.trim(),
        ),
      ]),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('letter_requests')
          .orderBy('uploadDate', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data!.docs;

        // Filters
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['title']       ?? '').toString().toLowerCase().contains(term) ||
                   (data['requestedBy'] ?? '').toString().toLowerCase().contains(term) ||
                   (data['department']  ?? '').toString().toLowerCase().contains(term);
          }).toList();
        }
        if (_statusFilter != 'All') {
          docs = docs
              .where((d) =>
                  (d.data() as Map)['status'] == _statusFilter.toLowerCase())
              .toList();
        }

        final totalPages = docs.isEmpty ? 1 : (docs.length / _pageSize).ceil();
        final safePage   = _currentPage.clamp(1, totalPages);
        final start      = (safePage - 1) * _pageSize;
        final end        = (start + _pageSize).clamp(0, docs.length);
        final pageDocs   = docs.isEmpty
            ? <QueryDocumentSnapshot>[]
            : docs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(children: [
            _buildTableHeader(),
            Expanded(
              child: docs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: pageDocs.length,
                      itemBuilder: (_, i) {
                        final data =
                            pageDocs[i].data() as Map<String, dynamic>;
                        final doc = LetterRequestDocument.fromFirestore(
                            pageDocs[i].id, data);
                        return _buildRow(
                            doc: doc, isLast: i == pageDocs.length - 1);
                      },
                    ),
            ),
            _buildFooter(docs.length, totalPages, start, end),
          ]),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(
            bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 4, child: _headerCell('DOCUMENT TITLE')),
        Expanded(flex: 2, child: _headerCell('REQUESTED BY')),
        Expanded(flex: 2, child: _headerCell('DEPARTMENT')),
        Expanded(flex: 2, child: _headerCell('UPLOAD DATE')),
        Expanded(flex: 1, child: _headerCell('STATUS')),
        Expanded(
          flex: 2,
          child: Align(
              alignment: Alignment.centerRight,
              child: _headerCell('ACTIONS')),
        ),
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

  Widget _buildRow(
      {required LetterRequestDocument doc, required bool isLast}) {
    final formattedDate =
        DateFormat('MMM dd, yyyy').format(doc.uploadDate);
    final fileInfo =
        doc.fileType.isNotEmpty ? doc.fileType.toUpperCase() : '';

    return InkWell(
      hoverColor: const Color(0xFFF8F9FB),
      onTap: () => _showViewDialog(doc),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom:
                      BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(children: [
          // Title + file type chip
          Expanded(
            flex: 4,
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _fileIcon(doc.fileType),
                  size: 18,
                  color: UpriseColors.primaryDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (fileInfo.isNotEmpty)
                      Text(
                        '$fileInfo • ${_formatFileSize(doc.fileSize)}',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            color: const Color(0xFF9AA5B4)),
                      ),
                  ],
                ),
              ),
            ]),
          ),
          // Requested By
          Expanded(
            flex: 2,
            child: Text(
              doc.requestedBy.isNotEmpty ? doc.requestedBy : '—',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: const Color(0xFF374151)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Department
          Expanded(
            flex: 2,
            child: doc.department.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: UpriseColors.primaryDark.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      doc.department,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: UpriseColors.primaryDark,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text('—',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: const Color(0xFF9AA5B4))),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              formattedDate,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          // Status
          Expanded(flex: 1, child: _statusBadge(doc.status)),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View Details',
                  onTap: () => _showViewDialog(doc),
                ),
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit',
                  onTap: () => _showEditDialog(doc),
                ),
                if (doc.status == 'pending') ...[
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.check_circle_outline,
                    tooltip: 'Approve',
                    color: const Color(0xFF059669),
                    onTap: () => _setStatus(doc.id, 'approved',
                        title: doc.title),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.cancel_outlined,
                    tooltip: 'Reject',
                    color: const Color(0xFFDC2626),
                    onTap: () =>
                        _setStatus(doc.id, 'rejected', title: doc.title),
                  ),
                ],
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  color: const Color(0xFFDC2626),
                  onTap: () => _confirmDelete(doc),
                ),
              ],
            ),
          ),
        ]),
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
            child: const Icon(Icons.description_rounded,
                size: 40, color: Color(0xFF9AA5B4)),
          ),
          const SizedBox(height: 16),
          Text('No letter requests found',
              style: GoogleFonts.beVietnamPro(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF374151),
              )),
          const SizedBox(height: 6),
          Text('Try adjusting your filters.',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 13, color: const Color(0xFF64748B))),
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
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages =
        List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border:
            Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total requests',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, color: const Color(0xFF64748B)),
          ),
          Row(children: [
            _PageButton(
              icon: Icons.chevron_left_rounded,
              enabled: _currentPage > 1,
              onTap: () => setState(() => _currentPage--),
            ),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumButton(
                  page: p,
                  isActive: p == _currentPage,
                  onTap: () => setState(() => _currentPage = p),
                )),
            if (lastPage < totalPages) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('…',
                    style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFF64748B),
                        fontSize: 12)),
              ),
              _PageNumButton(
                page: totalPages,
                isActive: _currentPage == totalPages,
                onTap: () =>
                    setState(() => _currentPage = totalPages),
              ),
            ],
            const SizedBox(width: 4),
            _PageButton(
              icon: Icons.chevron_right_rounded,
              enabled: _currentPage < totalPages,
              onTap: () => setState(() => _currentPage++),
            ),
          ]),
        ],
      ),
    );
  }

  // ── CRUD actions ───────────────────────────────────────────────────

  Future<void> _setStatus(
    String docId,
    String newStatus, {
    required String title,
  }) async {
    await FirebaseFirestore.instance
        .collection('letter_requests')
        .doc(docId)
        .update({'status': newStatus});

    await activity_log.ActivityLogger.log(
      action: '${newStatus.toUpperCase()} letter request: $title',
      module: 'Letter Request',
      severity: newStatus == 'rejected' ? 'warning' : 'info',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Status updated to ${newStatus[0].toUpperCase()}${newStatus.substring(1)}'),
        backgroundColor: newStatus == 'approved'
            ? const Color(0xFF059669)
            : newStatus == 'rejected'
                ? const Color(0xFFDC2626)
                : UpriseColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
    }
  }

  void _showAddDialog() => _showDocumentForm(isEdit: false, doc: null);
  void _showEditDialog(LetterRequestDocument doc) =>
      _showDocumentForm(isEdit: true, doc: doc);

  // ── Add / Edit Dialog ──────────────────────────────────────────────
  void _showDocumentForm(
      {required bool isEdit, required LetterRequestDocument? doc}) {
    final formKey        = GlobalKey<FormState>();
    final titleCtrl      = TextEditingController(text: isEdit ? doc!.title       : '');
    final requestedCtrl  = TextEditingController(text: isEdit ? doc!.requestedBy : '');
    final departmentCtrl = TextEditingController(text: isEdit ? doc!.department  : '');
    final contentCtrl    = TextEditingController(text: isEdit ? doc!.content     : '');
    String status    = isEdit ? doc!.status   : 'pending';
    String fileName  = isEdit ? doc!.fileName : '';
    String fileType  = isEdit ? doc!.fileType : 'pdf';
    int    fileSize  = isEdit ? doc!.fileSize : 0;
    bool   isSaving  = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 560,
            constraints: BoxConstraints(
                maxHeight:
                    MediaQuery.of(context).size.height * 0.88),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ──────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18)),
                  ),
                  child: Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                          isEdit
                              ? Icons.edit_rounded
                              : Icons.add_rounded,
                          color: Colors.white,
                          size: 18),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        isEdit
                            ? 'Edit Letter Request'
                            : 'Add Letter Request',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 20),
                      onPressed:
                          isSaving ? null : () => Navigator.pop(ctx),
                    ),
                  ]),
                ),
                // ── Body ────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel('Request Details',
                              icon: Icons.description_outlined),
                          // Title
                          TextFormField(
                            controller: titleCtrl,
                            decoration: _DS.inputDecoration(
                              'Document Title',
                              hint: 'e.g., Letter of Intent for Event',
                              icon: Icons.title_rounded,
                            ),
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                          // Requested By + Department row
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: requestedCtrl,
                                decoration: _DS.inputDecoration(
                                  'Requested By',
                                  hint: 'e.g., John dela Cruz',
                                  icon: Icons.person_outline,
                                ),
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? 'Required'
                                        : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: departmentCtrl,
                                decoration: _DS.inputDecoration(
                                  'Department / Organization',
                                  hint: 'e.g., BSIT-3A',
                                  icon: Icons.school_outlined,
                                ),
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 13),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          // Content
                          TextFormField(
                            controller: contentCtrl,
                            maxLines: 4,
                            decoration: _DS.inputDecoration(
                              'Content / Description',
                              hint:
                                  'Provide the letter content or a brief description…',
                            ),
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          if (isEdit) ...[
                            _sectionLabel('Status',
                                icon: Icons.toggle_on_outlined),
                            DropdownButtonFormField<String>(
                              value: status,
                              decoration:
                                  _DS.inputDecoration('Request Status'),
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: const Color(0xFF1A202C),
                              ),
                              items: const [
                                'pending',
                                'approved',
                                'rejected',
                                'archived'
                              ]
                                  .map((s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(
                                            '${s[0].toUpperCase()}${s.substring(1)}'),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setDs(() => status = v!),
                            ),
                            const SizedBox(height: 16),
                          ],
                          // File picker (add mode only)
                          if (!isEdit) ...[
                            _sectionLabel('Attachment',
                                icon: Icons.attach_file_rounded),
                            GestureDetector(
                              onTap: () async {
                                final result =
                                    await FilePicker.platform.pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: [
                                    'pdf',
                                    'doc',
                                    'docx',
                                    'txt'
                                  ],
                                );
                                if (result != null) {
                                  setDs(() {
                                    fileName = result.files.single.name;
                                    fileType =
                                        result.files.single.extension ??
                                            'pdf';
                                    fileSize = result.files.single.size;
                                  });
                                }
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: fileName.isEmpty
                                      ? const Color(0xFFF8F9FB)
                                      : const Color(0xFFECFDF5),
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  border: Border.all(
                                    color: fileName.isEmpty
                                        ? const Color(0xFFE2E6EA)
                                        : const Color(0xFF059669),
                                    width: fileName.isEmpty ? 1 : 1.5,
                                  ),
                                ),
                                child: Column(children: [
                                  Icon(
                                    fileName.isEmpty
                                        ? Icons.cloud_upload_rounded
                                        : Icons.check_circle_rounded,
                                    size: 34,
                                    color: fileName.isEmpty
                                        ? const Color(0xFF9AA5B4)
                                        : const Color(0xFF059669),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    fileName.isEmpty
                                        ? 'Click to attach a file'
                                        : fileName,
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: fileName.isEmpty
                                          ? const Color(0xFF64748B)
                                          : const Color(0xFF059669),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Supported: PDF, DOC, DOCX, TXT',
                                    style: GoogleFonts.beVietnamPro(
                                        fontSize: 11,
                                        color:
                                            const Color(0xFF9AA5B4)),
                                  ),
                                ]),
                              ),
                            ),
                          ],
                          if (errorMsg != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF2F2),
                                borderRadius:
                                    BorderRadius.circular(8),
                                border: Border.all(
                                    color: const Color(0xFFFCA5A5)),
                              ),
                              child: Row(children: [
                                const Icon(
                                    Icons.error_outline_rounded,
                                    size: 15,
                                    color: Color(0xFFDC2626)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(errorMsg!,
                                      style: GoogleFonts.beVietnamPro(
                                          fontSize: 12,
                                          color: const Color(
                                              0xFF991B1B))),
                                ),
                              ]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                // ── Footer ──────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(24, 16, 24, 20),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(color: Color(0xFFE8ECF0))),
                    color: Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: isSaving
                            ? null
                            : () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFE2E6EA)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 11),
                        ),
                        child: Text('Cancel',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: const Color(
                                    0xFF374151))),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                if (!formKey.currentState!
                                    .validate()) return;
                                if (!isEdit &&
                                    fileName.isEmpty) {
                                  setDs(() => errorMsg =
                                      'Please attach a file.');
                                  return;
                                }
                                setDs(() {
                                  isSaving = true;
                                  errorMsg = null;
                                });
                                try {
                                  final data = <String, dynamic>{
                                    'title':
                                        titleCtrl.text.trim(),
                                    'requestedBy': requestedCtrl
                                        .text
                                        .trim(),
                                    'department':
                                        departmentCtrl.text.trim(),
                                    'content':
                                        contentCtrl.text.trim(),
                                    'status': status,
                                    'fileName': fileName,
                                    'fileType': fileType,
                                    'fileSize': fileSize,
                                    'uploadDate':
                                        FieldValue.serverTimestamp(),
                                    'updatedAt':
                                        FieldValue.serverTimestamp(),
                                  };
                                  if (isEdit) {
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'letter_requests')
                                        .doc(doc!.id)
                                        .update(data);
                                    await activity_log
                                        .ActivityLogger.log(
                                      action:
                                          'Updated letter request: ${titleCtrl.text.trim()}',
                                      module: 'Letter Request',
                                      severity: 'info',
                                    );
                                  } else {
                                    data['createdAt'] =
                                        FieldValue.serverTimestamp();
                                    await FirebaseFirestore
                                        .instance
                                        .collection(
                                            'letter_requests')
                                        .add(data);
                                    await activity_log
                                        .ActivityLogger.log(
                                      action:
                                          'Created letter request: ${titleCtrl.text.trim()}',
                                      module: 'Letter Request',
                                      severity: 'info',
                                    );
                                  }
                                  if (mounted) {
                                    Navigator.pop(ctx);
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(SnackBar(
                                      content: Text(isEdit
                                          ? 'Letter request updated.'
                                          : 'Letter request created.'),
                                      backgroundColor:
                                          const Color(0xFF059669),
                                      behavior:
                                          SnackBarBehavior.floating,
                                      shape:
                                          RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(8)),
                                    ));
                                  }
                                } catch (e) {
                                  setDs(() {
                                    errorMsg = e.toString();
                                    isSaving = false;
                                  });
                                }
                              },
                        icon: isSaving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                            : Icon(
                                isEdit
                                    ? Icons.save_rounded
                                    : Icons.add_rounded,
                                size: 16),
                        label: Text(
                          isEdit
                              ? 'Save Changes'
                              : 'Create Request',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              UpriseColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
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

  // ── View Dialog ────────────────────────────────────────────────────
  void _showViewDialog(LetterRequestDocument doc) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding:
                    const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_fileIcon(doc.fileType),
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.title,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '#${doc.id.substring(0, 8).toUpperCase()}',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              // Body
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status + date strip
                    Row(children: [
                      _statusBadge(doc.status),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_outlined,
                          size: 13,
                          color: const Color(0xFF9AA5B4)),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM dd, yyyy')
                            .format(doc.uploadDate),
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: const Color(0xFF64748B)),
                      ),
                    ]),
                    const SizedBox(height: 20),
                    _sectionLabel('Request Information',
                        icon: Icons.info_outline_rounded),
                    _infoGrid([
                      ('Requested By', doc.requestedBy.isNotEmpty
                          ? doc.requestedBy
                          : '—'),
                      ('Department', doc.department.isNotEmpty
                          ? doc.department
                          : '—'),
                      ('File', doc.fileName.isNotEmpty
                          ? doc.fileName
                          : '—'),
                      ('File Size',
                          _formatFileSize(doc.fileSize)),
                    ]),
                    if (doc.content.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _sectionLabel('Content',
                          icon: Icons.article_outlined),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFE2E6EA)),
                        ),
                        child: Text(
                          doc.content,
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              color: const Color(0xFF374151),
                              height: 1.6),
                        ),
                      ),
                    ],
                    if (doc.revisionNotes.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                              color: const Color(0xFFFED7AA)),
                        ),
                        child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                          const Icon(
                              Icons.edit_note_rounded,
                              size: 15,
                              color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                              Text('Revision Notes',
                                  style: GoogleFonts.beVietnamPro(
                                      fontSize: 11,
                                      fontWeight:
                                          FontWeight.w700,
                                      color: const Color(
                                          0xFFD97706))),
                              const SizedBox(height: 4),
                              Text(doc.revisionNotes,
                                  style: GoogleFonts.beVietnamPro(
                                      fontSize: 12,
                                      color: const Color(
                                          0xFF92400E),
                                      height: 1.5)),
                            ]),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              // Footer actions
              Container(
                padding:
                    const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Row(children: [
                  if (doc.status == 'pending') ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showRevisionDialog(doc);
                        },
                        icon: const Icon(
                            Icons.edit_note_rounded,
                            size: 15),
                        label: Text('Revision',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              const Color(0xFFD97706),
                          side: const BorderSide(
                              color: Color(0xFFFED7AA)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _setStatus(doc.id, 'rejected',
                              title: doc.title);
                        },
                        icon: const Icon(Icons.cancel_rounded,
                            size: 15),
                        label: Text('Reject',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
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
                                  vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _setStatus(doc.id, 'approved',
                              title: doc.title);
                        },
                        icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 15),
                        label: Text('Approve',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showEditDialog(doc);
                        },
                        icon: const Icon(Icons.edit_rounded,
                            size: 15),
                        label: Text('Edit',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: Color(0xFFE2E6EA)),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              UpriseColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(8)),
                          padding:
                              const EdgeInsets.symmetric(
                                  vertical: 11),
                        ),
                        child: Text('Close',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoGrid(List<(String, String)> items) {
    return Wrap(
      spacing: 0,
      runSpacing: 12,
      children: items
          .map((item) => SizedBox(
                width: 230,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$1,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                            letterSpacing: 0.4)),
                    const SizedBox(height: 3),
                    Text(item.$2,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A202C))),
                  ],
                ),
              ))
          .toList(),
    );
  }

  // ── Revision Dialog ────────────────────────────────────────────────
  void _showRevisionDialog(LetterRequestDocument doc) {
    final notesCtrl =
        TextEditingController(text: doc.revisionNotes);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        color: Color(0xFFD97706), size: 20),
                  ),
                  const SizedBox(width: 14),
                  Text('Request Revision',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C),
                      )),
                ]),
                const SizedBox(height: 16),
                Text(
                  'Specify the changes or additional information needed for "${doc.title}".',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 13,
                      color: const Color(0xFF64748B),
                      height: 1.5),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: notesCtrl,
                  maxLines: 4,
                  decoration: _DS.inputDecoration(
                    'Revision Notes',
                    hint: 'Describe what changes are needed…',
                    icon: Icons.notes_rounded,
                  ),
                  style:
                      GoogleFonts.beVietnamPro(fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isSaving
                          ? null
                          : () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFE2E6EA)),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 11),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              color:
                                  const Color(0xFF374151))),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              setDs(() => isSaving = true);
                              await FirebaseFirestore.instance
                                  .collection('letter_requests')
                                  .doc(doc.id)
                                  .update({
                                'revisionNotes':
                                    notesCtrl.text.trim(),
                                'status': 'pending',
                              });
                              await activity_log
                                  .ActivityLogger.log(
                                action:
                                    'Requested revision for: ${doc.title}',
                                module: 'Letter Request',
                                severity: 'info',
                              );
                              if (mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context)
                                    .showSnackBar(const SnackBar(
                                  content: Text(
                                      'Revision request sent.'),
                                  behavior:
                                      SnackBarBehavior.floating,
                                ));
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Icon(
                              Icons.send_rounded, size: 15),
                      label: Text('Send Request',
                          style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color(0xFFD97706),
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
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Delete Confirm Dialog ──────────────────────────────────────────
  void _confirmDelete(LetterRequestDocument doc) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFDC2626),
                      size: 20),
                ),
                const SizedBox(width: 14),
                Text('Delete Letter Request',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    )),
              ]),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete "${doc.title}"? This action cannot be undone.',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    color: const Color(0xFF64748B),
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(
                          color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 11),
                    ),
                    child: Text('Cancel',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color:
                                const Color(0xFF374151))),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await FirebaseFirestore.instance
                            .collection('letter_requests')
                            .doc(doc.id)
                            .delete();
                        await activity_log
                            .ActivityLogger.log(
                          action:
                              'Deleted letter request: ${doc.title}',
                          module: 'Letter Request',
                          severity: 'warning',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content: const Text(
                                'Letter request deleted.'),
                            backgroundColor:
                                UpriseColors.primaryDark,
                            behavior:
                                SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(8)),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(
                            content:
                                Text('Error: $e'),
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
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────
  IconData _fileIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':  return Icons.picture_as_pdf_rounded;
      case 'doc':
      case 'docx': return Icons.description_rounded;
      case 'txt':  return Icons.text_snippet_rounded;
      default:     return Icons.insert_drive_file_rounded;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0)             return '—';
    if (bytes < 1024)           return '$bytes B';
    if (bytes < 1024 * 1024)    return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets (mirrors student_accounts.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String  label, value;
  final IconData icon;
  final Color   color;
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
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C))),
              ],
            ),
          ),
        ]),
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
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(
              fontSize: 13, color: const Color(0xFF374151)),
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s,
                        style: GoogleFonts.beVietnamPro(
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
                fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: UpriseColors.primaryDark,
          side: BorderSide(color: UpriseColors.primaryDark),
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 13, fontWeight: FontWeight.w600)),
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

class _ExportButton extends StatelessWidget {
  final String statusFilter, searchTerm;
  const _ExportButton({
    required this.statusFilter,
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
          .collection('letter_requests')
          .orderBy('uploadDate', descending: true)
          .get();
      var docs = snap.docs;
      if (statusFilter != 'All') {
        docs = docs
            .where((d) =>
                d.data()['status'] == statusFilter.toLowerCase())
            .toList();
      }
      if (searchTerm.isNotEmpty) {
        docs = docs.where((d) {
          final data = d.data();
          return (data['title']       ?? '').toString().toLowerCase().contains(searchTerm) ||
                 (data['requestedBy'] ?? '').toString().toLowerCase().contains(searchTerm);
        }).toList();
      }

      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No data to export.'),
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }

      String content, fileName;
      final now =
          DateTime.now().toString().substring(0, 10);

      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln(
            'Title,Requested By,Department,Upload Date,Status,File Name,File Size');
        for (final doc in docs) {
          final d = doc.data();
          String esc(String s) =>
              '"${s.replaceAll('"', '""')}"';
          final date = (d['uploadDate'] as Timestamp?)
                  ?.toDate()
                  .toString()
                  .substring(0, 10) ??
              '';
          buf.writeln([
            esc(d['title']       ?? ''),
            esc(d['requestedBy'] ?? ''),
            esc(d['department']  ?? ''),
            esc(date),
            esc(d['status']      ?? ''),
            esc(d['fileName']    ?? ''),
            esc(d['fileSize']?.toString() ?? '0'),
          ].join(','));
        }
        content  = buf.toString();
        fileName = 'letter_requests_$now.csv';
        await AdminExportUtil.saveText(
          content,
          fileName,
          mimeType: 'text/csv',
        );
      } else if (format == 'pdf') {
        final rows = docs.map((doc) {
          final d = doc.data();
          final date = (d['uploadDate'] as Timestamp?)
                  ?.toDate()
                  .toString()
                  .substring(0, 10) ??
              '';
          return [
            d['title']       ?? '',
            d['requestedBy'] ?? '',
            d['department']  ?? '',
            date,
            d['status']      ?? '',
            d['fileName']    ?? '',
            d['fileSize']?.toString() ?? '0',
          ].map((value) => value.toString()).toList();
        }).toList();

        final pdfBytes = await AdminExportPdf.generateTablePdf(
          title: 'Letter Requests Report',
          headers: const ['Title', 'Requested By', 'Department', 'Upload Date', 'Status', 'File Name', 'File Size'],
          rows: rows,
        );
        await AdminExportUtil.saveBytes(
          pdfBytes,
          'letter_requests_$now.pdf',
          mimeType: 'application/pdf',
        );
      } else {
        throw UnsupportedError('Unsupported export format: $format');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export failed: $e'),
        backgroundColor: UpriseColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8)),
      ));
    }
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String   tooltip;
  final VoidCallback? onTap;
  final Color?   color;
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
                  : (color ?? const Color(0xFF64748B))),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool     enabled;
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
  final int  page;
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
        margin: const EdgeInsets.symmetric(horizontal: 2),
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
            fontWeight:
                isActive ? FontWeight.w700 : FontWeight.normal,
            color: isActive
                ? Colors.white
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}