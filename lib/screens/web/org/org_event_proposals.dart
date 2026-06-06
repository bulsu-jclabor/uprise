// ignore_for_file: unused_field, duplicate_ignore, use_build_context_synchronously, deprecated_member_use
import 'dart:convert';
import 'dart:async';
import '../../../utils/platform_file_utils.dart' as platform_file_utils;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import '../../../services/activity_logger.dart' as activity_log;
import '../../../widgets/admin_export_button.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Status badge
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

Widget _statusBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'approved':   _BadgeStyle(const Color(0xFFECFDF5), const Color(0xFF059669), 'APPROVED'),
    'pending':    _BadgeStyle(const Color(0xFFFFFBEB), const Color(0xFFD97706), 'PENDING'),
    'rejected':   _BadgeStyle(const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'REJECTED'),
    'for_review': _BadgeStyle(const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'FOR REVIEW'),
  };
  final s = styles[status.toLowerCase()] ??
      _BadgeStyle(const Color(0xFFF3F4F6), const Color(0xFF6B7280), status.toUpperCase());
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

// ─────────────────────────────────────────────────────────────────────────────
// Section label helper
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [
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
      Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Input decoration helper
// ─────────────────────────────────────────────────────────────────────────────
InputDecoration _orgEventProposalsInputDecoration(String label, {String? hint, IconData? icon}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4)) : null,
    labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
    hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
    filled: true,
    fillColor: const Color(0xFFF8F9FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      borderSide: const BorderSide(color: Color(0xFFE2E6EA), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      borderSide: BorderSide(color: UpriseColors.error, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      borderSide: BorderSide(color: UpriseColors.error, width: 1.5),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgEventProposalsScreen extends StatefulWidget {
  final String orgId;
  const OrgEventProposalsScreen({super.key, required this.orgId});

  @override
  State<OrgEventProposalsScreen> createState() => _OrgEventProposalsScreenState();
}

class _OrgEventProposalsScreenState extends State<OrgEventProposalsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery  = '';
  String _filterStatus = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  // ── Streams ──────────────────────────────────────────────────────
  Stream<QuerySnapshot> get _allStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .snapshots();

  Stream<QuerySnapshot> get _pendingStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'pending')
      .snapshots();

  Stream<QuerySnapshot> get _approvedStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .snapshots();

  Stream<QuerySnapshot> get _forReviewStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'for_review')
      .snapshots();

  Stream<QuerySnapshot> get _proposalsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('submittedAt', descending: true)
      .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Filters ───────────────────────────────────────────────────────
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _applyFilters(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    var filtered = docs;
    if (_filterStatus != 'All') {
      final key = _filterStatus.toLowerCase().replaceAll(' ', '_');
      filtered = filtered.where((d) =>
          ((d.data())['status']?.toString().toLowerCase() ?? '') == key).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((d) {
        final data = d.data();
        return (data['title'] ?? '').toString().toLowerCase().contains(q) ||
            (data['category'] ?? '').toString().toLowerCase().contains(q) ||
            (data['location'] ?? '').toString().toLowerCase().contains(q);
      }).toList();
    }
    return filtered;
  }

  // ── Actions ───────────────────────────────────────────────────────
  void _openSubmitModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _SubmitProposalModal(orgId: widget.orgId),
    ).then((_) => setState(() {}));
  }

  void _openEditModal(String docId, Map<String, dynamic> data) {
  final status = data['status'] ?? 'pending';
  
  // Only pending proposals can be edited
  if (status != 'pending') {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Only pending proposals can be edited'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }
  
  showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _SubmitProposalModal(orgId: widget.orgId, editDocId: docId, existing: data),
  ).then((_) => setState(() {}));
}

  void _openViewModal(String docId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ViewProposalModal(docId: docId, data: data),
    );
  }

  // ── Archive logic (replaces delete for approved/rejected) ────────────────
void _confirmArchive(String docId, String title) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.archive_outlined, color: Color(0xFF6B7280), size: 20),
              ),
              const SizedBox(width: 14),
              Text('Archive Proposal',
                  style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
            ]),
            const SizedBox(height: 16),
            Text(
              'Are you sure you want to archive "$title"? You can still view it in the archived filter. This action can be reversed.',
              style: GoogleFonts.beVietnamPro(fontSize: 14, color: const Color(0xFF64748B), height: 1.5),
            ),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E6EA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _archiveProposal(docId, title);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B7280),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: Text('Archive', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

Future<void> _archiveProposal(String docId, String title) async {
  try {
    // Update proposal status to 'archived'
    await FirebaseFirestore.instance
        .collection('event_proposals')
        .doc(docId)
        .update({
      'status': 'archived',
      'archivedAt': FieldValue.serverTimestamp(),
      'archivedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });
    
    await activity_log.ActivityLogger.log(
      action: 'archive_proposal',
      module: 'event_proposals',
      details: {'orgId': widget.orgId, 'proposalId': docId, 'title': title},
    );
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Proposal "$title" has been archived'),
        backgroundColor: const Color(0xFF6B7280),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Archive failed: $e'),
        backgroundColor: UpriseColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
  }
}

  Future<void> _deleteProposalAndLinkedEvents(String docId, String title) async {
    try {
      final db = FirebaseFirestore.instance;

      final byProposalId = await db
          .collection('events')
          .where('createdFromProposalId', isEqualTo: docId)
          .get();

      final byOrgAndTitle = await db
          .collection('events')
          .where('orgId', isEqualTo: widget.orgId)
          .where('title', isEqualTo: title)
          .get();

      final eventIds = <String>{
        ...byProposalId.docs.map((d) => d.id),
        ...byOrgAndTitle.docs.map((d) => d.id),
      };

      for (final eventId in eventIds) {
        await db.collection('events').doc(eventId).delete();
        await activity_log.ActivityLogger.log(
          action: 'delete_event_from_proposal',
          module: 'events',
          details: {
            'orgId': widget.orgId,
            'eventId': eventId,
            'proposalId': docId,
          },
        );
      }

      await db.collection('event_proposals').doc(docId).delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_proposal',
        module: 'event_proposals',
        details: {'orgId': widget.orgId, 'proposalId': docId, 'title': title},
      );

      if (mounted) {
        final deleted = eventIds.length;
        final msg = deleted > 0
            ? 'Proposal and $deleted linked event${deleted == 1 ? '' : 's'} deleted'
            : 'Proposal deleted successfully';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Delete failed: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    }
  }

  // ── Export ────────────────────────────────────────────────────────
  Future<void> _exportProposals(String format) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('event_proposals')
        .where('orgId', isEqualTo: widget.orgId)
        .orderBy('submittedAt', descending: true)
        .get();
    final docs = _applyFilters(
        snapshot.docs.cast<QueryDocumentSnapshot<Map<String, dynamic>>>().toList());

    if (docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No data to export'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    final now = DateTime.now().toString().substring(0, 10);
    final fileName = 'event_proposals_$now';

    String _esc(String v) =>
        (v.contains(',') || v.contains('"') || v.contains('\n'))
            ? '"${v.replaceAll('"', '""')}"'
            : v;

    if (format == 'csv') {
      final buf = StringBuffer();
      buf.writeln('Proposal ID,Title,Category,Audience,Description,Date,Start Time,End Time,Location,Status,Submitted By,Submitted At');
      for (final doc in docs) {
        final d = doc.data();
        buf.writeln([
          'EP-${doc.id.substring(0, 4).toUpperCase()}',
          _esc(d['title'] ?? ''),
          _esc(d['category'] ?? ''),
          _esc(d['audience'] ?? ''),
          _esc(d['description'] ?? ''),
          d['date'] != null ? DateFormat('yyyy-MM-dd').format((d['date'] as Timestamp).toDate()) : '',
          d['startTime'] ?? '',
          d['endTime'] ?? '',
          _esc(d['location'] ?? ''),
          d['status'] ?? 'pending',
          d['submittedByEmail'] ?? '',
          d['submittedAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((d['submittedAt'] as Timestamp).toDate()) : '',
        ].join(','));
      }
      await OrgExportUtil.saveText(buf.toString(), '$fileName.csv', mimeType: 'text/csv');
    } else if (format == 'pdf') {
      final rows = docs.map((doc) {
        final d = doc.data();
        return <String>[
          'EP-${doc.id.substring(0, 4).toUpperCase()}',
          d['title'] ?? '',
          d['category'] ?? '',
          d['audience'] ?? '',
          d['description'] ?? '',
          d['date'] != null ? DateFormat('yyyy-MM-dd').format((d['date'] as Timestamp).toDate()) : '',
          d['startTime'] ?? '',
          d['endTime'] ?? '',
          d['location'] ?? '',
          d['status'] ?? 'pending',
          d['submittedByEmail'] ?? '',
          d['submittedAt'] != null ? DateFormat('yyyy-MM-dd HH:mm').format((d['submittedAt'] as Timestamp).toDate()) : '',
        ];
      }).toList();
      final pdfBytes = await OrgExportPdf.generateTablePdf(
        title: 'Event Proposals Report',
        headers: const ['Proposal ID', 'Title', 'Category', 'Audience', 'Description', 'Date', 'Start Time', 'End Time', 'Location', 'Status', 'Submitted By', 'Submitted At'],
        rows: rows,
      );
      await OrgExportUtil.saveBytes(pdfBytes, '$fileName.pdf', mimeType: 'application/pdf');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Exported ${docs.length} proposals as $format'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
    }
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
      child: Row(children: [
        _StatCard(
          label: 'Total Proposals',
          stream: _allStream,
          icon: Icons.description_outlined,
          color: UpriseColors.primaryDark,
        ),
        const SizedBox(width: 14),
        _StatCard(
          label: 'Pending',
          stream: _pendingStream,
          icon: Icons.hourglass_empty_rounded,
          color: const Color(0xFFD97706),
        ),
        const SizedBox(width: 14),
        _StatCard(
          label: 'Approved',
          stream: _approvedStream,
          icon: Icons.check_circle_outline_rounded,
          color: const Color(0xFF059669),
        ),
        const SizedBox(width: 14),
        _StatCard(
          label: 'For Review',
          stream: _forReviewStream,
          icon: Icons.rate_review_outlined,
          color: const Color(0xFF2563EB),
        ),
      ]),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by title, category, or location…',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
                ),
              ),
              onChanged: (v) => setState(() { _searchQuery = v; _currentPage = 1; }),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _FilterDropdown(
          value: _filterStatus,
          items: const ['All', 'Pending', 'Approved', 'For Review', 'Rejected', 'Archived'],
          hint: 'Status',
          icon: Icons.tune_rounded,
          onChanged: (v) => setState(() { _filterStatus = v!; _currentPage = 1; }),
        ),
        const SizedBox(width: 10),
        AdminExportButton(
          label: 'Export',
          onSelected: (format) => _exportProposals(format),
        ),
        const SizedBox(width: 10),
        _ToolbarButton(
          label: 'Submit Proposal',
          icon: Icons.add_rounded,
          onPressed: _openSubmitModal,
        ),
      ]),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _proposalsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allDocs = (snapshot.data?.docs ?? [])
            .cast<QueryDocumentSnapshot<Map<String, dynamic>>>();
        final filtered = _applyFilters(allDocs);

        final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, filtered.length);
        final pageDocs = filtered.isEmpty ? <QueryDocumentSnapshot<Map<String, dynamic>>>[] : filtered.sublist(start, end);

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
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: pageDocs.length,
                      itemBuilder: (_, i) {
                        final doc = pageDocs[i];
                        final data = doc.data();
                        return _buildProposalRow(
                          docId: doc.id,
                          data: data,
                          isLast: i == pageDocs.length - 1,
                        );
                      },
                    ),
            ),
            _buildFooter(filtered.length, totalPages, start, end),
          ]),
        );
      },
    );
  }

  // ============ UPDATED TABLE HEADER - REMOVED PROPOSAL # COLUMN ============
  Widget _buildTableHeader() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    decoration: const BoxDecoration(
      color: Color(0xFFF8F9FB),
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
    ),
    child: Row(children: [
      Expanded(flex: 4, child: _headerCell('EVENT TITLE')),  // <-- EVENT TITLE na agad
      Expanded(flex: 2, child: _headerCell('CATEGORY')),
      Expanded(flex: 2, child: _headerCell('AUDIENCE')),
      Expanded(flex: 2, child: _headerCell('DATE')),
      Expanded(flex: 2, child: _headerCell('TIME')),
      Expanded(flex: 2, child: _headerCell('LOCATION')),
      Expanded(flex: 2, child: _headerCell('STATUS')),
      Expanded(flex: 2, child: _headerCell('SUBMITTED')),
      Expanded(flex: 2, child: Align(
        alignment: Alignment.centerRight,
        child: _headerCell('ACTIONS'),
      )),
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

  Widget _buildProposalRow({
  required String docId,
  required Map<String, dynamic> data,
  required bool isLast,
}) {
  final status = (data['status'] ?? 'pending').toString().toLowerCase();
  // TANGGALIN mo na si proposalNum variable - hindi na kailangan
  final date = data['date'];
  final dateStr = date is Timestamp
      ? DateFormat('MMM dd, yyyy').format(date.toDate())
      : '—';
  final startTime = data['startTime'] ?? '';
  final endTime = data['endTime'] ?? '';
  final timeStr = (startTime.isNotEmpty && endTime.isNotEmpty) 
      ? '$startTime - $endTime' 
      : (startTime.isNotEmpty ? startTime : '—');
  final submittedAt = data['submittedAt'];
  final submittedStr = submittedAt is Timestamp
      ? DateFormat('MMM dd, yyyy').format(submittedAt.toDate())
      : '—';

  return InkWell(
    hoverColor: const Color(0xFFF8F9FB),
    onTap: () => _openViewModal(docId, data),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(children: [
        // ITO NA ANG UNA - EVENT TITLE (walang proposal #)
        Expanded(
          flex: 4,  // GINAWA KONG 4 (dating 2 + 2)
          child: Text(
            data['title'] ?? '—',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A202C),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // CATEGORY
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.07),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              data['category'] ?? '—',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: UpriseColors.primaryDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        // AUDIENCE
        Expanded(
          flex: 2,
          child: _audienceChip(data['audience'] ?? 'Public'),
        ),
        // DATE
        Expanded(
          flex: 2,
          child: Text(dateStr,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
        ),
        // TIME
        Expanded(
          flex: 2,
          child: Text(
            timeStr,
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // LOCATION
        Expanded(
          flex: 2,
          child: Text(
            data['location'] ?? '—',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // STATUS
        Expanded(flex: 2, child: _statusBadge(status)),
        // SUBMITTED
        Expanded(
          flex: 2,
          child: Text(submittedStr,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
        ),
        // ACTIONS (same pa rin)
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionIconButton(
                icon: Icons.visibility_outlined,
                tooltip: 'View Details',
                onTap: () => _openViewModal(docId, data),
              ),
              if (status == 'pending') ...[
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit Proposal',
                  color: UpriseColors.primaryDark,
                  onTap: () => _openEditModal(docId, data),
                ),
              ],
              if (status == 'approved' || status == 'rejected') ...[
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.archive_outlined,
                  tooltip: 'Archive Proposal',
                  color: const Color(0xFF6B7280),
                  onTap: () => _confirmArchive(docId, data['title'] ?? 'Proposal'),
                ),
              ],
            ],
          ),
        ),
      ]),
    ),
  );
}

  Widget _audienceChip(String audience) {
    Color bg;
    Color fg;
    if (audience == 'Public') {
      bg = const Color(0xFFECFDF5);
      fg = const Color(0xFF059669);
    } else if (audience == 'CICT Only') {
      bg = const Color(0xFFEFF6FF);
      fg = const Color(0xFF2563EB);
    } else {
      bg = const Color(0xFFFFFBEB);
      fg = const Color(0xFFD97706);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        audience,
        style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.description_outlined, size: 40, color: Color(0xFF9AA5B4)),
        ),
        const SizedBox(height: 16),
        Text('No proposals found',
            style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        Text('Submit your first event proposal to get started.',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _openSubmitModal,
          icon: const Icon(Icons.add_rounded, size: 15),
          label: Text('Submit Proposal', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: UpriseColors.primaryDark,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          ),
        ),
      ]),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage  = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          'Showing ${total == 0 ? 0 : start + 1}–$end of $total proposals',
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
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
              child: Text('…', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12)),
            ),
            _PageNumButton(
              page: totalPages,
              isActive: _currentPage == totalPages,
              onTap: () => setState(() => _currentPage = totalPages),
            ),
          ],
          const SizedBox(width: 4),
          _PageButton(
            icon: Icons.chevron_right_rounded,
            enabled: _currentPage < totalPages,
            onTap: () => setState(() => _currentPage++),
          ),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Card
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final Stream<QuerySnapshot> stream;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.stream, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: stream,
        builder: (context, snapshot) {
          final count = snapshot.data?.docs.length ?? 0;
          return Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('$count', style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
                ]),
              ),
            ]),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable small widgets
// ─────────────────────────────────────────────────────────────────────────────
class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String hint;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.items, required this.hint, required this.icon, required this.onChanged});

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
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.beVietnamPro(fontSize: 13)))).toList(),
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
        label: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: UpriseColors.primaryDark,
          side: BorderSide(color: UpriseColors.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
      style: ElevatedButton.styleFrom(
        backgroundColor: UpriseColors.primaryDark,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionIconButton({required this.icon, required this.tooltip, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16,
              color: onTap == null ? const Color(0xFFD1D5DB) : (color ?? const Color(0xFF64748B))),
        ),
      ),
    );
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: 20, color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
      ),
    );
  }
}

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumButton({required this.page, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? UpriseColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text('$page',
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
              color: isActive ? Colors.white : const Color(0xFF374151),
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Submit / Edit Modal
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitProposalModal extends StatefulWidget {
  final String orgId;
  final String? editDocId;
  final Map<String, dynamic>? existing;
  const _SubmitProposalModal({required this.orgId, this.editDocId, this.existing});

  @override
  State<_SubmitProposalModal> createState() => _SubmitProposalModalState();
}

class _SubmitProposalModalState extends State<_SubmitProposalModal> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  final _locCtrl     = TextEditingController();
  final _dateCtrl    = TextEditingController();
  final _startTimeCtrl = TextEditingController();
  final _endTimeCtrl   = TextEditingController();

  String _category = 'Workshop';
  String _audience = 'Public';
  bool _isSubmitting = false;
  String? _errorMsg;
  bool _issuesCertificate = false;

  String? _attachmentBase64;
  String? _attachmentName;
  String? _attachmentSize;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  static const _categories = [
    'Workshop', 'Seminar', 'Competition', 'General Assembly',
    'Social', 'Outreach', 'Sports', 'Academic', 'Technical', 'Cultural', 'Other',
  ];
  static const _audiences = ['Public', 'CICT Only', 'Members Only'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleCtrl.text = e['title'] ?? '';
      _descCtrl.text  = e['description'] ?? '';
      _locCtrl.text   = e['location'] ?? '';
      _startTimeCtrl.text = e['startTime'] ?? '';
      _endTimeCtrl.text   = e['endTime'] ?? '';
      _attachmentBase64 = e['attachmentBase64'];
      _attachmentName   = e['attachmentName'];
      _attachmentSize   = e['attachmentSize'];
      if (e['date'] is Timestamp) {
        _dateCtrl.text = DateFormat('MM/dd/yyyy').format((e['date'] as Timestamp).toDate());
      }
      final cat = e['category'] ?? 'Workshop';
      _category = _categories.contains(cat) ? cat : 'Workshop';
      _audience = e['audience'] ?? 'Public';
      _issuesCertificate = e['issuesCertificate'] == true;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locCtrl.dispose();
    _dateCtrl.dispose();
    _startTimeCtrl.dispose();
    _endTimeCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'jpg', 'png'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      _showError('Cannot read file!');
      return;
    }
    final sizeBytes = file.bytes!.length;
    if (sizeBytes > 700 * 1024) {
      _showError('File too large. Max 700 KB allowed.');
      return;
    }
    final sizeKB = (sizeBytes / 1024).toStringAsFixed(1);
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _attachmentName = file.name;
      _attachmentSize = '$sizeKB KB';
    });
    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) setState(() => _uploadProgress = i / 100);
    }
    setState(() {
      _attachmentBase64 = base64Encode(file.bytes!);
      _uploadProgress = 1.0;
      _isUploading = false;
    });
  }

  void _removeFile() => setState(() {
    _attachmentBase64 = null;
    _attachmentName   = null;
    _attachmentSize   = null;
    _uploadProgress   = 0.0;
  });

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: UpriseColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isSubmitting = true; _errorMsg = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      String orgName = '';
      try {
        final orgDoc = await FirebaseFirestore.instance.collection('organizations').doc(widget.orgId).get();
        if (orgDoc.exists) orgName = orgDoc.data()?['name'] ?? '';
      } catch (_) {}

      final payload = <String, dynamic>{
        'orgId': widget.orgId,
        'orgName': orgName,
        'title': _titleCtrl.text.trim(),
        'category': _category,
        'audience': _audience,
        'description': _descCtrl.text.trim(),
        'location': _locCtrl.text.trim(),
        'startTime': _startTimeCtrl.text.trim(),
        'endTime': _endTimeCtrl.text.trim(),
        'submittedBy': user?.uid ?? '',
        'submittedByEmail': user?.email ?? '',
        'issuesCertificate': _issuesCertificate,
        'attachmentBase64': _attachmentBase64,
        'attachmentName': _attachmentName,
        'attachmentSize': _attachmentSize,
      };

      try {
        final parsed = DateFormat('MM/dd/yyyy').parse(_dateCtrl.text.trim());
        payload['date'] = Timestamp.fromDate(parsed);
      } catch (_) {}

      final col = FirebaseFirestore.instance.collection('event_proposals');
      if (widget.editDocId != null) {
        await col.doc(widget.editDocId).update(payload);
        await activity_log.ActivityLogger.log(
          action: 'edit_proposal', module: 'event_proposals',
          details: {'orgId': widget.orgId, 'proposalId': widget.editDocId},
        );
      } else {
        payload['status'] = 'pending';
        payload['createdAt'] = FieldValue.serverTimestamp();
        payload['submittedAt'] = FieldValue.serverTimestamp();
        final ref = await col.add(payload);
        await activity_log.ActivityLogger.log(
          action: 'submit_proposal', module: 'event_proposals',
          details: {'orgId': widget.orgId, 'proposalId': ref.id},
        );
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.editDocId != null ? 'Proposal updated.' : 'Proposal submitted successfully!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      setState(() { _errorMsg = e.toString(); _isSubmitting = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.editDocId != null;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 560,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: Icon(isEdit ? Icons.edit_rounded : Icons.description_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isEdit ? 'Edit Event Proposal' : 'Submit Event Proposal',
                  style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              ),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _sectionLabel('Event Details', icon: Icons.event_outlined),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _titleCtrl,
                        decoration: _orgEventProposalsInputDecoration('Event Title *', hint: 'e.g. Flutter Workshop 2025', icon: Icons.title),
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        decoration: _orgEventProposalsInputDecoration('Category *'),
                        style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _audience,
                    decoration: _orgEventProposalsInputDecoration('Audience *'),
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                    items: _audiences.map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                    onChanged: (v) => setState(() => _audience = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descCtrl,
                    maxLines: 3,
                    decoration: _orgEventProposalsInputDecoration('Description *', hint: 'Describe your event...', icon: Icons.notes_rounded),
                    style: GoogleFonts.beVietnamPro(fontSize: 13),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateCtrl,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) _dateCtrl.text = DateFormat('MM/dd/yyyy').format(picked);
                        },
                        decoration: _orgEventProposalsInputDecoration('Date *', hint: 'MM/DD/YYYY', icon: Icons.calendar_today_outlined),
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _startTimeCtrl,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked != null && mounted) _startTimeCtrl.text = picked.format(context);
                        },
                        decoration: _orgEventProposalsInputDecoration('Start Time *', hint: '-- : --', icon: Icons.access_time_rounded),
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _endTimeCtrl,
                        readOnly: true,
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked != null && mounted) _endTimeCtrl.text = picked.format(context);
                        },
                        decoration: _orgEventProposalsInputDecoration('End Time *', hint: '-- : --', icon: Icons.access_time_rounded),
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _locCtrl,
                    decoration: _orgEventProposalsInputDecoration('Location *', hint: 'e.g. IT Building Room 301', icon: Icons.location_on_outlined),
                    style: GoogleFonts.beVietnamPro(fontSize: 13),
                    validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    title: Text('Issue certificates to participants/guests', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                    value: _issuesCertificate,
                    onChanged: (v) => setState(() => _issuesCertificate = v ?? false),
                  ),
                  const SizedBox(height: 20),
                  _sectionLabel('Attachment', icon: Icons.attach_file_rounded),
                  _buildFileArea(),
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.error_outline_rounded, size: 15, color: Color(0xFFDC2626)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_errorMsg!,
                            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF991B1B)))),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E6EA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: (_isSubmitting || _isUploading) ? null : _submit,
                icon: _isSubmitting
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Icon(isEdit ? Icons.save_rounded : Icons.send_rounded, size: 16),
                label: Text(
                  isEdit ? 'Save Changes' : 'Submit Proposal',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildFileArea() {
    final hasFile = _attachmentBase64 != null;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isUploading
              ? UpriseColors.primaryDark.withOpacity(0.4)
              : hasFile ? const Color(0xFF059669) : const Color(0xFFE2E6EA),
          width: (_isUploading || hasFile) ? 1.5 : 1,
        ),
      ),
      child: _isUploading
          ? _uploadingState()
          : hasFile ? _uploadedState() : _idleState(),
    );
  }

  Widget _idleState() => GestureDetector(
    onTap: _pickFile,
    behavior: HitTestBehavior.opaque,
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: UpriseColors.primaryDark.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.cloud_upload_outlined, size: 24, color: UpriseColors.primaryDark),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
            children: [
              TextSpan(text: 'Click to upload ', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.primaryDark, fontWeight: FontWeight.w600)),
              const TextSpan(text: 'proposal documents'),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text('PDF, DOC, DOCX, TXT, JPG, PNG — max 700 KB',
            style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4))),
      ]),
    ]),
  );

  Widget _uploadingState() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(Icons.insert_drive_file_outlined, size: 16, color: UpriseColors.primaryDark),
      const SizedBox(width: 10),
      Expanded(child: Text(_attachmentName ?? 'Uploading...',
          style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
          overflow: TextOverflow.ellipsis)),
      Text(_attachmentSize ?? '', style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
    ]),
    const SizedBox(height: 10),
    ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: _uploadProgress, minHeight: 6,
        backgroundColor: const Color(0xFFE2E6EA),
        valueColor: AlwaysStoppedAnimation<Color>(UpriseColors.primaryDark),
      ),
    ),
    const SizedBox(height: 6),
    Text('Uploading ${(_uploadProgress * 100).toInt()}%',
        style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF64748B))),
  ]);

  Widget _uploadedState() => Row(children: [
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF059669)),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_attachmentName ?? 'File attached',
          style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
          overflow: TextOverflow.ellipsis),
      if (_attachmentSize != null)
        Text(_attachmentSize!, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF059669))),
    ])),
    TextButton(
      onPressed: _removeFile,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      child: Text('Remove', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFFDC2626))),
    ),
    TextButton(
      onPressed: _pickFile,
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
      child: Text('Change', style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.primaryDark)),
    ),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// View Proposal Modal - UPDATED with Proposal ID in header
// ─────────────────────────────────────────────────────────────────────────────
class _ViewProposalModal extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  const _ViewProposalModal({required this.docId, required this.data});

  String _fmt(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) return DateFormat('MMMM dd, yyyy').format(ts.toDate());
    return ts.toString();
  }

  static String _mimeFromExt(String ext) {
    switch (ext) {
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'pdf': return 'application/pdf';
      case 'txt': return 'text/plain';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status   = (data['status'] ?? 'pending').toString().toLowerCase();
    final propNum  = 'EP-${docId.substring(0, 4).toUpperCase()}';
    final hasFile  = data['attachmentBase64'] != null && data['attachmentBase64'].toString().isNotEmpty;
    
    final startTime = data['startTime'] ?? '';
    final endTime = data['endTime'] ?? '';
    final timeStr = (startTime.isNotEmpty && endTime.isNotEmpty) 
        ? '$startTime - $endTime' 
        : (startTime.isNotEmpty ? startTime : '—');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.description_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              // ============ ADDED PROPOSAL ID HERE ============
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(data['title'] ?? 'Proposal Details',
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 2),
                Text(propNum,  // <-- Proposal ID now visible here
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white.withOpacity(0.7))),
              ])),
              _statusBadge(status),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _detailItem('Category', data['category'] ?? '—', Icons.category_outlined)),
                  const SizedBox(width: 16),
                  Expanded(child: _detailItem('Audience', data['audience'] ?? '—', Icons.people_outline)),
                ]),
                const SizedBox(height: 14),
                _detailItem('Description', data['description'] ?? '—', Icons.notes_rounded),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _detailItem('Date', _fmt(data['date']), Icons.calendar_today_outlined)),
                  const SizedBox(width: 16),
                  Expanded(child: _detailItem('Time', timeStr, Icons.access_time_rounded)),
                ]),
                const SizedBox(height: 14),
                _detailItem('Location', data['location'] ?? '—', Icons.location_on_outlined),
                const SizedBox(height: 14),
                _detailItem('Submitted', _fmt(data['submittedAt']), Icons.send_outlined),
                
                // Wet Sign Schedule
                if (data['wetSignSchedule'] != null) ...[
                  const SizedBox(height: 20),
                  _buildWetSignInfo(),
                ],
                
                if (hasFile) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E6EA)),
                    ),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: UpriseColors.primaryDark.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.insert_drive_file_rounded, size: 20, color: UpriseColors.primaryDark),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(data['attachmentName'] ?? 'Attached File',
                            style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        if (data['attachmentSize'] != null)
                          Text(data['attachmentSize'], style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                      ])),
                      TextButton.icon(
                        onPressed: () => _openAttachment(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Open'),
                        style: TextButton.styleFrom(foregroundColor: UpriseColors.primaryDark),
                      ),
                    ]),
                  ),
                ],
              ]),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                ),
                child: Text('Close', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _detailItem(String label, String value, IconData icon) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 13, color: const Color(0xFF9AA5B4)),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B), letterSpacing: 0.4)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C))),
    ]);
  }

  Widget _buildWetSignInfo() {
    final wetSign = data['wetSignSchedule'];
    if (wetSign == null) return const SizedBox.shrink();
    
    final startDateTime = wetSign['startDateTime'] as Timestamp?;
    final endDateTime = wetSign['endDateTime'] as Timestamp?;
    final location = wetSign['location'] ?? 'Dean\'s Office';
    
    if (startDateTime == null) return const SizedBox.shrink();
    
    final startDate = startDateTime.toDate();
    final endDate = endDateTime?.toDate();
    
    final dateStr = DateFormat('MMMM dd, yyyy').format(startDate);
    final startTimeStr = DateFormat('h:mm a').format(startDate);
    final endTimeStr = endDate != null ? DateFormat('h:mm a').format(endDate) : 'TBD';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF059669).withOpacity(0.08), const Color(0xFF059669).withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF059669).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF059669), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '📄 Wet Sign Schedule',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF059669),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildWetSignDetailRow(Icons.calendar_today_outlined, 'Date', dateStr),
          const SizedBox(height: 8),
          _buildWetSignDetailRow(Icons.access_time_rounded, 'Time', '$startTimeStr - $endTimeStr'),
          const SizedBox(height: 8),
          _buildWetSignDetailRow(Icons.location_on_outlined, 'Location', location),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please bring printed copies of your proposal documents for signing.',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF065F46)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWetSignDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF059669)),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1F2937)),
          ),
        ),
      ],
    );
  }

  Future<void> _openAttachment(BuildContext context) async {
    final b64 = data['attachmentBase64'];
    if (b64 == null || b64.toString().isEmpty) return;
    try {
      final bytes = base64Decode(b64.toString());
      final name  = data['attachmentName'] ?? 'document';
      final ext   = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      final mime  = _mimeFromExt(ext);

      if (mime.startsWith('image/')) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(8),
                  child: Text(name, style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600))),
              Flexible(child: Image.memory(bytes)),
              Padding(padding: const EdgeInsets.all(8),
                child: TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
              ),
            ]),
          ),
        );
      } else if (mime == 'text/plain') {
        final text = utf8.decode(bytes);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(name),
            content: SingleChildScrollView(child: SelectableText(text)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
          ),
        );
      } else {
        await platform_file_utils.saveBytesToTempAndOpen(bytes, name);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening attachment: $e')));
      }
    }
  }
}