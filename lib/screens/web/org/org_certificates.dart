// ignore_for_file: unnecessary_cast, unused_field, deprecated_member_use

import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:image/image.dart' as img;
import 'package:qr_flutter/qr_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/certificate_preview.dart';

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
// Signature background removal — runs on a background isolate via compute()
// so the UI doesn't freeze, and downscales first since the embedded result
// only needs to be a few hundred px wide (a full-resolution photo has far
// more pixels than necessary and is the main cause of the lag).
// ─────────────────────────────────────────────────────────────────────────────
Uint8List removeSignatureBackground(Uint8List bytes) {
  var decoded = img.decodeImage(bytes);
  if (decoded == null) throw Exception('Unsupported image format');
  if (decoded.width > 800) {
    decoded = img.copyResize(decoded, width: 800);
  }
  const threshold = 235; // pixels lighter than this (near-white) become transparent
  for (final pixel in decoded) {
    final luminance = (pixel.r + pixel.g + pixel.b) / 3;
    if (luminance >= threshold) {
      pixel.a = 0;
    } else if (luminance > threshold - 40) {
      // Soft edge: fade the anti-aliased pixels around the ink instead of a hard halo.
      pixel.a = (255 * (threshold - luminance) / 40).clamp(0, 255).toInt();
    }
  }
  return img.encodePng(decoded);
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
  final String? signatureImage; // legacy single-signature certs, pre-multi-signatory
  final List<Map<String, dynamic>> signatories;
  final String? verificationCode;
  final String? recipientName;
  // The editable canvas state from the last time this draft was customized —
  // restored on reopen so "Customize" continues from where the org left
  // off instead of resetting to the generic default layout every time.
  final String? customLayoutJson;
  final int? customBgColor;

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
    this.signatureImage,
    this.signatories = const [],
    this.verificationCode,
    this.recipientName,
    this.customLayoutJson,
    this.customBgColor,
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
      signatureImage: d['signatureImage'] as String?,
      signatories: d['signatories'] is List
          ? (d['signatories'] as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : const [],
      verificationCode: d['verificationCode'] as String?,
      recipientName: d['recipientName'] as String?,
      customLayoutJson: d['customLayoutJson'] as String?,
      customBgColor: (d['customBgColor'] as num?)?.toInt(),
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

  // Created once, not a getter — re-evaluating .snapshots() on every
  // keystroke/setState (search, filter, pagination) was re-subscribing to
  // Firestore from scratch every time, which is what caused the lag.
  late final Stream<QuerySnapshot> _certsStream = FirebaseFirestore.instance
      .collection('certificates')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('issuedAt', descending: true)
      .snapshots();

  // Event comes first: choosing a template / customizing / importing all
  // happen inline inside the Generate Certificate modal now.
  void _openGenerateFlow() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => _GenerateCertificateModal(
        orgId: widget.orgId,
        selectedTemplateType: 'Formal Academic',
        selectedTemplateUrl: null,
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
          clipBehavior: Clip.antiAlias,
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
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFFB923C))),
      ),
      child: Row(children: [
        Expanded(flex: 2, child: _headerCell('CERTIFICATE ID')),
        Expanded(flex: 3, child: _headerCell('EVENT NAME')),
        Expanded(flex: 2, child: _headerCell('ORGANIZATION')),
        Expanded(flex: 2, child: _headerCell('TYPE')),
        Expanded(flex: 2, child: _headerCell('DATE ISSUED')),
        Expanded(flex: 2, child: _headerCell('RECIPIENTS')),
        Expanded(flex: 2, child: _headerCell('STATUS')),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('ACTIONS'))),
      ]),
    );
  }

  Widget _headerCell(String text) => Text(
    text,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.ellipsis,
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
            flex: 2,
            child: Text('${r.recipients}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
          ),
          Expanded(flex: 2, child: _certBadge(r.status)),
          Expanded(
            flex: 2,
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionIconButton(icon: Icons.visibility_outlined,    tooltip: 'View',   color: const Color(0xFF3B82F6),  onTap: () => _viewCert(r)),
              const SizedBox(width: 6),
              _ActionIconButton(icon: Icons.edit_outlined,          tooltip: 'Edit',   color: UpriseColors.primaryDark, onTap: () => _editCert(r)),
              const SizedBox(width: 6),
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
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF1A202C), size: 20),
                  tooltip: 'Close',
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
              spacing: 6,
              children: [
                _ActionIconButton(icon: Icons.visibility_outlined,    tooltip: 'View',   color: const Color(0xFF3B82F6),  onTap: () => _viewCert(r)),
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

  static const Map<int, Color> _bgByFg = {
    0xFF3B82F6: Color(0xFFEFF6FF), // view - blue
    0xFF2563EB: Color(0xFFEFF6FF), // publish - blue
    0xFFB45309: Color(0xFFFFF7ED), // edit - orange (UpriseColors.primaryDark)
    0xFF7C3AED: Color(0xFFF3E8FF), // revise - purple
    0xFF0D9488: Color(0xFFECFDF5), // form builder - teal
    0xFF6B7280: Color(0xFFF3F4F6), // archive - gray
    0xFFDC2626: Color(0xFFFEF2F2), // delete - red
    0xFF059669: Color(0xFFECFDF5), // approve - green
  };

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null ? const Color(0xFFD1D5DB) : color;
    final bg = onTap == null ? const Color(0xFFF1F5F9) : (_bgByFg[fg.value] ?? fg.withAlpha(26));
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: fg),
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

  // Persisted alongside the certificate draft so reopening Customize
  // restores exactly what the org left it at, instead of resetting to the
  // generic default layout every time.
  Map<String, dynamic> toJson() => {
    'id': id, 'type': type, 'x': x, 'y': y, 'w': w, 'h': h,
    'text': text, 'fontSize': fontSize, 'fontWeight': fontWeight.index,
    'color': color.toARGB32(), 'align': align.index, 'italic': italic,
    'letterSpacing': letterSpacing, 'fillColor': fillColor.toARGB32(),
    'strokeColor': strokeColor.toARGB32(), 'strokeWidth': strokeWidth,
  };

  factory _CanvasElement.fromJson(Map<String, dynamic> j) => _CanvasElement(
    id: j['id'] as String, type: j['type'] as String,
    x: (j['x'] as num).toDouble(), y: (j['y'] as num).toDouble(),
    w: (j['w'] as num).toDouble(), h: (j['h'] as num).toDouble(),
    text: j['text'] as String? ?? '',
    fontSize: (j['fontSize'] as num?)?.toDouble() ?? 14,
    fontWeight: FontWeight.values[(j['fontWeight'] as num?)?.toInt() ?? FontWeight.w400.index],
    color: Color((j['color'] as num?)?.toInt() ?? 0xFF1A202C),
    align: TextAlign.values[(j['align'] as num?)?.toInt() ?? TextAlign.center.index],
    italic: j['italic'] as bool? ?? false,
    letterSpacing: (j['letterSpacing'] as num?)?.toDouble() ?? 0,
    fillColor: Color((j['fillColor'] as num?)?.toInt() ?? 0xFFEFF6FF),
    strokeColor: Color((j['strokeColor'] as num?)?.toInt() ?? 0xFF2563EB),
    strokeWidth: (j['strokeWidth'] as num?)?.toDouble() ?? 1.5,
  );
}

// Default element set, seeded from the same data + theme colors the Live
// Preview pane already shows — so opening the editor doesn't reset the
// certificate back to generic placeholder copy and an unrelated palette.
List<_CanvasElement> _defaultElementsFor({
  required String orgName,
  required String eventTitle,
  required String eventDate,
  required String signatoryLine,
  required Color accent,
  required Color textCol,
}) {
  // Font sizes and vertical rhythm mirror CertificatePreview's actual flow
  // (lib/widgets/certificate_preview.dart) field-for-field, so what the org
  // sees in Live Preview is what they get when they open Customize — not a
  // same-ballpark approximation with different sizes/spacing. The org-letter
  // badge is recreated as a rect + a centered text element layered on top
  // (this canvas has no element type that can hold a label inside a shape
  // on its own); the small workspace_premium corner icon has no equivalent
  // primitive here and is left out, since it's a minor decorative detail.
  return [
    _CanvasElement(id: 'border', type: 'rect',    x: 8,   y: 8,   w: 584, h: 408, fillColor: Colors.transparent, strokeColor: accent, strokeWidth: 2),
    _CanvasElement(id: 'badge',  type: 'rect',    x: 287, y: 22,  w: 26,  h: 26,  fillColor: accent, strokeColor: accent, strokeWidth: 0),
    _CanvasElement(id: 'badgeletter', type: 'text', x: 287, y: 22, w: 26, h: 26, text: orgName.isNotEmpty ? orgName[0].toUpperCase() : '?', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
    _CanvasElement(id: 'org',    type: 'text',    x: 0,   y: 52,  w: 600, h: 18,  text: orgName.toUpperCase(), fontSize: 11, fontWeight: FontWeight.w800, color: accent, letterSpacing: 2),
    _CanvasElement(id: 'certty', type: 'text',    x: 0,   y: 84,  w: 600, h: 32,  text: 'CERTIFICATE', fontSize: 24, fontWeight: FontWeight.w900, color: textCol, letterSpacing: 1),
    _CanvasElement(id: 'certof', type: 'text',    x: 0,   y: 116, w: 600, h: 18,  text: 'OF PARTICIPATION', fontSize: 13, fontWeight: FontWeight.w700, color: accent, letterSpacing: 3),
    _CanvasElement(id: 'certfy', type: 'text',    x: 0,   y: 148, w: 600, h: 16,  text: 'This certificate is proudly presented to', fontSize: 10, color: textCol.withAlpha(166)),
    _CanvasElement(id: 'recip',  type: 'text',    x: 0,   y: 168, w: 600, h: 28,  text: '[Recipient Name]', fontSize: 19, fontWeight: FontWeight.w700, color: textCol, italic: true),
    _CanvasElement(id: 'div1',   type: 'divider', x: 230, y: 200, w: 140, h: 1,   strokeColor: accent.withAlpha(102), strokeWidth: 1),
    _CanvasElement(id: 'parti',  type: 'text',    x: 0,   y: 212, w: 600, h: 16,  text: 'for successfully participating in', fontSize: 10, color: textCol.withAlpha(153)),
    _CanvasElement(id: 'evtit',  type: 'text',    x: 0,   y: 232, w: 600, h: 18,  text: eventTitle, fontSize: 12, fontWeight: FontWeight.w700, color: textCol),
    _CanvasElement(id: 'evdat',  type: 'text',    x: 0,   y: 252, w: 600, h: 16,  text: 'held on $eventDate', fontSize: 10, color: textCol.withAlpha(153)),
    _CanvasElement(id: 'div2',   type: 'divider', x: 190, y: 282, w: 220, h: 1,   strokeColor: accent, strokeWidth: 1),
    _CanvasElement(id: 'signa',  type: 'text',    x: 0,   y: 290, w: 600, h: 16,  text: signatoryLine, fontSize: 9, color: textCol.withAlpha(128)),
  ];
}

class _CanvaTemplateEditor extends StatefulWidget {
  final String orgId;
  final String initialTemplateType;
  final String orgName;
  final String eventTitle;
  final String eventDate;
  final String signatoryLine;
  final Color themeBg;
  final Color themeAccent;
  final Color themeText;
  // Restores exactly where the org left off customizing last time, instead
  // of resetting to the generic default layout every time Customize opens.
  final List<_CanvasElement>? initialElements;
  final Color? initialBgColor;
  final void Function(String? savedUrl, List<_CanvasElement> elements, Color bgColor) onSave;
  const _CanvaTemplateEditor({
    required this.orgId,
    required this.initialTemplateType,
    required this.orgName,
    required this.eventTitle,
    required this.eventDate,
    required this.signatoryLine,
    required this.themeBg,
    required this.themeAccent,
    required this.themeText,
    this.initialElements,
    this.initialBgColor,
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
    _elements = widget.initialElements ?? _defaultElementsFor(
      orgName: widget.orgName,
      eventTitle: widget.eventTitle,
      eventDate: widget.eventDate,
      signatoryLine: widget.signatoryLine,
      accent: widget.themeAccent,
      textCol: widget.themeText,
    );
    _bgColor = widget.initialBgColor ?? widget.themeBg;
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

      if (downloadUrl == null) {
        // Capture genuinely failed (or the repaint boundary wasn't ready) —
        // closing the dialog here would silently discard everything the org
        // just designed with no way to recover it. Keep the editor open and
        // tell them plainly instead.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not capture your customization as an image. Your edits are still here — try again, or use Import Template instead.'),
              backgroundColor: Color(0xFFDC2626),
            ),
          );
        }
        return;
      }

      await activity_log.ActivityLogger.log(
        action: 'customize_certificate_template',
        module: 'certificates',
        details: {'orgId': widget.orgId, 'templateType': widget.initialTemplateType},
      );
      if (mounted) widget.onSave(downloadUrl, _elements, _bgColor);
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
              _EditorTopBtn(icon: Icons.text_fields_rounded, label: 'Text', onTap: _addText),
              const SizedBox(width: 8),
              _EditorTopBtn(icon: Icons.crop_square_rounded, label: 'Rectangle', onTap: _addRect),
              const SizedBox(width: 8),
              _EditorTopBtn(icon: Icons.circle_outlined, label: 'Circle', onTap: _addCircle),
              if (_selectedId != null) ...[
                const SizedBox(width: 8),
                Container(width: 1, height: 22, color: borderColor),
                const SizedBox(width: 8),
                _EditorTopBtn(icon: Icons.delete_outline_rounded, label: 'Delete', onTap: _deleteSelected, danger: true),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: UpriseColors.white, size: 20),
                tooltip: 'Close',
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
  // Local-only visual offset while dragging/resizing. Keeping this in this
  // widget's own state (instead of bubbling every pixel up to the editor's
  // setState) means only this element rebuilds during the gesture, instead of
  // the whole canvas + layers panel + properties panel on every drag frame.
  // The parent is only notified once, via onMove/onResize, when the gesture ends.
  Offset _dragOffset = Offset.zero;
  Offset _resizeOffset = Offset.zero;
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
      left: el.x + _dragOffset.dx, top: el.y + _dragOffset.dy,
      child: RepaintBoundary(
        child: GestureDetector(
          onTap: () { widget.onTap(); setState(() => _editing = false); },
          onDoubleTap: () {
            if (el.type == 'text') setState(() => _editing = true);
          },
          onPanStart: (d) => _lastDrag = d.globalPosition,
          onPanUpdate: (d) {
            if (_lastDrag != null) {
              final delta = d.globalPosition - _lastDrag!;
              setState(() => _dragOffset += delta);
              _lastDrag = d.globalPosition;
            }
          },
          onPanEnd: (_) {
            _lastDrag = null;
            final committed = _dragOffset;
            if (committed != Offset.zero) {
              setState(() => _dragOffset = Offset.zero);
              widget.onMove(committed.dx, committed.dy);
            }
          },
          child: SizedBox(
            width: el.w + _resizeOffset.dx,
            height: el.type == 'divider' ? 10 : el.h + _resizeOffset.dy,
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
                        final delta = d.globalPosition - _lastResize!;
                        setState(() => _resizeOffset += delta);
                        _lastResize = d.globalPosition;
                      }
                    },
                    onPanEnd: (_) {
                      _lastResize = null;
                      final committed = _resizeOffset;
                      if (committed != Offset.zero) {
                        setState(() => _resizeOffset = Offset.zero);
                        widget.onResize(committed.dx, committed.dy);
                      }
                    },
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
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ContentField(
                  key: ValueKey(sel.id),
                  value: sel.text,
                  onChanged: (v) => onUpdate(sel.copyWith(text: v)),
                ),
              ),
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

// Editable text content for the selected canvas element — the actual
// "fill in the details" field a cert maker needs (recipient name, org
// name, event title, signatory, etc.), instead of relying on double-
// clicking the element on the canvas to discover it's editable.
// Keyed by element id from the parent so switching the selection swaps
// in a fresh controller, while typing in the same element doesn't reset
// the cursor on every keystroke rebuild.
class _ContentField extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _ContentField({super.key, required this.value, required this.onChanged});

  @override
  State<_ContentField> createState() => _ContentFieldState();
}

class _ContentFieldState extends State<_ContentField> {
  late final TextEditingController _ctrl = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextField(
      controller: _ctrl,
      maxLines: 3,
      minLines: 1,
      style: GoogleFonts.beVietnamPro(fontSize: 12, color: colorScheme.onSurface),
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Text content…',
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        filled: true,
        fillColor: colorScheme.surfaceVariant,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: colorScheme.outline)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: colorScheme.outline)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: colorScheme.primary)),
      ),
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
      const Color(0xFFEA580C), const Color(0xFFFB923C), const Color(0xFFFCD34D),
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
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _EditorTopBtn({required this.icon, required this.label, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFEF4444) : UpriseColors.primaryDark;
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: danger ? const Color(0xFFEF4444).withAlpha(18) : UpriseColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: danger ? const Color(0xFFEF4444).withAlpha(64) : UpriseColors.primaryDark.withAlpha(38)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ]),
        ),
      ),
    );
  }
}

// A certificate can have more than one signatory (e.g. org president +
// adviser). Each one gets its own name, title, and optional signature image.
class _SignatoryEntry {
  final nameCtrl = TextEditingController();
  final titleCtrl = TextEditingController();
  String? signatureImageBase64;
  bool processing = false;

  void dispose() {
    nameCtrl.dispose();
    titleCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Generate Certificate Modal — event comes first, certificates are only
// distributed for attendees who attended and evaluated the event.
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
  final List<_SignatoryEntry> _signatories = [_SignatoryEntry()];

  String? _selectedEventId;
  String? _selectedEventName;
  String? _selectedEventDocId;

  // Attendees who showed up AND submitted their event evaluation —
  // these are exactly who "Generate & Distribute" issues a certificate to.
  List<Map<String, String>> _eligibleRecipients = [];
  int    _attendeeCount = 0;
  bool   _attendanceSynced = false;
  bool get _hasEligibleRecipients => _eligibleRecipients.isNotEmpty;

  String? _selectedTemplateUrl;
  // The editable canvas state from the last Customize session for this
  // draft — kept in memory (and persisted on submit) so reopening Customize
  // continues from here instead of resetting to the generic default.
  List<_CanvasElement>? _customElements;
  Color? _customBgColor;
  String  _certType    = 'Formal Academic';
  bool    _isSubmitting = false;

  // Pre-filters to only approved proposals that issue certificates. Created
  // once (not a getter) — re-evaluating .snapshots() on every keystroke was
  // re-subscribing to Firestore on every rebuild and is what caused the lag.
  late final Stream<QuerySnapshot> _eventsStream = FirebaseFirestore.instance
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
      final existingSignatories = widget.existingRecord!.signatories;
      if (existingSignatories.isNotEmpty) {
        _signatories.clear();
        for (final s in existingSignatories) {
          final entry = _SignatoryEntry();
          entry.nameCtrl.text = (s['name'] ?? '').toString();
          entry.titleCtrl.text = (s['title'] ?? '').toString();
          entry.signatureImageBase64 = s['signatureImage'] as String?;
          _signatories.add(entry);
        }
      }
      final savedLayout = widget.existingRecord!.customLayoutJson;
      if (savedLayout != null) {
        try {
          final decoded = jsonDecode(savedLayout) as List;
          _customElements = decoded
              .map((e) => _CanvasElement.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
          final bg = widget.existingRecord!.customBgColor;
          if (bg != null) _customBgColor = Color(bg);
        } catch (_) {
          // Corrupt/old-format layout — fall back to the generic default.
        }
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _orgCtrl.dispose();
    _dateCtrl.dispose();
    for (final s in _signatories) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSignatory() => setState(() => _signatories.add(_SignatoryEntry()));

  void _removeSignatory(_SignatoryEntry entry) {
    setState(() {
      _signatories.remove(entry);
      entry.dispose();
    });
  }

  Future<void> _importSignature(_SignatoryEntry entry) async {
    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.image);
    if (res == null || res.files.isEmpty) return;
    final bytes = res.files.first.bytes;
    if (bytes == null) return;

    setState(() => entry.processing = true);
    try {
      // Runs on a background isolate so the UI doesn't freeze while processing.
      final pngBytes = await compute(removeSignatureBackground, bytes);
      if (mounted) setState(() => entry.signatureImageBase64 = base64Encode(pngBytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not process signature: $e'), backgroundColor: UpriseColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => entry.processing = false);
    }
  }

  CertTheme get _previewTheme => CertTheme.forType(_certType,
      primaryDark: UpriseColors.primaryDark, primaryLight: UpriseColors.primaryLight, accentColor: UpriseColors.accent);

  String _generateVerificationCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = math.Random.secure();
    return List.generate(12, (_) => chars[rng.nextInt(chars.length)]).join();
  }

  // Opens the Canva-like editor for the currently selected template type.
  // The editor returns an optional custom templateUrl (if the user saved an
  // image from the canvas); if null is returned the preset name is kept.
  //
  // Seeded with exactly what the Live Preview pane is already showing (same
  // org name / title / date / signatory / theme colors) so the editor opens
  // on the certificate the user is actually looking at, not a generic preset.
  void _openCanvaEditor() {
    final theme = _previewTheme;
    String signatoryLine = 'Authorized Signatory';
    for (final s in _signatories) {
      final name = s.nameCtrl.text.trim();
      if (name.isNotEmpty) {
        final title = s.titleCtrl.text.trim();
        signatoryLine = title.isNotEmpty ? '$name, $title' : name;
        break;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (_) => _CanvaTemplateEditor(
        orgId: widget.orgId,
        initialTemplateType: _certType,
        orgName: _orgCtrl.text.trim().isNotEmpty ? _orgCtrl.text.trim() : 'Your Organization',
        eventTitle: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Certificate of Participation',
        eventDate: _dateCtrl.text.trim().isNotEmpty ? _dateCtrl.text.trim() : DateFormat('MMMM dd, yyyy').format(DateTime.now()),
        signatoryLine: signatoryLine,
        themeBg: theme.bg,
        themeAccent: theme.accent,
        themeText: theme.text,
        initialElements: _customElements,
        initialBgColor: _customBgColor,
        onSave: (savedUrl, elements, bgColor) {
          Navigator.pop(context);
          setState(() {
            if (savedUrl != null) _selectedTemplateUrl = savedUrl;
            _customElements = elements;
            _customBgColor = bgColor;
          });
        },
      ),
    );
  }

  Future<void> _openImportTemplate() async {
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (_) => _ImportTemplateModal(orgId: widget.orgId),
    );
    if (result != null && result['name'] != null && mounted) {
      setState(() {
        _certType = result['name']!;
        _selectedTemplateUrl = result['url'];
      });
    }
  }

  // Single source of truth for what "the certificate" currently looks like —
  // used both inline in the modal and in the full-size preview dialog, so
  // the two can never show something different from each other.
  Widget _buildPreviewVisual(CertTheme theme) {
    // Once a template has been customized or imported, the preview shows
    // that actual design — not the generic preset layout — since that
    // image is exactly what gets issued.
    if (_selectedTemplateUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _selectedTemplateUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(color: const Color(0xFFF1F4F8), child: const Center(child: CircularProgressIndicator())),
          errorBuilder: (_, __, ___) => Container(
            color: const Color(0xFFF1F4F8),
            padding: const EdgeInsets.all(16),
            child: Text('Could not load the custom template image.',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8)), textAlign: TextAlign.center),
          ),
        ),
      );
    }
    // Rendered at its true 600×424 design size (same logical canvas size
    // Customize opens to) then scaled as a whole via FittedBox — so the
    // proportions always match the editor exactly, with nothing cropped
    // off at narrow widths.
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: 600,
        height: 424,
        child: CertificatePreview(
          theme: theme,
          orgName:   _orgCtrl.text.isNotEmpty  ? _orgCtrl.text  : 'Your Organization',
          eventTitle: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Certificate of Participation',
          eventDate:  _dateCtrl.text.isNotEmpty  ? _dateCtrl.text  : DateFormat('MMMM dd, yyyy').format(DateTime.now()),
          recipient: '[Recipient Name]',
          signatories: _signatories
              .where((s) => s.nameCtrl.text.trim().isNotEmpty)
              .map((s) => CertSignatory(
                    name: s.nameCtrl.text.trim(),
                    title: s.titleCtrl.text.trim(),
                    signatureImageBase64: s.signatureImageBase64,
                  ))
              .toList(),
        ),
      ),
    );
  }

  void _showPreviewFullscreen(CertTheme theme) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: Stack(clipBehavior: Clip.none, children: [
          Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 32, offset: Offset(0, 12))],
            ),
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: 600 / 424,
              child: _buildPreviewVisual(theme),
            ),
          ),
          Positioned(
            top: -16, right: -16,
            child: IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54, shape: const CircleBorder()),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _submit({required bool distribute}) async {
    if (_formKey.currentState?.validate() != true) return;
    if (distribute && !_hasEligibleRecipients) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No attendees have completed their evaluation yet — certificates can only be distributed to attendees who attended and evaluated the event.', style: GoogleFonts.beVietnamPro(color: Colors.white)),
          backgroundColor: UpriseColors.error,
        ));
      }
      return;
    }
    setState(() => _isSubmitting = true);

    final eventName = _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : (_selectedEventName ?? 'Untitled');
    final signatoriesPayload = _signatories
        .where((s) => s.nameCtrl.text.trim().isNotEmpty)
        .map((s) => {
              'name': s.nameCtrl.text.trim(),
              'title': s.titleCtrl.text.trim(),
              if (s.signatureImageBase64 != null) 'signatureImage': s.signatureImageBase64,
            })
        .toList();

    try {
      if (distribute) {
        // One verifiable certificate per attendee who attended AND evaluated the event.
        final batch = FirebaseFirestore.instance.batch();
        final certsRef = FirebaseFirestore.instance.collection('certificates');
        for (final r in _eligibleRecipients) {
          final isGuest = r['isGuest'] == 'true';
          final key = r['recipientKey']!;
          final docRef = certsRef.doc('${_selectedEventDocId}_$key');
          batch.set(docRef, {
            'orgId':            widget.orgId,
            'eventId':          _selectedEventDocId,
            'eventName':        eventName,
            'organization':     _orgCtrl.text.trim(),
            'templateType':     _certType,
            'type':             'Participation',
            'issuedAt':         FieldValue.serverTimestamp(),
            'status':           'distributed',
            'recipients':       1,
            'recipientName':    r['recipientName'],
            'isGuest':          isGuest,
            // recipientUid must always be set, guest or not — the student
            // viewer matches certificates by exact recipientUid equality, so
            // a guest's email here will simply never match any real
            // student's uid. Leaving it unset is what actually causes a
            // leak: this collection has no other "broadcast to everyone"
            // certificate type, so a missing recipientUid has no legitimate
            // meaning here and should never be relied on by a reader.
            'recipientId': key, 'recipientUid': key,
            if (isGuest) 'recipientEmail': key,
            'signatories':      signatoriesPayload,
            'verificationCode': _generateVerificationCode(),
            'autoGenerated':    false,
            if (_selectedTemplateUrl != null) 'templateFileUrl': _selectedTemplateUrl,
            if (_customElements != null) 'customLayoutJson': jsonEncode(_customElements!.map((e) => e.toJson()).toList()),
            if (_customBgColor != null) 'customBgColor': _customBgColor!.toARGB32(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      } else {
        // Draft: a single placeholder record, since no certificates are issued yet.
        final payload = <String, dynamic>{
          'orgId':        widget.orgId,
          'eventName':    eventName,
          'organization': _orgCtrl.text.trim(),
          'templateType': _certType,
          'type':         'Participation',
          'issuedAt':     FieldValue.serverTimestamp(),
          'status':       'draft',
          'recipients':   _eligibleRecipients.length,
          'signatories':  signatoriesPayload,
          if (_selectedTemplateUrl != null) 'templateFileUrl': _selectedTemplateUrl,
          if (_customElements != null) 'customLayoutJson': jsonEncode(_customElements!.map((e) => e.toJson()).toList()),
          if (_customBgColor != null) 'customBgColor': _customBgColor!.toARGB32(),
          if (_selectedEventDocId != null) 'eventId': _selectedEventDocId,
        };
        if (widget.existingRecord != null) {
          await FirebaseFirestore.instance.collection('certificates').doc(widget.existingRecord!.id).update(payload);
        } else {
          await FirebaseFirestore.instance.collection('certificates').add(payload);
        }
      }

      await activity_log.ActivityLogger.log(
        action: distribute ? 'generate_distribute_certificate' : 'save_draft_certificate',
        module: 'certificates',
        details: {'orgId': widget.orgId, 'templateType': _certType, 'recipients': _eligibleRecipients.length},
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(distribute ? 'Distributed ${_eligibleRecipients.length} certificate(s)!' : 'Saved as draft.',
              style: GoogleFonts.beVietnamPro(color: Colors.white)),
          backgroundColor: distribute ? UpriseColors.success : UpriseColors.darkGray,
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

  Future<int> _fetchAttendanceCount(String eventDocId) async {
    final snap = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventDocId)
        .collection('attendances')
        .get();
    return snap.docs.length;
  }

  /// Attendees who showed up (present/late) AND submitted their event
  /// evaluation. This is the actual recipient list for distribution —
  /// it's recomputed every time so newly-submitted evaluations are picked up.
  ///
  /// Returns both students (keyed by uid) and guests (keyed by email) —
  /// disambiguated via the 'isGuest' flag ('true'/'false' string, since this
  /// method's `Map<String, String>` signature is relied on elsewhere).
  Future<List<Map<String, String>>> _fetchEligibleRecipients(String eventDocId) async {
    final attSnap = await FirebaseFirestore.instance
        .collection('events')
        .doc(eventDocId)
        .collection('attendances')
        .get();

    final feedbackSnap = await FirebaseFirestore.instance
        .collection('event_feedback')
        .where('eventId', isEqualTo: eventDocId)
        .get();
    final evaluatedUids = feedbackSnap.docs
        .map((d) => d.data()['userId']?.toString())
        .whereType<String>()
        .toSet();
    final evaluatedGuestEmails = feedbackSnap.docs
        .where((d) => d.data()['isGuest'] == true)
        .map((d) => d.data()['guestEmail']?.toString())
        .whereType<String>()
        .toSet();

    final eligible = <Map<String, String>>[];
    for (final doc in attSnap.docs) {
      final data = doc.data();
      final status = (data['status'] ?? '').toString();
      if (status != 'present' && status != 'late') continue;

      if (data['isGuest'] == true) {
        final email = (data['guestEmail'] ?? '').toString();
        if (email.isEmpty || !evaluatedGuestEmails.contains(email)) continue;
        eligible.add({
          'recipientKey': email,
          'recipientName': (data['studentName'] ?? 'Guest').toString(),
          'isGuest': 'true',
        });
      } else {
        final studentId = (data['studentId'] ?? '').toString();
        if (studentId.isEmpty || !evaluatedUids.contains(studentId)) continue;
        eligible.add({
          'recipientKey': studentId,
          'recipientName': (data['studentName'] ?? 'Unknown').toString(),
          'isGuest': 'false',
        });
      }
    }
    return eligible;
  }

  @override
  Widget build(BuildContext context) {
    final theme  = _previewTheme;
    final isEdit = widget.existingRecord != null;
    final templateOptions = ['Formal Academic', 'Modern Workshop', 'Vibrant Event'];
    if (!templateOptions.contains(_certType)) {
      templateOptions.add(_certType);
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        // Wide enough (with the flex split below) that the live preview
        // renders at ~600px — the same logical size Customize's canvas
        // opens to — instead of shrinking to a noticeably smaller, harder
        // to judge preview.
        width: 1080,
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  tooltip: 'Close',
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
                    flex: 2,
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
                                  isExpanded: true,
                                  hint: Text(
                                    events.isEmpty
                                        ? 'No approved certificate events found'
                                        : 'Choose an approved event',
                                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  decoration: _fieldDecoration(),
                                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                                  validator: (_) => _selectedEventId == null ? 'Required' : null,
                                  items: events.map((doc) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    return DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(data['title'] as String? ?? 'Untitled', overflow: TextOverflow.ellipsis),
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
                                      _orgCtrl.text       = (data['orgName'] as String?) ?? _orgCtrl.text;
                                      _selectedEventDocId = null;
                                      _attendeeCount = 0;
                                      _attendanceSynced = false;
                                      _eligibleRecipients = [];
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
                                        final attendeeCount = await _fetchAttendanceCount(eventDoc.id);
                                        final eligible = await _fetchEligibleRecipients(eventDoc.id);
                                        if (mounted) {
                                          setState(() {
                                            _selectedEventDocId = eventDoc.id;
                                            _attendeeCount = attendeeCount;
                                            _eligibleRecipients = eligible;
                                            _attendanceSynced = true;
                                          });
                                        }
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
                              isExpanded: true,
                              decoration: _fieldDecoration(),
                              style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
                              items: templateOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) { if (v != null) setState(() => _certType = v); },
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        OutlinedButton.icon(
                          onPressed: _openCanvaEditor,
                          icon: const Icon(Icons.brush_outlined, size: 14),
                          label: Text('Customize', style: GoogleFonts.beVietnamPro(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: UpriseColors.primaryDark,
                            side: BorderSide(color: UpriseColors.primaryDark.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: _openImportTemplate,
                          icon: const Icon(Icons.upload_file_outlined, size: 14),
                          label: Text('Import Template', style: GoogleFonts.beVietnamPro(fontSize: 12.5, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: UpriseColors.primaryDark,
                            side: BorderSide(color: UpriseColors.primaryDark.withOpacity(0.4)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      Text('Signatories (Authorized Personnel) *',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
                      const SizedBox(height: 6),
                      for (int i = 0; i < _signatories.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        _SignatoryRow(
                          entry: _signatories[i],
                          isFirst: i == 0,
                          canRemove: _signatories.length > 1,
                          onChanged: () => setState(() {}),
                          onImport: () => _importSignature(_signatories[i]),
                          onRemove: () => _removeSignatory(_signatories[i]),
                        ),
                      ],
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _addSignatory,
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: Text('Add another signatory', style: GoogleFonts.beVietnamPro(fontSize: 12.5, fontWeight: FontWeight.w600)),
                        style: TextButton.styleFrom(foregroundColor: UpriseColors.primaryDark, padding: const EdgeInsets.symmetric(horizontal: 4)),
                      ),
                      const SizedBox(height: 16),

                      // Single recipient-status banner — replaces the recipient
                      // count field entirely: recipients are always exactly the
                      // attendees who showed up and submitted their evaluation.
                      Builder(builder: (_) {
                        final noEventSelected = _selectedEventId == null;
                        final checking = !noEventSelected && !_attendanceSynced;
                        final ready = _hasEligibleRecipients;
                        final bg = noEventSelected || checking
                            ? UpriseColors.lightGray
                            : (ready ? UpriseColors.success.withOpacity(0.18) : UpriseColors.warning.withOpacity(0.18));
                        final border = noEventSelected || checking
                            ? UpriseColors.primaryDark.withOpacity(0.12)
                            : (ready ? UpriseColors.success.withOpacity(0.45) : UpriseColors.warning.withOpacity(0.45));
                        final fg = noEventSelected || checking
                            ? UpriseColors.charcoal
                            : (ready ? UpriseColors.success : UpriseColors.warning);
                        final icon = noEventSelected || checking
                            ? Icons.info_outline_rounded
                            : (ready ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded);
                        final message = noEventSelected
                            ? 'Recipients are detected automatically: certificates go to attendees who attended and completed their event evaluation. Select an event to see who qualifies.'
                            : checking
                                ? 'Checking attendance and evaluations…'
                                : ready
                                    ? '${_eligibleRecipients.length} of $_attendeeCount attendee(s) evaluated the event and will receive a certificate.'
                                    : '$_attendeeCount attendee(s) recorded, but none have submitted their evaluation yet. You can save a draft — "Generate & Distribute" unlocks once at least one attendee evaluates.';
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: border),
                          ),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(icon, size: 16, color: fg),
                            const SizedBox(width: 8),
                            Expanded(child: Text(message, style: GoogleFonts.beVietnamPro(fontSize: 12, color: fg, height: 1.4))),
                          ]),
                        );
                      }),
                    ]),
                  ),
                  const SizedBox(width: 24),
                  // Right — live preview
                  Expanded(
                    flex: 3,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: _sectionLabel('Live Preview', icon: Icons.preview_outlined)),
                        IconButton(
                          icon: const Icon(Icons.zoom_out_map_rounded, size: 16, color: UpriseColors.darkGray),
                          tooltip: 'View larger',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () => _showPreviewFullscreen(theme),
                        ),
                        if (_selectedTemplateUrl != null)
                          TextButton(
                            onPressed: () => setState(() => _selectedTemplateUrl = null),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6), minimumSize: Size.zero),
                            child: Text('Use preset instead', style: GoogleFonts.beVietnamPro(fontSize: 11.5, color: UpriseColors.primaryDark)),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      AspectRatio(
                        aspectRatio: 600 / 424,
                        child: _buildPreviewVisual(theme),
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
                // Disabled until at least one attendee has evaluated the event
                ElevatedButton.icon(
                  onPressed: (_isSubmitting || (_selectedEventId != null && !_hasEligibleRecipients))
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

// One row in the repeatable signatories list: name, title, signature import.
class _SignatoryRow extends StatelessWidget {
  final _SignatoryEntry entry;
  final bool isFirst;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onImport;
  final VoidCallback onRemove;
  const _SignatoryRow({
    required this.entry, required this.isFirst, required this.canRemove,
    required this.onChanged, required this.onImport, required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE4E8EF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextFormField(
              controller: entry.nameCtrl,
              onChanged: (_) => onChanged(),
              decoration: _fieldDecoration(hint: 'Full name', icon: Icons.person_outline_rounded),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              validator: (v) => isFirst && v?.trim().isEmpty == true ? 'Required' : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextFormField(
              controller: entry.titleCtrl,
              onChanged: (_) => onChanged(),
              decoration: _fieldDecoration(hint: 'Title / Position', icon: Icons.badge_outlined),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
            ),
          ),
          if (canRemove) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: const Color(0xFF9AA5B4)),
              tooltip: 'Remove signatory',
              onPressed: onRemove,
            ),
          ],
        ]),
        const SizedBox(height: 10),
        Row(children: [
          OutlinedButton.icon(
            onPressed: entry.processing ? null : onImport,
            icon: entry.processing
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: UpriseColors.primaryDark))
                : const Icon(Icons.draw_outlined, size: 14),
            label: Text(entry.signatureImageBase64 == null ? 'Import Signature' : 'Replace Signature',
                style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: UpriseColors.primaryDark,
              side: BorderSide(color: UpriseColors.primaryDark.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          if (entry.signatureImageBase64 != null) ...[
            const SizedBox(width: 10),
            // Checkerboard-style backdrop so a transparent cutout is visible.
            Container(
              width: 64, height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F8),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE4E8EF)),
              ),
              padding: const EdgeInsets.all(2),
              child: Image.memory(base64Decode(entry.signatureImageBase64!), fit: BoxFit.contain),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () { entry.signatureImageBase64 = null; onChanged(); },
              child: Icon(Icons.close_rounded, size: 16, color: const Color(0xFF9AA5B4)),
            ),
          ],
        ]),
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
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: CertificatePreview(
              theme: CertTheme.forType(record.templateType,
                  primaryDark: UpriseColors.primaryDark, primaryLight: UpriseColors.primaryLight, accentColor: UpriseColors.accent),
              orgName:   record.organization,
              eventTitle: record.eventName,
              eventDate:  DateFormat('MMMM dd, yyyy').format(record.date),
              recipient:  record.recipientName ?? '[Recipient Name]',
              signatories: record.signatories.isNotEmpty
                  ? record.signatories.map((s) => CertSignatory(
                        name: (s['name'] ?? '').toString(),
                        title: (s['title'] ?? '').toString(),
                        signatureImageBase64: s['signatureImage'] as String?,
                      )).toList()
                  : (record.signatureImage != null
                      ? [CertSignatory(name: 'Authorized Signatory', signatureImageBase64: record.signatureImage)]
                      : const []),
              verificationCode: record.verificationCode,
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

  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB

  Future<void> _pickFile() async {
    final res = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf']);
    if (res == null || res.files.isEmpty) return;
    final picked = res.files.first;
    // Caught here, before attempting the upload — otherwise an oversized file
    // uploads fully (slow) before Storage's size rule rejects it, which looks
    // like the picker is just hanging and then mysteriously failing.
    if ((picked.size) > _maxBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${picked.name} is ${(picked.size / (1024 * 1024)).toStringAsFixed(1)} MB — max size is 5 MB.'),
          backgroundColor: UpriseColors.error,
        ));
      }
      return;
    }
    setState(() => _file = picked);
  }

  Future<void> _upload() async {
    if (_file == null || _name?.trim().isEmpty == true) return;
    setState(() => _isUploading = true);
    try {
      final path = 'certificate_templates/${widget.orgId}/${DateTime.now().millisecondsSinceEpoch}_${_file!.name}';
      final ref = FirebaseStorage.instance.ref().child(path);
      final data = _file!.bytes as Uint8List?;
      if (data == null) throw Exception('Failed to read file bytes — try picking the file again.');
      final ext = (_file!.extension ?? '').toLowerCase();
      await ref.putData(data, SettableMetadata(contentType: ext == 'pdf' ? 'application/pdf' : 'image/$ext'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('certificate_templates').add({
        'orgId': widget.orgId,
        'name': _name!.trim(),
        'storagePath': path,
        'url': url,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, {'name': _name!.trim(), 'url': url});
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Upload failed (${e.code}): ${e.message ?? 'Storage rejected the upload — check Storage rules/CORS for this project.'}'),
          backgroundColor: UpriseColors.error,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: UpriseColors.error));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 480,
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
                child: const Icon(Icons.upload_file_outlined, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Import Certificate Template',
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Bring in a design from outside Uprise',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, color: Colors.white.withOpacity(0.7))),
              ])),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _FieldWrapper(
                label: 'Template Name *',
                child: TextField(
                  decoration: _fieldDecoration(hint: 'e.g. CICT Awards Design', icon: Icons.badge_outlined),
                  style: GoogleFonts.beVietnamPro(fontSize: 13),
                  onChanged: (v) => setState(() => _name = v),
                ),
              ),
              const SizedBox(height: 14),
              _FieldWrapper(
                label: 'File (PNG, JPG, or PDF) *',
                child: InkWell(
                  onTap: _pickFile,
                  borderRadius: BorderRadius.circular(_DS.radiusSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(_DS.radiusSm),
                      border: Border.all(color: const Color(0xFFE4E8EF)),
                    ),
                    child: Row(children: [
                      Icon(Icons.upload_file_outlined, size: 17, color: UpriseColors.primaryDark),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_file?.name ?? 'Choose a file…',
                          style: GoogleFonts.beVietnamPro(fontSize: 13, color: _file == null ? const Color(0xFF9AA5B4) : const Color(0xFF1A202C)),
                          overflow: TextOverflow.ellipsis)),
                      Text('Browse', style: GoogleFonts.beVietnamPro(fontSize: 12.5, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
                    ]),
                  ),
                ),
              ),
            ]),
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
                onPressed: (_file == null || _name == null || _name!.trim().isEmpty || _isUploading) ? null : _upload,
                icon: _isUploading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: Text('Upload', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
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