// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
// Firebase Storage is no longer needed for uploads
// import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../services/notification_service.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../utils/platform_file_utils.dart' as platform_file_utils;
import '../../../theme/app_theme.dart';
import '../../../widgets/admin_export_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — mirrors student_accounts.dart / org_letter_request.dart
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusPill = 100;

  // Brand amber
  static const Color primary = Color(0xFFBE4700);
  static const Color primaryBg = Color(0xFFFEF3C7);

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  static InputDecoration inputDecoration(
    String label, {
    String? hint,
    IconData? icon,
    int? maxLines,
  }) => InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon != null
        ? Icon(icon, size: 18, color: const Color(0xFF9AA5B4))
        : null,
    alignLabelWithHint: maxLines != null && maxLines > 1,
    labelStyle: GoogleFonts.beVietnamPro(
      fontSize: 13,
      color: const Color(0xFF64748B),
    ),
    hintStyle: GoogleFonts.beVietnamPro(
      fontSize: 13,
      color: const Color(0xFF9AA5B4),
    ),
    filled: true,
    fillColor: const Color(0xFFF8F9FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: const BorderSide(color: _DS.primary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: const BorderSide(color: Color(0xFFDC2626)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusSm),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text, {IconData? icon}) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 16, color: _DS.primary),
        const SizedBox(width: 8),
      ],
      Text(
        text,
        style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _DS.primary,
          letterSpacing: 0.3,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
    ],
  ),
);

Widget _statusBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'pending': _BadgeStyle(
      const Color(0xFFFFFBEB),
      const Color(0xFFFB923C),
      'PENDING',
    ),
    'approved': _BadgeStyle(
      const Color(0xFFECFDF5),
      const Color(0xFF059669),
      'APPROVED',
    ),
    'rejected': _BadgeStyle(
      const Color(0xFFFEF2F2),
      const Color(0xFFDC2626),
      'REJECTED',
    ),
    'review': _BadgeStyle(
      const Color(0xFFEDE9FE),
      const Color(0xFF5B21B6),
      'ON REVIEW',
    ),
  };
  final s =
      styles[status.toLowerCase()] ??
      _BadgeStyle(
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
        status.toUpperCase(),
      );
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

class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgReportsScreen extends StatefulWidget {
  final String orgId;
  const OrgReportsScreen({super.key, required this.orgId});

  @override
  State<OrgReportsScreen> createState() => _OrgReportsScreenState();
}

class _OrgReportsScreenState extends State<OrgReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String? _typeFilter; // null = no filter, 'Financial' or 'Accomplishment'
  int _currentPage = 1;
  static const int _pageSize = 10;

  // Countdown
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  DateTime? _eventDate;
  String _eventLabel = '';
  bool _eventLoaded = false;

  // Deadlines
  DateTime? _financialDeadline;
  DateTime? _accomplishmentDeadline;
  bool _deadlinesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadEventDate();
    _loadReportDeadlines();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEventDate() async {
    try {
      final now = DateTime.now();
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('orgId', isEqualTo: widget.orgId)
          .where('status', isEqualTo: 'approved')
          .get();

      DateTime? nextDate;
      String nextLabel = '';
      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = data['date'] as Timestamp?;
        if (ts == null) continue;
        final date = ts.toDate();
        if (date.isBefore(now)) continue;
        if (nextDate == null || date.isBefore(nextDate)) {
          nextDate = date;
          nextLabel = data['title']?.toString() ?? 'Upcoming Event';
        }
      }

      if (nextDate != null) {
        _eventDate = nextDate;
        _eventLabel = nextLabel;
        _updateRemaining();
        _countdownTimer = Timer.periodic(
          const Duration(seconds: 1),
          (_) => _updateRemaining(),
        );
      }
    } catch (_) {}
    if (mounted) setState(() => _eventLoaded = true);
  }

  void _updateRemaining() {
    if (_eventDate == null) return;
    final diff = _eventDate!.difference(DateTime.now());
    if (mounted)
      setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  // Per-org, not a single blanket date: defaults to 7 days after this org's
  // most recently *finished* event, or whatever the admin overrode it to —
  // and only exists once that event has actually happened, never before.
  Future<void> _loadReportDeadlines() async {
    try {
      final now = DateTime.now();
      final eventsSnap = await FirebaseFirestore.instance
          .collection('events')
          .where('orgId', isEqualTo: widget.orgId)
          .where('status', isEqualTo: 'approved')
          .get();
      DateTime? lastFinishedEventDate;
      for (final doc in eventsSnap.docs) {
        final date = (doc.data()['date'] as Timestamp?)?.toDate();
        if (date == null || !date.isBefore(now)) continue;
        if (lastFinishedEventDate == null || date.isAfter(lastFinishedEventDate)) {
          lastFinishedEventDate = date;
        }
      }

      if (lastFinishedEventDate != null) {
        final overridesSnap = await FirebaseFirestore.instance
            .collection('report_deadline_overrides')
            .where('orgId', isEqualTo: widget.orgId)
            .get();
        DateTime? financialOverride, accomplishmentOverride;
        for (final doc in overridesSnap.docs) {
          final data = doc.data();
          final deadline = (data['deadline'] as Timestamp?)?.toDate();
          if (deadline == null) continue;
          if (data['type'] == 'financial') financialOverride = deadline;
          if (data['type'] == 'accomplishment') accomplishmentOverride = deadline;
        }
        final autoDeadline = lastFinishedEventDate.add(const Duration(days: 7));
        if (mounted) {
          setState(() {
            _financialDeadline = financialOverride ?? autoDeadline;
            _accomplishmentDeadline = accomplishmentOverride ?? autoDeadline;
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _deadlinesLoaded = true);
  }

  Stream<QuerySnapshot> get _reportsStream => FirebaseFirestore.instance
      .collection('reports')
      .where('orgId', isEqualTo: widget.orgId)
      .snapshots();

  List<ReportModel> _applyFilters(List<ReportModel> raw) {
    final sorted = [...raw]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return sorted.where((r) {
      if (r.status == 'archived') return false;
      // Type filter
      if (_typeFilter != null) {
        final typeVal = _typeFilter == 'Financial' ? 'financial' : 'accomplishment';
        if (r.type != typeVal) return false;
      }
      final term = _searchController.text.trim().toLowerCase();
      if (term.isNotEmpty) {
        return r.title.toLowerCase().contains(term) ||
            r.reportId.toLowerCase().contains(term) ||
            r.description.toLowerCase().contains(term);
      }
      return true;
    }).toList();
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: StreamBuilder<QuerySnapshot>(
        stream: _reportsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          final all = (snap.data?.docs ?? [])
              .map(ReportModel.fromFirestore)
              .toList();
          final filtered = _applyFilters(all);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsRow(all),
            
              if (_deadlinesLoaded) ...[_buildDeadlineRow(all)],
              _buildToolbar(),
              const SizedBox(height: 16),
              Expanded(child: _buildTable(filtered, snap)),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(List<ReportModel> all) {
  final total = all.length;
  final financial = all.where((r) => r.type == 'financial').length;
  final accompl = all.where((r) => r.type == 'accomplishment').length;

  return Padding(
    padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
    child: Row(
      children: [
        _StatCard(
          label: 'Total Reports',
          value: '$total',
          icon: Icons.article_outlined,
          color: _DS.primary,
        ),
        const SizedBox(width: 14),
        _StatCard(
          label: 'Financial',
          value: '$financial',
          icon: Icons.account_balance_outlined,
          color: const Color(0xFF059669),
        ),
        const SizedBox(width: 14),
        _StatCard(
          label: 'Accomplishment',
          value: '$accompl',
          icon: Icons.assignment_turned_in_outlined,
          color: const Color(0xFF2563EB),
        ),
      ],
    ),
  );
}

  // ── Deadline row ───────────────────────────────────────────────────────────
  Widget _buildDeadlineRow(List<ReportModel> all) {
    DateTime? latestFinancial = all
        .where((r) => r.type == 'financial')
        .map((r) => r.submittedAt.toDate())
        .fold<DateTime?>(
          null,
          (l, d) => l == null ? d : (d.isAfter(l) ? d : l),
        );
    DateTime? latestAccompl = all
        .where((r) => r.type == 'accomplishment')
        .map((r) => r.submittedAt.toDate())
        .fold<DateTime?>(
          null,
          (l, d) => l == null ? d : (d.isAfter(l) ? d : l),
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Row(
        children: [
          _DeadlineCard(
            label: 'Financial Report Deadline',
            deadline: _financialDeadline,
            submittedOn: latestFinancial,
          ),
          const SizedBox(width: 14),
          _DeadlineCard(
            label: 'Accomplishment Report Deadline',
            deadline: _accomplishmentDeadline,
            submittedOn: latestAccompl,
          ),
        ],
      ),
    );
  }

  // ── Toolbar ────────────────────────────────────────────────────────────────
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
                  hintText: 'Search by ID, title, or description…',
                  hintStyle: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    color: const Color(0xFF9AA5B4),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF9AA5B4),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _currentPage = 1);
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
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
                    borderSide: const BorderSide(
                      color: _DS.primary,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() => _currentPage = 1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Type filter (no "All" option; placeholder shows "Type")
          _FilterDropdown(
            value: _typeFilter,
            items: const ['Financial', 'Accomplishment'],
            hint: 'Type',
            icon: Icons.category_outlined,
            onChanged: (v) => setState(() {
              _typeFilter = v;
              _currentPage = 1;
            }),
          ),
          const SizedBox(width: 10),
          _ExportButton(orgId: widget.orgId),
          const SizedBox(width: 10),
          _ToolbarButton(
            label: 'Upload Report',
            icon: Icons.upload_file_outlined,
            onPressed: _openCreateModal,
          ),
        ],
      ),
    );
  }

  // ── Table ──────────────────────────────────────────────────────────────────
  Widget _buildTable(
    List<ReportModel> filtered,
    AsyncSnapshot<QuerySnapshot> snap,
  ) {
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalPages = filtered.isEmpty
        ? 1
        : (filtered.length / _pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, filtered.length);
    final pageItems = filtered.isEmpty
        ? <ReportModel>[]
        : filtered.sublist(start, end);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        children: [
          _buildTableHeader(),
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: pageItems.length,
                    itemBuilder: (_, i) => _buildReportRow(
                      pageItems[i],
                      isLast: i == pageItems.length - 1,
                    ),
                  ),
          ),
          _buildFooter(filtered.length, totalPages, start, end),
        ],
      ),
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
    child: Row(
      children: [
        Expanded(flex: 2, child: _headerCell('REPORT ID')),
        Expanded(flex: 4, child: _headerCell('EVENT')),  // Changed from 'TITLE' to 'EVENT'
        Expanded(flex: 2, child: _headerCell('TYPE')),
        Expanded(flex: 2, child: _headerCell('DATE SUBMITTED')),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: _headerCell('ACTIONS'),
          ),
        ),
      ],
    ),
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

  
 Widget _buildReportRow(ReportModel report, {required bool isLast}) {
  final isFinancial = report.type == 'financial';
  return InkWell(
    hoverColor: const Color(0xFFF8F9FB),
    onTap: () => _openViewModal(report),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          // Report ID
          Expanded(
            flex: 2,
            child: Text(
              report.reportId,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _DS.primary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // EVENT (Title + Description)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  report.title,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A202C),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                if (report.description.isNotEmpty)
                  Text(
                    report.description,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
              ],
            ),
          ),
          // Type chip
          Expanded(
            flex: 2,
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isFinancial
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isFinancial ? 'Financial' : 'Accomplishment',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isFinancial
                        ? const Color(0xFF059669)
                        : const Color(0xFF2563EB),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          // Date
          Expanded(
            flex: 2,
            child: Text(
              DateFormat('MMM dd, yyyy').format(report.submittedAt.toDate()),
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View Details',
                  onTap: () => _openViewModal(report),
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit Report',
                  color: UpriseColors.primaryDark,
                  onTap: () => _openEditModal(report),
                ),
                const SizedBox(width: 6),
                _ActionIconButton(
                  icon: Icons.archive_outlined,
                  tooltip: 'Archive',
                  color: const Color(0xFF6B7280),
                  onTap: () => _archiveReport(report),
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
            child: const Icon(
              Icons.article_outlined,
              size: 40,
              color: Color(0xFF9AA5B4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No reports found',
            style: GoogleFonts.beVietnamPro(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters or upload a new report.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total reports',
            style: GoogleFonts.beVietnamPro(
              fontSize: 12,
              color: const Color(0xFF64748B),
            ),
          ),
          Row(
            children: [
              _PageButton(
                icon: Icons.chevron_left_rounded,
                enabled: _currentPage > 1,
                onTap: () => setState(() => _currentPage--),
              ),
              const SizedBox(width: 4),
              ...pages.map(
                (p) => _PageNumButton(
                  page: p,
                  isActive: p == _currentPage,
                  onTap: () => setState(() => _currentPage = p),
                ),
              ),
              if (lastPage < totalPages) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '…',
                    style: GoogleFonts.beVietnamPro(
                      color: const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
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
            ],
          ),
        ],
      ),
    );
  }

  // ── Actions ────────────────────────────────────────────────────────────────
  void _openCreateModal() => showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _ReportModal(orgId: widget.orgId),
  );

  void _openEditModal(ReportModel r) => showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    builder: (_) => _ReportModal(orgId: widget.orgId, existingReport: r),
  );

  void _openViewModal(ReportModel r) => showDialog(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _ViewReportModal(report: r),
  );

  Future<void> _archiveReport(ReportModel report) async {
    final ok = await _confirm(
      title: 'Archive Report',
      message: 'Archive "${report.title}"? It will be removed from the active list.',
      confirmLabel: 'Archive',
      destructive: true,
    );
    if (ok != true) return;
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .update({'status': 'archived'});
      await activity_log.ActivityLogger.log(
        action: 'archive_report',
        module: 'reports',
        details: {
          'orgId': widget.orgId,
          'reportId': report.id,
          'title': report.title,
        },
      );
      _snack('Report archived');
    } catch (e) {
      _snack('Failed to archive report: $e', error: true);
    }
  }

  Future<void> _deleteReport(ReportModel report) async {
    final ok = await _confirm(
      title: 'Delete Report',
      message: 'Delete "${report.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (ok != true) return;
    try {
      // No storage deletion needed since files are stored in Firestore
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .delete();
      await _refreshSubmissionStateAfterDelete(report.type);
      await activity_log.ActivityLogger.log(
        action: 'delete_report',
        module: 'reports',
        details: {
          'orgId': widget.orgId,
          'reportId': report.id,
          'title': report.title,
        },
      );
      _snack('Report deleted successfully');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  Future<void> _refreshSubmissionStateAfterDelete(String type) async {
    final col = FirebaseFirestore.instance.collection(
      type == 'financial'
          ? 'financial_submissions'
          : 'accomplishment_submissions',
    );
    final snap = await FirebaseFirestore.instance
        .collection('reports')
        .where('orgId', isEqualTo: widget.orgId)
        .where('type', isEqualTo: type)
        .get();
    final doc = col.doc(widget.orgId);
    if (snap.docs.isEmpty) {
      try {
        await doc.delete();
      } catch (_) {}
      return;
    }
    final latest = snap.docs.reduce((a, b) {
      final aT =
          (a.data()['submittedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bT =
          (b.data()['submittedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return aT.isAfter(bT) ? a : b;
    });
    await doc.set({
      'orgId': widget.orgId,
      'fileBase64': latest.data()['fileBase64'],
      'fileName': latest.data()['fileName'],
      'fileSize': latest.data()['fileSize'],
      'submittedAt':
          latest.data()['submittedAt'] ?? FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.beVietnamPro(color: Colors.white),
        ),
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) => showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => _ConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// View Report Modal (updated to handle base64)
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// View Report Modal (updated: removed Status, uses event proposal file viewing)
// ─────────────────────────────────────────────────────────────────────────────
class _ViewReportModal extends StatelessWidget {
  final ReportModel report;
  const _ViewReportModal({required this.report});

  // MIME type detection (copied from event proposals)
  static String _mimeFromExt(String ext) {
    switch (ext) {
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xlsx': return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFinancial = report.type == 'financial';
    final hasFile = report.fileBase64 != null && report.fileBase64!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: BoxDecoration(
                color: _DS.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.article_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Report Details',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          report.reportId,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: Colors.white.withAlpha(179),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    report.title,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Status removed here
                  Row(
                    children: [
                      Expanded(
                        child: _detailItem(
                          'Report ID',
                          report.reportId,
                          Icons.badge_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _detailItem(
                          'Type',
                          isFinancial
                              ? 'Financial Report'
                              : 'Accomplishment Report',
                          Icons.label_outlined,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _detailItem(
                          'Date Submitted',
                          DateFormat(
                            'MMM dd, yyyy',
                          ).format(report.submittedAt.toDate()),
                          Icons.calendar_today_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Empty space to keep layout balanced
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                  if (report.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _detailItem(
                      'Description',
                      report.description,
                      Icons.notes_rounded,
                    ),
                  ],
                  // File Attachment (using event proposal style)
                  if (hasFile) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E6EA)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _DS.primary.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.insert_drive_file_rounded,
                              size: 20,
                              color: _DS.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.fileName ?? 'Attached File',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (report.fileSize != null)
                                  Text(
                                    report.fileSize!,
                                    style: GoogleFonts.beVietnamPro(
                                      fontSize: 11,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _openAttachment(context),
                            icon: const Icon(Icons.open_in_new_rounded, size: 15),
                            label: const Text('Open'),
                            style: TextButton.styleFrom(
                              foregroundColor: _DS.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DS.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: const Color(0xFF9AA5B4)),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? const Color(0xFF1A202C),
          ),
        ),
      ],
    );
  }

  // ── OPEN ATTACHMENT (exact copy from event proposals) ──
  Future<void> _openAttachment(BuildContext context) async {
    final b64 = report.fileBase64;
    if (b64 == null || b64.isEmpty) return;
    try {
      final bytes = base64Decode(b64);
      final name = report.fileName ?? 'document';
      final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
      final mime = _mimeFromExt(ext);

      if (mime.startsWith('image/')) {
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    name,
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
                  ),
                ),
                Flexible(child: Image.memory(bytes)),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      } else if (mime == 'text/plain') {
        final text = utf8.decode(bytes);
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(name),
            content: SingleChildScrollView(
              child: SelectableText(text),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      } else {
        await platform_file_utils.saveBytesToTempAndOpen(bytes, name, mimeType: mime);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening attachment: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create / Edit Report Modal (base64 approach - identical to event proposals)
// ─────────────────────────────────────────────────────────────────────────────
class _ReportModal extends StatefulWidget {
  final String orgId;
  final ReportModel? existingReport;
  const _ReportModal({required this.orgId, this.existingReport});

  @override
  State<_ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends State<_ReportModal> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();

  String _type = 'financial';
  String? _fileBase64;
  String? _fileName;
  String? _fileSize;
  bool _isSubmitting = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _errorMsg;

  List<Map<String, dynamic>> _events = [];
  bool _eventsLoaded = false;
  String? _selectedEventId;

  @override
  void initState() {
    super.initState();
    final r = widget.existingReport;
    if (r != null) {
      _descCtrl.text = r.description;
      _type = r.type;
      _fileBase64 = r.fileBase64;
      _fileName = r.fileName;
      _fileSize = r.fileSize;
    }
    _loadEvents();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('orgId', isEqualTo: widget.orgId)
          .where('status', isEqualTo: 'approved')
          .orderBy('date', descending: false)
          .get();

      final List<Map<String, dynamic>> loaded = [];
      for (final doc in snap.docs) {
        final data = doc.data();
        final title = data['title']?.toString() ?? 'Untitled Event';
        final date = (data['date'] as Timestamp?)?.toDate();
        final dateStr = date != null
            ? DateFormat('MMM dd, yyyy').format(date)
            : 'No date';
        loaded.add({'id': doc.id, 'title': title, 'dateStr': dateStr});
      }
      if (mounted) {
        setState(() {
          _events = loaded;
          _eventsLoaded = true;
          if (widget.existingReport != null &&
              widget.existingReport!.eventId != null) {
            _selectedEventId = widget.existingReport!.eventId;
          } else if (widget.existingReport != null) {
            final title = widget.existingReport!.title;
            final match = _events.firstWhere(
              (e) => e['title'] == title,
              orElse: () => {},
            );
            if (match.isNotEmpty) {
              _selectedEventId = match['id'];
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _eventsLoaded = true);
        _snack('Failed to load events: $e', error: true);
      }
    }
  }

  String _submissionCollection(String type) => type == 'financial'
      ? 'financial_submissions'
      : 'accomplishment_submissions';

  Future<void> _syncSubmissionRecord(String type, String? base64, String? name, String? size) async {
    await FirebaseFirestore.instance
        .collection(_submissionCollection(type))
        .doc(widget.orgId)
        .set({
          'orgId': widget.orgId,
          'fileBase64': base64,
          'fileName': name,
          'fileSize': size,
          'submittedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // ── PICK FILE (base64 encoding, identical to event proposals) ──────────
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xlsx', 'jpg', 'png'],
      withData: true,
    );
    if (result == null) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      _snack('Cannot read file!', error: true);
      return;
    }
    const maxSize = 700 * 1024; // 700 KB limit (same as event proposals)
    if (file.bytes!.length > maxSize) {
      _snack('File too large. Max 700 KB allowed.', error: true);
      return;
    }
    final sizeKB = (file.bytes!.length / 1024).toStringAsFixed(1);
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _fileName = file.name;
      _fileSize = '$sizeKB KB';
    });
    // Simulate progress (like event proposals)
    for (int i = 0; i <= 100; i += 20) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) setState(() => _uploadProgress = i / 100);
    }
    setState(() {
      _fileBase64 = base64Encode(file.bytes!);
      _uploadProgress = 1.0;
      _isUploading = false;
    });
    _snack('File ready: ${file.name}');
  }

  void _removeFile() => setState(() {
    _fileBase64 = null;
    _fileName = null;
    _fileSize = null;
    _uploadProgress = 0.0;
  });

  Future<void> _submit() async {
    setState(() => _errorMsg = null);
    if (!_formKey.currentState!.validate()) return;

    if (_selectedEventId == null) {
      setState(() => _errorMsg = 'Please select an event');
      return;
    }

    if (_fileBase64 == null || _fileBase64!.isEmpty) {
      setState(() => _errorMsg = 'Please attach a file before submitting');
      return;
    }

    final isEdit = widget.existingReport != null;

    final dupSnap = await FirebaseFirestore.instance
        .collection('reports')
        .where('orgId', isEqualTo: widget.orgId)
        .where('eventId', isEqualTo: _selectedEventId)
        .where('type', isEqualTo: _type)
        .get();
    final hasDuplicate = dupSnap.docs.any((d) => d.id != widget.existingReport?.id);
    if (hasDuplicate) {
      setState(() => _errorMsg =
          'A ${_type == 'financial' ? 'financial' : 'accomplishment'} report has already been uploaded for that selection. Only one of each type is allowed.');
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ConfirmDialog(
        title: isEdit ? 'Save Changes' : 'Submit Report',
        message: isEdit
            ? 'Save changes to this report?'
            : 'Submit this report?',
        confirmLabel: 'Confirm',
      ),
    );
    if (ok != true) return;

    final selectedEvent = _events.firstWhere(
      (e) => e['id'] == _selectedEventId,
    );
    final eventTitle = selectedEvent['title'] as String;

    setState(() => _isSubmitting = true);

    final Map<String, dynamic> data = {
      'orgId': widget.orgId,
      'title': eventTitle,
      'type': _type,
      'description': _descCtrl.text.trim(),
      'fileBase64': _fileBase64,
      'fileName': _fileName,
      'fileSize': _fileSize,
      'eventId': _selectedEventId,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      final col = FirebaseFirestore.instance.collection('reports');
      if (isEdit) {
        final oldType = widget.existingReport!.type;
        await col.doc(widget.existingReport!.id).update(data);
        await _syncSubmissionRecord(_type, _fileBase64, _fileName, _fileSize);
        if (oldType != _type) {
          final snap = await col
              .where('orgId', isEqualTo: widget.orgId)
              .where('type', isEqualTo: oldType)
              .get();
          final oldCol = FirebaseFirestore.instance.collection(
            _submissionCollection(oldType),
          );
          if (snap.docs.isEmpty) {
            try {
              await oldCol.doc(widget.orgId).delete();
            } catch (_) {}
          }
        }
        await activity_log.ActivityLogger.log(
          action: 'edit_report',
          module: 'reports',
          details: {
            'orgId': widget.orgId,
            'reportId': widget.existingReport!.id,
          },
        );
      } else {
        final snap = await col.where('orgId', isEqualTo: widget.orgId).get();
        final nextNum = (snap.docs.length + 1).toString().padLeft(3, '0');
        data['reportId'] = 'REP-$nextNum';
        data['status'] = 'pending';
        data['submittedAt'] = FieldValue.serverTimestamp();
        data['submittedBy'] = FirebaseAuth.instance.currentUser?.uid ?? '';
        await col.add(data);
        await _syncSubmissionRecord(_type, _fileBase64, _fileName, _fileSize);
        await activity_log.ActivityLogger.log(
          action: 'create_report',
          module: 'reports',
          details: {'orgId': widget.orgId, 'title': data['title']},
        );
        _notifyAdminsOfReportSubmission(eventTitle);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
        _isSubmitting = false;
      });
    }
  }

  // Fire-and-forget — admins should hear about a new submission even if
  // the org's own UI flow (closing this dialog) finishes first.
  Future<void> _notifyAdminsOfReportSubmission(String eventTitle) async {
    try {
      String orgName = widget.orgId;
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(widget.orgId)
          .get();
      if (orgDoc.exists) {
        orgName = (orgDoc.data()?['name'] ?? orgDoc.data()?['orgName'] ?? widget.orgId).toString();
      }
      final reportLabel = _type == 'financial' ? 'financial report' : 'accomplishment report';
      await NotificationService.sendToAllAdmins(
        title: 'New $reportLabel submitted',
        body: '$orgName submitted a $reportLabel for "$eventTitle".',
        type: 'report_submission',
        orgId: widget.orgId,
        data: {'orgId': widget.orgId, 'reportType': _type},
      );
    } catch (_) {}
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.beVietnamPro(color: Colors.white),
        ),
        backgroundColor: error
            ? const Color(0xFFDC2626)
            : const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingReport != null;
    final hasFile = _fileBase64 != null && _fileBase64!.isNotEmpty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        width: 520,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
              decoration: BoxDecoration(
                color: _DS.primary,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(38),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isEdit ? Icons.edit_outlined : Icons.upload_file_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Report' : 'Upload Report',
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
                      size: 20,
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(
                        'Report Details',
                        icon: Icons.article_outlined,
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Select Event *',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          _buildEventDropdown(),
                          if (_errorMsg != null &&
                              _selectedEventId == null &&
                              _errorMsg!.contains('event')) ...[
                            const SizedBox(height: 6),
                            Text(
                              _errorMsg!,
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 12,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Report Type',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 13,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              _TypeCard(
                                label: 'Financial',
                                icon: Icons.account_balance_outlined,
                                selected: _type == 'financial',
                                onTap: () =>
                                    setState(() => _type = 'financial'),
                              ),
                              const SizedBox(width: 10),
                              _TypeCard(
                                label: 'Accomplishment',
                                icon: Icons.assignment_turned_in_outlined,
                                selected: _type == 'accomplishment',
                                onTap: () =>
                                    setState(() => _type = 'accomplishment'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descCtrl,
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        decoration: _DS.inputDecoration(
                          'Description',
                          hint: 'Brief description of this report…',
                          icon: Icons.notes_rounded,
                          maxLines: 3,
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),
                      _sectionLabel(
                        'File Attachment *',
                        icon: Icons.attach_file_rounded,
                      ),
                      _buildFileZone(hasFile),
                      if (_errorMsg != null &&
                          !_errorMsg!.contains('event')) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 15,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMsg!,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 12,
                                    color: const Color(0xFF991B1B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
                color: Color(0xFFF8F9FB),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 11,
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        color: const Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting || _isUploading || !_eventsLoaded
                        ? null
                        : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            isEdit
                                ? Icons.save_rounded
                                : Icons.upload_file_outlined,
                            size: 16,
                          ),
                    label: Text(
                      isEdit ? 'Save Changes' : 'Submit Report',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _DS.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 11,
                      ),
                      disabledBackgroundColor: _DS.primary.withAlpha(128),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventDropdown() {
    if (!_eventsLoaded) {
      return const SizedBox(
        height: 48,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'No approved events found. Please create an event first.',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  color: Color(0xFF991B1B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedEventId,
        isExpanded: true,
        decoration: InputDecoration(
          prefixIcon: const Icon(
            Icons.event_rounded,
            size: 18,
            color: Color(0xFF9AA5B4),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        hint: Text(
          'Select an approved event',
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            color: const Color(0xFF9AA5B4),
          ),
        ),
        // FIX for "RenderFlex overflowed by 11 pixels on the bottom":
        // the closed field now shows a single-line title only. The full
        // two-line (title + date) layout still shows in the open menu via
        // `items` below — this is exactly what selectedItemBuilder is for.
        selectedItemBuilder: (context) => _events
            .map(
              (event) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  event['title'] as String,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        items: _events.map((event) {
          return DropdownMenuItem<String>(
            value: event['id'] as String,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  event['title'] as String,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  event['dateStr'] as String,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 10,
                    color: const Color(0xFF9AA5B4),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) => setState(() {
          _selectedEventId = value;
          if (_errorMsg != null && _errorMsg!.contains('event')) {
            _errorMsg = null;
          }
        }),
        validator: (value) => value == null ? 'Please select an event' : null,
      ),
    );
  }

  Widget _buildFileZone(bool hasFile) {
    if (_isUploading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _DS.primary.withAlpha(102), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insert_drive_file_outlined,
                  size: 16,
                  color: _DS.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _fileName ?? 'Uploading...',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF1A202C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_fileSize != null)
                  Text(
                    _fileSize!,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      color: const Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E6EA),
                valueColor: AlwaysStoppedAnimation<Color>(_DS.primary),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Processing ${(_uploadProgress * 100).toInt()}%',
              style: GoogleFonts.beVietnamPro(
                fontSize: 10,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    if (hasFile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF059669), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFF059669).withAlpha(26),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF059669),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _fileName ?? 'File attached',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF065F46),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_fileSize != null)
                    Text(
                      _fileSize!,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: const Color(0xFF059669),
                      ),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: _removeFile,
              child: Text(
                'Remove',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: const Color(0xFFDC2626),
                ),
              ),
            ),
            TextButton(
              onPressed: _pickFile,
              child: Text(
                'Change',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: _DS.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E6EA)),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _DS.primary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.cloud_upload_rounded,
                size: 24,
                color: _DS.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text.rich(
              TextSpan(
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
                children: [
                  TextSpan(
                    text: 'Click to browse ',
                    style: GoogleFonts.beVietnamPro(
                      fontWeight: FontWeight.w600,
                      color: _DS.primary,
                    ),
                  ),
                  const TextSpan(text: 'or drop your file here'),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, DOC, DOCX, XLSX, JPG, PNG — max 700 KB',
              style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                color: const Color(0xFF9AA5B4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Type selector card (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _DS.primaryBg : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _DS.primary : const Color(0xFFE2E6EA),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? _DS.primary : const Color(0xFF9AA5B4),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? _DS.primary : const Color(0xFF64748B),
                ),
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: _DS.primary,
              ),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Countdown card (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _CountdownCard extends StatelessWidget {
  final Duration remaining;
  final DateTime eventDate;
  final String eventLabel;
  const _CountdownCard({
    required this.remaining,
    required this.eventDate,
    required this.eventLabel,
  });

  @override
  Widget build(BuildContext context) {
    final expired = remaining == Duration.zero;
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _DS.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timer_outlined,
              color: _DS.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expired
                    ? '$eventLabel has started!'
                    : 'Countdown to: $eventLabel',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
              Text(
                DateFormat('MMMM d, yyyy — h:mm a').format(eventDate),
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!expired)
            Row(
              children: [
                _CountUnit(value: d, label: 'DAYS'),
                _Colon(),
                _CountUnit(value: h, label: 'HRS'),
                _Colon(),
                _CountUnit(value: m, label: 'MIN'),
                _Colon(),
                _CountUnit(value: s, label: 'SEC'),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Event Started!',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF059669),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        width: 48,
        height: 42,
        decoration: BoxDecoration(
          color: _DS.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          value.toString().padLeft(2, '0'),
          style: GoogleFonts.beVietnamPro(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 9,
          color: const Color(0xFF64748B),
          letterSpacing: 0.5,
        ),
      ),
    ],
  );
}

class _Colon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      ':',
      style: GoogleFonts.beVietnamPro(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _DS.primary,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Deadline card (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _DeadlineCard extends StatelessWidget {
  final String label;
  final DateTime? deadline;
  final DateTime? submittedOn;
  const _DeadlineCard({required this.label, this.deadline, this.submittedOn});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final deadlineText = deadline != null
        ? DateFormat('MMM d, yyyy').format(deadline!)
        : 'No finished event yet';
    final submittedText = submittedOn != null
        ? DateFormat('MMM d, yyyy').format(submittedOn!)
        : 'Not submitted yet';
    final status = submittedOn != null
        ? (deadline != null && submittedOn!.isAfter(deadline!)
              ? 'Submitted late'
              : 'Submitted on time')
        : (deadline != null && now.isAfter(deadline!)
              ? 'Overdue'
              : 'Pending submission');
    final statusColor = submittedOn != null
        ? (deadline != null && submittedOn!.isAfter(deadline!)
              ? const Color(0xFFDC2626)
              : const Color(0xFF059669))
        : (deadline != null && now.isAfter(deadline!)
              ? const Color(0xFFDC2626)
              : const Color(0xFFFB923C));

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.event_outlined, color: statusColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Deadline: $deadlineText',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    'Last upload: $submittedText',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(26),
                borderRadius: BorderRadius.circular(_DS.radiusPill),
              ),
              child: Text(
                status,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Confirm dialog (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    child: Container(
      width: 420,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: destructive ? const Color(0xFFFEF2F2) : _DS.primaryBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  destructive
                      ? Icons.delete_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: destructive ? const Color(0xFFDC2626) : _DS.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                title,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1A202C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.beVietnamPro(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context, false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE2E6EA)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
                child: Text(
                  'Cancel',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    color: const Color(0xFF374151),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: destructive
                      ? const Color(0xFFDC2626)
                      : _DS.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 11,
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Error state (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            size: 40,
            color: Color(0xFFDC2626),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Failed to load reports',
          style: GoogleFonts.beVietnamPro(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 6),
        if (message.contains('index') ||
            message.contains('FAILED_PRECONDITION'))
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
            child: Text(
              'A Firestore composite index is missing. '
              'Check the debug console for an auto-create link.',
              textAlign: TextAlign.center,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: const Color(0xFF64748B),
              ),
            ),
          )
        else
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: Text(
            'Retry',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _DS.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Export button — uses the shared AdminExportButton so styling matches
// every other table screen (neutral gray outline, not brand orange).
// ─────────────────────────────────────────────────────────────────────────────
class _ExportButton extends StatelessWidget {
  final String orgId;
  const _ExportButton({required this.orgId});

  @override
  Widget build(BuildContext context) {
    return AdminExportButton(
      label: 'Export',
      onSelected: (choice) => _doExport(context, choice),
    );
  }

  Future<void> _doExport(BuildContext ctx, String format) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('reports')
          .where('orgId', isEqualTo: orgId)
          .get();
      final rows = snap.docs.map(ReportModel.fromFirestore).toList()
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      if (rows.isEmpty) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(
            content: Text(
              'No reports to export.',
              style: GoogleFonts.beVietnamPro(),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
        return;
      }

      final headers = [
        'Report ID',
        'Title',
        'Type',
        'Date Submitted',
        'Status',
      ];
      final dataRows = rows
          .map(
            (r) => [
              r.reportId,
              r.title,
              r.type == 'financial' ? 'Financial' : 'Accomplishment',
              DateFormat('yyyy-MM-dd').format(r.submittedAt.toDate()),
              r.status,
            ],
          )
          .toList();

      final now = DateTime.now().toString().substring(0, 10);
      if (format == 'csv') {
        final csv = [headers, ...dataRows]
            .map(
              (row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(','),
            )
            .join('\n');
        await OrgExportUtil.saveText(
          csv,
          'reports_$now.csv',
          mimeType: 'text/csv',
        );
      } else {
        final pdfBytes = await OrgExportPdf.generateTablePdf(
          title: 'Reports',
          headers: headers,
          rows: dataRows,
        );
        await OrgExportUtil.saveBytes(
          pdfBytes,
          'reports_$now.pdf',
          mimeType: 'application/pdf',
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: $e',
            style: GoogleFonts.beVietnamPro(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets (unchanged)
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
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  final String? value; // now nullable, no "All" option
  final List<String> items;
  final String hint;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({
    this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFE2E6EA)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, // null allowed
        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 18,
          color: Color(0xFF9AA5B4),
        ),
        style: GoogleFonts.beVietnamPro(
          fontSize: 13,
          color: const Color(0xFF374151),
        ),
        hint: Text(
          hint,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            color: const Color(0xFF9AA5B4),
          ),
        ),
        items: items
            .map(
              (s) => DropdownMenuItem(
                value: s,
                child: Text(s, style: GoogleFonts.beVietnamPro(fontSize: 13)),
              ),
            )
            .toList(),
        onChanged: onChanged,
        borderRadius: BorderRadius.circular(10),
        dropdownColor: Colors.white,
      ),
    ),
  );
}

class _ToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon, size: 15),
    label: Text(
      label,
      style: GoogleFonts.beVietnamPro(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: UpriseColors.primaryDark,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0,
    ),
  );
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
    final fg = onTap == null ? const Color(0xFFD1D5DB) : (color ?? const Color(0xFF3B82F6));
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
  const _PageButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: enabled ? onTap : null,
    borderRadius: BorderRadius.circular(6),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Icon(
        icon,
        size: 20,
        color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
      ),
    ),
  );
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
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? _DS.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$page',
        style: GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
          color: isActive ? Colors.white : const Color(0xFF374151),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Report Model (updated with base64 fields)
// ─────────────────────────────────────────────────────────────────────────────
class ReportModel {
  final String id;
  final String reportId;
  final String title;
  final String type;
  final String description;
  final String? fileBase64;   // base64 encoded file data
  final String? fileName;     // original file name
  final String? fileSize;     // formatted size (e.g., "123.4 KB")
  final String status;
  final Timestamp submittedAt;
  final String submittedBy;
  final String? eventId;

  const ReportModel({
    required this.id,
    required this.reportId,
    required this.title,
    required this.type,
    required this.description,
    this.fileBase64,
    this.fileName,
    this.fileSize,
    required this.status,
    required this.submittedAt,
    required this.submittedBy,
    this.eventId,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id: doc.id,
      reportId:
          d['reportId'] as String? ??
          'REP-${doc.id.substring(0, 6).toUpperCase()}',
      title: d['title'] as String? ?? '',
      type: d['type'] as String? ?? 'financial',
      description: d['description'] as String? ?? '',
      fileBase64: d['fileBase64'] as String?,
      fileName: d['fileName'] as String?,
      fileSize: d['fileSize'] as String?,
      status: d['status'] as String? ?? 'pending',
      submittedAt: d['submittedAt'] as Timestamp? ?? Timestamp.now(),
      submittedBy: d['submittedBy'] as String? ?? '',
      eventId: d['eventId'] as String?,
    );
  }
}