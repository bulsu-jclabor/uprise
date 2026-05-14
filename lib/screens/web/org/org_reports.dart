// lib/screens/web/org/org_reports.dart

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ignore_for_file: use_build_context_synchronously

// ============ COLOR SCHEME ============
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color accentBg     = Color(0xFFFEF3C7);
  static const Color accentText   = Color(0xFF92400E);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF16A34A);
  static const Color successBg    = Color(0xFFDCFCE7);
  static const Color warning      = Color(0xFFB45309);
  static const Color warningBg    = Color(0xFFFEF3C7);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color info         = Color(0xFF2563EB);
  static const Color infoBg       = Color(0xFFEFF6FF);
  static const Color purple       = Color(0xFF7C3AED);
  static const Color purpleBg     = Color(0xFFF3E8FF);
  static const Color reviewColor  = Color(0xFF5B21B6);
  static const Color reviewBg     = Color(0xFFEDE9FE);
}

// ============ MAIN SCREEN ============
class OrgReportsScreen extends StatefulWidget {
  final String orgId;
  const OrgReportsScreen({super.key, required this.orgId});

  @override
  State<OrgReportsScreen> createState() => _OrgReportsScreenState();
}

class _OrgReportsScreenState extends State<OrgReportsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery  = '';
  String _typeFilter   = 'all';
  String _statusFilter = 'all';

  // Countdown — loaded dynamically from Firestore, nothing hardcoded
  Timer?    _countdownTimer;
  Duration  _remaining   = Duration.zero;
  DateTime? _eventDate;
  String    _eventLabel  = '';
  bool      _eventLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadEventDate();
  }

  /// Reads eventDate (Timestamp) and eventLabel (String) from orgs/{orgId}.
  /// If the fields don't exist, the countdown card is simply not shown.
  Future<void> _loadEventDate() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('orgs')
          .doc(widget.orgId)
          .get();

      if (doc.exists) {
        final data  = doc.data()!;
        final ts    = data['eventDate']  as Timestamp?;
        final label = data['eventLabel'] as String?;

        if (ts != null) {
          _eventDate  = ts.toDate();
          _eventLabel = (label?.isNotEmpty == true) ? label! : 'Upcoming Event';
          _updateRemaining();
          _countdownTimer = Timer.periodic(
            const Duration(seconds: 1),
            (_) => _updateRemaining(),
          );
        }
      }
    } catch (_) {
      // Silently skip — countdown is optional
    } finally {
      if (mounted) setState(() => _eventLoaded = true);
    }
  }

  void _updateRemaining() {
    if (_eventDate == null) return;
    final diff = _eventDate!.difference(DateTime.now());
    if (mounted) setState(() => _remaining = diff.isNegative ? Duration.zero : diff);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Stream ──────────────────────────────────────────────────────────────────
  // Single .where() avoids needing a composite Firestore index.
  // Sorting is done client-side (see _applyFilters).
  // If you DO create the composite index (orgId ASC + submittedAt DESC) in the
  // Firebase console, you can add .orderBy('submittedAt', descending: true)
  // back to the query and remove the sort in _applyFilters.
  Stream<QuerySnapshot> get _reportsStream => FirebaseFirestore.instance
      .collection('reports')
      .where('orgId', isEqualTo: widget.orgId)
      .snapshots();

  // ── Filtering ───────────────────────────────────────────────────────────────
  List<ReportModel> _applyFilters(List<ReportModel> raw) {
    // Client-side sort: newest first
    final sorted = [...raw]
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

    return sorted.where((r) {
      if (_typeFilter   != 'all' && r.type   != _typeFilter)   return false;
      if (_statusFilter != 'all' && r.status != _statusFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        if (!r.title.toLowerCase().contains(q) &&
            !r.reportId.toLowerCase().contains(q) &&
            !r.description.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _openCreateModal() => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReportModal(orgId: widget.orgId),
      );

  void _openEditModal(ReportModel r) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ReportModal(orgId: widget.orgId, existingReport: r),
      );

  void _openViewModal(ReportModel r) => showDialog(
        context: context,
        builder: (_) => _ViewReportModal(report: r),
      );

  Future<void> _deleteReport(ReportModel report) async {
    final ok = await _confirm(
      title:        'Delete Report',
      message:      'Delete "${report.title}"? This cannot be undone.',
      confirmLabel: 'Delete',
      destructive:  true,
    );
    if (ok != true) return;
    try {
      if (report.fileUrl?.isNotEmpty == true) {
        try {
          await FirebaseStorage.instance.refFromURL(report.fileUrl!).delete();
        } catch (_) {}
      }
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .delete();
      await activity_log.ActivityLogger.log(
        action: 'delete_report',
        module: 'reports',
        details: {'orgId': widget.orgId, 'reportId': report.id, 'title': report.title},
      );
      _snack('Report deleted successfully');
    } catch (e) {
      _snack('Error: $e', error: true);
    }
  }

  void _exportCSV(List<ReportModel> rows) {
    final lines = [
      ['Report ID', 'Title', 'Type', 'Date Submitted', 'Status'],
      ...rows.map((r) => [
            r.reportId,
            r.title,
            r.type == 'financial' ? 'Financial' : 'Accomplishment',
            DateFormat('yyyy-MM-dd').format(r.submittedAt.toDate()),
            r.status,
          ]),
    ];
    final csv = lines
        .map((row) => row.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
        .join('\n');
    // On web: use `universal_html` to trigger a download.
    // On mobile: use `share_plus` or `path_provider` to save/share.
    debugPrint(csv);
    _snack('Exported ${rows.length} report(s) to CSV');
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro(color: Colors.white)),
      backgroundColor: error ? OrgColors.error : OrgColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) =>
      showDialog<bool>(
        context: context,
        builder: (_) => _ConfirmDialog(
          title:        title,
          message:      message,
          confirmLabel: confirmLabel,
          destructive:  destructive,
        ),
      );

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<QuerySnapshot>(
        stream: _reportsStream,
        builder: (context, snap) {
          // Explicit error state
          if (snap.hasError) {
            return _ErrorState(
              message: snap.error.toString(),
              onRetry: () => setState(() {}),
            );
          }

          // Spinner only on the very first load
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = (snap.data?.docs ?? [])
              .map(ReportModel.fromFirestore)
              .toList();

          final filtered       = _applyFilters(all);
          final totalCount     = all.length;
          final financialCount = all.where((r) => r.type == 'financial').length;
          final accomplCount   = all.where((r) => r.type == 'accomplishment').length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(filtered),
              const SizedBox(height: 20),

              // Countdown — only shown when eventDate is set in Firestore
              if (_eventLoaded && _eventDate != null) ...[
                _CountdownCard(
                  remaining:  _remaining,
                  eventDate:  _eventDate!,
                  eventLabel: _eventLabel,
                ),
                const SizedBox(height: 16),
              ],

              _buildStats(totalCount, financialCount, accomplCount),
              const SizedBox(height: 16),
              Expanded(child: _buildTableCard(filtered, snap)),
            ],
          );
        },
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────────
  Widget _buildHeader(List<ReportModel> filtered) => Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Reports',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
          const SizedBox(height: 2),
          Text('Manage financial and accomplishment reports',
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
        ]),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: filtered.isEmpty ? null : () => _exportCSV(filtered),
          icon: const Icon(Icons.download_outlined, size: 16),
          label: Text('Export CSV',
              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: OrgColors.darkGray,
            side: const BorderSide(color: OrgColors.mediumGray),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton.icon(
          onPressed: _openCreateModal,
          icon: const Icon(Icons.upload_file_outlined, size: 18, color: Colors.white),
          label: Text('Upload Report',
              style: GoogleFonts.beVietnamPro(
                  color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
          style: ElevatedButton.styleFrom(
            backgroundColor: OrgColors.primaryDark,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]);

  // ── Stats ────────────────────────────────────────────────────────────────────
  Widget _buildStats(int total, int financial, int accomplishment) => Row(children: [
        _StatCard(label: 'Total Reports',          value: total,        icon: Icons.article_outlined,              iconBg: OrgColors.infoBg,    iconColor: OrgColors.info),
        const SizedBox(width: 12),
        _StatCard(label: 'Financial Reports',      value: financial,    icon: Icons.account_balance_outlined,       iconBg: OrgColors.successBg, iconColor: OrgColors.success),
        const SizedBox(width: 12),
        _StatCard(label: 'Accomplishment Reports', value: accomplishment, icon: Icons.assignment_turned_in_outlined, iconBg: OrgColors.accentBg,  iconColor: OrgColors.primaryDark),
      ]);

  // ── Table card ───────────────────────────────────────────────────────────────
  Widget _buildTableCard(List<ReportModel> filtered, AsyncSnapshot<QuerySnapshot> snap) {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.mediumGray, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('All Reports',
                style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('View and manage your submitted reports',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
            const SizedBox(height: 12),
            _buildToolbar(),
          ]),
        ),
        const SizedBox(height: 8),
        const Divider(height: 0, thickness: 0.5),
        Expanded(child: _buildTable(filtered, snap)),
      ]),
    );
  }

  // ── Toolbar ──────────────────────────────────────────────────────────────────
  Widget _buildToolbar() => Row(children: [
        SizedBox(
          width: 240, height: 36,
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.beVietnamPro(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search reports...',
              hintStyle: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
              prefixIcon: const Icon(Icons.search, size: 16, color: OrgColors.darkGray),
              filled: true,
              fillColor: OrgColors.lightGray,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close, size: 14),
                      onPressed: () => setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                      }),
                    )
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _label('Type'), const SizedBox(width: 6),
        _drop(
          value: _typeFilter,
          items: {'all': 'All', 'financial': 'Financial', 'accomplishment': 'Accomplishment'},
          onChange: (v) => setState(() => _typeFilter = v ?? 'all'),
        ),
        const SizedBox(width: 8),
        _label('Status'), const SizedBox(width: 6),
        _drop(
          value: _statusFilter,
          items: {'all': 'All', 'pending': 'Pending', 'approved': 'Approved', 'rejected': 'Rejected', 'review': 'On Review'},
          onChange: (v) => setState(() => _statusFilter = v ?? 'all'),
        ),
      ]);

  Widget _label(String t) => Text(t,
      style: GoogleFonts.beVietnamPro(
          fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray));

  Widget _drop({
    required String value,
    required Map<String, String> items,
    required ValueChanged<String?> onChange,
  }) =>
      Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: OrgColors.lightGray,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: OrgColors.mediumGray, width: 0.5),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.charcoal),
            icon: const Icon(Icons.keyboard_arrow_down, size: 16, color: OrgColors.darkGray),
            items: items.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value, style: GoogleFonts.beVietnamPro(fontSize: 12)),
                    ))
                .toList(),
            onChanged: onChange,
          ),
        ),
      );

  // ── Table ────────────────────────────────────────────────────────────────────
  Widget _buildTable(List<ReportModel> filtered, AsyncSnapshot<QuerySnapshot> snap) {
    if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    if (filtered.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open_outlined, size: 48, color: OrgColors.mediumGray),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty || _typeFilter != 'all' || _statusFilter != 'all'
                ? 'No matching reports'
                : 'No reports submitted yet',
            style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text('Try adjusting your filters or submit a new report',
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
        ]),
      );
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 20,
          headingRowHeight: 40,
          dataRowMinHeight: 52,
          dataRowMaxHeight: 64,
          headingRowColor: WidgetStateProperty.all(OrgColors.lightGray),
          dividerThickness: 0.5,
          border: const TableBorder(
              horizontalInside: BorderSide(color: OrgColors.mediumGray, width: 0.5)),
          columns: ['Report ID', 'Report Title', 'Type', 'Date Submitted', 'Status', 'Actions']
              .map((c) => DataColumn(
                    label: Text(c,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: OrgColors.darkGray,
                            letterSpacing: 0.4)),
                  ))
              .toList(),
          rows: filtered.map((r) {
            return DataRow(cells: [
              DataCell(Text(r.reportId,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray))),

              DataCell(SizedBox(
                width: 240,
                child: Text(r.title,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              )),

              DataCell(_TypeChip(type: r.type)),

              DataCell(Text(DateFormat('MMM d, yyyy').format(r.submittedAt.toDate()),
                  style: GoogleFonts.beVietnamPro(fontSize: 12))),

              DataCell(_StatusChip(status: r.status, reportId: r.id)),

              DataCell(Row(children: [
                _ActionBtn(
                  icon: Icons.visibility_outlined, label: 'View', color: OrgColors.info,
                  onTap: () => _openViewModal(r),
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.download_outlined, label: '', color: OrgColors.darkGray,
                  onTap: () {
                    if (r.fileUrl?.isNotEmpty == true) {
                      Clipboard.setData(ClipboardData(text: r.fileUrl!));
                      _snack('File URL copied to clipboard');
                    } else {
                      _snack('No file attached to this report', error: true);
                    }
                  },
                ),
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.edit_outlined, tooltip: 'Edit', color: OrgColors.primaryDark,
                  onTap: () => _openEditModal(r),
                ),
                _ActionIconButton(
                  icon: Icons.delete_outline, tooltip: 'Delete', color: OrgColors.error,
                  onTap: () => _deleteReport(r),
                ),
              ])),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ============ REUSABLE SMALL WIDGETS ============

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.error_outline, size: 48, color: OrgColors.error),
          const SizedBox(height: 12),
          Text('Failed to load reports',
              style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (message.contains('index') || message.contains('FAILED_PRECONDITION'))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
              child: Text(
                'A Firestore composite index is missing. '
                'Check the debug console for an auto-create link.',
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
              ),
            )
          else
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: OrgColors.primaryDark,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ]),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: OrgColors.mediumGray, width: 0.5),
          ),
          child: Row(children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$value',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 26, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
              Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
            ]),
          ]),
        ),
      );
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final fin = type == 'financial';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fin ? OrgColors.successBg : OrgColors.infoBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(fin ? 'Financial' : 'Accomplishment',
          style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: fin ? OrgColors.success : OrgColors.info)),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  final String reportId;
  const _StatusChip({required this.status, required this.reportId});

  static const _cfg = <String, Map<String, dynamic>>{
    'pending':  {'label': 'Pending',   'bg': OrgColors.warningBg, 'fg': OrgColors.warning},
    'approved': {'label': 'Approved',  'bg': OrgColors.successBg, 'fg': OrgColors.success},
    'rejected': {'label': 'Rejected',  'bg': OrgColors.errorBg,   'fg': OrgColors.error},
    'review':   {'label': 'On Review', 'bg': OrgColors.reviewBg,  'fg': OrgColors.reviewColor},
  };

  @override
  Widget build(BuildContext context) {
    final c = _cfg[status] ?? _cfg['pending']!;
    return PopupMenuButton<String>(
      tooltip: 'Change status',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      offset: const Offset(0, 32),
      onSelected: (s) async {
        try {
          await FirebaseFirestore.instance.collection('reports').doc(reportId).update({
            'status':    s,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
            color: c['bg'] as Color, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(c['label'] as String,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11, fontWeight: FontWeight.w700, color: c['fg'] as Color)),
          const SizedBox(width: 3),
          Icon(Icons.arrow_drop_down, size: 14, color: c['fg'] as Color),
        ]),
      ),
      itemBuilder: (_) => ['pending', 'approved', 'rejected', 'review']
          .where((s) => s != status)
          .map((s) {
            final cfg = _cfg[s]!;
            return PopupMenuItem(
              value: s,
              child: Row(children: [
                Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        color: cfg['fg'] as Color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(cfg['label'] as String,
                    style: GoogleFonts.beVietnamPro(fontSize: 13)),
              ]),
            );
          })
          .toList(),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn(
      {required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 6 : 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.4), width: 0.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(label,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 12, color: color, fontWeight: FontWeight.w500)),
            ],
          ]),
        ),
      );
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _ActionIconButton(
      {required this.icon, required this.tooltip, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 17, color: color),
          ),
        ),
      );
}

// ============ COUNTDOWN CARD ============
// Receives eventDate and eventLabel from Firestore — zero hardcoded values.
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OrgColors.mediumGray, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: const BoxDecoration(color: OrgColors.accentBg, shape: BoxShape.circle),
          child: const Icon(Icons.timer_outlined, color: OrgColors.primaryDark, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(expired ? '$eventLabel has started!' : 'Countdown to: $eventLabel',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 14, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
          Text(DateFormat('MMMM d, yyyy — h:mm a').format(eventDate),
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray)),
        ]),
        const Spacer(),
        if (!expired)
          Row(children: [
            _CountUnit(value: d, label: 'DAYS'),
            _Colon(),
            _CountUnit(value: h, label: 'HOURS'),
            _Colon(),
            _CountUnit(value: m, label: 'MINUTES'),
            _Colon(),
            _CountUnit(value: s, label: 'SECONDS'),
          ])
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
                color: OrgColors.successBg, borderRadius: BorderRadius.circular(8)),
            child: Text('Event Started!',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, fontWeight: FontWeight.w700, color: OrgColors.success)),
          ),
      ]),
    );
  }
}

class _CountUnit extends StatelessWidget {
  final int value;
  final String label;
  const _CountUnit({required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Column(children: [
        Container(
          width: 52, height: 44,
          decoration: BoxDecoration(
              color: OrgColors.primaryDark, borderRadius: BorderRadius.circular(8)),
          alignment: Alignment.center,
          child: Text(value.toString().padLeft(2, '0'),
              style: GoogleFonts.beVietnamPro(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 9, color: OrgColors.darkGray, letterSpacing: 0.5)),
      ]);
}

class _Colon extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(':',
            style: GoogleFonts.beVietnamPro(
                fontSize: 20, fontWeight: FontWeight.w700, color: OrgColors.primaryDark)),
      );
}

// ============ CONFIRM DIALOG ============
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
        backgroundColor: Colors.transparent,
        child: Container(
          width: 360,
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 24,
                  offset: const Offset(0, 8))
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                color: destructive ? OrgColors.errorBg : OrgColors.accentBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                destructive ? Icons.delete_outline : Icons.check_circle_outline,
                color: destructive ? OrgColors.error : OrgColors.primaryDark,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray)),
            const SizedBox(height: 24),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: OrgColors.mediumGray),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.beVietnamPro(
                          color: OrgColors.darkGray, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    backgroundColor: destructive ? OrgColors.error : OrgColors.primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(confirmLabel,
                      style: GoogleFonts.beVietnamPro(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          ]),
        ),
      );
}

// ============ REPORT MODAL (CREATE / EDIT) ============
class _ReportModal extends StatefulWidget {
  final String orgId;
  final ReportModel? existingReport;
  const _ReportModal({required this.orgId, this.existingReport});

  @override
  State<_ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends State<_ReportModal> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();

  String  _type             = 'financial';
  String? _fileUrl;
  String? _newFileUrl;
  String? _attachedFileName;
  bool    _isSubmitting     = false;
  bool    _isUploading      = false;

  @override
  void initState() {
    super.initState();
    final r = widget.existingReport;
    if (r != null) {
      _titleCtrl.text   = r.title;
      _descCtrl.text    = r.description;
      _type             = r.type;
      _fileUrl          = r.fileUrl;
      if (r.fileUrl?.isNotEmpty == true) _attachedFileName = 'Attached file';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xlsx', 'jpg', 'png'],
    );
    if (result == null) return;
    final file = result.files.first;
    if (file.bytes == null && file.path == null) return;
    setState(() => _isUploading = true);
    try {
      final name = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('reports/${widget.orgId}/$name');
      if (file.bytes != null) {
        await ref.putData(file.bytes!);
      } else {
        await ref.putFile(File(file.path!));
      }
      final url = await ref.getDownloadURL();
      setState(() {
        _newFileUrl       = url;
        _attachedFileName = file.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: OrgColors.error));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _clearFile() => setState(() {
        _newFileUrl       = null;
        _attachedFileName = null;
      });

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final isEdit = widget.existingReport != null;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title:        isEdit ? 'Save Changes' : 'Submit Report',
        message:      isEdit
            ? 'Save changes to this report?'
            : 'Are you sure you want to submit this report?',
        confirmLabel: 'Confirm',
      ),
    );
    if (ok != true) return;

    setState(() => _isSubmitting = true);
    final user = FirebaseAuth.instance.currentUser;

    final Map<String, dynamic> data = {
      'orgId':       widget.orgId,
      'title':       _titleCtrl.text.trim(),
      'type':        _type,
      'description': _descCtrl.text.trim(),
      'fileUrl':     _newFileUrl ?? _fileUrl,
      'updatedAt':   FieldValue.serverTimestamp(),
    };

    try {
      final col = FirebaseFirestore.instance.collection('reports');
      if (isEdit) {
        await col.doc(widget.existingReport!.id).update(data);
        await activity_log.ActivityLogger.log(
          action: 'edit_report', module: 'reports',
          details: {'orgId': widget.orgId, 'reportId': widget.existingReport!.id},
        );
      } else {
        // Generate sequential reportId based on current count
        final snap = await col.where('orgId', isEqualTo: widget.orgId).get();
        final nextNum = (snap.docs.length + 1).toString().padLeft(3, '0');
        data['reportId']    = 'REP-$nextNum';
        data['status']      = 'pending';
        data['submittedAt'] = FieldValue.serverTimestamp();
        data['submittedBy'] = user?.uid ?? '';
        await col.add(data);
        await activity_log.ActivityLogger.log(
          action: 'create_report', module: 'reports',
          details: {'orgId': widget.orgId, 'title': data['title']},
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: OrgColors.error));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText:  hint,
        labelStyle: GoogleFonts.beVietnamPro(
            fontSize: 11, fontWeight: FontWeight.w600,
            letterSpacing: 0.4, color: OrgColors.darkGray),
        hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.mediumGray),
        filled:    true,
        fillColor: OrgColors.lightGray,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: OrgColors.primaryDark, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: OrgColors.error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  @override
  Widget build(BuildContext context) {
    final isEdit  = widget.existingReport != null;
    final hasFile = _newFileUrl != null ||
        (_fileUrl?.isNotEmpty == true && _attachedFileName != null);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 8))
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              decoration: const BoxDecoration(
                color: OrgColors.lightGray,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(bottom: BorderSide(color: OrgColors.mediumGray, width: 0.5)),
              ),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: const BoxDecoration(color: OrgColors.accentBg, shape: BoxShape.circle),
                  child: const Icon(Icons.article_outlined, color: OrgColors.primaryDark, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(isEdit ? 'Edit Report' : 'Submit Report',
                        style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700)),
                    Text('Fill in all required fields',
                        style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                  ]),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, size: 18),
                  splashRadius: 18,
                ),
              ]),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  TextFormField(
                    controller: _titleCtrl,
                    style: GoogleFonts.beVietnamPro(fontSize: 13),
                    decoration: _dec('REPORT TITLE *', hint: 'e.g. Q1 2026 Financial Summary'),
                    validator: (v) =>
                        v?.trim().isEmpty == true ? 'Report title is required' : null,
                  ),
                  const SizedBox(height: 14),

                  // Type cards
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('REPORT TYPE *',
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            letterSpacing: 0.4, color: OrgColors.darkGray)),
                    const SizedBox(height: 8),
                    Row(children: [
                      _TypeCard(
                        label: 'Financial Report',
                        icon: Icons.account_balance_outlined,
                        selected: _type == 'financial',
                        onTap: () => setState(() => _type = 'financial'),
                      ),
                      const SizedBox(width: 10),
                      _TypeCard(
                        label: 'Accomplishment Report',
                        icon: Icons.assignment_turned_in_outlined,
                        selected: _type == 'accomplishment',
                        onTap: () => setState(() => _type = 'accomplishment'),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _descCtrl,
                    style: GoogleFonts.beVietnamPro(fontSize: 13),
                    decoration: _dec('DESCRIPTION', hint: 'Brief description of this report...'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 14),

                  // File upload
                  if (!hasFile)
                    InkWell(
                      onTap: _isUploading ? null : _pickAndUploadFile,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        decoration: BoxDecoration(
                          border: Border.all(color: OrgColors.mediumGray, width: 1.5),
                          borderRadius: BorderRadius.circular(8),
                          color: OrgColors.lightGray,
                        ),
                        child: Column(children: [
                          _isUploading
                              ? const SizedBox(
                                  width: 28, height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.cloud_upload_outlined,
                                  size: 34, color: OrgColors.darkGray),
                          const SizedBox(height: 8),
                          Text(_isUploading
                              ? 'Uploading...'
                              : 'Click to upload or drag and drop',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13, color: OrgColors.darkGray)),
                          const SizedBox(height: 2),
                          Text('PDF, DOC, DOCX, XLSX — Max 10MB',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 11, color: OrgColors.darkGray)),
                        ]),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: OrgColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: OrgColors.success.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.insert_drive_file_outlined,
                            color: OrgColors.success, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(_attachedFileName ?? 'File attached',
                              style: GoogleFonts.beVietnamPro(
                                  fontSize: 13,
                                  color: OrgColors.success,
                                  fontWeight: FontWeight.w500)),
                        ),
                        InkWell(
                          onTap: _clearFile,
                          child: const Icon(Icons.close, size: 16, color: OrgColors.success),
                        ),
                      ]),
                    ),
                ]),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: OrgColors.mediumGray, width: 0.5))),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: OrgColors.mediumGray),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Cancel',
                      style: GoogleFonts.beVietnamPro(
                          color: OrgColors.darkGray, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isSubmitting || _isUploading ? null : _submit,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.upload_file_outlined, size: 16, color: Colors.white),
                  label: Text(isEdit ? 'Save Changes' : 'Submit Report',
                      style: GoogleFonts.beVietnamPro(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: OrgColors.primaryDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    disabledBackgroundColor: OrgColors.primaryDark.withOpacity(0.5),
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

class _TypeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeCard(
      {required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            decoration: BoxDecoration(
              color: selected ? OrgColors.accentBg : OrgColors.lightGray,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? OrgColors.primaryDark : OrgColors.mediumGray,
                width: selected ? 1.5 : 0.5,
              ),
            ),
            child: Row(children: [
              Icon(icon,
                  size: 18,
                  color: selected ? OrgColors.primaryDark : OrgColors.darkGray),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? OrgColors.primaryDark : OrgColors.darkGray)),
              ),
              if (selected)
                const Icon(Icons.check_circle, size: 16, color: OrgColors.primaryDark),
            ]),
          ),
        ),
      );
}

// ============ VIEW REPORT MODAL ============
class _ViewReportModal extends StatelessWidget {
  final ReportModel report;
  const _ViewReportModal({required this.report});

  static const _statusCfg = <String, Map<String, dynamic>>{
    'pending':  {'label': 'Pending',   'bg': OrgColors.warningBg, 'fg': OrgColors.warning},
    'approved': {'label': 'Approved',  'bg': OrgColors.successBg, 'fg': OrgColors.success},
    'rejected': {'label': 'Rejected',  'bg': OrgColors.errorBg,   'fg': OrgColors.error},
    'review':   {'label': 'On Review', 'bg': OrgColors.reviewBg,  'fg': OrgColors.reviewColor},
  };

  @override
  Widget build(BuildContext context) {
    final sc = _statusCfg[report.status] ?? _statusCfg['pending']!;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 480,
        decoration: BoxDecoration(
          color: OrgColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            decoration: const BoxDecoration(
              color: OrgColors.lightGray,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: OrgColors.mediumGray, width: 0.5)),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: const BoxDecoration(color: OrgColors.accentBg, shape: BoxShape.circle),
                child: const Icon(Icons.article_outlined, color: OrgColors.primaryDark, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('Report Details',
                      style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, size: 18),
                splashRadius: 18,
              ),
            ]),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(report.title,
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 16, fontWeight: FontWeight.w700, color: OrgColors.charcoal)),
              const SizedBox(height: 16),
              _row('Report ID', report.reportId),
              _row('Type', report.type == 'financial' ? 'Financial Report' : 'Accomplishment Report'),
              _row('Date Submitted',
                  DateFormat('MMM d, yyyy — h:mm a').format(report.submittedAt.toDate())),
              _row('Status', '',
                  statusWidget: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                        color: sc['bg'] as Color,
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(sc['label'] as String,
                        style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: sc['fg'] as Color)),
                  )),
              if (report.description.isNotEmpty) ...[
                const Divider(height: 24, thickness: 0.5),
                Text('Description',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
                const SizedBox(height: 6),
                Text(report.description,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, color: OrgColors.charcoal, height: 1.5)),
              ],
              if (report.fileUrl?.isNotEmpty == true) ...[
                const Divider(height: 24, thickness: 0.5),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: report.fileUrl!));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File URL copied to clipboard')));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: OrgColors.infoBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: OrgColors.info.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.attach_file, size: 16, color: OrgColors.info),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('View Attachment — tap to copy URL',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 12,
                                color: OrgColors.info,
                                decoration: TextDecoration.underline)),
                      ),
                      const Icon(Icons.copy, size: 14, color: OrgColors.info),
                    ]),
                  ),
                ),
              ],
            ]),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: OrgColors.mediumGray, width: 0.5))),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: OrgColors.mediumGray),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Close',
                    style: GoogleFonts.beVietnamPro(
                        color: OrgColors.darkGray, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, {Widget? statusWidget}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
          ),
          statusWidget ??
              Expanded(
                child: Text(value,
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal)),
              ),
        ]),
      );
}

// ============ REPORT MODEL ============
class ReportModel {
  final String    id;
  final String    reportId;
  final String    title;
  final String    type;
  final String    description;
  final String?   fileUrl;
  final String    status;
  final Timestamp submittedAt;
  final String    submittedBy;

  const ReportModel({
    required this.id,
    required this.reportId,
    required this.title,
    required this.type,
    required this.description,
    this.fileUrl,
    required this.status,
    required this.submittedAt,
    required this.submittedBy,
  });

  factory ReportModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ReportModel(
      id:          doc.id,
      reportId:    d['reportId']    as String?    ?? 'REP-${doc.id.substring(0, 6).toUpperCase()}',
      title:       d['title']       as String?    ?? '',
      type:        d['type']        as String?    ?? 'financial',
      description: d['description'] as String?    ?? '',
      fileUrl:     d['fileUrl']     as String?,
      status:      d['status']      as String?    ?? 'pending',
      submittedAt: d['submittedAt'] as Timestamp? ?? Timestamp.now(),
      submittedBy: d['submittedBy'] as String?    ?? '',
    );
  }
}

