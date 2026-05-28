// ignore_for_file: unused_field, duplicate_ignore, use_build_context_synchronously, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — identical to student_accounts / org_event_proposals
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
// Certificate status badge — mirrors _statusBadge pattern exactly
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

Widget _certBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'distributed':   _BadgeStyle(const Color(0xFFECFDF5), const Color(0xFF059669), 'DISTRIBUTED'),
    'pending':       _BadgeStyle(const Color(0xFFFFFBEB), const Color(0xFFD97706), 'PENDING'),
    'draft':         _BadgeStyle(const Color(0xFFF3F4F6), const Color(0xFF6B7280), 'DRAFT'),
    'undistributed': _BadgeStyle(const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'UNDISTRIBUTED'),
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
InputDecoration _fieldDecoration({String? label, String? hint, IconData? icon}) {
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
// Models
// ─────────────────────────────────────────────────────────────────────────────
class CertificateRecord {
  final String id;
  final String certificateId;
  final String eventName;
  final String organization;
  final String type;
  final DateTime date;
  final int recipients;
  final String status;
  final String templateType;
  final String? templateFileUrl;

  const CertificateRecord({
    required this.id,
    required this.certificateId,
    required this.eventName,
    required this.organization,
    required this.type,
    required this.date,
    required this.recipients,
    required this.status,
    required this.templateType,
    this.templateFileUrl,
  });

  factory CertificateRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CertificateRecord(
      id:            doc.id,
      certificateId: 'CERT-${doc.id.substring(0, 4).toUpperCase()}',
      eventName:     d['eventName'] as String? ?? d['certificateName'] as String? ?? 'Untitled',
      organization:  d['organization'] as String? ?? 'N/A',
      type:          d['type'] as String? ?? 'Participation',
      date:          (d['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      recipients:    (d['recipients'] as num?)?.toInt() ?? 1,
      status:        d['status'] as String? ?? 'draft',
      templateType:  d['templateType'] as String? ?? 'Formal Academic',
      templateFileUrl: d['templateFileUrl'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgCertificatesScreen extends StatefulWidget {
  final String orgId;
  const OrgCertificatesScreen({super.key, required this.orgId});

  @override
  State<OrgCertificatesScreen> createState() => _OrgCertificatesScreenState();
}

class _OrgCertificatesScreenState extends State<OrgCertificatesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery  = '';
  String _filterStatus = 'All';
  int _currentPage     = 1;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> get _certsStream => FirebaseFirestore.instance
      .collection('certificates')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('issuedAt', descending: true)
      .snapshots();

  void _openGenerateFlow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _SelectTemplateModal(
        orgId: widget.orgId,
        onConfirm: (templateType, templateUrl) {
          Navigator.pop(context);
          showDialog(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black54,
            builder: (_) => _GenerateCertificateModal(
              orgId: widget.orgId,
              selectedTemplateType: templateType,
              selectedTemplateUrl: templateUrl,
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
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

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _certsStream,
      builder: (context, snapshot) {
        final docs         = snapshot.data?.docs ?? [];
        final total        = docs.length;
        final totalRec     = docs.fold<int>(0, (s, d) => s + ((d.data() as Map<String, dynamic>)['recipients'] as num? ?? 1).toInt());
        final distributed  = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'distributed').length;
        final pending      = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(label: 'Total Certificates', value: total,       icon: Icons.card_membership_outlined,     color: const Color(0xFF2563EB)),
            const SizedBox(width: 14),
            _StatCard(label: 'Total Recipients',   value: totalRec,    icon: Icons.people_outline_rounded,       color: const Color(0xFFD97706)),
            const SizedBox(width: 14),
            _StatCard(label: 'Distributed',        value: distributed, icon: Icons.assignment_turned_in_outlined, color: const Color(0xFF059669)),
            const SizedBox(width: 14),
            _StatCard(label: 'Pending',            value: pending,     icon: Icons.pending_outlined,             color: UpriseColors.primaryDark),
          ]),
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
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
                hintText: 'Search by ID, event name, or organization…',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
              ),
              onChanged: (v) => setState(() { _searchQuery = v.toLowerCase(); _currentPage = 1; }),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _FilterDropdown(
          value: _filterStatus,
          items: const ['All', 'Distributed', 'Pending', 'Draft', 'Undistributed'],
          onChanged: (v) => setState(() { _filterStatus = v!; _currentPage = 1; }),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _openGenerateFlow,
          icon: const Icon(Icons.add_rounded, size: 15),
          label: Text('Generate Certificate', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: UpriseColors.primaryDark,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            elevation: 0,
          ),
        ),
      ]),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────────────
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: _certsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = (snapshot.data?.docs ?? []).cast<QueryDocumentSnapshot>();

        // Filters
        if (_filterStatus != 'All') {
          docs = docs.where((d) =>
              (d.data() as Map<String, dynamic>)['status']?.toString().toLowerCase() ==
              _filterStatus.toLowerCase()).toList();
        }
        if (_searchQuery.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = (data['eventName'] ?? '').toString().toLowerCase();
            final org  = (data['organization'] ?? '').toString().toLowerCase();
            final id   = 'CERT-${d.id.substring(0, 4).toUpperCase()}'.toLowerCase();
            return name.contains(_searchQuery) || org.contains(_searchQuery) || id.contains(_searchQuery);
          }).toList();
        }

        final records = docs.map((d) => CertificateRecord.fromFirestore(d)).toList();

        final totalPages = records.isEmpty ? 1 : (records.length / _pageSize).ceil();
        final safePage   = _currentPage.clamp(1, totalPages);
        final start      = (safePage - 1) * _pageSize;
        final end        = (start + _pageSize).clamp(0, records.length);
        final pageItems  = records.isEmpty ? <CertificateRecord>[] : records.sublist(start, end);

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
              child: records.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: pageItems.length,
                      itemBuilder: (_, i) => _buildRow(pageItems[i], i == pageItems.length - 1),
                    ),
            ),
            _buildFooter(records.length, totalPages, start, end),
          ]),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: _headerCell('CERTIFICATE ID')),
        Expanded(flex: 3, child: _headerCell('EVENT NAME')),
        Expanded(flex: 2, child: _headerCell('ORGANIZATION')),
        Expanded(flex: 2, child: _headerCell('TYPE')),
        Expanded(flex: 2, child: _headerCell('DATE ISSUED')),
        Expanded(flex: 1, child: _headerCell('RECIPIENTS')),
        Expanded(flex: 2, child: _headerCell('STATUS')),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('ACTIONS'))),
      ]),
    );
  }

  Widget _headerCell(String text) => Text(
    text,
    style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF64748B), letterSpacing: 0.7),
  );

  Widget _buildRow(CertificateRecord r, bool isLast) {
    return InkWell(
      hoverColor: const Color(0xFFF8F9FB),
      onTap: () => _viewCert(r),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(children: [
          // Cert ID
          Expanded(
            flex: 2,
            child: Text(r.certificateId,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
          ),
          // Event name
          Expanded(
            flex: 3,
            child: Text(r.eventName,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
                overflow: TextOverflow.ellipsis),
          ),
          // Organization chip — mirrors course chip from student_accounts
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark.withOpacity(0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(r.organization,
                  style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark),
                  overflow: TextOverflow.ellipsis),
            ),
          ),
          // Type
          Expanded(
            flex: 2,
            child: Text(r.type,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(DateFormat('MMM d, yyyy').format(r.date),
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          // Recipients
          Expanded(
            flex: 1,
            child: Text('${r.recipients}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
          ),
          // Status badge
          Expanded(flex: 2, child: _certBadge(r.status)),
          // Actions
          Expanded(
            flex: 2,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionIconButton(icon: Icons.visibility_outlined,    tooltip: 'View',   color: const Color(0xFF2563EB),  onTap: () => _viewCert(r)),
              const SizedBox(width: 4),
              _ActionIconButton(icon: Icons.edit_outlined,          tooltip: 'Edit',   color: UpriseColors.primaryDark, onTap: () => _editCert(r)),
              const SizedBox(width: 4),
              _ActionIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: const Color(0xFFDC2626),  onTap: () => _confirmDelete(r)),
            ]),
          ),
        ]),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────
  void _viewCert(CertificateRecord r) {
    showDialog(context: context, barrierColor: Colors.black54, builder: (_) => _CertPreviewDialog(record: r));
  }

  void _editCert(CertificateRecord r) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _GenerateCertificateModal(
        orgId: widget.orgId,
        selectedTemplateType: r.templateType,
        selectedTemplateUrl: r.templateFileUrl,
        existingRecord: r,
      ),
    );
  }

  void _confirmDelete(CertificateRecord r) {
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
                  decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                ),
                const SizedBox(width: 14),
                Text('Delete Certificate',
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
              ]),
              const SizedBox(height: 16),
              Text('Delete "${r.certificateId}"? This action cannot be undone.',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: const Color(0xFF64748B), height: 1.5)),
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
                    try {
                      await FirebaseFirestore.instance.collection('certificates').doc(r.id).delete();
                      await activity_log.ActivityLogger.log(
                        action: 'delete_certificate', module: 'certificates',
                        details: {'certId': r.id, 'eventName': r.eventName},
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Certificate deleted', style: GoogleFonts.beVietnamPro(color: Colors.white)),
                          backgroundColor: const Color(0xFF059669),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Delete', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.card_membership_outlined, size: 40, color: Color(0xFF9AA5B4)),
        ),
        const SizedBox(height: 16),
        Text('No certificates issued yet',
            style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        Text('Click "Generate Certificate" to create your first one.',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _openGenerateFlow,
          icon: const Icon(Icons.add_rounded, size: 15),
          label: Text('Generate Certificate', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
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
        Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total certificates',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
        Row(children: [
          _PageButton(icon: Icons.chevron_left_rounded,  enabled: _currentPage > 1,          onTap: () => setState(() => _currentPage--)),
          const SizedBox(width: 4),
          ...pages.map((p) => _PageNumButton(page: p, isActive: p == _currentPage, onTap: () => setState(() => _currentPage = p))),
          if (lastPage < totalPages) ...[
            Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12))),
            _PageNumButton(page: totalPages, isActive: _currentPage == totalPages, onTap: () => setState(() => _currentPage = totalPages)),
          ],
          const SizedBox(width: 4),
          _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
        ]),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat Card — mirrors student_accounts _StatCard exactly
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

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
            width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text('$value', style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
          ])),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable small widgets — mirrors student_accounts
// ─────────────────────────────────────────────────────────────────────────────
class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.items, required this.onChanged});

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

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;
  const _ActionIconButton({required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: onTap == null ? const Color(0xFFD1D5DB) : color),
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
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(icon, size: 20, color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
    ),
  );
}

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumButton({required this.page, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
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

// ─────────────────────────────────────────────────────────────────────────────
// Step 1 — Select Template Modal
// ─────────────────────────────────────────────────────────────────────────────
class _SelectTemplateModal extends StatefulWidget {
  final String orgId;
  final void Function(String templateType, String? templateUrl) onConfirm;
  const _SelectTemplateModal({required this.orgId, required this.onConfirm});

  @override
  State<_SelectTemplateModal> createState() => _SelectTemplateModalState();
}

class _SelectTemplateModalState extends State<_SelectTemplateModal> {
  String _selected = 'Formal Academic';
  String? _selectedCustomTemplateName;
  String? _selectedTemplateUrl;

  final Map<String, double> _completionLevels = {
    'Formal Academic': 0.85,
    'Modern Workshop': 0.60,
    'Vibrant Event':   0.40,
  };

  final List<Map<String, dynamic>> _templates = [
    {'type': 'Formal Academic', 'colors': [const Color(0xFFFDF6EC), const Color(0xFFB45309)],  'accent': const Color(0xFFB45309)},
    {'type': 'Modern Workshop', 'colors': [const Color(0xFF1E3A5F), const Color(0xFF2563EB)],  'accent': const Color(0xFF2563EB)},
    {'type': 'Vibrant Event',   'colors': [const Color(0xFF065F46), const Color(0xFF10B981)],  'accent': const Color(0xFF10B981)},
  ];

  @override
  Widget build(BuildContext context) {
    final completion = _completionLevels[_selected] ?? 0.5;
    final displayedTemplateLabel = _selectedCustomTemplateName ?? _selected;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header — amber, matches all other modals
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
                child: const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Select Certificate Template',
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Choose a design for your certificate',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white.withOpacity(0.7))),
              ])),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Available Templates', icon: Icons.style_outlined),
              Row(
                children: _templates.map((t) {
                  final type   = t['type'] as String;
                  final colors = t['colors'] as List<Color>;
                  final accent = t['accent'] as Color;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: t == _templates.last ? 0 : 10),
                      child: _TemplateCard(
                        type: type,
                        colors: colors,
                        accent: accent,
                        isSelected: _selected == type && _selectedCustomTemplateName == null,
                        onTap: () => setState(() {
                          _selected = type;
                          _selectedCustomTemplateName = null;
                          _selectedTemplateUrl = null;
                        }),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    final result = await showDialog<Map<String, String>?>(
                      context: context,
                      builder: (_) => _ImportTemplateModal(orgId: widget.orgId),
                    );
                    if (result != null && result['name'] != null) {
                      setState(() {
                        _selectedCustomTemplateName = result['name'];
                        _selectedTemplateUrl = result['url'];
                      });
                    }
                  },
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Import Template'),
                ),
              ),
              const SizedBox(height: 18),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('certificate_templates')
                    .where('orgId', isEqualTo: widget.orgId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Imported Templates', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF374151))),
                    const SizedBox(height: 10),
                    Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'Imported Template';
                        final url = data['url'] as String?;
                        final isSelected = _selectedCustomTemplateName == name;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedCustomTemplateName = name;
                                _selectedTemplateUrl = url;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8F9FB),
                                border: Border.all(color: isSelected ? UpriseColors.primaryDark : const Color(0xFFE2E6EA)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(children: [
                                Expanded(child: Text(name, style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1F2937)))),
                                if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF059669), size: 18),
                              ]),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                  ]);
                },
              ),
              _sectionLabel('Template Readiness', icon: Icons.check_circle_outline_rounded),
              Row(children: [
                Text('${(completion * 100).toInt()}% Ready',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
                const Spacer(),
                Text(displayedTemplateLabel, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completion, minHeight: 7,
                  backgroundColor: const Color(0xFFE2E6EA),
                  valueColor: AlwaysStoppedAnimation<Color>(UpriseColors.primaryDark),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ensure all required fields are filled correctly to unlock automatic signing.',
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B)),
              ),
            ]),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E6EA)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                ),
                child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => widget.onConfirm(_selectedCustomTemplateName ?? _selected, _selectedTemplateUrl),
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: Text('Confirm & Continue', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
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
}

// Template preview card
class _TemplateCard extends StatelessWidget {
  final String type;
  final List<Color> colors;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;
  const _TemplateCard({required this.type, required this.colors, required this.accent, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        // Mini certificate preview
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 96,
          decoration: BoxDecoration(
            color: colors[0],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? accent : const Color(0xFFE2E6EA),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected ? [BoxShadow(color: accent.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          child: Stack(children: [
            // Corner accent
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.25),
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomLeft: Radius.circular(8)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Certificate', style: GoogleFonts.beVietnamPro(fontSize: 8, fontWeight: FontWeight.w800, color: accent)),
                Text('of Participation', style: GoogleFonts.beVietnamPro(fontSize: 6, color: accent)),
                const SizedBox(height: 5),
                Container(height: 1, color: accent.withOpacity(0.3)),
                const SizedBox(height: 5),
                Text('[Recipient]',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 7, fontWeight: FontWeight.w600,
                      color: colors[0].computeLuminance() > 0.5 ? const Color(0xFF1A202C) : Colors.white,
                    )),
              ]),
            ),
            // Selected indicator
            if (isSelected)
              Positioned(
                top: 5, left: 5,
                child: Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: const Icon(Icons.check_rounded, size: 10, color: Colors.white),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(type, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF374151)), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? UpriseColors.primaryDark : const Color(0xFFF3F4F6),
              foregroundColor: isSelected ? Colors.white : const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('SELECT', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step 2 — Generate Certificate Modal
// ─────────────────────────────────────────────────────────────────────────────
class _GenerateCertificateModal extends StatefulWidget {
  final String orgId;
  final String selectedTemplateType;
  final String? selectedTemplateUrl;
  final CertificateRecord? existingRecord;
  const _GenerateCertificateModal({required this.orgId, required this.selectedTemplateType, this.selectedTemplateUrl, this.existingRecord});

  @override
  State<_GenerateCertificateModal> createState() => _GenerateCertificateModalState();
}

class _GenerateCertificateModalState extends State<_GenerateCertificateModal> {
  final _formKey       = GlobalKey<FormState>();
  final _titleCtrl     = TextEditingController();
  final _orgCtrl       = TextEditingController();
  final _dateCtrl      = TextEditingController();
  final _sigCtrl       = TextEditingController();

  String? _selectedEventId;
  String? _selectedEventName;
  bool   _eventIssuesCertificate = false;
  String? _selectedTemplateUrl;
  String  _certType    = 'Formal Academic';
  bool    _isSubmitting = false;

  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('date', descending: false)
      .snapshots();

  @override
  void initState() {
    super.initState();
    _certType = widget.selectedTemplateType;
    _selectedTemplateUrl = widget.selectedTemplateUrl;
    _orgCtrl.text  = '';
    _dateCtrl.text = DateFormat('MM/dd/yyyy').format(DateTime.now());
    if (widget.existingRecord != null) {
      _titleCtrl.text = widget.existingRecord!.eventName;
      _orgCtrl.text   = widget.existingRecord!.organization;
      _dateCtrl.text  = DateFormat('MM/dd/yyyy').format(widget.existingRecord!.date);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _orgCtrl.dispose();
    _dateCtrl.dispose();
    _sigCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _previewTheme {
    switch (_certType) {
      case 'Modern Workshop':
        return {'bg': const Color(0xFF1E3A5F), 'accent': const Color(0xFF2563EB), 'text': Colors.white};
      case 'Vibrant Event':
        return {'bg': const Color(0xFF065F46), 'accent': const Color(0xFF10B981), 'text': Colors.white};
      default:
        return {'bg': const Color(0xFFFDF6EC), 'accent': UpriseColors.primaryDark, 'text': const Color(0xFF1A202C)};
    }
  }

  Future<void> _submit({required bool distribute}) async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _isSubmitting = true);

    final payload = <String, dynamic>{
      'orgId':        widget.orgId,
      'eventName':    _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : (_selectedEventName ?? 'Untitled'),
      'organization': _orgCtrl.text.trim(),
      'templateType': _certType,
      'type':         'Participation',
      'issuedAt':     FieldValue.serverTimestamp(),
      'status':       distribute ? 'distributed' : 'draft',
      'recipients':   0,
      'signatories':  _sigCtrl.text.trim(),
      if (_selectedTemplateUrl != null) 'templateFileUrl': _selectedTemplateUrl,
    };

    try {
      if (widget.existingRecord != null) {
        await FirebaseFirestore.instance.collection('certificates').doc(widget.existingRecord!.id).update(payload);
      } else {
        await FirebaseFirestore.instance.collection('certificates').add(payload);
      }
      await activity_log.ActivityLogger.log(
        action: distribute ? 'generate_distribute_certificate' : 'save_draft_certificate',
        module: 'certificates',
        details: {'orgId': widget.orgId, 'templateType': _certType},
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(distribute ? 'Certificate generated & distributed!' : 'Saved as draft.',
              style: GoogleFonts.beVietnamPro(color: Colors.white)),
          backgroundColor: distribute ? const Color(0xFF059669) : const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = _previewTheme;
    final isEdit = widget.existingRecord != null;
    final templateOptions = ['Formal Academic', 'Modern Workshop', 'Vibrant Event'];
    if (widget.selectedTemplateUrl != null && !_certType.isEmpty && !templateOptions.contains(_certType)) {
      templateOptions.add(_certType);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 820,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // ── Header ──
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
                  child: const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(isEdit ? 'Edit Certificate' : 'Generate New Certificate',
                      style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text('Create and customize certificates for event participants',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white.withOpacity(0.7))),
                ])),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                ),
              ]),
            ),
            // ── Body ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Left — form
                  Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Event & Template', icon: Icons.event_outlined),
                      Row(children: [
                        Expanded(
                          child: _FieldWrapper(
                            label: 'Select Event *',
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _eventsStream,
                              builder: (context, snapshot) {
                                final events = snapshot.data?.docs ?? [];
                                return DropdownButtonFormField<String>(
                                  value: _selectedEventId,
                                  hint: Text('Choose an event', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4))),
                                  decoration: _fieldDecoration(),
                                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                                  items: events.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem(value: doc.id, child: Text(data['title'] as String? ?? 'Untitled'));
                                  }).toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    final doc  = events.firstWhere((d) => d.id == v);
                                    final data = doc.data() as Map<String, dynamic>;
                                    setState(() {
                                      _selectedEventId   = v;
                                      _selectedEventName = data['title'] as String?;
                                      _titleCtrl.text    = _selectedEventName ?? '';
                                      _eventIssuesCertificate = (data['issuesCertificate'] == true);
                                      // prefer event-specific template if present
                                      final t = data['templateType'] as String? ?? data['certificateTemplate'] as String?;
                                      if (t != null && t.isNotEmpty) _certType = t;
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FieldWrapper(
                            label: 'Template Type *',
                            child: DropdownButtonFormField<String>(
                              value: _certType,
                              decoration: _fieldDecoration(),
                              style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                              items: templateOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (v) { if (v != null) setState(() => _certType = v); },
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 20),
                      _sectionLabel('Certificate Details', icon: Icons.description_outlined),
                      _FieldWrapper(
                        label: 'Certificate Title *',
                        child: TextFormField(
                          controller: _titleCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: _fieldDecoration(hint: 'e.g. Certificate of Participation'),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _FieldWrapper(
                            label: 'Organization Name *',
                            child: TextFormField(
                              controller: _orgCtrl,
                              onChanged: (_) => setState(() {}),
                              decoration: _fieldDecoration(hint: 'Your organization name', icon: Icons.business_outlined),
                              style: GoogleFonts.beVietnamPro(fontSize: 13),
                              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FieldWrapper(
                            label: 'Event Date *',
                            child: TextFormField(
                              controller: _dateCtrl,
                              readOnly: true,
                              onChanged: (_) => setState(() {}),
                              decoration: _fieldDecoration(hint: 'MM/DD/YYYY', icon: Icons.calendar_today_outlined),
                              style: GoogleFonts.beVietnamPro(fontSize: 13),
                              validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                  builder: (context, child) => Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(primary: UpriseColors.primaryDark),
                                    ),
                                    child: child!,
                                  ),
                                );
                                if (picked != null) { _dateCtrl.text = DateFormat('MM/dd/yyyy').format(picked); setState(() {}); }
                              },
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _FieldWrapper(
                        label: 'Signatories (Authorized Personnel) *',
                        child: TextFormField(
                          controller: _sigCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: _fieldDecoration(hint: 'Name and Title, comma separated', icon: Icons.draw_outlined),
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                          validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Info box
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2563EB).withOpacity(0.25)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF2563EB)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF1A202C)),
                                children: [
                                  TextSpan(text: 'Automatic Recipient Detection  ', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                                  TextSpan(text: 'Certificates are generated for all event attendees automatically.',
                                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
                                  if (_eventIssuesCertificate) ...[
                                    TextSpan(text: '\nThis event is configured to issue certificates. Using the event template if available.',
                                        style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF059669))),
                                  ],
                                  if (!_eventIssuesCertificate) ...[
                                    TextSpan(text: '\nNote: This event is not configured to issue certificates automatically. You can still generate certificates manually.',
                                        style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  // Right — live preview
                  Expanded(
                    flex: 2,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Live Preview', icon: Icons.preview_outlined),
                      _CertPreview(
                        bg:        theme['bg'] as Color,
                        accent:    theme['accent'] as Color,
                        textColor: theme['text'] as Color,
                        orgName:   _orgCtrl.text.isNotEmpty  ? _orgCtrl.text  : 'Your Organization',
                        eventTitle: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Certificate of Participation',
                        eventDate:  _dateCtrl.text.isNotEmpty  ? _dateCtrl.text  : DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                        recipient: '[Recipient Name]',
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            // ── Footer ──
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => _submit(distribute: false),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E6EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Save as Draft', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: (_isSubmitting) ? null : () => _submit(distribute: true),
                  icon: _isSubmitting
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text('Generate & Distribute', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
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
      ),
    );
  }
}

// Form field label wrapper — mirrors _FieldWrapper from proposals
class _FieldWrapper extends StatelessWidget {
  final String label;
  final Widget child;
  const _FieldWrapper({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
      const SizedBox(height: 6),
      child,
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Certificate Live Preview Widget
// ─────────────────────────────────────────────────────────────────────────────
class _CertPreview extends StatelessWidget {
  final Color bg, accent, textColor;
  final String orgName, eventTitle, eventDate, recipient;
  const _CertPreview({
    required this.bg, required this.accent, required this.textColor,
    required this.orgName, required this.eventTitle, required this.eventDate, required this.recipient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Org header
        Text(
          orgName.toUpperCase(),
          style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w800, color: accent, letterSpacing: 2.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        // Decorative rule
        Row(children: [
          Expanded(child: Divider(color: accent.withOpacity(0.35), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.workspace_premium_rounded, size: 20, color: accent),
          ),
          Expanded(child: Divider(color: accent.withOpacity(0.35), thickness: 1)),
        ]),
        const SizedBox(height: 12),
        Text('Certificate of', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w300, color: textColor)),
        Text('Participation', style: GoogleFonts.beVietnamPro(fontSize: 22, fontWeight: FontWeight.w800, color: accent)),
        const SizedBox(height: 10),
        Text('This is to certify that',
            style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withOpacity(0.65))),
        const SizedBox(height: 6),
        Text(recipient,
            style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: textColor, fontStyle: FontStyle.italic),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Divider(color: accent.withOpacity(0.25), thickness: 0.8),
        const SizedBox(height: 6),
        Text('has successfully participated in',
            style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withOpacity(0.6)),
            textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(eventTitle,
            style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: textColor),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text('held on $eventDate',
            style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withOpacity(0.6))),
        const SizedBox(height: 14),
        Divider(color: accent.withOpacity(0.4), thickness: 0.8, indent: 40, endIndent: 40),
        const SizedBox(height: 2),
        Text('Authorized Signatory',
            style: GoogleFonts.beVietnamPro(fontSize: 9, color: textColor.withOpacity(0.45))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Certificate Preview Dialog (view mode) — mirrors _ViewProposalModal style
// ─────────────────────────────────────────────────────────────────────────────
class _CertPreviewDialog extends StatelessWidget {
  final CertificateRecord record;
  const _CertPreviewDialog({required this.record});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 440,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Amber header — same as all modals in this system
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
                child: const Icon(Icons.card_membership_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(record.certificateId,
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(record.eventName,
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                    overflow: TextOverflow.ellipsis),
              ])),
              _certBadge(record.status),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Preview
          Padding(
            padding: const EdgeInsets.all(24),
            child: _CertPreview(
              bg:        const Color(0xFFFDF6EC),
              accent:    UpriseColors.primaryDark,
              textColor: const Color(0xFF1A202C),
              orgName:   record.organization,
              eventTitle: record.eventName,
              eventDate:  DateFormat('MMMM dd, yyyy').format(record.date),
              recipient:  '[Recipient Name]',
            ),
          ),
          // Footer
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Import Template Modal — upload custom template to Firebase Storage
// ─────────────────────────────────────────────────────────────────────────────
class _ImportTemplateModal extends StatefulWidget {
  final String orgId;
  const _ImportTemplateModal({required this.orgId});

  @override
  State<_ImportTemplateModal> createState() => _ImportTemplateModalState();
}

class _ImportTemplateModalState extends State<_ImportTemplateModal> {
  String? _name;
  PlatformFile? _file;
  bool _isUploading = false;

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf']);
    if (res != null && res.files.isNotEmpty) setState(() => _file = res.files.first);
  }

  Future<void> _upload() async {
    if (_file == null || _name?.trim().isEmpty == true) return;
    setState(() => _isUploading = true);
    try {
      final path = 'certificate_templates/${widget.orgId}/${DateTime.now().millisecondsSinceEpoch}_${_file!.name}';
      final ref = FirebaseStorage.instance.ref().child(path);
      final data = _file!.bytes as Uint8List?;
      if (data == null) throw Exception('Failed to read file bytes');
      final task = await ref.putData(data, SettableMetadata(contentType: _file!.extension == 'pdf' ? 'application/pdf' : 'image/${_file!.extension}'));
      final url = await ref.getDownloadURL();
      // Save template record
      await FirebaseFirestore.instance.collection('certificate_templates').add({
        'orgId': widget.orgId,
        'name': _name!.trim(),
        'storagePath': path,
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, {'name': _name!.trim(), 'url': url});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: UpriseColors.error));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Import Certificate Template', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(labelText: 'Template name'),
            onChanged: (v) => setState(() => _name = v),
          ),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(onPressed: _pickFile, icon: const Icon(Icons.upload_file), label: const Text('Choose file')),
            const SizedBox(width: 12),
            Expanded(child: Text(_file?.name ?? 'No file selected', overflow: TextOverflow.ellipsis)),
          ]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: (_file == null || _name == null || _name!.trim().isEmpty || _isUploading) ? null : _upload,
              child: _isUploading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Upload'),
            ),
          ]),
        ]),
      ),
    );
  }
}