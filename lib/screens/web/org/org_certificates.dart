// ignore_for_file: unnecessary_cast, unused_field, deprecated_member_use

import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
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
    'distributed':   _BadgeStyle(UpriseColors.success.withOpacity(0.18), UpriseColors.success, 'DISTRIBUTED'),
    'pending':       _BadgeStyle(UpriseColors.warning.withOpacity(0.18), UpriseColors.warning, 'PENDING'),
    'draft':         _BadgeStyle(UpriseColors.lightGray, UpriseColors.darkGray, 'DRAFT'),
    'undistributed': _BadgeStyle(UpriseColors.error.withOpacity(0.18), UpriseColors.error, 'UNDISTRIBUTED'),
  };
  final s = styles[status.toLowerCase()] ??
      _BadgeStyle(UpriseColors.lightGray, UpriseColors.darkGray, status.toUpperCase());
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

  // ── UNCHANGED: openGenerateFlow now routes through the new _SelectTemplateModal
  //    which has the Canva editor built in. No logic change here.
  void _openGenerateFlow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _SelectTemplateModal(
        orgId: widget.orgId,
        onConfirm: (templateType, templateUrl) {
          Navigator.pop(context as BuildContext);
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final isTablet = screenWidth < 1200;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(isMobile, isTablet),
          _buildToolbar(isMobile, isTablet),
          SizedBox(height: isMobile ? 12 : 16),
          Expanded(child: _buildTable(isMobile, isTablet)),
          SizedBox(height: isMobile ? 16 : 24),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────
  Widget _buildStatsRow(bool isMobile, bool isTablet) {
    return StreamBuilder<QuerySnapshot>(
      stream: _certsStream,
      builder: (context, snapshot) {
        final docs         = snapshot.data?.docs ?? [];
        final total        = docs.length;
        final totalRec     = docs.fold<int>(0, (s, d) => s + ((d.data() as Map<String, dynamic>)['recipients'] as num? ?? 1).toInt());
        final distributed  = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'distributed').length;
        final pending      = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').length;

        final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 28.0);
        final cardGap = isMobile ? 8.0 : 14.0;
        final statCards = [
          _StatCard(label: 'Total Certificates', value: total,       icon: Icons.card_membership_outlined,     color: UpriseColors.primaryDark),
          _StatCard(label: 'Total Recipients',   value: totalRec,    icon: Icons.people_outline_rounded,       color: UpriseColors.accent),
          _StatCard(label: 'Distributed',        value: distributed, icon: Icons.assignment_turned_in_outlined, color: UpriseColors.success),
          _StatCard(label: 'Pending',            value: pending,     icon: Icons.pending_outlined,             color: UpriseColors.warning),
        ];

        return Padding(
          padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 16 : 24, horizontalPadding, 0),
          child: isMobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      statCards.length,
                      (i) => Padding(
                        padding: EdgeInsets.only(right: i < statCards.length - 1 ? cardGap : 0),
                        child: SizedBox(width: 200, child: statCards[i]),
                      ),
                    ),
                  ),
                )
              : Row(
                  children: List.generate(
                    statCards.length,
                    (i) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: i < statCards.length - 1 ? cardGap : 0),
                        child: statCards[i],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar(bool isMobile, bool isTablet) {
    final horizontalPadding = isMobile ? 16.0 : (isTablet ? 20.0 : 28.0);
    final itemGap = isMobile ? 8.0 : 10.0;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, isMobile ? 14 : 20, horizontalPadding, 0),
      child: isMobile
          ? Column(
              spacing: itemGap,
              children: [
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.beVietnamPro(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search certificates...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.greyText),
                      prefixIcon: Icon(Icons.search_rounded, size: 16, color: UpriseColors.greyText),
                      filled: true,
                      fillColor: UpriseColors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.mediumGray)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.mediumGray)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
                    ),
                    onChanged: (v) => setState(() { _searchQuery = v.toLowerCase(); _currentPage = 1; }),
                  ),
                ),
                Row(
                  spacing: itemGap,
                  children: [
                    Expanded(
                      child: _FilterDropdown(
                        value: _filterStatus,
                        items: const ['All', 'Distributed', 'Pending', 'Draft', 'Undistributed'],
                        onChanged: (v) => setState(() { _filterStatus = v!; _currentPage = 1; }),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openGenerateFlow,
                        icon: const Icon(Icons.add_rounded, size: 14),
                        label: Text('Generate', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UpriseColors.primaryDark,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              spacing: itemGap,
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by ID, event name, or organization…',
                        hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.greyText),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: UpriseColors.greyText),
                        filled: true,
                        fillColor: UpriseColors.white,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.mediumGray)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.mediumGray)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
                      ),
                      onChanged: (v) => setState(() { _searchQuery = v.toLowerCase(); _currentPage = 1; }),
                    ),
                  ),
                ),
                _FilterDropdown(
                  value: _filterStatus,
                  items: const ['All', 'Distributed', 'Pending', 'Draft', 'Undistributed'],
                  onChanged: (v) => setState(() { _filterStatus = v!; _currentPage = 1; }),
                ),
                Tooltip(
                  message: 'Only approved event proposals that issue certificates can be selected.',
                  child: ElevatedButton.icon(
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
                ),
              ],
            ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────────────
  Widget _buildTable(bool isMobile, bool isTablet) {
    final horizontalMargin = isMobile ? 12.0 : (isTablet ? 16.0 : 28.0);
    
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
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(children: [
            if (!isMobile) _buildTableHeader(),
            Expanded(
              child: records.isEmpty
                  ? _buildEmptyState()
                  : isMobile
                      ? ListView.builder(
                          itemCount: pageItems.length,
                          itemBuilder: (_, i) => _buildCardRow(pageItems[i], i == pageItems.length - 1),
                        )
                      : ListView.builder(
                          itemCount: pageItems.length,
                          itemBuilder: (_, i) => _buildRow(pageItems[i], i == pageItems.length - 1),
                        ),
            ),
            _buildFooter(records.length, totalPages, start, end, isMobile),
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
          Expanded(
            flex: 2,
            child: Text(r.certificateId,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
          ),
          Expanded(
            flex: 3,
            child: Text(r.eventName,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
                overflow: TextOverflow.ellipsis),
          ),
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
          Expanded(
            flex: 2,
            child: Text(r.type,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          Expanded(
            flex: 2,
            child: Text(DateFormat('MMM d, yyyy').format(r.date),
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          ),
          Expanded(
            flex: 1,
            child: Text('${r.recipients}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
          ),
          Expanded(flex: 2, child: _certBadge(r.status)),
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
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1A202C), size: 20),
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(ctx),
                ),
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
                        ScaffoldMessenger.of(context as BuildContext).showSnackBar(SnackBar(
                          content: Text('Certificate deleted', style: GoogleFonts.beVietnamPro(color: Colors.white)),
                          backgroundColor: UpriseColors.success,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ));
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context as BuildContext).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UpriseColors.error,
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

  Widget _buildCardRow(CertificateRecord r, bool isLast) {
    return InkWell(
      onTap: () => _viewCert(r),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(r.certificateId,
                      style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
                ),
                _certBadge(r.status),
              ],
            ),
            Text(r.eventName,
                style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('MMM d, yyyy').format(r.date),
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                Text('${r.recipients} recipient${r.recipients != 1 ? 's' : ''}',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 4,
              children: [
                _ActionIconButton(icon: Icons.visibility_outlined,    tooltip: 'View',   color: const Color(0xFF2563EB),  onTap: () => _viewCert(r)),
                _ActionIconButton(icon: Icons.edit_outlined,          tooltip: 'Edit',   color: UpriseColors.primaryDark, onTap: () => _editCert(r)),
                _ActionIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: const Color(0xFFDC2626),  onTap: () => _confirmDelete(r)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end, bool isMobile) {
    final int maxVisible = isMobile ? 3 : 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage  = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: isMobile
          ? Column(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PageButton(icon: Icons.chevron_left_rounded,  enabled: _currentPage > 1,          onTap: () => setState(() => _currentPage--)),
                      const SizedBox(width: 4),
                      ...pages.map((p) => _PageNumButton(page: p, isActive: p == _currentPage, onTap: () => setState(() => _currentPage = p))),
                      if (lastPage < totalPages) ...[
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Text('…', style: GoogleFonts.beVietnamPro(color: const Color(0xFF64748B), fontSize: 12))),
                        _PageNumButton(page: totalPages, isActive: _currentPage == totalPages, onTap: () => setState(() => _currentPage = totalPages)),
                      ],
                      const SizedBox(width: 4),
                      _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
                    ],
                  ),
                ),
              ],
            )
          : Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
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
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: UpriseColors.greyText),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
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
// CHANGED: Step 1 — Select Template Modal
// Now includes a Canva-like editor launched via "Customize" on each template card.
// Imported templates from Firebase Storage are still shown below the presets,
// exactly as before.
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
    {'type': 'Formal Academic', 'colors': [UpriseColors.white, UpriseColors.primaryDark],  'accent': UpriseColors.primaryDark},
    {'type': 'Modern Workshop', 'colors': [UpriseColors.primaryDark, UpriseColors.primaryLight],  'accent': UpriseColors.primaryLight},
    {'type': 'Vibrant Event',   'colors': [UpriseColors.accent, UpriseColors.primaryDark],  'accent': UpriseColors.primaryDark},
  ];

  // ── Opens the Canva-like editor as a full-screen dialog.
  // The editor returns an optional custom templateUrl (if the user exported/saved
  // an image from the canvas).  If null is returned the preset name is kept.
  void _openCanvaEditor(String templateType) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _CanvaTemplateEditor(
        orgId: widget.orgId,
        initialTemplateType: templateType,
        onSave: (savedUrl) {
          Navigator.pop(context as BuildContext);
          setState(() {
            _selected = templateType;
            _selectedCustomTemplateName = null;
            if (savedUrl != null) {
              _selectedTemplateUrl = savedUrl;
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completion = _completionLevels[_selected] ?? 0.5;
    final displayedTemplateLabel = _selectedCustomTemplateName ?? _selected;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 460,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header — unchanged ──────────────────────────────────────────
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
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // ── Body ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Available Templates', icon: Icons.style_outlined),
              // ── CHANGED: each template card now has a "Customize" button
              //    that launches _CanvaTemplateEditor.
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
                        // NEW: "Customize" opens the Canva editor
                        onCustomize: () => _openCanvaEditor(type),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              // ── Import button — unchanged ───────────────────────────────
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
              // ── Imported templates from Firestore — unchanged ───────────
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('certificate_templates')
                    .where('orgId', isEqualTo: widget.orgId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Imported Templates', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.charcoal)),
                    const SizedBox(height: 10),
                    Column(
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = data['name'] as String? ?? 'Imported Template';
                        final url  = data['url'] as String?;
                        final isSelected = _selectedCustomTemplateName == name;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () => setState(() {
                              _selectedCustomTemplateName = name;
                              _selectedTemplateUrl = url;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? UpriseColors.primaryLight.withOpacity(0.18) : UpriseColors.lightGray,
                                border: Border.all(color: isSelected ? UpriseColors.primaryDark : UpriseColors.mediumGray),
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
              // ── Readiness bar — unchanged ───────────────────────────────
              _sectionLabel('Template Readiness', icon: Icons.check_circle_outline_rounded),
              Row(children: [
                Text('${(completion * 100).toInt()}% Ready',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
                const Spacer(),
                Text(displayedTemplateLabel, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.greyText)),
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
          // ── Footer — unchanged ──────────────────────────────────────────
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

// ─────────────────────────────────────────────────────────────────────────────
// CHANGED: _TemplateCard — added onCustomize callback for the Canva button.
// Visual layout is unchanged; only a small "Customize" TextButton was added
// below the SELECT button.
// ─────────────────────────────────────────────────────────────────────────────
class _TemplateCard extends StatelessWidget {
  final String type;
  final List<Color> colors;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onCustomize; // NEW
  const _TemplateCard({
    required this.type,
    required this.colors,
    required this.accent,
    required this.isSelected,
    required this.onTap,
    required this.onCustomize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(children: [
        // Mini certificate preview — unchanged
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
        Text(type, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.charcoal), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: isSelected ? UpriseColors.primaryDark : UpriseColors.lightGray,
              foregroundColor: isSelected ? Colors.white : UpriseColors.darkGray,
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: Text('SELECT', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ),
        // NEW: Customize button opens the Canva editor
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onCustomize,
            icon: const Icon(Icons.brush_outlined, size: 12),
            label: Text('Customize', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: UpriseColors.primaryDark,
              side: BorderSide(color: UpriseColors.primaryDark.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 5),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NEW: Canva-like Template Editor
// Full-screen dialog.  Elements are dragged with GestureDetector + Stack.
// Text is edited inline with a TextField overlay.
// Colors, font size, alignment are changed via a right-side properties panel.
// On save, the canvas is rendered to an image via RepaintBoundary and
// uploaded to Firebase Storage, returning a download URL to the caller.
// ─────────────────────────────────────────────────────────────────────────────

/// A single editable element on the certificate canvas.
class _CanvasElement {
  final String id;
  String type; // 'text' | 'rect' | 'circle' | 'divider'
  double x, y, w, h;
  // text props
  String text;
  double fontSize;
  FontWeight fontWeight;
  Color color;
  TextAlign align;
  bool italic;
  double letterSpacing;
  // shape props
  Color fillColor;
  Color strokeColor;
  double strokeWidth;

  _CanvasElement({
    required this.id,
    required this.type,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    this.text = '',
    this.fontSize = 14,
    this.fontWeight = FontWeight.w400,
    this.color = const Color(0xFF1A202C),
    this.align = TextAlign.center,
    this.italic = false,
    this.letterSpacing = 0,
    this.fillColor = const Color(0xFFEFF6FF),
    this.strokeColor = const Color(0xFF2563EB),
    this.strokeWidth = 1.5,
  });

  _CanvasElement copyWith({
    double? x, double? y, double? w, double? h,
    String? text, double? fontSize, FontWeight? fontWeight, Color? color,
    TextAlign? align, bool? italic, double? letterSpacing,
    Color? fillColor, Color? strokeColor, double? strokeWidth,
  }) => _CanvasElement(
    id: id, type: type,
    x: x ?? this.x, y: y ?? this.y, w: w ?? this.w, h: h ?? this.h,
    text: text ?? this.text,
    fontSize: fontSize ?? this.fontSize,
    fontWeight: fontWeight ?? this.fontWeight,
    color: color ?? this.color,
    align: align ?? this.align,
    italic: italic ?? this.italic,
    letterSpacing: letterSpacing ?? this.letterSpacing,
    fillColor: fillColor ?? this.fillColor,
    strokeColor: strokeColor ?? this.strokeColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
  );
}

// Default element sets for each preset
List<_CanvasElement> _defaultElementsFor(String templateType) {
  Color accent, textCol;
  switch (templateType) {
    case 'Modern Workshop':
      accent  = const Color(0xFF2563EB);
      textCol = Colors.white;
      break;
    case 'Vibrant Event':
      accent  = const Color(0xFF10B981);
      textCol = const Color(0xFFECFDF5);
      break;
    default: // Formal Academic
      accent  = const Color(0xFFB45309);
      textCol = const Color(0xFF1A202C);
  }
  return [
    _CanvasElement(id: 'border', type: 'rect',    x: 8,   y: 8,   w: 584, h: 408, fillColor: Colors.transparent, strokeColor: accent, strokeWidth: 2),
    _CanvasElement(id: 'seal',   type: 'circle',  x: 245, y: 28,  w: 110, h: 110, fillColor: accent.withOpacity(0.12), strokeColor: accent, strokeWidth: 2.5),
    _CanvasElement(id: 'org',    type: 'text',    x: 0,   y: 44,  w: 600, h: 28,  text: 'ORGANIZATION NAME', fontSize: 11, fontWeight: FontWeight.w700, color: accent, letterSpacing: 3),
    _CanvasElement(id: 'certof', type: 'text',    x: 0,   y: 148, w: 600, h: 22,  text: 'Certificate of', fontSize: 13, fontWeight: FontWeight.w300, color: textCol.withOpacity(0.75)),
    _CanvasElement(id: 'certty', type: 'text',    x: 0,   y: 170, w: 600, h: 44,  text: 'PARTICIPATION', fontSize: 30, fontWeight: FontWeight.w800, color: accent, letterSpacing: 2),
    _CanvasElement(id: 'certfy', type: 'text',    x: 0,   y: 222, w: 600, h: 20,  text: 'This is to certify that', fontSize: 11, color: textCol.withOpacity(0.6)),
    _CanvasElement(id: 'recip',  type: 'text',    x: 0,   y: 244, w: 600, h: 36,  text: '[Recipient Name]', fontSize: 24, fontWeight: FontWeight.w700, color: textCol, italic: true),
    _CanvasElement(id: 'div1',   type: 'divider', x: 80,  y: 286, w: 440, h: 1,   strokeColor: accent.withOpacity(0.4), strokeWidth: 1),
    _CanvasElement(id: 'parti',  type: 'text',    x: 0,   y: 295, w: 600, h: 20,  text: 'has successfully participated in', fontSize: 11, color: textCol.withOpacity(0.6)),
    _CanvasElement(id: 'evtit',  type: 'text',    x: 0,   y: 317, w: 600, h: 28,  text: 'Event Title Here', fontSize: 16, fontWeight: FontWeight.w700, color: textCol),
    _CanvasElement(id: 'evdat',  type: 'text',    x: 0,   y: 347, w: 600, h: 20,  text: 'held on January 1, 2025', fontSize: 11, color: textCol.withOpacity(0.6)),
    _CanvasElement(id: 'div2',   type: 'divider', x: 190, y: 375, w: 220, h: 1,   strokeColor: accent, strokeWidth: 1),
    _CanvasElement(id: 'signa',  type: 'text',    x: 0,   y: 382, w: 600, h: 18,  text: 'Authorized Signatory', fontSize: 10, color: textCol.withOpacity(0.5)),
  ];
}

Color _bgColorFor(String templateType) {
  switch (templateType) {
    case 'Modern Workshop': return const Color(0xFF0F172A);
    case 'Vibrant Event':   return const Color(0xFF065F46);
    default:                return const Color(0xFFFDF6EC);
  }
}

class _CanvaTemplateEditor extends StatefulWidget {
  final String orgId;
  final String initialTemplateType;
  final void Function(String? savedUrl) onSave;
  const _CanvaTemplateEditor({
    required this.orgId,
    required this.initialTemplateType,
    required this.onSave,
  });

  @override
  State<_CanvaTemplateEditor> createState() => _CanvaTemplateEditorState();
}

class _CanvaTemplateEditorState extends State<_CanvaTemplateEditor> {
  late List<_CanvasElement> _elements;
  late Color _bgColor;
  String? _selectedId;
  bool _isSaving = false;

  // Drag state
  Offset? _dragStart;
  double? _dragOrigX, _dragOrigY;
  // Resize state
  Offset? _resizeStart;
  double? _resizeOrigW, _resizeOrigH;

  // Canvas logical size
  static const double _cW = 600;
  static const double _cH = 424;

  final _repaintKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _elements = _defaultElementsFor(widget.initialTemplateType);
    _bgColor  = _bgColorFor(widget.initialTemplateType);
  }

  _CanvasElement? get _selected =>
      _selectedId == null ? null : _elements.cast<_CanvasElement?>().firstWhere((e) => e?.id == _selectedId, orElse: () => null);

  void _updateSelected(_CanvasElement updated) {
    setState(() {
      _elements = _elements.map((e) => e.id == updated.id ? updated : e).toList();
    });
  }

  void _addText() {
    final el = _CanvasElement(
      id: 'txt_${DateTime.now().millisecondsSinceEpoch}',
      type: 'text', x: 100, y: 100, w: 200, h: 30,
      text: 'New text', fontSize: 14, color: const Color(0xFF1A202C),
    );
    setState(() { _elements.add(el); _selectedId = el.id; });
  }

  void _addRect() {
    final el = _CanvasElement(
      id: 'rect_${DateTime.now().millisecondsSinceEpoch}',
      type: 'rect', x: 100, y: 100, w: 160, h: 80,
      fillColor: const Color(0xFFEFF6FF), strokeColor: const Color(0xFF2563EB), strokeWidth: 1.5,
    );
    setState(() { _elements.add(el); _selectedId = el.id; });
  }

  void _addCircle() {
    final el = _CanvasElement(
      id: 'circ_${DateTime.now().millisecondsSinceEpoch}',
      type: 'circle', x: 200, y: 150, w: 80, h: 80,
      fillColor: const Color(0xFFEFF6FF), strokeColor: const Color(0xFF2563EB), strokeWidth: 1.5,
    );
    setState(() { _elements.add(el); _selectedId = el.id; });
  }

  void _deleteSelected() {
    if (_selectedId == null) return;
    setState(() { _elements.removeWhere((e) => e.id == _selectedId); _selectedId = null; });
  }

  /// Saves canvas to Firebase Storage and returns the download URL.
  /// Falls back to returning null (keeps preset name) if capture fails.
  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Attempt to capture the canvas as PNG bytes via RepaintBoundary.
      // On platforms where this is unsupported (e.g. web without canvaskit)
      // we still succeed — we just pass null and keep the preset template name.
      String? downloadUrl;
      try {
        final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData = await image.toByteData(format: ImageByteFormat.png);
          if (byteData != null) {
            final bytes = byteData.buffer.asUint8List();
            final path = 'certificate_templates/${widget.orgId}/canvas_${DateTime.now().millisecondsSinceEpoch}.png';
            final ref = FirebaseStorage.instance.ref().child(path);
            await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
            downloadUrl = await ref.getDownloadURL();
            // Persist template record so it appears in Imported Templates list
            await FirebaseFirestore.instance.collection('certificate_templates').add({
              'orgId': widget.orgId,
              'name': 'Custom (${widget.initialTemplateType}) ${DateFormat('MM/dd HH:mm').format(DateTime.now())}',
              'storagePath': path,
              'url': downloadUrl,
              'createdAt': FieldValue.serverTimestamp(),
            });
          }
        }
      } catch (_) {
        // Canvas export not available on this platform — continue without url.
      }
      await activity_log.ActivityLogger.log(
        action: 'customize_certificate_template',
        module: 'certificates',
        details: {'orgId': widget.orgId, 'templateType': widget.initialTemplateType},
      );
      if (mounted) widget.onSave(downloadUrl);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = _selected;
    final dialogSurface = UpriseColors.white;
    final panelSurface = const Color(0xFFFFF4E8);
    final headerSurface = UpriseColors.primaryDark;
    final headerText = UpriseColors.white;
    final borderColor = UpriseColors.primaryDark.withOpacity(0.18);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: dialogSurface,
      child: SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.92,
        child: Column(children: [
          // ── Top bar ─────────────────────────────────────────────────
          Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: headerSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(children: [
              Icon(Icons.brush_rounded, color: headerText, size: 18),
              const SizedBox(width: 10),
              Text('Template Editor', style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700, color: headerText)),
              const SizedBox(width: 20),
              // ── Add element buttons ────────────────────────────────
              _EditorTopBtn(label: '＋ Text',   onTap: _addText),
              const SizedBox(width: 6),
              _EditorTopBtn(label: '⬜ Rect',   onTap: _addRect),
              const SizedBox(width: 6),
              _EditorTopBtn(label: '⭕ Circle', onTap: _addCircle),
              if (_selectedId != null) ...[
                const SizedBox(width: 6),
                _EditorTopBtn(label: '🗑 Delete', onTap: _deleteSelected, danger: true),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: UpriseColors.white, size: 20),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: UpriseColors.white))
                    : const Icon(Icons.check_rounded, size: 16, color: UpriseColors.white),
                label: Text('Save Template', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  foregroundColor: UpriseColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ]),
          ),
          // ── Main area: layers | canvas | properties ──────────────
          Expanded(
            child: Row(children: [
              // Left: layers panel
              RepaintBoundary(
                child: _LayersPanel(
                  elements: _elements,
                  selectedId: _selectedId,
                  onSelect: (id) => setState(() => _selectedId = id),
                  onReorder: (oldI, newI) {
                    setState(() {
                      final el = _elements.removeAt(oldI);
                      _elements.insert(newI, el);
                    });
                  },
                ),
              ),
              // Centre: canvas
              Expanded(
                child: Container(
                  color: panelSurface,
                  child: Center(
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: _CanvasArea(
                        bgColor: _bgColor,
                        elements: _elements,
                        selectedId: _selectedId,
                        canvasW: _cW,
                        canvasH: _cH,
                        onSelect: (id) => setState(() => _selectedId = id),
                        onDeselect: () => setState(() => _selectedId = null),
                        onMove: (id, dx, dy) {
                          setState(() {
                            _elements = _elements.map((e) {
                              if (e.id != id) return e;
                              return e.copyWith(
                                x: (e.x + dx).clamp(0, _cW - e.w),
                                y: (e.y + dy).clamp(0, _cH - e.h),
                              );
                            }).toList();
                          });
                        },
                        onResize: (id, dw, dh) {
                          setState(() {
                            _elements = _elements.map((e) {
                              if (e.id != id) return e;
                              return e.copyWith(
                                w: (e.w + dw).clamp(30, _cW),
                                h: (e.h + dh).clamp(10, _cH),
                              );
                            }).toList();
                          });
                        },
                        onTextCommit: (id, text) {
                          setState(() {
                            _elements = _elements.map((e) => e.id == id ? e.copyWith(text: text) : e).toList();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ),
              // Right: properties panel
              RepaintBoundary(
                child: _PropertiesPanel(
                  bgColor: _bgColor,
                  onBgColorChanged: (c) => setState(() => _bgColor = c),
                  selected: sel,
                  onUpdate: _updateSelected,
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Canvas area ───────────────────────────────────────────────────────────────
// Extracted ResizeHandle to avoid rebuilding on drag
class _ResizeHandle extends StatelessWidget {
  final void Function(DragStartDetails) onPanStart;
  final void Function(DragUpdateDetails) onPanUpdate;
  final void Function(DragEndDetails) onPanEnd;
  final Color color;

  const _ResizeHandle({
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: onPanStart,
      onPanUpdate: onPanUpdate,
      onPanEnd: onPanEnd,
      child: Container(
        width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _CanvasArea extends StatelessWidget {
  final Color bgColor;
  final List<_CanvasElement> elements;
  final String? selectedId;
  final double canvasW, canvasH;
  final void Function(String id) onSelect;
  final VoidCallback onDeselect;
  final void Function(String id, double dx, double dy) onMove;
  final void Function(String id, double dw, double dh) onResize;
  final void Function(String id, String text) onTextCommit;

  const _CanvasArea({
    required this.bgColor, required this.elements, required this.selectedId,
    required this.canvasW, required this.canvasH,
    required this.onSelect, required this.onDeselect,
    required this.onMove, required this.onResize, required this.onTextCommit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDeselect,
      child: RepaintBoundary(
        child: Container(
          width: canvasW,
          height: canvasH,
          color: bgColor,
          child: Stack(
            clipBehavior: Clip.none,
            children: elements.map((el) {
              final isSel = el.id == selectedId;
              return _CanvasElementWidget(
                el: el,
                isSelected: isSel,
                onTap: () => onSelect(el.id),
                onMove: (dx, dy) => onMove(el.id, dx, dy),
                onResize: (dw, dh) => onResize(el.id, dw, dh),
                onTextCommit: (t) => onTextCommit(el.id, t),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CanvasElementWidget extends StatefulWidget {
  final _CanvasElement el;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(double dx, double dy) onMove;
  final void Function(double dw, double dh) onResize;
  final void Function(String text) onTextCommit;

  const _CanvasElementWidget({
    required this.el, required this.isSelected,
    required this.onTap, required this.onMove,
    required this.onResize, required this.onTextCommit,
  });

  @override
  State<_CanvasElementWidget> createState() => _CanvasElementWidgetState();
}

class _CanvasElementWidgetState extends State<_CanvasElementWidget> {
  Offset? _lastDrag;
  Offset? _lastResize;
  bool _editing = false;
  late TextEditingController _textCtrl;

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController(text: widget.el.text);
  }

  @override
  void didUpdateWidget(_CanvasElementWidget old) {
    super.didUpdateWidget(old);
    if (!_editing && old.el.text != widget.el.text) {
      _textCtrl.text = widget.el.text;
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final el = widget.el;
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned(
      left: el.x, top: el.y,
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () { widget.onTap(); setState(() => _editing = false); },
          onDoubleTap: () {
            if (el.type == 'text') setState(() => _editing = true);
          },
          onPanStart: (d) => _lastDrag = d.globalPosition,
          onPanUpdate: (d) {
            if (_lastDrag != null) {
              widget.onMove(d.globalPosition.dx - _lastDrag!.dx, d.globalPosition.dy - _lastDrag!.dy);
              _lastDrag = d.globalPosition;
            }
          },
          onPanEnd: (_) => _lastDrag = null,
          child: SizedBox(
            width: el.w,
            height: el.type == 'divider' ? 10 : el.h,
            child: Stack(clipBehavior: Clip.none, children: [
              // The element itself
              _buildContent(el),
              // Selection outline
              if (widget.isSelected)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
              // Resize handle
              if (widget.isSelected)
                Positioned(
                  right: -5, bottom: -5,
                  child: _ResizeHandle(onPanStart: (d) => _lastResize = d.globalPosition,
                    onPanUpdate: (d) {
                      if (_lastResize != null) {
                        widget.onResize(d.globalPosition.dx - _lastResize!.dx, d.globalPosition.dy - _lastResize!.dy);
                        _lastResize = d.globalPosition;
                      }
                    },
                    onPanEnd: (_) => _lastResize = null,
                    color: colorScheme.primary,
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(_CanvasElement el) {
    if (el.type == 'text') {
      if (_editing) {
        return SizedBox(
          width: el.w, height: el.h,
          child: TextField(
            controller: _textCtrl,
            autofocus: true,
            style: GoogleFonts.beVietnamPro(
              fontSize: el.fontSize, fontWeight: el.fontWeight,
              color: el.color, fontStyle: el.italic ? FontStyle.italic : FontStyle.normal,
              letterSpacing: el.letterSpacing,
            ),
            textAlign: el.align,
            decoration: const InputDecoration(
              isDense: true, contentPadding: EdgeInsets.zero,
              border: InputBorder.none, focusedBorder: InputBorder.none,
            ),
            onSubmitted: (v) {
              widget.onTextCommit(v);
              setState(() => _editing = false);
            },
          ),
        );
      }
      return SizedBox(
        width: el.w, height: el.h,
        child: Align(
          alignment: el.align == TextAlign.center ? Alignment.center
              : el.align == TextAlign.right ? Alignment.centerRight
              : Alignment.centerLeft,
          child: Text(
            el.text,
            textAlign: el.align,
            style: GoogleFonts.beVietnamPro(
              fontSize: el.fontSize, fontWeight: el.fontWeight,
              color: el.color, fontStyle: el.italic ? FontStyle.italic : FontStyle.normal,
              letterSpacing: el.letterSpacing,
            ),
          ),
        ),
      );
    }
    if (el.type == 'divider') {
      return SizedBox(width: el.w, height: 10,
          child: Center(child: Container(height: el.strokeWidth, color: el.strokeColor)));
    }
    // rect or circle
    return CustomPaint(
      size: Size(el.w, el.h),
      painter: _ShapePainter(el),
    );
  }
}

class _ShapePainter extends CustomPainter {
  final _CanvasElement el;
  const _ShapePainter(this.el);

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = el.fillColor..style = PaintingStyle.fill;
    final stroke = Paint()..color = el.strokeColor..style = PaintingStyle.stroke..strokeWidth = el.strokeWidth;
    if (el.type == 'circle') {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawOval(rect, fill);
      canvas.drawOval(rect, stroke);
    } else {
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, stroke);
    }
  }

  @override
  bool shouldRepaint(_ShapePainter old) => old.el != el;
}

// ── Layers panel ──────────────────────────────────────────────────────────────
class _LayersPanel extends StatelessWidget {
  final List<_CanvasElement> elements;
  final String? selectedId;
  final void Function(String id) onSelect;
  final void Function(int oldIndex, int newIndex) onReorder;
  const _LayersPanel({required this.elements, required this.selectedId, required this.onSelect, required this.onReorder});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      color: const Color(0xFFFFF4E8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Text('LAYERS', style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark, letterSpacing: 1)),
        ),
        Expanded(
          child: ReorderableListView(
            onReorder: onReorder,
            children: elements.reversed.map((el) {
              final isSel = el.id == selectedId;
              return ListTile(
                key: ValueKey(el.id),
                dense: true,
                selected: isSel,
                selectedTileColor: UpriseColors.primaryDark,
                tileColor: Colors.transparent,
                leading: Icon(
                  el.type == 'text' ? Icons.text_fields_rounded
                      : el.type == 'circle' ? Icons.circle_outlined
                      : el.type == 'divider' ? Icons.horizontal_rule_rounded
                      : Icons.crop_square_rounded,
                  size: 14,
                  color: isSel ? UpriseColors.white : UpriseColors.primaryDark,
                ),
                title: Text(
                  el.type == 'text' ? el.text.length > 16 ? '${el.text.substring(0, 16)}…' : el.text : el.type,
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: isSel ? UpriseColors.white : UpriseColors.primaryDark),
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onSelect(el.id),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Properties panel ──────────────────────────────────────────────────────────
class _PropertiesPanel extends StatelessWidget {
  final Color bgColor;
  final void Function(Color) onBgColorChanged;
  final _CanvasElement? selected;
  final void Function(_CanvasElement) onUpdate;
  const _PropertiesPanel({required this.bgColor, required this.onBgColorChanged, required this.selected, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final sel = selected;
    return Container(
      width: 220,
      color: const Color(0xFFFFF4E8),
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _propTitle(context, 'CANVAS'),
          _PropRow(label: 'Background', child: _ColorSwatch(color: bgColor, onChanged: onBgColorChanged)),
          if (sel != null) ...[
            const SizedBox(height: 16),
            _propTitle(context, 'POSITION & SIZE'),
            _PropRow(label: 'X', child: _NumField(value: sel.x, onChanged: (v) => onUpdate(sel.copyWith(x: v)))),
            _PropRow(label: 'Y', child: _NumField(value: sel.y, onChanged: (v) => onUpdate(sel.copyWith(y: v)))),
            _PropRow(label: 'W', child: _NumField(value: sel.w, onChanged: (v) => onUpdate(sel.copyWith(w: v)))),
            if (sel.type != 'divider')
              _PropRow(label: 'H', child: _NumField(value: sel.h, onChanged: (v) => onUpdate(sel.copyWith(h: v)))),
            if (sel.type == 'text') ...[
              const SizedBox(height: 16),
              _propTitle(context, 'TEXT'),
              _PropRow(label: 'Size',    child: _NumField(value: sel.fontSize, onChanged: (v) => onUpdate(sel.copyWith(fontSize: v)))),
              _PropRow(label: 'Color',   child: _ColorSwatch(color: sel.color, onChanged: (c) => onUpdate(sel.copyWith(color: c)))),
              _PropRow(label: 'Align',   child: _AlignDropdown(value: sel.align, onChanged: (a) => onUpdate(sel.copyWith(align: a)))),
              _PropRow(label: 'Bold',    child: _Toggle(value: sel.fontWeight == FontWeight.w700, onChanged: (v) => onUpdate(sel.copyWith(fontWeight: v ? FontWeight.w700 : FontWeight.w400)))),
              _PropRow(label: 'Italic',  child: _Toggle(value: sel.italic, onChanged: (v) => onUpdate(sel.copyWith(italic: v)))),
              _PropRow(label: 'Spacing', child: _NumField(value: sel.letterSpacing, onChanged: (v) => onUpdate(sel.copyWith(letterSpacing: v)))),
            ],
            if (sel.type == 'rect' || sel.type == 'circle') ...[
              const SizedBox(height: 16),
              _propTitle(context, 'SHAPE'),
              _PropRow(label: 'Fill',     child: _ColorSwatch(color: sel.fillColor,   onChanged: (c) => onUpdate(sel.copyWith(fillColor: c)))),
              _PropRow(label: 'Stroke',   child: _ColorSwatch(color: sel.strokeColor, onChanged: (c) => onUpdate(sel.copyWith(strokeColor: c)))),
              _PropRow(label: 'Stroke W', child: _NumField(value: sel.strokeWidth,    onChanged: (v) => onUpdate(sel.copyWith(strokeWidth: v)))),
            ],
            if (sel.type == 'divider') ...[
              const SizedBox(height: 16),
              _propTitle(context, 'LINE'),
              _PropRow(label: 'Color',   child: _ColorSwatch(color: sel.strokeColor, onChanged: (c) => onUpdate(sel.copyWith(strokeColor: c)))),
              _PropRow(label: 'Width',   child: _NumField(value: sel.strokeWidth,    onChanged: (v) => onUpdate(sel.copyWith(strokeWidth: v)))),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _propTitle(BuildContext context, String t) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant, letterSpacing: 1)),
    );
  }
}

class _PropRow extends StatelessWidget {
  final String label;
  final Widget child;
  const _PropRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        child,
      ]),
    );
  }
}

class _NumField extends StatelessWidget {
  final double value;
  final void Function(double) onChanged;
  const _NumField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 72,
      height: 28,
      child: TextField(
        controller: TextEditingController(text: value.toStringAsFixed(0)),
        keyboardType: TextInputType.number,
        style: GoogleFonts.beVietnamPro(fontSize: 12, color: colorScheme.onSurface),
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          filled: true,
          fillColor: colorScheme.surfaceVariant,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: colorScheme.outline)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: colorScheme.outline)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: colorScheme.primary)),
        ),
        onSubmitted: (v) {
          final parsed = double.tryParse(v);
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final void Function(Color) onChanged;
  const _ColorSwatch({required this.color, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Flutter doesn't have a built-in color picker; we show a tappable swatch
    // that opens a simple dialog with common swatches and a hex input.
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        width: 36, height: 24,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final swatches = [
      Colors.white, const Color(0xFFF8F9FB), const Color(0xFF1A202C), Colors.black,
      const Color(0xFFB45309), const Color(0xFFD97706), const Color(0xFFFCD34D),
      const Color(0xFF059669), const Color(0xFF10B981), const Color(0xFF34D399),
      const Color(0xFF2563EB), const Color(0xFF60A5FA), const Color(0xFF1E3A5F),
      const Color(0xFFDC2626), const Color(0xFFFCA5A5),
      const Color(0xFF7C3AED), Colors.transparent,
    ];
    final hexCtrl = TextEditingController(text: '#${color.value.toRadixString(16).substring(2).toUpperCase()}');

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text('Pick Color', style: GoogleFonts.beVietnamPro(fontSize: 14, color: theme.colorScheme.onSurface)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(spacing: 8, runSpacing: 8, children: swatches.map((s) => GestureDetector(
            onTap: () { onChanged(s); Navigator.pop(ctx); },
            child: Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: s == Colors.transparent ? null : s,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: s == color ? theme.colorScheme.primary : theme.colorScheme.outline, width: s == color ? 2 : 1),
                image: s == Colors.transparent ? const DecorationImage(image: AssetImage('assets/transparent.png'), fit: BoxFit.cover) : null,
              ),
              child: s == Colors.transparent ? Icon(Icons.block, size: 18, color: theme.colorScheme.onSurfaceVariant) : null,
            ),
          )).toList()),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(
              controller: hexCtrl,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: theme.colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: '#RRGGBB',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                isDense: true, contentPadding: const EdgeInsets.all(8),
                filled: true, fillColor: theme.colorScheme.surfaceVariant,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: theme.colorScheme.outline)),
              ),
            )),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                try {
                  final hex = hexCtrl.text.trim().replaceFirst('#', '');
                  final val = int.parse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
                  onChanged(Color(val));
                  Navigator.pop(ctx);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
              child: Text('Apply', style: GoogleFonts.beVietnamPro(fontSize: 12, color: theme.colorScheme.onPrimary)),
            ),
          ]),
        ]),
      );
    });
  }
}

class _AlignDropdown extends StatelessWidget {
  final TextAlign value;
  final void Function(TextAlign) onChanged;
  const _AlignDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colorScheme.outline),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<TextAlign>(
          value: value,
          dropdownColor: colorScheme.surface,
          style: GoogleFonts.beVietnamPro(fontSize: 11, color: colorScheme.onSurface),
          isDense: true,
          items: const [
            DropdownMenuItem(value: TextAlign.left,   child: Text('Left')),
            DropdownMenuItem(value: TextAlign.center, child: Text('Center')),
            DropdownMenuItem(value: TextAlign.right,  child: Text('Right')),
          ],
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  final bool value;
  final void Function(bool) onChanged;
  const _Toggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      activeColor: UpriseColors.primaryDark,
    );
  }
}

class _EditorTopBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _EditorTopBtn({required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFEF4444) : UpriseColors.primaryLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: danger ? UpriseColors.white : UpriseColors.primaryDark)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHANGED: Step 2 — Generate Certificate Modal
// Gate added: the event dropdown now only lists proposals where
//   issuesCertificate == true.
// After selecting an event a second check confirms evaluated == true
//   before enabling "Generate & Distribute".  If the event has not been
//   evaluated yet, an inline warning is shown and the distribute button
//   stays disabled.  "Save as Draft" remains always available.
// Everything else (form fields, Firestore writes, ActivityLogger) is unchanged.
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
  String? _selectedEventDocId;
  bool   _eventIssuesCertificate = false;

  // CHANGED: tracks whether the selected event has been evaluated
  bool   _eventIsEvaluated = false;
  int    _attendeeCount = 0;
  bool   _attendanceSynced = false;

  String? _selectedTemplateUrl;
  String  _certType    = 'Formal Academic';
  bool    _isSubmitting = false;

  // CHANGED: stream now pre-filters to only approved proposals that issue certificates
  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .where('issuesCertificate', isEqualTo: true)
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
        return {'bg': UpriseColors.primaryDark, 'accent': UpriseColors.primaryLight, 'text': Colors.white};
      case 'Vibrant Event':
        return {'bg': UpriseColors.accent, 'accent': UpriseColors.primaryDark, 'text': Colors.white};
      default:
        return {'bg': UpriseColors.white, 'accent': UpriseColors.primaryDark, 'text': UpriseColors.charcoal};
    }
  }

  Future<void> _submit({required bool distribute}) async {
    if (_formKey.currentState?.validate() != true) return;
    if (distribute && !_eventIsEvaluated) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('You can only distribute certificates after attendees complete evaluation.', style: GoogleFonts.beVietnamPro(color: Colors.white)),
          backgroundColor: UpriseColors.error,
        ));
      }
      return;
    }
    setState(() => _isSubmitting = true);

    final recipients = _attendanceSynced ? _attendeeCount : 0;
    final payload = <String, dynamic>{
      'orgId':        widget.orgId,
      'eventName':    _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : (_selectedEventName ?? 'Untitled'),
      'organization': _orgCtrl.text.trim(),
      'templateType': _certType,
      'type':         'Participation',
      'issuedAt':     FieldValue.serverTimestamp(),
      'status':       distribute ? 'distributed' : 'draft',
      'recipients':   recipients,
      'signatories':  _sigCtrl.text.trim(),
      if (_selectedTemplateUrl != null) 'templateFileUrl': _selectedTemplateUrl,
      if (_selectedEventDocId != null) 'eventId': _selectedEventDocId,
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
        Navigator.pop(context as BuildContext);
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(SnackBar(
          content: Text(distribute ? 'Certificate generated & distributed!' : 'Saved as draft.',
              style: GoogleFonts.beVietnamPro(color: Colors.white)),
          backgroundColor: distribute ? UpriseColors.success : UpriseColors.darkGray,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: UpriseColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<int> _fetchAttendanceCount(String eventDocId) async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventDocId)
        .collection('attendances')
        .get();
    return snap.docs.length;
  }

  Future<int> _fetchEvaluatedRecipientCount(String eventDocId) async {
    final snap = await FirebaseFirestore.instance
        .collection('event_feedbacks')
        .where('eventId', isEqualTo: eventDocId)
        .get();

    final ids = <String>{};
    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String?
          ?? data['participantId'] as String?
          ?? data['submittedBy'] as String?;
      if (userId != null && userId.isNotEmpty) {
        ids.add(userId);
      }
    }
    return ids.isNotEmpty ? ids.length : snap.docs.length;
  }

  @override
  Widget build(BuildContext context) {
    final theme  = _previewTheme;
    final isEdit = widget.existingRecord != null;
    final templateOptions = ['Formal Academic', 'Modern Workshop', 'Vibrant Event'];
    if (widget.selectedTemplateUrl != null && !templateOptions.contains(_certType)) {
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
            // ── Header — unchanged ──────────────────────────────────
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
                  Text(
                    'Create certificates only for approved events that issue certificates',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white.withOpacity(0.7)),
                  ),
                ])),
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  tooltip: 'Back',
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                ),
              ]),
            ),
            // ── Body ───────────────────────────────────────────────
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
                            label: 'Select Event (approved cert event) *',
                            child: StreamBuilder<QuerySnapshot>(
                              stream: _eventsStream,
                              builder: (context, snapshot) {
                                final events = snapshot.data?.docs ?? [];
                                return DropdownButtonFormField<String>(
                                  value: _selectedEventId,
                                  hint: Text(
                                    events.isEmpty
                                        ? 'No approved certificate events found'
                                        : 'Choose an approved event that issues certificates',
                                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                                  ),
                                  decoration: _fieldDecoration(),
                                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                                  validator: (_) => _selectedEventId == null ? 'Required' : null,
                                  items: events.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(data['title'] as String? ?? 'Untitled'),
                                    );
                                  }).toList(),
                                  onChanged: (v) async {
                                    if (v == null) return;
                                    final doc  = events.firstWhere((d) => d.id == v);
                                    final data = doc.data() as Map<String, dynamic>;
                                    setState(() {
                                      _selectedEventId   = v;
                                      _selectedEventName = data['title'] as String?;
                                      _titleCtrl.text    = _selectedEventName ?? '';
                                      _eventIssuesCertificate = (data['issuesCertificate'] == true);
                                      // CHANGED: read evaluated flag from Firestore
                                      _eventIsEvaluated  = (data['evaluated'] == true);
                                      _selectedEventDocId = null;
                                      _attendeeCount = 0;
                                      _attendanceSynced = false;
                                      final t = data['templateType'] as String? ?? data['certificateTemplate'] as String?;
                                      if (t != null && t.isNotEmpty) _certType = t;
                                    });

                                    try {
                                      final evQ = await FirebaseFirestore.instance
                                          .collection('events')
                                          .where('createdFromProposalId', isEqualTo: v)
                                          .limit(1)
                                          .get();

                                      if (mounted && evQ.docs.isNotEmpty) {
                                        final eventDoc = evQ.docs.first;
                                        var count = 0;
                                        if (_eventIsEvaluated) {
                                          count = await _fetchEvaluatedRecipientCount(eventDoc.id);
                                        }
                                        if (count == 0) {
                                          count = await _fetchAttendanceCount(eventDoc.id);
                                        }
                                        setState(() {
                                          _selectedEventDocId = eventDoc.id;
                                          _attendeeCount = count;
                                          _attendanceSynced = true;
                                        });
                                      }
                                    } catch (_) {
                                      // Fall back to proposal-only detection.
                                    }
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

                      // ── CHANGED: evaluation gate banner ─────────────────
                      if (_selectedEventId != null && !_eventIsEvaluated)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: UpriseColors.warning.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: UpriseColors.warning.withOpacity(0.45)),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.warning_amber_rounded, size: 16, color: UpriseColors.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Evaluation required before distributing',
                                    style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.warning)),
                                const SizedBox(height: 4),
                                Text(
                                  'This event has not been evaluated yet. You can save a draft now, but "Generate & Distribute" will be unlocked only after participants have submitted their evaluations.',
                                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.warning, height: 1.4),
                                ),
                              ]),
                            ),
                          ]),
                        ),

                      // CHANGED: confirmed banner when evaluated
                      if (_selectedEventId != null && _eventIsEvaluated)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: UpriseColors.success.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: UpriseColors.success.withOpacity(0.45)),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 16, color: UpriseColors.success),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Event has been evaluated — certificate distribution is unlocked.',
                                style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.success, height: 1.4),
                              ),
                            ),
                          ]),
                        ),

                      // Original info box — unchanged
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: UpriseColors.lightGray,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: UpriseColors.primaryDark.withOpacity(0.12)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.info_outline_rounded, size: 15, color: UpriseColors.primaryDark),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.charcoal),
                                children: [
                                  TextSpan(text: 'Automatic Recipient Detection  ', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                                  TextSpan(text: 'Certificates are generated only for attendees who have completed event evaluation before distribution.',
                                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.greyText)),
                                ],
                              ),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  // Right — live preview — unchanged
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
            // ── Footer ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
                color: UpriseColors.lightGray,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => _submit(distribute: false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: UpriseColors.mediumGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                  ),
                  child: Text('Save as Draft', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal)),
                ),
                const SizedBox(width: 12),
                // CHANGED: disabled when event not yet evaluated
                ElevatedButton.icon(
                  onPressed: (_isSubmitting || (_selectedEventId != null && !_eventIsEvaluated))
                      ? null
                      : () => _submit(distribute: true),
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

// Form field label wrapper — unchanged
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
// Certificate Live Preview Widget — unchanged
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
        Text(
          orgName.toUpperCase(),
          style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w800, color: accent, letterSpacing: 2.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
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
// Certificate Preview Dialog (view mode) — unchanged
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
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
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
// Import Template Modal — unchanged
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
      await ref.putData(data, SettableMetadata(contentType: _file!.extension == 'pdf' ? 'application/pdf' : 'image/${_file!.extension}'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('certificate_templates').add({
        'orgId': widget.orgId,
        'name': _name!.trim(),
        'storagePath': path,
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context as BuildContext, {'name': _name!.trim(), 'url': url});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context as BuildContext).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: UpriseColors.error));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 520,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(children: [
              Expanded(child: Text('Import Certificate Template', style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))),
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
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
        ]),
      ),
    );
  }
}