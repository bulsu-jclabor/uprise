// lib/screens/web/org/org_attendance_qr.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'dart:convert';

// ─── NOTE: MobileScanner works on web via getUserMedia (Chrome/Edge).
// If you want a pure-web fallback (no camera), swap MobileScanner with
// the manual-entry widget below by setting kUseManualEntry = true.
import 'package:mobile_scanner/mobile_scanner.dart';

// ============ COLOR SCHEME ============
class OrgColors {
  static const Color primaryDark  = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent       = Color(0xFFF59E0B);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF9FAFB);
  static const Color mediumGray   = Color(0xFFE5E7EB);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF111827);
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color error        = Color(0xFFEF4444);
  static const Color info         = Color(0xFF3B82F6);
  static const Color successBg    = Color(0xFFD1FAE5);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color warningBg    = Color(0xFFFEF3C7);
}

// ============ STATUS BADGE ============
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    switch (status.toLowerCase()) {
      case 'present':
        bg = OrgColors.successBg;
        fg = const Color(0xFF065F46);
        break;
      case 'late':
        bg = OrgColors.warningBg;
        fg = const Color(0xFF92400E);
        break;
      default:
        bg = OrgColors.errorBg;
        fg = const Color(0xFF991B1B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ============ MAIN SCREEN ============
class OrgAttendanceQRScreen extends StatefulWidget {
  final String orgId;
  const OrgAttendanceQRScreen({super.key, required this.orgId});

  @override
  State<OrgAttendanceQRScreen> createState() => _OrgAttendanceQRScreenState();
}

class _OrgAttendanceQRScreenState extends State<OrgAttendanceQRScreen> {
  String? _selectedEventId;
  EventModel? _selectedEvent;
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _searchController = TextEditingController();

  bool _isScanning = true;
  String _lastScannedCode = '';
  String _searchQuery = '';

  @override
  void dispose() {
    _scannerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Streams ──────────────────────────────────────────────────────────────

  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('events')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('date', descending: false)
      .snapshots();

  Stream<QuerySnapshot>? get _attendanceStream => _selectedEventId != null
      ? FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendances')
          .orderBy('timestamp', descending: true)
          .snapshots()
      : null;

  // ── QR Scan Handler ───────────────────────────────────────────────────────

  Future<void> _onScanComplete(BarcodeCapture capture) async {
    if (!_isScanning || _selectedEventId == null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastScannedCode) return;
    _lastScannedCode = code;
    setState(() => _isScanning = false);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(code)
          .get();

      if (!userDoc.exists) throw Exception('Student not found');

      final studentData = userDoc.data()!;
      if (studentData['orgId'] != widget.orgId) {
        throw Exception('Student not part of this organization');
      }

      // Check duplicate
      final existing = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendances')
          .where('studentId', isEqualTo: code)
          .get();

      if (existing.docs.isNotEmpty) {
        throw Exception('Student already marked present');
      }

      // Record attendance
      await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendances')
          .add({
        'studentId': code,
        'studentName': studentData['name'] ?? studentData['email'] ?? 'Unknown',
        'studentEmail': studentData['email'] ?? '',
        'program': studentData['program'] ?? 'N/A',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'present',
      });

      await activity_log.ActivityLogger.log(
        action: 'scan_attendance',
        module: 'attendance_qr',
        details: {
          'orgId': widget.orgId,
          'eventId': _selectedEventId,
          'studentId': code,
        },
      );

      if (mounted) {
        _showToast('${studentData['name'] ?? 'Student'} marked present ✓', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showToast(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    } finally {
      setState(() => _isScanning = true);
      await Future.delayed(const Duration(seconds: 2));
      _lastScannedCode = '';
    }
  }

  void _showToast(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.beVietnamPro(color: OrgColors.white)),
        backgroundColor: isError ? OrgColors.error : OrgColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _exportAttendance({
    required DateTimeRange dateRange,
    required Set<String> dataFields,
  }) async {
    if (_selectedEventId == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventId)
          .collection('attendances')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(
            dateRange.end.add(const Duration(days: 1)),
          ))
          .orderBy('timestamp', descending: false)
          .get();

      final List<List<dynamic>> rows = [];
      rows.add(dataFields.toList());

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final row = <dynamic>[];
        for (final field in dataFields) {
          switch (field) {
            case 'Student Name':
              row.add(data['studentName'] ?? '');
              break;
            case 'Student ID':
              row.add(data['studentId'] ?? '');
              break;
            case 'Program/Team':
              row.add(data['program'] ?? '');
              break;
            case 'Time In':
              final ts = data['timestamp'] as Timestamp?;
              row.add(ts != null
                  ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
                  : '');
              break;
            case 'Time Out':
              row.add('');
              break;
            case 'Status':
              row.add(data['status'] ?? 'present');
              break;
          }
        }
        rows.add(row);
      }

      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final fileName = 'attendance_${(_selectedEvent?.title ?? 'export').replaceAll(' ', '_')}';

      await FileSaver.instance.saveAs(
        name: fileName,
        bytes: bytes,
        file: 'csv',
        mimeType: MimeType.csv,
      );

      if (mounted) _showToast('Export successful!', isError: false);

      await activity_log.ActivityLogger.log(
        action: 'export_attendance',
        module: 'attendance_qr',
        details: {
          'orgId': widget.orgId,
          'eventId': _selectedEventId,
          'format': 'CSV',
          'rows': snapshot.docs.length,
        },
      );
    } catch (e) {
      if (mounted) _showToast('Export failed: $e', isError: true);
    }
  }

  void _showExportDialog() {
    DateTimeRange selectedRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    final Set<String> selectedFields = {
      'Student Name',
      'Student ID',
      'Program/Team',
      'Time In',
      'Status',
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: Text(
            'Export Attendance Report',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DATE RANGE',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
                const SizedBox(height: 6),
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
                          colorScheme: const ColorScheme.light(primary: OrgColors.primaryDark),
                        ),
                        child: child!,
                      ),
                    );
                    if (picked != null) setDialogState(() => selectedRange = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: OrgColors.primaryLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 16, color: OrgColors.darkGray),
                        const SizedBox(width: 8),
                        Text(
                          '${DateFormat('MMM dd, yyyy').format(selectedRange.start)}  →  ${DateFormat('MMM dd, yyyy').format(selectedRange.end)}',
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('DATA TO INCLUDE',
                    style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.darkGray)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    'Student Name',
                    'Student ID',
                    'Program/Team',
                    'Time In',
                    'Time Out',
                    'Status',
                  ].map((field) => FilterChip(
                    label: Text(field, style: GoogleFonts.beVietnamPro(fontSize: 12)),
                    selected: selectedFields.contains(field),
                    selectedColor: OrgColors.warningBg,
                    checkmarkColor: OrgColors.primaryDark,
                    onSelected: (v) => setDialogState(() {
                      v ? selectedFields.add(field) : selectedFields.remove(field);
                    }),
                  )).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray)),
            ),
            ElevatedButton(
              onPressed: selectedFields.isEmpty
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _exportAttendance(dateRange: selectedRange, dataFields: selectedFields);
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: OrgColors.primaryDark,
                foregroundColor: OrgColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: Text('Export CSV', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildEventSelector(),
          const SizedBox(height: 16),
          if (_selectedEvent != null) _buildEventInfoBanner(),
          if (_selectedEvent != null) const SizedBox(height: 20),
          if (_selectedEvent != null)
            Expanded(child: _buildMainContent())
          else
            Expanded(child: _buildEmptyState()),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance & QR Scan',
              style: GoogleFonts.beVietnamPro(
                fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.charcoal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Scan student QR codes and track event attendance',
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray),
            ),
          ],
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: _selectedEventId != null ? _showExportDialog : null,
          icon: const Icon(Icons.download_outlined, size: 16, color: OrgColors.white),
          label: Text(
            'Export Report',
            style: GoogleFonts.beVietnamPro(color: OrgColors.white, fontWeight: FontWeight.w600, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: OrgColors.primaryDark,
            disabledBackgroundColor: OrgColors.mediumGray,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // ── Event Selector ────────────────────────────────────────────────────────

  Widget _buildEventSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(
        children: [
          Text(
            'SELECT EVENT',
            style: GoogleFonts.beVietnamPro(
              fontSize: 11, fontWeight: FontWeight.w600, color: OrgColors.charcoal,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _eventsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 20,
                    child: LinearProgressIndicator(
                      color: OrgColors.primaryLight,
                      backgroundColor: OrgColors.mediumGray,
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Text(
                    'No events found for this organization',
                    style: GoogleFonts.beVietnamPro(color: OrgColors.error, fontSize: 13),
                  );
                }
                final events = snapshot.data!.docs
                    .map((doc) => EventModel.fromFirestore(doc))
                    .toList();

                // Auto-select first event if none selected
                if (_selectedEventId == null && events.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    setState(() {
                      _selectedEventId = events.first.id;
                      _selectedEvent = events.first;
                    });
                  });
                }

                return DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedEventId,
                    hint: Text(
                      'Choose an event',
                      style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
                    ),
                    icon: const Icon(Icons.keyboard_arrow_down, color: OrgColors.darkGray, size: 20),
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal),
                    items: events.map((event) => DropdownMenuItem(
                      value: event.id,
                      child: Text(event.title),
                    )).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _selectedEventId = value;
                        _selectedEvent = events.firstWhere((e) => e.id == value);
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Event Info Banner ─────────────────────────────────────────────────────

  Widget _buildEventInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Row(
        children: [
          _infoCell('LOCATION', _selectedEvent!.location),
          const SizedBox(width: 24),
          _infoCell('START TIME', _selectedEvent!.startTime),
          const SizedBox(width: 24),
          _infoCell('END TIME', _selectedEvent!.endTime),
          const SizedBox(width: 24),
          _infoCell('DATE', DateFormat('MMM dd, yyyy').format(_selectedEvent!.date)),
        ],
      ),
    );
  }

  Widget _infoCell(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600, color: OrgColors.darkGray, letterSpacing: 0.3)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
        ],
      ),
    );
  }

  // ── Main Content (two-column layout) ─────────────────────────────────────

  Widget _buildMainContent() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left column: QR Scanner + Table
        Expanded(
          flex: 3,
          child: Column(
            children: [
              _buildQRScannerCard(),
              const SizedBox(height: 14),
              _buildTodayAttendanceCount(),
              const SizedBox(height: 14),
              Expanded(child: _buildAttendanceTable()),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Right column: Stats + Chart
        SizedBox(
          width: 280,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildStatsCard(),
                const SizedBox(height: 14),
                _buildChartCard(),
                const SizedBox(height: 14),
                _buildStatusBreakdownCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── QR Scanner Card ───────────────────────────────────────────────────────

  Widget _buildQRScannerCard() {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'QR Scanner',
              style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: OrgColors.charcoal),
            ),
          ),
          // Camera viewport
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onScanComplete,
                  ),
                  // Corner scan brackets
                  ..._buildScanCorners(),
                  // Scanning status overlay at bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Text(
                        _isScanning ? 'Scanning for QR codes...' : 'Processing...',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.beVietnamPro(
                          color: Colors.white70, fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scanner Mode toggle
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Text(
                  'Scanner Mode',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12, fontWeight: FontWeight.w500, color: OrgColors.charcoal,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _isScanning,
                  onChanged: (v) => setState(() => _isScanning = v),
                  activeColor: OrgColors.success,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isScanning ? OrgColors.successBg : OrgColors.mediumGray,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isScanning ? 'Ready to scan student IDs' : 'Scanner paused',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: _isScanning ? const Color(0xFF065F46) : OrgColors.darkGray,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScanCorners() {
    const double cornerSize = 20;
    const double cornerThickness = 3;
    const Color cornerColor = OrgColors.primaryLight;
    const double inset = 40.0;

    Widget corner({required Alignment alignment, required BorderRadius radius}) {
      return Positioned(
        top: alignment.y < 0 ? inset : null,
        bottom: alignment.y > 0 ? inset : null,
        left: alignment.x < 0 ? inset : null,
        right: alignment.x > 0 ? inset : null,
        child: Container(
          width: cornerSize,
          height: cornerSize,
          decoration: BoxDecoration(
            border: Border(
              top: alignment.y < 0
                  ? const BorderSide(color: cornerColor, width: cornerThickness)
                  : BorderSide.none,
              bottom: alignment.y > 0
                  ? const BorderSide(color: cornerColor, width: cornerThickness)
                  : BorderSide.none,
              left: alignment.x < 0
                  ? const BorderSide(color: cornerColor, width: cornerThickness)
                  : BorderSide.none,
              right: alignment.x > 0
                  ? const BorderSide(color: cornerColor, width: cornerThickness)
                  : BorderSide.none,
            ),
          ),
        ),
      );
    }

    return [
      corner(alignment: const Alignment(-1, -1), radius: const BorderRadius.only(topLeft: Radius.circular(4))),
      corner(alignment: const Alignment(1, -1), radius: const BorderRadius.only(topRight: Radius.circular(4))),
      corner(alignment: const Alignment(-1, 1), radius: const BorderRadius.only(bottomLeft: Radius.circular(4))),
      corner(alignment: const Alignment(1, 1), radius: const BorderRadius.only(bottomRight: Radius.circular(4))),
    ];
  }

  // ── Today's Attendance Count ───────────────────────────────────────────────

  Widget _buildTodayAttendanceCount() {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        final total = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: OrgColors.primaryLight),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Today's Attendance",
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                  Text(
                    '$total',
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 30, fontWeight: FontWeight.w700, color: OrgColors.charcoal, height: 1.1,
                    ),
                  ),
                  Text('Students', style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: OrgColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text('Scanned',
                        style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                    Text(
                      '$total',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 22, fontWeight: FontWeight.w700, color: OrgColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Attendance Table ──────────────────────────────────────────────────────

  Widget _buildAttendanceTable() {
    return Container(
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Text(
                  'Live Attendance List',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: OrgColors.charcoal),
                ),
                const Spacer(),
                _tableActionButton(
                  icon: Icons.download_outlined,
                  label: 'Export CSV',
                  onTap: _showExportDialog,
                ),
                const SizedBox(width: 8),
                _tableActionButton(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Export PDF',
                  onTap: _showExportDialog, // hook up PDF export separately
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by name or student ID...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.darkGray),
                prefixIcon: const Icon(Icons.search, size: 18, color: OrgColors.darkGray),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: OrgColors.primaryLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: OrgColors.primaryLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: OrgColors.primaryLight, width: 1.5),
                ),
                filled: true,
                fillColor: OrgColors.lightGray,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Column headers
          Container(
            color: OrgColors.lightGray,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _colHeader('STUDENT NAME', flex: 3),
                _colHeader('STUDENT ID', flex: 2),
                _colHeader('PROGRAM/TEAM', flex: 3),
                _colHeader('TIME IN', flex: 2),
                _colHeader('TIME OUT', flex: 2),
                _colHeader('STATUS', flex: 2),
              ],
            ),
          ),
          const Divider(height: 1, color: OrgColors.mediumGray),
          // Rows
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _attendanceStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: OrgColors.primaryLight));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_scanner, size: 40, color: OrgColors.mediumGray),
                        const SizedBox(height: 8),
                        Text('No attendees yet. Start scanning!',
                            style: GoogleFonts.beVietnamPro(color: OrgColors.darkGray, fontSize: 13)),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['studentName'] ?? '').toString().toLowerCase();
                  final id = (data['studentId'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) || id.contains(_searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final ts = data['timestamp'] as Timestamp?;
                    final timeIn = ts != null
                        ? DateFormat('hh:mm a').format(ts.toDate())
                        : '—';
                    final isEven = i % 2 == 0;

                    return Container(
                      color: isEven ? OrgColors.white : OrgColors.lightGray,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(flex: 3, child: Text(data['studentName'] ?? '—',
                              style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: OrgColors.charcoal))),
                          Expanded(flex: 2, child: Text(data['studentId'] ?? '—',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray))),
                          Expanded(flex: 3, child: Text(data['program'] ?? 'N/A',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray))),
                          Expanded(flex: 2, child: Text(timeIn,
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray))),
                          Expanded(flex: 2, child: Text('—',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: OrgColors.darkGray))),
                          Expanded(flex: 2, child: _StatusBadge(data['status'] ?? 'present')),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: OrgColors.primaryLight)),
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: _attendanceStream,
              builder: (context, snapshot) {
                final total = snapshot.data?.docs.length ?? 0;
                return Row(
                  children: [
                    Text(
                      'Showing $total attendees',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _showExportDialog,
                      icon: const Icon(Icons.download_outlined, size: 14),
                      label: Text('Download CSV Template',
                          style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w500)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: OrgColors.charcoal,
                        side: const BorderSide(color: OrgColors.primaryLight),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: OrgColors.primaryLight),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: OrgColors.charcoal),
            const SizedBox(width: 4),
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.charcoal, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _colHeader(String label, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: GoogleFonts.beVietnamPro(
          fontSize: 10, fontWeight: FontWeight.w600,
          color: OrgColors.darkGray, letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ── Right Panel: Stats Card ───────────────────────────────────────────────

  Widget _buildStatsCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        final present = snapshot.data?.docs
            .where((d) => (d.data() as Map<String, dynamic>)['status'] == 'present')
            .length ?? 0;

        return StreamBuilder<DocumentSnapshot>(
          stream: _selectedEventId != null
              ? FirebaseFirestore.instance.collection('events').doc(_selectedEventId).snapshots()
              : null,
          builder: (context, eventSnap) {
            final capacity = (eventSnap.data?.data() as Map<String, dynamic>?)?['capacity'] ?? 0;
            final rate = capacity > 0 ? (present / capacity * 100) : 0.0;

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OrgColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: OrgColors.primaryLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Attendance Statistics',
                      style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
                  const SizedBox(height: 14),
                  // Stat grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 2.0,
                    children: [
                      _statCell('Total Present', '$present', OrgColors.success),
                      _statCell('Registered', '$capacity', OrgColors.info),
                      _statCell('Rate', '${rate.toStringAsFixed(1)}%', OrgColors.primaryDark),
                      _statCell('Absent', '${(capacity - present).clamp(0, capacity)}', OrgColors.error),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Attendance Progress',
                      style: GoogleFonts.beVietnamPro(fontSize: 11, color: OrgColors.darkGray)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (rate / 100).clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: OrgColors.mediumGray,
                      valueColor: const AlwaysStoppedAnimation<Color>(OrgColors.success),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('0', style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray)),
                      Text('$capacity', style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statCell(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: OrgColors.lightGray,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 10, color: OrgColors.darkGray)),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  // ── Right Panel: Chart Card ───────────────────────────────────────────────

  Widget _buildChartCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: OrgColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OrgColors.primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly Attendance Trend',
              style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
          const SizedBox(height: 14),
          _AttendanceChart(eventId: _selectedEventId!),
        ],
      ),
    );
  }

  // ── Right Panel: Status Breakdown ─────────────────────────────────────────

  Widget _buildStatusBreakdownCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _attendanceStream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final present = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'present').length;
        final late    = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'late').length;
        final absent  = docs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'absent').length;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: OrgColors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: OrgColors.primaryLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Status Breakdown',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: OrgColors.charcoal)),
              const SizedBox(height: 12),
              _statusRow('Present', present, OrgColors.success, OrgColors.successBg, const Color(0xFF065F46)),
              const SizedBox(height: 8),
              _statusRow('Late', late, OrgColors.warning, OrgColors.warningBg, const Color(0xFF92400E)),
              const SizedBox(height: 8),
              _statusRow('Absent', absent, OrgColors.error, OrgColors.errorBg, const Color(0xFF991B1B)),
            ],
          ),
        );
      },
    );
  }

  Widget _statusRow(String label, int count, Color dot, Color badgeBg, Color badgeFg) {
    return Row(
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, color: OrgColors.charcoal)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(12)),
          child: Text('$count', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: badgeFg)),
        ),
      ],
    );
  }

  // ── Empty State ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_outlined, size: 56, color: OrgColors.mediumGray),
          const SizedBox(height: 12),
          Text(
            'Select an event to start scanning',
            style: GoogleFonts.beVietnamPro(fontSize: 15, color: OrgColors.darkGray),
          ),
        ],
      ),
    );
  }
}

// ============ ATTENDANCE CHART ============
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
            child: Center(child: CircularProgressIndicator(color: OrgColors.primaryLight)),
          );
        }

        final attendances = snapshot.data!.docs;

        // Group attendance by date
        final Map<DateTime, int> countByDate = {};
        for (final doc in attendances) {
          final data = doc.data() as Map<String, dynamic>;
          final ts = data['timestamp'] as Timestamp?;
          if (ts == null) continue;
          final d = ts.toDate();
          final date = DateTime(d.year, d.month, d.day);
          countByDate[date] = (countByDate[date] ?? 0) + 1;
        }

        if (countByDate.isEmpty) {
          return const SizedBox(
            height: 160,
            child: Center(
              child: Text('No data yet', style: TextStyle(color: OrgColors.darkGray, fontSize: 13)),
            ),
          );
        }

        final sortedDates = countByDate.keys.toList()..sort();
        final maxY = countByDate.values.reduce((a, b) => a > b ? a : b).toDouble();

        final spots = List.generate(sortedDates.length, (i) {
          return FlSpot(i.toDouble(), countByDate[sortedDates[i]]!.toDouble());
        });

        return SizedBox(
          height: 160,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: OrgColors.mediumGray,
                  strokeWidth: 0.8,
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= sortedDates.length) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat('dd MMM').format(sortedDates[i]),
                          style: GoogleFonts.beVietnamPro(fontSize: 9, color: OrgColors.darkGray),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: GoogleFonts.beVietnamPro(fontSize: 9, color: OrgColors.darkGray),
                    ),
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(
                show: true,
                border: const Border(
                  bottom: BorderSide(color: OrgColors.primaryLight),
                  left: BorderSide(color: OrgColors.primaryLight),
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
                  color: OrgColors.primaryLight,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3,
                      color: OrgColors.primaryDark,
                      strokeWidth: 0,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: OrgColors.primaryLight.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============ EVENT MODEL ============
class EventModel {
  final String id;
  final String title;
  final String description;
  final String location;
  final int capacity;
  final String startTime;
  final String endTime;
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
    final data = doc.data() as Map<String, dynamic>;
    return EventModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Event',
      description: data['description'] as String? ?? '',
      location: data['location'] as String? ?? 'TBA',
      capacity: (data['capacity'] as num?)?.toInt() ?? 0,
      startTime: data['startTime'] as String? ?? '—',
      endTime: data['endTime'] as String? ?? '—',
      date: (data['date'] as Timestamp).toDate(),
    );
  }
}



