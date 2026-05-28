// ignore_for_file: unused_field, duplicate_ignore, use_build_context_synchronously, deprecated_member_use
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import '../admin/export_pdf.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../theme/app_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — mirrors student_accounts.dart / org_event_proposals.dart
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
// Attendance status badge — mirrors _statusBadge pattern
// ─────────────────────────────────────────────────────────────────────────────
class _BadgeStyle {
  final Color bg, fg;
  final String label;
  const _BadgeStyle(this.bg, this.fg, this.label);
}

Widget _attendanceBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'present': _BadgeStyle(const Color(0xFFECFDF5), const Color(0xFF059669), 'PRESENT'),
    'late':    _BadgeStyle(const Color(0xFFFFFBEB), const Color(0xFFD97706), 'LATE'),
    'absent':  _BadgeStyle(const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'ABSENT'),
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
// Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class OrgAttendanceQRScreen extends StatefulWidget {
  final String orgId;
  const OrgAttendanceQRScreen({super.key, required this.orgId});

  @override
  State<OrgAttendanceQRScreen> createState() => _OrgAttendanceQRScreenState();
}

class _OrgAttendanceQRScreenState extends State<OrgAttendanceQRScreen> {
  String? _selectedEventId;
  EventModel? _selectedEvent;
  String? _selectedEventDocId; // event document id in `events` collection (createdFromProposalId)

  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _searchController    = TextEditingController();

  bool   _isScanning     = true;
  String _lastScannedCode = '';
  String _searchQuery    = '';
  String _statusFilter   = 'All';

  @override
  void dispose() {
    _scannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Streams ──────────────────────────────────────────────────────────────
    Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('date', descending: false)
      .snapshots();

    Stream<QuerySnapshot>? get _attendanceStream => _selectedEventDocId != null
      ? FirebaseFirestore.instance
        .collection('events')
        .doc(_selectedEventDocId)
        .collection('attendances')
        .orderBy('timestamp', descending: true)
        .snapshots()
      : null;

  // ── QR scan handler ───────────────────────────────────────────────────────
  Future<void> _onScanComplete(BarcodeCapture capture) async {
    if (!_isScanning || _selectedEventId == null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastScannedCode) return;
    _lastScannedCode = code;
    setState(() => _isScanning = false);

    try {
      // Check event active state (manual or time-based)
      if (_selectedEventDocId == null) throw Exception('Event record not created yet');
      final eventDoc = await FirebaseFirestore.instance.collection('events').doc(_selectedEventDocId).get();
      if (!eventDoc.exists) throw Exception('Selected event not found');
      if (!_computeEventActiveFromDoc(eventDoc)) {
        // Determine if event already ended to give clearer message
        final data = eventDoc.data() as Map<String, dynamic>?;
        var msg = 'Event is not active. Start the event to allow scanning.';
        try {
          final dateTs = data?['date'] as Timestamp?;
          final startStr = data?['startTime'] as String? ?? '';
          final endStr = data?['endTime'] as String? ?? '';
          if (dateTs != null) {
            final date = dateTs.toDate();
            final start = DateFormat.jm().parse(startStr);
            final end = DateFormat.jm().parse(endStr);
            final startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
            var endDt = DateTime(date.year, date.month, date.day, end.hour, end.minute);
            if (endDt.isBefore(startDt)) endDt = endDt.add(const Duration(days: 1));
            if (DateTime.now().isAfter(endDt)) msg = 'Event already ended. Attendance is read-only.';
          }
        } catch (_) {}
        throw Exception(msg);
      }
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(code).get();
      if (!userDoc.exists) throw Exception('Student not found');
      final studentData = userDoc.data()!;
      if (studentData['orgId'] != widget.orgId) {
        throw Exception('Student not part of this organization');
      }
      final existing = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendances')
          .where('studentId', isEqualTo: code)
          .get();
      if (existing.docs.isNotEmpty) throw Exception('Student already marked present');

      await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendances')
          .add({
        'studentId':    code,
        'studentName':  studentData['name'] ?? studentData['email'] ?? 'Unknown',
        'studentEmail': studentData['email'] ?? '',
        'program':      studentData['program'] ?? 'N/A',
        'timestamp':    FieldValue.serverTimestamp(),
        'status':       'present',
      });

      await activity_log.ActivityLogger.log(
        action: 'scan_attendance',
        module: 'attendance_qr',
        details: {'orgId': widget.orgId, 'eventId': _selectedEventId, 'studentId': code},
      );

      if (mounted) _showToast('${studentData['name'] ?? 'Student'} marked present ✓', isError: false);
    } catch (e) {
      if (mounted) _showToast(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      setState(() => _isScanning = true);
      await Future.delayed(const Duration(seconds: 2));
      _lastScannedCode = '';
    }
  }

  void _showToast(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.beVietnamPro(color: Colors.white)),
      backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 3),
    ));
  }

  // Determine active state from event document or time range
  bool _computeEventActiveFromDoc(DocumentSnapshot? doc) {
    if (doc == null || !doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;
    if (data['isActive'] == true) return true;
    try {
      final dateTs = data['date'] as Timestamp?;
      final startStr = data['startTime'] as String? ?? '';
      final endStr = data['endTime'] as String? ?? '';
      if (dateTs == null || startStr.isEmpty || endStr.isEmpty) return false;
      final date = dateTs.toDate();
      final start = DateFormat.jm().parse(startStr);
      final end = DateFormat.jm().parse(endStr);
      final startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
      var endDt = DateTime(date.year, date.month, date.day, end.hour, end.minute);
      if (endDt.isBefore(startDt)) endDt = endDt.add(const Duration(days: 1));
      final now = DateTime.now();
      // Active if within start..end (with small grace window)
      if (now.isAfter(startDt.subtract(const Duration(minutes: 15))) && now.isBefore(endDt.add(const Duration(minutes: 15)))) {
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  // ── Export handlers ───────────────────────────────────────────────────────
  void _handleExportChoice(String choice) {
    if (_selectedEventId == null) {
      _showToast('Select an event first', isError: true);
      return;
    }
    _showExportDialog(asPdf: choice == 'pdf');
  }

  void _showExportDialog({bool asPdf = false}) {
    DateTimeRange selectedRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    final Set<String> selectedFields = {
      'Student Name', 'Student ID', 'Program/Team', 'Time In', 'Status',
    };
    const allFields = ['Student Name', 'Student ID', 'Program/Team', 'Time In', 'Time Out', 'Status'];

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Container(
            width: 460,
            constraints: const BoxConstraints(maxHeight: 520),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header — amber, mirrors submit modals
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
                    child: Icon(asPdf ? Icons.picture_as_pdf_outlined : Icons.download_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(
                    'Export Attendance Report${asPdf ? ' (PDF)' : ' (CSV)'}',
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                  )),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              // Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Date range section
                    _exportSectionLabel('DATE RANGE', Icons.calendar_today_outlined),
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: ctx,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialDateRange: selectedRange,
                          builder: (context, child) => Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: ColorScheme.light(primary: UpriseColors.primaryDark),
                            ),
                            child: child!,
                          ),
                        );
                        if (picked != null) setDialogState(() => selectedRange = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E6EA)),
                        ),
                        child: Row(children: [
                          Icon(Icons.date_range_rounded, size: 16, color: UpriseColors.primaryDark),
                          const SizedBox(width: 10),
                          Text(
                            '${DateFormat('MMM dd, yyyy').format(selectedRange.start)}  →  ${DateFormat('MMM dd, yyyy').format(selectedRange.end)}',
                            style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
                          ),
                          const Spacer(),
                          Icon(Icons.edit_outlined, size: 14, color: const Color(0xFF9AA5B4)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Fields section
                    _exportSectionLabel('DATA TO INCLUDE', Icons.checklist_rounded),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: allFields.map((field) {
                        final selected = selectedFields.contains(field);
                        return GestureDetector(
                          onTap: () => setDialogState(() {
                            selected ? selectedFields.remove(field) : selectedFields.add(field);
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected ? UpriseColors.primaryDark.withOpacity(0.08) : const Color(0xFFF8F9FB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected ? UpriseColors.primaryDark : const Color(0xFFE2E6EA),
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (selected) ...[
                                Icon(Icons.check_rounded, size: 13, color: UpriseColors.primaryDark),
                                const SizedBox(width: 5),
                              ],
                              Text(field,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                                    color: selected ? UpriseColors.primaryDark : const Color(0xFF374151),
                                  )),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ]),
                ),
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
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE2E6EA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: selectedFields.isEmpty ? null : () async {
                      Navigator.pop(ctx);
                      asPdf
                          ? await _doExportPdf(selectedRange, selectedFields.toList())
                          : await _doExportCsv(selectedRange, selectedFields);
                    },
                    icon: Icon(asPdf ? Icons.picture_as_pdf_outlined : Icons.download_rounded, size: 16),
                    label: Text(
                      asPdf ? 'Export PDF' : 'Export CSV',
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
        ),
      ),
    );
  }

  Widget _exportSectionLabel(String text, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Icon(icon, size: 14, color: UpriseColors.primaryDark),
        const SizedBox(width: 7),
        Text(text,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B), letterSpacing: 0.6,
            )),
        const SizedBox(width: 10),
        Expanded(child: Divider(color: const Color(0xFFE2E6EA), thickness: 1)),
      ]),
    );
  }

  Future<void> _doExportCsv(DateTimeRange range, Set<String> fields) async {
    try {
      final snapshot = await _fetchAttendanceInRange(range);
      final List<List<dynamic>> rows = [fields.toList()];
      for (final doc in snapshot.docs) {
        rows.add(_buildRow(doc.data() as Map<String, dynamic>, fields.toList()));
      }
      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final fileName = 'attendance_${(_selectedEvent?.title ?? 'export').replaceAll(' ', '_')}';
      await FileSaver.instance.saveAs(name: fileName, bytes: bytes, file: 'csv', mimeType: MimeType.csv);
      if (mounted) _showToast('CSV export successful! (${snapshot.docs.length} records)', isError: false);
      await activity_log.ActivityLogger.log(
        action: 'export_attendance', module: 'attendance_qr',
        details: {'orgId': widget.orgId, 'eventId': _selectedEventId, 'format': 'CSV'},
      );
    } catch (e) {
      if (mounted) _showToast('Export failed: $e', isError: true);
    }
  }

  Future<void> _doExportPdf(DateTimeRange range, List<String> headers) async {
    try {
      final snapshot = await _fetchAttendanceInRange(range);
      final rows = snapshot.docs
          .map((doc) => _buildRow(doc.data() as Map<String, dynamic>, headers).map((e) => e.toString()).toList())
          .toList();
      final pdfBytes = await AdminExportPdf.generateTablePdf(
        title: _selectedEvent?.title ?? 'Attendance Report',
        headers: headers,
        rows: rows,
      );
      final fileName = 'attendance_${(_selectedEvent?.title ?? 'export').replaceAll(' ', '_')}';
      await FileSaver.instance.saveAs(name: fileName, bytes: pdfBytes, file: 'pdf', mimeType: MimeType.pdf);
      if (mounted) _showToast('PDF export successful!', isError: false);
    } catch (e) {
      if (mounted) _showToast('PDF export failed: $e', isError: true);
    }
  }

  Future<QuerySnapshot> _fetchAttendanceInRange(DateTimeRange range) {
    return FirebaseFirestore.instance
      .collection('events')
      .doc(_selectedEventDocId)
        .collection('attendances')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(range.start))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(range.end.add(const Duration(days: 1))))
        .orderBy('timestamp', descending: false)
        .get();
  }

  List<dynamic> _buildRow(Map<String, dynamic> data, List<String> fields) {
    return fields.map((f) {
      switch (f) {
        case 'Student Name':   return data['studentName'] ?? '';
        case 'Student ID':     return data['studentId'] ?? '';
        case 'Program/Team':   return data['program'] ?? '';
        case 'Time In':
          final ts = data['timestamp'] as Timestamp?;
          return ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : '';
        case 'Time Out':       return '';
        case 'Status':         return data['status'] ?? 'present';
        default:               return '';
      }
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildToolbar(),
                  const SizedBox(height: 20),
                  // Summary cards moved to top to match other admin pages
                  _buildAttendanceSummaryRow(),
                  const SizedBox(height: 14),
                  _buildEventSelector(),
                  const SizedBox(height: 14),
                  if (_selectedEvent != null) ...[
                    _buildEventInfoBanner(),
                    const SizedBox(height: 20),
                    SizedBox(height: constraints.maxHeight - 250, child: _buildMainContent()),
                  ] else
                    SizedBox(height: constraints.maxHeight - 120, child: _buildEmptyState()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Row(children: [
      Expanded(
        child: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.beVietnamPro(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by name or student ID…',
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
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),
      ),
      const SizedBox(width: 10),
      _FilterDropdown(
        value: _statusFilter,
        items: const ['All', 'present', 'late', 'absent'],
        onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
      ),
      const SizedBox(width: 10),
      AdminExportButton(onSelected: _handleExportChoice),
      const SizedBox(width: 10),
      // Start / End event control — reads event doc to decide state
      StreamBuilder<DocumentSnapshot>(
      stream: _selectedEventDocId != null
        ? FirebaseFirestore.instance.collection('events').doc(_selectedEventDocId).snapshots()
        : null,
        builder: (context, snap) {
          final doc = snap.data;
          final active = _computeEventActiveFromDoc(doc);
          return SizedBox(
            height: 40,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: active ? const Color(0xFFDC2626) : UpriseColors.primaryDark,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _selectedEventId == null
                  ? null
                  : () async {
                      if (_selectedEventId == null) return;
                      try {
                        if (active) {
                            if (_selectedEventDocId == null) throw Exception('Event record not created yet');
                            await FirebaseFirestore.instance.collection('events').doc(_selectedEventDocId).update({
                            'isActive': false,
                            'endedAt': FieldValue.serverTimestamp(),
                          });
                          _showToast('Event ended; scanning disabled', isError: false);
                        } else {
                          if (_selectedEventDocId == null) throw Exception('Event record not created yet');
                          await FirebaseFirestore.instance.collection('events').doc(_selectedEventDocId).update({
                            'isActive': true,
                            'startedAt': FieldValue.serverTimestamp(),
                          });
                          _showToast('Event started; scanning enabled', isError: false);
                        }
                      } catch (e) {
                        _showToast('Failed to update event state', isError: true);
                      }
                    },
              child: Text(active ? 'End Event' : 'Start Event', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          );
        },
      ),
    ]);
  }

  // ── Event Selector ────────────────────────────────────────────────────────
  Widget _buildEventSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: UpriseColors.primaryDark.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.event_outlined, size: 18, color: UpriseColors.primaryDark),
        ),
        const SizedBox(width: 12),
        Text('Event',
            style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B), letterSpacing: 0.5,
            )),
        const SizedBox(width: 12),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _eventsStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return SizedBox(
                  height: 20,
                  child: LinearProgressIndicator(
                    color: UpriseColors.primaryDark,
                    backgroundColor: const Color(0xFFE2E6EA),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Text('No events found for this organization',
                    style: GoogleFonts.beVietnamPro(color: const Color(0xFFDC2626), fontSize: 13));
              }
              final events = snapshot.data!.docs.map((doc) => EventModel.fromFirestore(doc)).toList();
              if (_selectedEventId == null && events.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() { _selectedEventId = events.first.id; _selectedEvent = events.first; });
                });
              }
              return DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedEventId,
                  hint: Text('Choose an event', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4))),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF9AA5B4), size: 20),
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
                  items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title))).toList(),
                      onChanged: (v) async {
                        if (v == null) return;
                        setState(() {
                          _selectedEventId = v;
                          _selectedEvent = events.firstWhere((e) => e.id == v);
                          _selectedEventDocId = null; // reset until resolved
                        });

                        // Try to resolve a corresponding event document created from this proposal
                        try {
                          final evQ = await FirebaseFirestore.instance
                              .collection('events')
                              .where('createdFromProposalId', isEqualTo: v)
                              .limit(1)
                              .get();
                          if (evQ.docs.isNotEmpty) {
                            final evDoc = evQ.docs.first;
                            if (mounted) {
                              setState(() {
                              _selectedEventDocId = evDoc.id;
                              _selectedEvent = EventModel.fromFirestore(evDoc);
                            });
                            }
                          } else {
                            // no event created yet from proposal; leave _selectedEventDocId null
                            if (mounted) setState(() => _selectedEventDocId = null);
                          }
                        } catch (_) {
                          // ignore resolution errors and leave attendance disabled
                        }
                      },
                ),
              );
            },
          ),
        ),
      ]),
    );
  }

  // ── Event Info Banner ─────────────────────────────────────────────────────
  Widget _buildEventInfoBanner() {
    final event = _selectedEvent!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(children: [
        _infoBannerCell('LOCATION',   event.location),
        _divider(),
        _infoBannerCell('DATE',       DateFormat('MMM dd, yyyy').format(event.date)),
        _divider(),
        _infoBannerCell('START TIME', event.startTime),
        _divider(),
        _infoBannerCell('END TIME',   event.endTime),
        _divider(),
        _infoBannerCell('CAPACITY',   event.capacity > 0 ? '${event.capacity} seats' : 'Unlimited'),
      ]),
    );
  }

  Widget _infoBannerCell(String label, String value) {
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B), letterSpacing: 0.4,
            )),
        const SizedBox(height: 3),
        Text(value,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13, fontWeight: FontWeight.w600,
              color: const Color(0xFF1A202C),
            )),
      ]),
    );
  }

  Widget _divider() => Container(
    width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 16),
    color: const Color(0xFFE8ECF0),
  );

  // ── Main Content ──────────────────────────────────────────────────────────
  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left — QR scanner + table
        Expanded(
          flex: 3,
          child: Column(children: [
            _buildQRScannerCard(),
            const SizedBox(height: 14),
            Expanded(child: _buildAttendanceTable()),
          ]),
        ),
        const SizedBox(width: 16),
        // Right — stats + chart + breakdown
        SizedBox(
          width: 290,
          child: SingleChildScrollView(child: Column(children: [
            _buildStatsCard(),
            const SizedBox(height: 14),
            _buildChartCard(),
            const SizedBox(height: 14),
            _buildStatusBreakdownCard(),
          ])),
        ),
      ],
    );
  }

  // ── QR Scanner Card ───────────────────────────────────────────────────────
  Widget _buildQRScannerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Card header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.qr_code_scanner_rounded, size: 18, color: UpriseColors.primaryDark),
            ),
            const SizedBox(width: 10),
            Text('QR Scanner',
                style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
            const Spacer(),
            // Scanning status pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _isScanning ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: _isScanning ? const Color(0xFF059669) : const Color(0xFF9AA5B4),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _isScanning ? 'Ready' : 'Paused',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: _isScanning ? const Color(0xFF059669) : const Color(0xFF6B7280),
                  ),
                ),
              ]),
            ),
          ]),
        ),
        // Camera viewport
        Container(
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(controller: _scannerController, onDetect: _onScanComplete),
              ..._buildScanCorners(),
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.65), Colors.transparent],
                    ),
                  ),
                  child: Text(
                    _isScanning ? 'Point camera at student QR code…' : 'Processing scan…',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.beVietnamPro(color: Colors.white70, fontSize: 11),
                  ),
                ),
              ),
            ]),
          ),
        ),
        // Scanner mode toggle
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            Text('Scanner Mode',
                style: GoogleFonts.beVietnamPro(
                  fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFF374151),
                )),
            const Spacer(),
            Switch(
              value: _isScanning,
              onChanged: (v) => setState(() => _isScanning = v),
              activeColor: UpriseColors.primaryDark,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _buildScanCorners() {
    const double sz = 22, thickness = 3, inset = 38;
    const Color clr = Color(0xFFD97706);

    Widget corner({required bool top, required bool left}) => Positioned(
      top: top ? inset : null,
      bottom: top ? null : inset,
      left: left ? inset : null,
      right: left ? null : inset,
      child: Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          border: Border(
            top:    top  ? const BorderSide(color: clr, width: thickness) : BorderSide.none,
            bottom: !top ? const BorderSide(color: clr, width: thickness) : BorderSide.none,
            left:   left ? const BorderSide(color: clr, width: thickness) : BorderSide.none,
            right:  !left? const BorderSide(color: clr, width: thickness) : BorderSide.none,
          ),
        ),
      ),
    );

    return [
      corner(top: true,  left: true),
      corner(top: true,  left: false),
      corner(top: false, left: true),
      corner(top: false, left: false),
    ];
  }

  // ── Attendance summary row ────────────────────────────────────────────────
  Widget _buildAttendanceSummaryRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final total   = docs.length;
        final present = docs.where((d) => (d.data() as Map)['status'] == 'present').length;
        final late    = docs.where((d) => (d.data() as Map)['status'] == 'late').length;

        return Row(children: [
          _summaryCell("Today's Total", '$total', Icons.people_outline_rounded, UpriseColors.primaryDark),
          const SizedBox(width: 12),
          _summaryCell('Present', '$present', Icons.check_circle_outline_rounded, const Color(0xFF059669)),
          const SizedBox(width: 12),
          _summaryCell('Late', '$late', Icons.schedule_rounded, const Color(0xFFD97706)),
        ]);
      },
    );
  }

  Widget _summaryCell(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 1),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
          ]),
        ]),
      ),
    );
  }

  // ── Attendance Table ──────────────────────────────────────────────────────
  Widget _buildAttendanceTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(children: [
        // Table header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: const BoxDecoration(
            color: Color(0xFFF8F9FB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
            border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: _headerCell('STUDENT NAME')),
            Expanded(flex: 2, child: _headerCell('STUDENT ID')),
            Expanded(flex: 3, child: _headerCell('PROGRAM / TEAM')),
            Expanded(flex: 2, child: _headerCell('TIME IN')),
            Expanded(flex: 2, child: _headerCell('TIME OUT')),
            Expanded(flex: 2, child: _headerCell('STATUS')),
          ]),
        ),
        // Rows
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _attendanceStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return _buildEmptyTableState();
              }

              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                if (_searchQuery.isNotEmpty) {
                  final name = (data['studentName'] ?? '').toString().toLowerCase();
                  final id   = (data['studentId'] ?? '').toString().toLowerCase();
                  if (!name.contains(_searchQuery) && !id.contains(_searchQuery)) return false;
                }
                if (_statusFilter != 'All') {
                  if ((data['status'] ?? '').toString().toLowerCase() != _statusFilter.toLowerCase()) return false;
                }
                return true;
              }).toList();

              if (docs.isEmpty) return _buildEmptyTableState(message: 'No records match your filter.');

              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  final timeIn = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '—';
                  return InkWell(
                    hoverColor: const Color(0xFFF8F9FB),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                      decoration: BoxDecoration(
                        border: i == docs.length - 1
                            ? null
                            : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(children: [
                        Expanded(flex: 3, child: Row(children: [
                          _StudentAvatar(name: data['studentName'] ?? ''),
                          const SizedBox(width: 10),
                          Expanded(child: Text(
                            data['studentName'] ?? '—',
                            style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
                            overflow: TextOverflow.ellipsis,
                          )),
                        ])),
                        Expanded(flex: 2, child: Text(
                          data['studentId'] ?? '—',
                          style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark),
                        )),
                        Expanded(flex: 3, child: Text(
                          data['program'] ?? 'N/A',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
                          overflow: TextOverflow.ellipsis,
                        )),
                        Expanded(flex: 2, child: Text(
                          timeIn,
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151)),
                        )),
                        Expanded(flex: 2, child: Text(
                          '—',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF9AA5B4)),
                        )),
                        Expanded(flex: 2, child: _attendanceBadge(data['status'] ?? 'present')),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE8ECF0))),
            color: Color(0xFFF8F9FB),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
          ),
          child: StreamBuilder<QuerySnapshot>(
            stream: _attendanceStream,
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return Row(children: [
                Text('Showing $count attendees',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
                const Spacer(),
                _FooterButton(
                  icon: Icons.download_outlined,
                  label: 'Export CSV',
                  onTap: () => _showExportDialog(asPdf: false),
                ),
                const SizedBox(width: 8),
                _FooterButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Export PDF',
                  onTap: () => _showExportDialog(asPdf: true),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  Widget _headerCell(String text) => Text(
    text,
    style: GoogleFonts.beVietnamPro(
      fontSize: 11, fontWeight: FontWeight.w700,
      color: const Color(0xFF64748B), letterSpacing: 0.7,
    ),
  );

  Widget _buildEmptyTableState({String message = 'No attendees yet. Start scanning!'}) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.qr_code_scanner_rounded, size: 32, color: Color(0xFF9AA5B4)),
        ),
        const SizedBox(height: 14),
        Text(message, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 4),
        Text('Scanned QR codes will appear here in real time.',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
      ]),
    );
  }

  // ── Right panel — Stats ───────────────────────────────────────────────────
  Widget _buildStatsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapAttendance) {
        final present = (snapAttendance.data?.docs ?? [])
            .where((d) => (d.data() as Map)['status'] == 'present')
            .length;
        return StreamBuilder<DocumentSnapshot>(
          stream: _selectedEventId != null
              ? FirebaseFirestore.instance.collection('events').doc(_selectedEventId).snapshots()
              : null,
          builder: (context, snapEvent) {
            final capacity = ((snapEvent.data?.data() as Map?)?['capacity'] as num?)?.toInt() ?? 0;
            final rate = capacity > 0 ? (present / capacity * 100) : 0.0;

            return _RightCard(
              title: 'Attendance Statistics',
              icon: Icons.bar_chart_rounded,
              child: Column(children: [
                // 2×2 stat grid
                Row(children: [
                  Expanded(child: _statCell('Total Present', '$present', const Color(0xFF059669))),
                  const SizedBox(width: 8),
                  Expanded(child: _statCell('Registered', '$capacity', const Color(0xFF2563EB))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _statCell('Rate', '${rate.toStringAsFixed(1)}%', UpriseColors.primaryDark)),
                  const SizedBox(width: 8),
                  Expanded(child: _statCell('Absent', '${(capacity - present).clamp(0, capacity)}', const Color(0xFFDC2626))),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Text('Attendance Rate', style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B))),
                  const Spacer(),
                  Text('${rate.toStringAsFixed(1)}%',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (rate / 100).clamp(0.0, 1.0),
                    minHeight: 7,
                    backgroundColor: const Color(0xFFE8ECF0),
                    valueColor: AlwaysStoppedAnimation<Color>(UpriseColors.primaryDark),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('0', style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF9AA5B4))),
                    Text('$capacity', style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF9AA5B4))),
                  ],
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _statCell(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 10, color: const Color(0xFF64748B))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }

  // ── Right panel — Chart ───────────────────────────────────────────────────
  Widget _buildChartCard() {
    return _RightCard(
      title: 'Weekly Trend',
      icon: Icons.show_chart_rounded,
      child: _AttendanceChart(eventId: _selectedEventId!),
    );
  }

  // ── Right panel — Status Breakdown ───────────────────────────────────────
  Widget _buildStatusBreakdownCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        final docs    = snapshot.data?.docs ?? [];
        final present = docs.where((d) => (d.data() as Map)['status'] == 'present').length;
        final late    = docs.where((d) => (d.data() as Map)['status'] == 'late').length;
        final absent  = docs.where((d) => (d.data() as Map)['status'] == 'absent').length;
        final total   = docs.length;

        return _RightCard(
          title: 'Status Breakdown',
          icon: Icons.donut_small_rounded,
          child: Column(children: [
            _breakdownRow('Present', present, total, const Color(0xFF059669), const Color(0xFFECFDF5)),
            const SizedBox(height: 8),
            _breakdownRow('Late',    late,    total, const Color(0xFFD97706), const Color(0xFFFFFBEB)),
            const SizedBox(height: 8),
            _breakdownRow('Absent',  absent,  total, const Color(0xFFDC2626), const Color(0xFFFEF2F2)),
          ]),
        );
      },
    );
  }

  Widget _breakdownRow(String label, int count, int total, Color color, Color bg) {
    final pct = total > 0 ? count / total : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C))),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
          child: Text('$count', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct,
          minHeight: 4,
          backgroundColor: const Color(0xFFE8ECF0),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  // ── Empty state ───────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.event_outlined, size: 40, color: Color(0xFF9AA5B4)),
        ),
        const SizedBox(height: 16),
        Text('Select an event to start scanning',
            style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        Text('Choose an event from the dropdown above.',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Right-panel card wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _RightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _RightCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: UpriseColors.primaryDark),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable widgets — mirrors student_accounts / org_event_proposals
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
          items: items.map((s) => DropdownMenuItem(
            value: s,
            child: Text(s == 'All' ? 'All Status' : s.toUpperCase(),
                style: GoogleFonts.beVietnamPro(fontSize: 13)),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FooterButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500)),
      style: OutlinedButton.styleFrom(
        foregroundColor: UpriseColors.primaryDark,
        side: BorderSide(color: UpriseColors.primaryDark.withOpacity(0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// Avatar — mirrors _StudentAvatar from student_accounts
class _StudentAvatar extends StatelessWidget {
  final String name;
  const _StudentAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts    = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(initials,
            style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark,
            )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Chart
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceChart extends StatelessWidget {
  final String eventId;
  const _AttendanceChart({required this.eventId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('events')
          .doc(eventId)
          .collection('attendances')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final Map<DateTime, int> countByDate = {};
        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final ts   = data['timestamp'] as Timestamp?;
          if (ts == null) continue;
          final d    = ts.toDate();
          final date = DateTime(d.year, d.month, d.day);
          countByDate[date] = (countByDate[date] ?? 0) + 1;
        }
        if (countByDate.isEmpty) {
          return SizedBox(
            height: 160,
            child: Center(
              child: Text('No data yet',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4))),
            ),
          );
        }
        final sortedDates = countByDate.keys.toList()..sort();
        final maxY = countByDate.values.reduce((a, b) => a > b ? a : b).toDouble();
        final spots = List.generate(sortedDates.length,
            (i) => FlSpot(i.toDouble(), countByDate[sortedDates[i]]!.toDouble()));

        return SizedBox(
          height: 160,
          child: LineChart(LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE8ECF0), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= sortedDates.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(DateFormat('dd MMM').format(sortedDates[i]),
                        style: GoogleFonts.beVietnamPro(fontSize: 9, color: const Color(0xFF9AA5B4))),
                  );
                },
              )),
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text('${v.toInt()}',
                    style: GoogleFonts.beVietnamPro(fontSize: 9, color: const Color(0xFF9AA5B4))),
              )),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: const Border(
                bottom: BorderSide(color: Color(0xFFE8ECF0)),
                left:   BorderSide(color: Color(0xFFE8ECF0)),
              ),
            ),
            minX: 0,
            maxX: (sortedDates.length - 1).toDouble(),
            minY: 0,
            maxY: maxY + 1,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: UpriseColors.primaryDark,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: UpriseColors.primaryDark,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: UpriseColors.primaryDark.withOpacity(0.08),
                ),
              ),
            ],
          )),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event Model
// ─────────────────────────────────────────────────────────────────────────────
class EventModel {
  final String id, title, description, location, startTime, endTime;
  final int capacity;
  final DateTime date;

  const EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.capacity,
    required this.startTime,
    required this.endTime,
    required this.date,
  });

  factory EventModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return EventModel(
      id:          doc.id,
      title:       d['title']       as String? ?? 'Untitled Event',
      description: d['description'] as String? ?? '',
      location:    d['location']    as String? ?? 'TBA',
      capacity:    (d['capacity']   as num?)?.toInt() ?? 0,
      startTime:   d['startTime']   as String? ?? '—',
      endTime:     d['endTime']     as String? ?? '—',
      date:        (d['date'] as Timestamp).toDate(),
    );
  }
}