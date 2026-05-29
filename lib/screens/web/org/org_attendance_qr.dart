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
// Design tokens
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusPill = 100;

  static const Color surface     = Color(0xFFFBFCFE);
  static const Color surfaceAlt  = Color(0xFFF4F6FA);
  static const Color border      = Color(0xFFE8ECF2);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted   = Color(0xFF94A3B8);

  static const Color green       = Color(0xFF10B981);
  static const Color greenBg     = Color(0xFFECFDF5);
  static const Color amber       = Color(0xFFF59E0B);
  static const Color amberBg     = Color(0xFFFFFBEB);
  static const Color red         = Color(0xFFEF4444);
  static const Color redBg       = Color(0xFFFEF2F2);
  static const Color blue        = Color(0xFF3B82F6);
  static const Color blueBg      = Color(0xFFEFF6FF);

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static final elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 40,
      offset: const Offset(0, 16),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance status badge
// ─────────────────────────────────────────────────────────────────────────────
Widget _attendanceBadge(String status) {
  final Map<String, (Color, Color, String, IconData)> styles = {
    'present': (_DS.greenBg, _DS.green, 'PRESENT', Icons.check_circle_rounded),
    'late':    (_DS.amberBg, _DS.amber, 'LATE',    Icons.schedule_rounded),
    'absent':  (_DS.redBg,   _DS.red,   'ABSENT',  Icons.cancel_rounded),
  };
  final s = styles[status.toLowerCase()] ??
      (const Color(0xFFF3F4F6), const Color(0xFF6B7280), status.toUpperCase(), Icons.circle_outlined);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: s.$1,
      borderRadius: BorderRadius.circular(_DS.radiusPill),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(s.$4, size: 10, color: s.$2),
      const SizedBox(width: 4),
      Text(
        s.$3,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: s.$2,
          letterSpacing: 0.6,
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Event status / day info helpers
// ─────────────────────────────────────────────────────────────────────────────
enum _EventDayState { future, todayInactive, todayActive, ended, otherDay }

_EventDayState _computeEventDayState(EventModel event, {bool? isActiveOverride}) {
  final now = DateTime.now();
  final date = event.date;
  final today = DateTime(now.year, now.month, now.day);
  final eventDay = DateTime(date.year, date.month, date.day);

  if (isActiveOverride == true) return _EventDayState.todayActive;

  DateTime? startDt, endDt;
  try {
    final start = DateFormat.jm().parse(event.startTime);
    final end   = DateFormat.jm().parse(event.endTime);
    startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
    endDt   = DateTime(date.year, date.month, date.day, end.hour, end.minute);
    if (endDt.isBefore(startDt)) endDt = endDt.add(const Duration(days: 1));
  } catch (_) {}

  if (eventDay.isAfter(today)) return _EventDayState.future;
  if (eventDay.isBefore(today)) {
    if (startDt != null && endDt != null && now.isBefore(endDt.add(const Duration(minutes: 15)))) {
      return _EventDayState.todayActive;
    }
    return _EventDayState.ended;
  }


  // eventDay == today
  if (endDt != null && now.isAfter(endDt.add(const Duration(minutes: 15)))) return _EventDayState.ended;
  if (startDt != null && endDt != null &&
      now.isAfter(startDt.subtract(const Duration(minutes: 15))) &&
      now.isBefore(endDt.add(const Duration(minutes: 15)))) {
    return _EventDayState.todayActive;
  }
  return _EventDayState.todayInactive;
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

class _OrgAttendanceQRScreenState extends State<OrgAttendanceQRScreen>
    with TickerProviderStateMixin {
  String? _selectedEventId;        // proposal doc id (also used as event doc id fallback)
  EventModel? _selectedEvent;
  String? _selectedEventDocId;     // actual doc id in `events` collection
  Stream<QuerySnapshot>? _attendanceStream;
  Stream<QuerySnapshot>? _registrationStream;
  Stream<DocumentSnapshot>? _eventDocStream;
  int _attendanceTabIndex = 0;

  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _searchController    = TextEditingController();

  bool   _isScanning      = true;
  String _lastScannedCode = '';
  String _searchQuery     = '';
  String _statusFilter    = 'All';

  late AnimationController _pulseController;
  late Animation<double>   _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _showHistoryDialog() {
    DateTimeRange selectedRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 640,
            constraints: const BoxConstraints(maxHeight: 640),
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.history_rounded, size: 18, color: _DS.textMuted),
                const SizedBox(width: 10),
                Text('Attendance History', style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(onPressed: () async {
                  final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime.now(), initialDateRange: selectedRange);
                  if (picked != null) setDialogState(() => selectedRange = picked);
                }, child: Text('Change range', style: GoogleFonts.spaceGrotesk()))
              ]),
              const SizedBox(height: 12),
              Expanded(child: Builder(builder: (_) {
                if (_selectedEventDocId == null) {
                  return Center(child: Text('Event not yet synced. No attendance available.', style: GoogleFonts.spaceGrotesk(color: _DS.textMuted)));
                }
                return FutureBuilder<QuerySnapshot>(
                  future: _fetchAttendanceInRange(selectedRange),
                  builder: (ctx, snap) {
                    if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                    if (!snap.hasData || snap.data!.docs.isEmpty) return Center(child: Text('No records in this range', style: GoogleFonts.spaceGrotesk(color: _DS.textMuted)));
                    final docs = snap.data!.docs;
                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: _DS.borderLight),
                      itemBuilder: (_, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final ts = d['timestamp'] as Timestamp?;
                        final when = ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : '—';
                        return ListTile(
                          leading: _StudentAvatar(name: d['studentName'] ?? '', size: 36),
                          title: Text(d['studentName'] ?? '—', style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600)),
                          subtitle: Text('${d['studentId'] ?? ''} • ${d['program'] ?? ''} • $when', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textMuted)),
                          trailing: Text(d['status'] ?? 'present', style: GoogleFonts.spaceGrotesk(fontSize: 12)),
                        );
                      },
                    );
                  },
                );
              })),
              const SizedBox(height: 8),
              Row(children: [
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final defaultFields = {'Student Name', 'Student ID', 'Program/Team', 'Time In', 'Status'};
                    await _doExportCsv(selectedRange, defaultFields);
                  },
                  icon: const Icon(Icons.download_rounded, size: 14),
                  label: Text('Export CSV', style: GoogleFonts.spaceGrotesk()),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    final headers = ['Student Name', 'Student ID', 'Program/Team', 'Year Level', 'Time In', 'Status'];
                    await _doExportPdf(selectedRange, headers);
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                  label: Text('Export PDF', style: GoogleFonts.spaceGrotesk()),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), backgroundColor: UpriseColors.primaryDark),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close', style: GoogleFonts.spaceGrotesk())),
              ])
            ]),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _searchController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Streams ──────────────────────────────────────────────────────────────
  /// Only approved proposals, ordered by date ascending so upcoming/today appear first
  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('date', descending: false)
      .snapshots();

  void _refreshLiveStreams() {
    if (_selectedEventDocId != null) {
      _attendanceStream = FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventDocId)
          .collection('attendances')
          .orderBy('timestamp', descending: false)
          .snapshots();
      _registrationStream = FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: _selectedEventDocId)
          .snapshots();
      _eventDocStream = FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventDocId)
          .snapshots();
    } else {
      _attendanceStream = null;
      _registrationStream = null;
      _eventDocStream = null;
    }
  }

  // ── Active state helpers ──────────────────────────────────────────────────
  bool _computeEventActiveFromDoc(DocumentSnapshot? doc) {
    if (doc == null || !doc.exists) return false;
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;
    if (data['isActive'] == true) return true;
    if (_selectedEvent == null) return false;
    final state = _computeEventDayState(_selectedEvent!);
    return state == _EventDayState.todayActive;
  }

  /// Returns true only when today is the event day AND the time window is correct
  /// (or isActive flag is set). Used to gate scanning.
  bool _canScan(DocumentSnapshot? eventDoc) {
    if (_selectedEvent == null || _selectedEventDocId == null) return false;
    if (eventDoc != null && (eventDoc.data() as Map?)?['isActive'] == true) return true;
    final state = _computeEventDayState(_selectedEvent!);
    return state == _EventDayState.todayActive || state == _EventDayState.todayInactive;
  }

  // ── QR scan handler ───────────────────────────────────────────────────────
  Future<void> _onScanComplete(BarcodeCapture capture) async {
    if (!_isScanning || _selectedEventId == null) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastScannedCode) return;
    _lastScannedCode = code;
    setState(() => _isScanning = false);

    try {
      if (_selectedEventDocId == null) throw Exception('Event record not found');
      final eventDoc = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventDocId)
          .get();
      if (!eventDoc.exists) throw Exception('Event record not found');

      if (!_computeEventActiveFromDoc(eventDoc)) {
        var msg = 'Attendance scanning is not active for this event.';
        try {
          if (_selectedEvent != null) {
            final state = _computeEventDayState(_selectedEvent!);
            if (state == _EventDayState.future) {
              msg = 'This event hasn\'t started yet. Scanning opens on event day.';
            } else if (state == _EventDayState.ended) {
              msg = 'This event has already ended. Attendance is read-only.';
            }
          }
        } catch (_) {}
        throw Exception(msg);
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(code)
          .get();
      if (!userDoc.exists) throw Exception('Student not found in the system');

      final studentData = userDoc.data()!;
      if (studentData['orgId'] != widget.orgId) {
        throw Exception('This student is not part of your organization');
      }

      final existing = await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventDocId)
          .collection('attendances')
          .where('studentId', isEqualTo: code)
          .get();
      if (existing.docs.isNotEmpty) {
        throw Exception('${studentData['name'] ?? 'Student'} is already marked present');
      }

      // Determine status: present if within start time, late if after +15 min grace
      String attendanceStatus = 'present';
      try {
        if (_selectedEvent != null) {
          final date = _selectedEvent!.date;
          final start = DateFormat.jm().parse(_selectedEvent!.startTime);
          final startDt = DateTime(date.year, date.month, date.day, start.hour, start.minute);
          if (DateTime.now().isAfter(startDt.add(const Duration(minutes: 15)))) {
            attendanceStatus = 'late';
          }
        }
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('events')
          .doc(_selectedEventDocId)
          .collection('attendances')
          .add({
        'studentId':    code,
        'studentName':  studentData['name'] ?? studentData['email'] ?? 'Unknown',
        'studentEmail': studentData['email'] ?? '',
        'program':      studentData['program'] ?? 'N/A',
        'yearLevel':    studentData['yearLevel'] ?? '',
        'timestamp':    FieldValue.serverTimestamp(),
        'status':       attendanceStatus,
      });

      await activity_log.ActivityLogger.log(
        action: 'scan_attendance',
        module: 'attendance_qr',
        details: {
          'orgId': widget.orgId,
          'eventId': _selectedEventDocId,
          'studentId': code,
          'status': attendanceStatus,
        },
      );

      final emoji = attendanceStatus == 'late' ? '⏰' : '✓';
      final label = attendanceStatus == 'late' ? 'marked LATE' : 'marked PRESENT';
      if (mounted) {
        _showToast('${studentData['name'] ?? 'Student'} $label $emoji', isError: false);
      }
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
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white,
          size: 18,
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: GoogleFonts.spaceGrotesk(color: Colors.white, fontSize: 13))),
      ]),
      backgroundColor: isError ? _DS.red : _DS.green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Export handlers ───────────────────────────────────────────────────────
  void _handleExportChoice(String choice) {
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
    const allFields = [
      'Student Name', 'Student ID', 'Program/Team', 'Year Level', 'Time In', 'Status',
    ];

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
          child: Container(
            width: 480,
            constraints: const BoxConstraints(maxHeight: 540),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: _DS.elevatedShadow,
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
                decoration: BoxDecoration(
                  color: UpriseColors.primaryDark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      asPdf ? Icons.picture_as_pdf_outlined : Icons.download_rounded,
                      color: Colors.white, size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      asPdf ? 'Export as PDF' : 'Export as CSV',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white,
                      ),
                    ),
                    Text(
                      _selectedEvent?.title ?? 'Attendance Report',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ])),
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
                    _exportSectionLabel('DATE RANGE', Icons.calendar_today_outlined),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
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
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: _DS.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _DS.border),
                        ),
                        child: Row(children: [
                          Icon(Icons.date_range_rounded, size: 16, color: UpriseColors.primaryDark),
                          const SizedBox(width: 10),
                          Text(
                            '${DateFormat('MMM dd, yyyy').format(selectedRange.start)}  →  ${DateFormat('MMM dd, yyyy').format(selectedRange.end)}',
                            style: GoogleFonts.spaceGrotesk(fontSize: 13, color: _DS.textPrimary),
                          ),
                          const Spacer(),
                          const Icon(Icons.edit_outlined, size: 14, color: _DS.textMuted),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _exportSectionLabel('FIELDS TO INCLUDE', Icons.checklist_rounded),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: allFields.map((field) {
                        final selected = selectedFields.contains(field);
                        return GestureDetector(
                          onTap: () => setDialogState(() {
                            selected ? selectedFields.remove(field) : selectedFields.add(field);
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected
                                  ? UpriseColors.primaryDark.withOpacity(0.08)
                                  : _DS.surfaceAlt,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: selected ? UpriseColors.primaryDark : _DS.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (selected) ...[
                                Icon(Icons.check_rounded, size: 12, color: UpriseColors.primaryDark),
                                const SizedBox(width: 5),
                              ],
                              Text(field, style: GoogleFonts.spaceGrotesk(
                                fontSize: 12,
                                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                color: selected ? UpriseColors.primaryDark : _DS.textSecondary,
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
                  border: Border(top: BorderSide(color: _DS.border)),
                  color: _DS.surfaceAlt,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      foregroundColor: _DS.textSecondary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    child: Text('Cancel', style: GoogleFonts.spaceGrotesk(fontSize: 13)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: selectedFields.isEmpty ? null : () async {
                      Navigator.pop(ctx);
                      asPdf
                          ? await _doExportPdf(selectedRange, selectedFields.toList())
                          : await _doExportCsv(selectedRange, selectedFields);
                    },
                    icon: Icon(asPdf ? Icons.picture_as_pdf_outlined : Icons.download_rounded, size: 15),
                    label: Text(
                      asPdf ? 'Export PDF' : 'Export CSV',
                      style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        Icon(icon, size: 13, color: _DS.textMuted),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.spaceGrotesk(
          fontSize: 10, fontWeight: FontWeight.w700,
          color: _DS.textMuted, letterSpacing: 0.8,
        )),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _DS.border, thickness: 1)),
      ]),
    );
  }

  Future<void> _doExportCsv(DateTimeRange range, Set<String> fields) async {
    if (_selectedEventDocId == null) {
      if (mounted) _showToast('Event not yet synced. Export unavailable.', isError: true);
      return;
    }
    try {
      final snapshot = await _fetchAttendanceInRange(range);
      final List<List<dynamic>> rows = [fields.toList()];
      for (final doc in snapshot.docs) {
        rows.add(_buildRow(doc.data() as Map<String, dynamic>, fields.toList()));
      }
      final csvString = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvString));
      final fileName = 'attendance_${(_selectedEvent?.title ?? 'export').replaceAll(' ', '_')}';
      await FileSaver.instance.saveAs(
          name: fileName, bytes: bytes, file: 'csv', mimeType: MimeType.csv);
      if (mounted) {
        _showToast('CSV exported — ${snapshot.docs.length} records', isError: false);
      }
      await activity_log.ActivityLogger.log(
        action: 'export_attendance', module: 'attendance_qr',
        details: {'orgId': widget.orgId, 'eventId': _selectedEventDocId, 'format': 'CSV'},
      );
    } catch (e) {
      if (mounted) _showToast('Export failed: $e', isError: true);
    }
  }

  Future<void> _doExportPdf(DateTimeRange range, List<String> headers) async {
    if (_selectedEventDocId == null) {
      if (mounted) _showToast('Event not yet synced. Export unavailable.', isError: true);
      return;
    }
    try {
      final snapshot = await _fetchAttendanceInRange(range);
      final rows = snapshot.docs
          .map((doc) => _buildRow(doc.data() as Map<String, dynamic>, headers)
              .map((e) => e.toString())
              .toList())
          .toList();
      final pdfBytes = await AdminExportPdf.generateTablePdf(
        title: _selectedEvent?.title ?? 'Attendance Report',
        headers: headers,
        rows: rows,
      );
      final fileName = 'attendance_${(_selectedEvent?.title ?? 'export').replaceAll(' ', '_')}';
      await FileSaver.instance.saveAs(
          name: fileName, bytes: pdfBytes, file: 'pdf', mimeType: MimeType.pdf);
      if (mounted) _showToast('PDF exported successfully!', isError: false);
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
        .where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(range.end.add(const Duration(days: 1))))
        .orderBy('timestamp', descending: false)
        .get();
  }

  List<dynamic> _buildRow(Map<String, dynamic> data, List<String> fields) {
    return fields.map((f) {
      switch (f) {
        case 'Student Name':  return data['studentName'] ?? '';
        case 'Student ID':    return data['studentId'] ?? '';
        case 'Program/Team':  return data['program'] ?? '';
        case 'Year Level':    return data['yearLevel'] ?? '';
        case 'Time In':
          final ts = data['timestamp'] as Timestamp?;
          return ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate()) : '';
        case 'Status':        return data['status'] ?? 'present';
        default:              return '';
      }
    }).toList();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.surface,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _selectedEvent != null
                    ? StreamBuilder<QuerySnapshot>(
                        stream: _attendanceStream,
                        builder: (context, attendanceSnap) {
                          return StreamBuilder<DocumentSnapshot>(
                            stream: _eventDocStream,
                            builder: (context, eventSnap) {
                              final isSynced = _selectedEventDocId != null;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isSynced)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(_DS.radiusMd),
                                        border: Border.all(color: const Color(0xFFD97706)),
                                      ),
                                      child: Row(children: [
                                        const Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Event approved but not yet synced to attendance. Please wait or check back shortly.',
                                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: const Color(0xFF78350F)),
                                          ),
                                        ),
                                      ]),
                                    ),
                                  _buildSummaryAndEventRow(attendanceSnap.data, eventSnap.data),
                                  const SizedBox(height: 16),
                                  // Always show toolbar so admins can search, filter, export
                                  // and view history even while the linked `events` doc
                                  // is still being created/synced.
                                  _buildToolbar(eventSnap.data),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: isSynced
                                        ? _buildMainContent(attendanceSnap.data, eventSnap.data)
                                        : _buildPlaceholderContent(attendanceSnap.data, eventSnap.data),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      )
                    : _buildPlaceholderContent(null, null),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Summary + Event Selector Row ──────────────────────────────────────────
  Widget _buildSummaryAndEventRow(QuerySnapshot? attendanceSnapshot, DocumentSnapshot? eventDocSnapshot) {
    final docs    = attendanceSnapshot?.docs ?? [];
    final total   = docs.length;
    final present = docs.where((d) => (d.data() as Map)['status'] == 'present').length;
    final late    = docs.where((d) => (d.data() as Map)['status'] == 'late').length;
    final absent  = docs.where((d) => (d.data() as Map)['status'] == 'absent').length;

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _summaryCard('Total', total.toString(), Icons.people_alt_rounded, UpriseColors.primaryDark, isFirst: true),
      _summaryCard('Present', present.toString(), Icons.check_circle_rounded, _DS.green),
      _summaryCard('Late', late.toString(), Icons.schedule_rounded, _DS.amber),
      _summaryCard('Absent', absent.toString(), Icons.cancel_rounded, _DS.red),
      const SizedBox(width: 14),
      _buildEventSelector(eventDocSnapshot),
    ]);
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color,
      {bool isFirst = false}) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.only(right: isFirst ? 0 : 0, left: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(color: _DS.border),
          boxShadow: _DS.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const Spacer(),
          ]),
          const SizedBox(height: 10),
          Text(value, style: GoogleFonts.spaceGrotesk(
            fontSize: 26, fontWeight: FontWeight.w700, color: _DS.textPrimary,
          )),
          const SizedBox(height: 2),
          Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 11, fontWeight: FontWeight.w500, color: _DS.textMuted,
          )),
        ]),
      ),
    );
  }

  // ── Event Selector (card style) ───────────────────────────────────────────
  Widget _buildEventSelector(DocumentSnapshot? eventDocSnapshot) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _DS.border),
        boxShadow: _DS.cardShadow,
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: _eventsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: SizedBox(
              height: 20, width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.event_busy_outlined, size: 16, color: _DS.textMuted),
                  const SizedBox(width: 8),
                  Text('No Approved Events', style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textSecondary,
                  )),
                ]),
                const SizedBox(height: 4),
                Text('Proposals must be approved first',
                    style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _DS.textMuted)),
              ],
            );
          }

          final events = snapshot.data!.docs.map((d) => EventModel.fromFirestore(d)).toList();
          if (_selectedEventId == null && events.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _selectEvent(events.first, events);
            });
          }

          final selected = _selectedEvent;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.event_outlined, size: 14, color: _DS.textMuted),
                const SizedBox(width: 6),
                Text('SELECT EVENT', style: GoogleFonts.spaceGrotesk(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: _DS.textMuted, letterSpacing: 0.8,
                )),
              ]),
              const SizedBox(height: 8),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedEventId,
                  hint: Text('Choose an event',
                      style: GoogleFonts.spaceGrotesk(fontSize: 13, color: _DS.textMuted)),
                  icon: const Icon(Icons.unfold_more_rounded, size: 18, color: _DS.textMuted),
                  style: GoogleFonts.spaceGrotesk(fontSize: 13, color: _DS.textPrimary),
                  items: events.map((e) => DropdownMenuItem(
                    value: e.id,
                    child: _EventDropdownItem(event: e),
                  )).toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    final evt = events.firstWhere((e) => e.id == v);
                    _selectEvent(evt, events);
                  },
                ),
              ),
              if (selected != null) ...[
                const SizedBox(height: 10),
                _EventDayStatePill(event: selected, eventDocSnapshot: eventDocSnapshot),
              ],
            ],
          );
        },
      ),
    );
  }

  void _selectEvent(EventModel event, List<EventModel> allEvents) async {
    setState(() {
      _selectedEventId    = event.id;
      _selectedEvent      = event;
      _selectedEventDocId = null;
      _attendanceStream = null;
      _eventDocStream = null;
    });

    try {
      final evQ = await FirebaseFirestore.instance
          .collection('events')
          .where('createdFromProposalId', isEqualTo: event.id)
          .limit(1)
          .get();

      if (mounted && evQ.docs.isNotEmpty) {
        final eventDoc = evQ.docs.first;
        setState(() {
          _selectedEventDocId = eventDoc.id;
          _selectedEvent = EventModel.fromFirestore(eventDoc);
        });
      }
    } catch (_) {
      // Keep the selected proposal while preserving the existing event state.
    } finally {
      if (mounted) {
        _refreshLiveStreams();
      }
    }
  }

  // ── Toolbar ───────────────────────────────────────────────────────────────
  Widget _buildToolbar(DocumentSnapshot? eventDocSnapshot) {
    return Row(children: [
      // Search
      Expanded(
        child: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.spaceGrotesk(fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search by name or student ID…',
              hintStyle: GoogleFonts.spaceGrotesk(fontSize: 13, color: _DS.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 17, color: _DS.textMuted),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _DS.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _DS.border),
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
      _statusFilterDropdown(),
      const SizedBox(width: 10),
      AdminExportButton(onSelected: _handleExportChoice),
      const SizedBox(width: 8),
      SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _DS.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: const BorderSide(color: _DS.border),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: () => _showHistoryDialog(),
          icon: const Icon(Icons.history_rounded, size: 14, color: _DS.textMuted),
          label: Text('History', style: GoogleFonts.spaceGrotesk(fontSize: 13)),
        ),
      ),
      const SizedBox(width: 10),
      _buildStartEndButton(eventDocSnapshot),
    ]);
  }

  Widget _statusFilterDropdown() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _DS.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _statusFilter,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: _DS.textMuted),
          style: GoogleFonts.spaceGrotesk(fontSize: 13, color: _DS.textPrimary),
          items: ['All', 'present', 'late', 'absent'].map((s) => DropdownMenuItem(
            value: s,
            child: Text(
              s == 'All' ? 'All Status' : s[0].toUpperCase() + s.substring(1),
              style: GoogleFonts.spaceGrotesk(fontSize: 13),
            ),
          )).toList(),
          onChanged: (v) => setState(() => _statusFilter = v ?? 'All'),
        ),
      ),
    );
  }

  Widget _buildStartEndButton(DocumentSnapshot? eventDocSnapshot) {
    final active = _computeEventActiveFromDoc(eventDocSnapshot);

    // Determine if event day gating allows manual control
    bool canControl = false;
    if (_selectedEvent != null) {
      final state = _computeEventDayState(_selectedEvent!);
      canControl = state == _EventDayState.todayActive ||
          state == _EventDayState.todayInactive ||
          state == _EventDayState.ended;
    }

    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: active ? _DS.red : UpriseColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onPressed: (_selectedEventDocId == null || !canControl)
            ? null
            : () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('events')
                      .doc(_selectedEventDocId)
                      .update({
                    'isActive': !active,
                    if (!active) 'startedAt': FieldValue.serverTimestamp(),
                    if (active) 'endedAt': FieldValue.serverTimestamp(),
                  });
                  _showToast(
                      active ? 'Attendance closed' : 'Attendance opened — scanning enabled',
                      isError: false);
                } catch (_) {
                  _showToast('Failed to update event state', isError: true);
                }
              },
        icon: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (_, __) => Icon(
            active ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
            size: 16,
            color: active
                ? Colors.white
                : Colors.white.withOpacity(active ? 1.0 : _pulseAnimation.value),
          ),
        ),
        label: Text(
          active ? 'Close Attendance' : 'Open Attendance',
          style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ── Main Content ──────────────────────────────────────────────────────────
  Widget _buildMainContent(QuerySnapshot? attendanceSnapshot, DocumentSnapshot? eventDocSnapshot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildContentTabSelector(),
        const SizedBox(height: 16),
        Expanded(
          child: _attendanceTabIndex == 0
              ? _buildAttendancePanel(attendanceSnapshot, eventDocSnapshot)
              : _buildRegistrantsPanel(attendanceSnapshot, eventDocSnapshot),
        ),
      ],
    );
  }

  // ── Event Info Banner ─────────────────────────────────────────────────────
  Widget _buildContentTabSelector() {
    return Row(children: [
      Expanded(child: _buildTabButton(0, 'Attendance')),
      const SizedBox(width: 10),
      Expanded(child: _buildTabButton(1, 'Registered Participants')),
    ]);
  }

  Widget _buildTabButton(int index, String label) {
    final selected = _attendanceTabIndex == index;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? UpriseColors.primaryDark : Colors.white,
        foregroundColor: selected ? Colors.white : _DS.textPrimary,
        side: BorderSide(color: selected ? UpriseColors.primaryDark : _DS.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      onPressed: () => setState(() => _attendanceTabIndex = index),
      child: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildAttendancePanel(QuerySnapshot? attendanceSnapshot, DocumentSnapshot? eventDocSnapshot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Column(children: [
            _buildEventInfoBanner(eventDocSnapshot),
            const SizedBox(height: 14),
            SizedBox(height: 220, child: Row(children: [
              _buildQRScannerCard(eventDocSnapshot),
              const SizedBox(width: 14),
              _buildRecentScansCard(attendanceSnapshot),
            ])),
            const SizedBox(height: 14),
            Expanded(child: _buildAttendanceTable(attendanceSnapshot)),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 280,
          child: SingleChildScrollView(child: Column(children: [
            _buildStatsCard(attendanceSnapshot, eventDocSnapshot),
            const SizedBox(height: 14),
            _buildStatusBreakdownCard(attendanceSnapshot),
            const SizedBox(height: 14),
            _buildChartCard(attendanceSnapshot?.docs ?? []),
          ])),
        ),
      ],
    );
  }

  Widget _buildRegistrantsPanel(QuerySnapshot? attendanceSnapshot, DocumentSnapshot? eventDocSnapshot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Column(children: [
            _buildEventInfoBanner(eventDocSnapshot),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _registrationStream,
                builder: (context, registrationSnapshot) {
                  if (_registrationStream == null) {
                    return _buildEmptyTableState(
                      message: 'Registration tracking is not available until the approved event is synced.',
                    );
                  }
                  if (registrationSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }
                  return _buildRegistrationTable(attendanceSnapshot, registrationSnapshot.data);
                },
              ),
            ),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 280,
          child: SingleChildScrollView(child: Column(children: [
            _buildRegistrationStatsCard(attendanceSnapshot, registrationSnapshot: null),
            const SizedBox(height: 14),
            _buildStatsCard(attendanceSnapshot, eventDocSnapshot),
          ])),
        ),
      ],
    );
  }

  Widget _buildRegistrationTable(QuerySnapshot? attendanceSnapshot, QuerySnapshot? registrationSnapshot) {
    if (registrationSnapshot == null) {
      return _buildEmptyTableState(message: 'No registered participants yet for this event.');
    }

    final attendanceRecords = attendanceSnapshot?.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList() ?? [];

    final allRows = registrationSnapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final studentId = (data['studentId'] ?? '').toString();
      final studentEmail = (data['studentEmail'] ?? '').toString();
      final matchedAttendance = attendanceRecords.firstWhere(
        (record) {
          final recordedId = (record['studentId'] ?? '').toString();
          final recordedEmail = (record['studentEmail'] ?? '').toString();
          return (recordedId.isNotEmpty && recordedId == studentId) ||
              (recordedEmail.isNotEmpty && recordedEmail == studentEmail);
        },
        orElse: () => <String, dynamic>{},
      );
      final status = matchedAttendance.isNotEmpty
          ? (matchedAttendance['status'] ?? 'present')
          : ((data['attended'] == true) ? 'present' : 'absent');
      return {...data, 'status': status};
    }).toList();

    final filteredRows = allRows.where((row) {
      final name = (row['studentName'] ?? '').toString().toLowerCase();
      final id = (row['studentId'] ?? '').toString().toLowerCase();
      if (_searchQuery.isNotEmpty && !name.contains(_searchQuery) && !id.contains(_searchQuery)) {
        return false;
      }
      if (_statusFilter != 'All' && row['status']?.toString().toLowerCase() != _statusFilter) {
        return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _DS.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: const BoxDecoration(
            color: _DS.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_DS.radiusMd)),
            border: Border(bottom: BorderSide(color: _DS.border)),
          ),
          child: Row(children: [
            Expanded(flex: 4, child: _headerCell('STUDENT')),
            Expanded(flex: 2, child: _headerCell('ID')),
            Expanded(flex: 3, child: _headerCell('PROGRAM / TEAM')),
            Expanded(flex: 2, child: _headerCell('YEAR')),
            Expanded(flex: 2, child: _headerCell('STATUS')),
            Expanded(flex: 2, child: _headerCell('REGISTERED')),
          ]),
        ),
        Expanded(
          child: filteredRows.isEmpty
              ? _buildEmptyTableState(
                  message: registrationSnapshot.docs.isEmpty
                      ? 'No registrations yet for this event.'
                      : 'No records match your filter.')
              : ListView.builder(
                  itemCount: filteredRows.length,
                  itemBuilder: (_, i) {
                    final row = filteredRows[i];
                    final registeredAt = (row['createdAt'] as Timestamp?)?.toDate();
                    final registeredAtText = registeredAt != null
                        ? DateFormat('MMM dd, hh:mm a').format(registeredAt)
                        : '—';
                    final status = row['status']?.toString() ?? 'absent';
                    final isLast = i == filteredRows.length - 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(bottom: BorderSide(color: _DS.borderLight)),
                      ),
                      child: Row(children: [
                        Expanded(flex: 4, child: Row(children: [
                          _StudentAvatar(name: row['studentName'] ?? ''),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(row['studentName'] ?? '—', style: GoogleFonts.spaceGrotesk(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textPrimary,
                            ), overflow: TextOverflow.ellipsis),
                            Text(row['studentEmail'] ?? '', style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, color: _DS.textMuted,
                            ), overflow: TextOverflow.ellipsis),
                          ])),
                        ])),
                        Expanded(flex: 2, child: Text(row['studentId'] ?? '—', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark))),
                        Expanded(flex: 3, child: Text(row['program'] ?? 'N/A', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary), overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 2, child: Text(row['yearLevel'] ?? '—', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary))),
                        Expanded(flex: 2, child: _attendanceBadge(status)),
                        Expanded(flex: 2, child: Text(registeredAtText, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary))),
                      ]),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _DS.border)),
            color: _DS.surfaceAlt,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusMd)),
          ),
          child: Row(children: [
            const Icon(Icons.event_available_rounded, size: 14, color: _DS.textMuted),
            const SizedBox(width: 6),
            Text('${registrationSnapshot.docs.length} registered participant${registrationSnapshot.docs.length == 1 ? '' : 's'}',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildRegistrationStatsCard(QuerySnapshot? attendanceSnapshot, {QuerySnapshot? registrationSnapshot}) {
    final registrations = registrationSnapshot?.docs.length ?? 0;
    final records = attendanceSnapshot?.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList() ?? [];
    int present = 0, late = 0, absent = 0;

    if (registrationSnapshot != null) {
      for (final reg in registrationSnapshot.docs) {
        final registration = reg.data() as Map<String, dynamic>;
        final studentId = (registration['studentId'] ?? '').toString();
        final studentEmail = (registration['studentEmail'] ?? '').toString();
        final matchedAttendance = records.firstWhere(
          (record) {
            final recordedId = (record['studentId'] ?? '').toString();
            final recordedEmail = (record['studentEmail'] ?? '').toString();
            return (recordedId.isNotEmpty && recordedId == studentId) ||
                (recordedEmail.isNotEmpty && recordedEmail == studentEmail);
          },
          orElse: () => <String, dynamic>{},
        );
        final status = matchedAttendance.isNotEmpty
            ? (matchedAttendance['status'] ?? 'present')
            : ((registration['attended'] == true) ? 'present' : 'absent');
        if (status == 'late') {
          late += 1;
        } else if (status == 'absent') {
          absent += 1;
        } else {
          present += 1;
        }
      }
    }

    return _RightCard(
      title: 'Registration Summary',
      icon: Icons.how_to_reg_rounded,
      child: Column(children: [
        Row(children: [
          _statMini('Registered', registrations.toString(), UpriseColors.primaryDark),
          const SizedBox(width: 8),
          _statMini('Attended', present.toString(), _DS.green),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _statMini('Late', late.toString(), _DS.amber),
          const SizedBox(width: 8),
          _statMini('Absent', absent.toString(), _DS.red),
        ]),
      ]),
    );
  }

  Widget _buildEventInfoBanner(DocumentSnapshot? eventDocSnapshot) {
    final event = _selectedEvent!;
    final isActive = _computeEventActiveFromDoc(eventDocSnapshot);
    final state = _computeEventDayState(event,
        isActiveOverride: isActive ? true : null);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(
          color: isActive ? _DS.green.withOpacity(0.4) : _DS.border,
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(children: [
        // Event icon + title
        Expanded(flex: 4, child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event_rounded, size: 20, color: UpriseColors.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(event.title, style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700, color: _DS.textPrimary,
            ), overflow: TextOverflow.ellipsis),
            Text(event.location, style: GoogleFonts.spaceGrotesk(
              fontSize: 12, color: _DS.textMuted,
            )),
          ])),
        ])),
        _infoDivider(),
        _infoBannerCell(Icons.calendar_today_rounded, 'DATE',
            DateFormat('MMM dd, yyyy').format(event.date)),
        _infoDivider(),
        _infoBannerCell(Icons.schedule_rounded, 'TIME',
            '${event.startTime} – ${event.endTime}'),
        _infoDivider(),
        _infoBannerCell(Icons.people_outline_rounded, 'CAPACITY',
            event.capacity > 0 ? '${event.capacity} seats' : 'Open'),
        _infoDivider(),
        _EventStatusChip(state: state, isActive: isActive),
      ]),
    );
  }

  Widget _infoBannerCell(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 11, color: _DS.textMuted),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.spaceGrotesk(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _DS.textMuted, letterSpacing: 0.6,
          )),
        ]),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.spaceGrotesk(
          fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textPrimary,
        )),
      ]),
    );
  }

  Widget _infoDivider() => Container(
    width: 1, height: 36,
    margin: const EdgeInsets.symmetric(horizontal: 4),
    color: _DS.border,
  );

  // ── QR Scanner Card ───────────────────────────────────────────────────────
  Widget _buildQRScannerCard(DocumentSnapshot? eventDocSnapshot) {
    final scanAllowed = _canScan(eventDocSnapshot);
    final isActive    = _computeEventActiveFromDoc(eventDocSnapshot);

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(
            color: isActive && _isScanning ? _DS.green.withOpacity(0.5) : _DS.border,
            width: isActive && _isScanning ? 1.5 : 1,
          ),
          boxShadow: _DS.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          child: Stack(children: [
            // Camera
            Positioned.fill(
              child: scanAllowed
                  ? MobileScanner(
                      controller: _scannerController,
                      onDetect: _onScanComplete,
                    )
                  : _scanBlockedOverlay(eventDocSnapshot),
            ),
            // Scan corners
            if (isActive) ..._buildScanCorners(),
            // Bottom label
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                  ),
                ),
                child: Row(children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Container(
                      width: 7, height: 7,
                      decoration: BoxDecoration(
                        color: isActive && _isScanning
                            ? _DS.green.withOpacity(_pulseAnimation.value)
                            : Colors.white38,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    isActive && _isScanning
                        ? 'Scanning…'
                        : !isActive ? 'Attendance closed' : 'Paused',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (scanAllowed)
                    GestureDetector(
                      onTap: () => setState(() => _isScanning = !_isScanning),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isScanning ? 'Pause' : 'Resume',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _scanBlockedOverlay(DocumentSnapshot? doc) {
    String msg = 'Select an event to begin';
    IconData icon = Icons.event_outlined;
    Color color = _DS.textMuted;

    if (_selectedEvent != null) {
      final state = _computeEventDayState(_selectedEvent!);
      switch (state) {
        case _EventDayState.future:
          msg = 'Event opens on\n${DateFormat('MMM dd').format(_selectedEvent!.date)}';
          icon = Icons.lock_clock_outlined;
          color = _DS.blue;
          break;
        case _EventDayState.ended:
          msg = 'Event has ended\nAttendance is read-only';
          icon = Icons.lock_outline_rounded;
          color = _DS.textMuted;
          break;
        case _EventDayState.todayInactive:
          msg = 'Open attendance\nto enable scanning';
          icon = Icons.qr_code_scanner_rounded;
          color = UpriseColors.primaryDark;
          break;
        default:
          msg = 'Camera unavailable';
          icon = Icons.videocam_off_outlined;
      }
    }

    return Container(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 32, color: color.withOpacity(0.6)),
          const SizedBox(height: 10),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white54, fontSize: 12, height: 1.5,
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _buildScanCorners() {
    const double sz = 20, thickness = 2.5, inset = 24;
    const Color clr = _DS.green;

    Widget corner({required bool top, required bool left}) => Positioned(
      top: top ? inset : null, bottom: top ? null : inset,
      left: left ? inset : null, right: left ? null : inset,
      child: Container(
        width: sz, height: sz,
        decoration: BoxDecoration(
          border: Border(
            top:    top  ? const BorderSide(color: clr, width: thickness) : BorderSide.none,
            bottom: !top ? const BorderSide(color: clr, width: thickness) : BorderSide.none,
            left:   left ? const BorderSide(color: clr, width: thickness) : BorderSide.none,
            right: !left ? const BorderSide(color: clr, width: thickness) : BorderSide.none,
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

  // ── Recent Scans Card ─────────────────────────────────────────────────────
  Widget _buildRecentScansCard(QuerySnapshot? attendanceSnapshot) {
    final docs = attendanceSnapshot?.docs ?? [];
    if (docs.isEmpty) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_DS.radiusMd),
            border: Border.all(color: _DS.border),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.history_rounded, size: 14, color: _DS.textMuted),
              const SizedBox(width: 6),
              Text('RECENT CHECK-INS', style: GoogleFonts.spaceGrotesk(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: _DS.textMuted, letterSpacing: 0.7,
              )),
            ]),
            const SizedBox(height: 10),
            Expanded(
              child: Center(child: Text('No check-ins yet',
                  style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textMuted))),
            ),
          ]),
        ),
      );
    }

    final recent = docs.reversed.take(4).toList();
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(color: _DS.border),
          boxShadow: _DS.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.history_rounded, size: 14, color: _DS.textMuted),
            const SizedBox(width: 6),
            Text('RECENT CHECK-INS', style: GoogleFonts.spaceGrotesk(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: _DS.textMuted, letterSpacing: 0.7,
            )),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: recent.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: _DS.borderLight),
              itemBuilder: (_, i) {
                final data = recent[i].data() as Map<String, dynamic>;
                final ts   = data['timestamp'] as Timestamp?;
                final time = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '—';
                final status = data['status'] ?? 'present';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    _StudentAvatar(name: data['studentName'] ?? '', size: 26),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['studentName'] ?? '—', style: GoogleFonts.spaceGrotesk(
                        fontSize: 12, fontWeight: FontWeight.w600, color: _DS.textPrimary,
                      ), overflow: TextOverflow.ellipsis),
                      Text(time, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _DS.textMuted)),
                    ])),
                    _attendanceBadge(status),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  // ── Attendance Table ──────────────────────────────────────────────────────
  Widget _buildAttendanceTable(QuerySnapshot? attendanceSnapshot) {
    final docsSnapshot = attendanceSnapshot?.docs ?? [];
    if (attendanceSnapshot == null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(color: _DS.border),
          boxShadow: _DS.cardShadow,
        ),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final filteredDocs = docsSnapshot.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      if (_searchQuery.isNotEmpty) {
        final name = (data['studentName'] ?? '').toString().toLowerCase();
        final id   = (data['studentId'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery) && !id.contains(_searchQuery)) return false;
      }
      if (_statusFilter != 'All') {
        if ((data['status'] ?? '').toString().toLowerCase() != _statusFilter) return false;
      }
      return true;
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _DS.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(children: [
        // Header bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: const BoxDecoration(
            color: _DS.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_DS.radiusMd)),
            border: Border(bottom: BorderSide(color: _DS.border)),
          ),
          child: Row(children: [
            Expanded(flex: 4, child: _headerCell('STUDENT')),
            Expanded(flex: 2, child: _headerCell('ID')),
            Expanded(flex: 3, child: _headerCell('PROGRAM / TEAM')),
            Expanded(flex: 2, child: _headerCell('YEAR')),
            Expanded(flex: 2, child: _headerCell('TIME IN')),
            Expanded(flex: 2, child: _headerCell('STATUS')),
          ]),
        ),
        // Rows
        Expanded(
          child: filteredDocs.isEmpty
              ? _buildEmptyTableState(
                  message: docsSnapshot.isEmpty
                      ? 'No check-ins yet. Open attendance to begin scanning.'
                      : 'No records match your filter.')
              : ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (_, i) {
                    final data = filteredDocs[i].data() as Map<String, dynamic>;
                    final ts   = data['timestamp'] as Timestamp?;
                    final timeIn = ts != null ? DateFormat('hh:mm a').format(ts.toDate()) : '—';
                    final isLast = i == filteredDocs.length - 1;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        border: isLast
                            ? null
                            : const Border(bottom: BorderSide(color: _DS.borderLight)),
                      ),
                      child: Row(children: [
                        Expanded(flex: 4, child: Row(children: [
                          _StudentAvatar(name: data['studentName'] ?? ''),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(data['studentName'] ?? '—', style: GoogleFonts.spaceGrotesk(
                              fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textPrimary,
                            ), overflow: TextOverflow.ellipsis),
                            Text(data['studentEmail'] ?? '', style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, color: _DS.textMuted,
                            ), overflow: TextOverflow.ellipsis),
                          ])),
                        ])),
                        Expanded(flex: 2, child: Text(data['studentId'] ?? '—',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark,
                            ))),
                        Expanded(flex: 3, child: Text(data['program'] ?? 'N/A',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary),
                            overflow: TextOverflow.ellipsis)),
                        Expanded(flex: 2, child: Text(data['yearLevel'] ?? '—',
                            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary))),
                        Expanded(flex: 2, child: Row(children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: _DS.textMuted),
                          const SizedBox(width: 4),
                          Text(timeIn, style: GoogleFonts.spaceGrotesk(
                            fontSize: 12, color: _DS.textPrimary,
                          )),
                        ])),
                        Expanded(flex: 2, child: _attendanceBadge(data['status'] ?? 'present')),
                      ]),
                    );
                  },
                ),
        ),
        // Footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _DS.border)),
            color: _DS.surfaceAlt,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusMd)),
          ),
          child: Row(children: [
            const Icon(Icons.people_outline_rounded, size: 14, color: _DS.textMuted),
            const SizedBox(width: 6),
            Text('${docsSnapshot.length} attendee${docsSnapshot.length == 1 ? '' : 's'} recorded',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary)),
            const Spacer(),
            _FooterButton(
              icon: Icons.download_outlined,
              label: 'CSV',
              onTap: () => _showExportDialog(asPdf: false),
            ),
            const SizedBox(width: 8),
            _FooterButton(
              icon: Icons.picture_as_pdf_outlined,
              label: 'PDF',
              onTap: () => _showExportDialog(asPdf: true),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _headerCell(String text) => Text(text, style: GoogleFonts.spaceGrotesk(
    fontSize: 10, fontWeight: FontWeight.w700, color: _DS.textMuted, letterSpacing: 0.7,
  ));

  Widget _buildEmptyTableState({String message = 'No check-ins yet. Open attendance to begin scanning.'}) {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: _DS.surfaceAlt,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.qr_code_2_rounded, size: 28, color: _DS.textMuted),
        ),
        const SizedBox(height: 12),
        Text(message, style: GoogleFonts.spaceGrotesk(
          fontSize: 13, fontWeight: FontWeight.w600, color: _DS.textSecondary,
        )),
      ]),
    );
  }

  // ── Right panel — Stats ───────────────────────────────────────────────────
  Widget _buildStatsCard(QuerySnapshot? attendanceSnapshot, DocumentSnapshot? eventDocSnapshot) {
    final docs    = attendanceSnapshot?.docs ?? [];
    final present = docs.where((d) => (d.data() as Map)['status'] == 'present').length;
    final late    = docs.where((d) => (d.data() as Map)['status'] == 'late').length;
    final total   = docs.length;
    final capacity = ((eventDocSnapshot?.data() as Map?)?['capacity'] as num?)?.toInt() ?? 0;
    final rate = capacity > 0 ? (total / capacity * 100).clamp(0.0, 100.0) : 0.0;

    return _RightCard(
      title: 'Statistics',
      icon: Icons.analytics_outlined,
      child: Column(children: [
        Row(children: [
          _statMini('Present',  present.toString(), _DS.green),
          const SizedBox(width: 8),
          _statMini('Late',     late.toString(),    _DS.amber),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          _statMini('Total',    total.toString(),   UpriseColors.primaryDark),
          const SizedBox(width: 8),
          _statMini('Capacity', capacity > 0 ? capacity.toString() : '—', _DS.blue),
        ]),
        if (capacity > 0) ...[
          const SizedBox(height: 16),
          Row(children: [
            Text('Attendance Rate', style: GoogleFonts.spaceGrotesk(
              fontSize: 11, color: _DS.textMuted,
            )),
            const Spacer(),
            Text('${rate.toStringAsFixed(1)}%', style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark,
            )),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 6,
              backgroundColor: _DS.border,
              valueColor: AlwaysStoppedAnimation<Color>(UpriseColors.primaryDark),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _statMini(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _DS.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 10, color: _DS.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.spaceGrotesk(
            fontSize: 20, fontWeight: FontWeight.w700, color: color,
          )),
        ]),
      ),
    );
  }

  // ── Right panel — Status Breakdown ───────────────────────────────────────
  Widget _buildStatusBreakdownCard(QuerySnapshot? attendanceSnapshot) {
    final docs    = attendanceSnapshot?.docs ?? [];
    final present = docs.where((d) => (d.data() as Map)['status'] == 'present').length;
    final late    = docs.where((d) => (d.data() as Map)['status'] == 'late').length;
    final absent  = docs.where((d) => (d.data() as Map)['status'] == 'absent').length;
    final total   = docs.isNotEmpty ? docs.length : 1;

    return _RightCard(
      title: 'Breakdown',
      icon: Icons.donut_small_rounded,
      child: Column(children: [
        _breakdownRow('Present', present, total, _DS.green, _DS.greenBg),
        const SizedBox(height: 10),
        _breakdownRow('Late',    late,    total, _DS.amber, _DS.amberBg),
        const SizedBox(height: 10),
        _breakdownRow('Absent',  absent,  total, _DS.red,   _DS.redBg),
      ]),
    );
  }

  Widget _breakdownRow(String label, int count, int total, Color color, Color bg) {
    final pct = count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 7, height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
          child: Text('$count', style: GoogleFonts.spaceGrotesk(
            fontSize: 11, fontWeight: FontWeight.w700, color: color,
          )),
        ),
      ]),
      const SizedBox(height: 5),
      ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: pct.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: _DS.border,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ]);
  }

  // ── Right panel — Chart ───────────────────────────────────────────────────
  Widget _buildChartCard(List<DocumentSnapshot> attendanceDocs) {
    return _RightCard(
      title: 'Trend',
      icon: Icons.show_chart_rounded,
      child: _AttendanceChart(attendanceDocs: attendanceDocs),
    );
  }

  

  // ── Placeholder content shown while the event doc is being created/synced
  Widget _buildPlaceholderContent(QuerySnapshot? attendanceSnapshot, DocumentSnapshot? eventDocSnapshot) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 11,
          child: Column(children: [
            if (_selectedEvent != null)
              _buildEventInfoBanner(eventDocSnapshot)
            else
              _buildNoEventSelectedBanner(),
            const SizedBox(height: 14),
            SizedBox(height: 220, child: Row(children: [
              _buildPlaceholderScannerCard(),
              const SizedBox(width: 14),
              _buildRecentScansCard(null),
            ])),
            const SizedBox(height: 14),
            Expanded(child: _buildPlaceholderTable()),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 280,
          child: SingleChildScrollView(child: Column(children: [
            _buildStatsCard(null, null),
            const SizedBox(height: 14),
            _buildStatusBreakdownCard(null),
            const SizedBox(height: 14),
            _buildChartCard([]),
          ])),
        ),
      ],
    );
  }

  Widget _buildPlaceholderScannerCard() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(color: _DS.border),
          boxShadow: _DS.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.qr_code_scanner_rounded, size: 14, color: _DS.textMuted),
            const SizedBox(width: 8),
            Text('QR SCANNER', style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.w700, color: _DS.textMuted)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), border: Border.all(color: _DS.border)),
              child: Text('Disabled', style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _DS.textMuted)),
            ),
          ]),
          const SizedBox(height: 12),
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 140, height: 100, decoration: BoxDecoration(color: _DS.surfaceAlt, borderRadius: BorderRadius.circular(12)), child: Center(child: Icon(Icons.qr_code_2_rounded, size: 48, color: _DS.textMuted))),
            const SizedBox(height: 12),
            Text('Scanner disabled until event sync completes', textAlign: TextAlign.center, style: GoogleFonts.spaceGrotesk(fontSize: 13, color: _DS.textSecondary)),
          ]))),
        ]),
      ),
    );
  }

  Widget _buildNoEventSelectedBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _DS.surfaceAlt,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _DS.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_note_outlined, size: 16, color: _DS.textMuted),
          const SizedBox(width: 8),
          Text('No event selected', style: GoogleFonts.spaceGrotesk(fontSize: 12, fontWeight: FontWeight.w700, color: _DS.textPrimary)),
        ]),
        const SizedBox(height: 10),
        Text(
          'Select an approved event from the selector above to see attendance details and start scanning.',
          style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary, height: 1.4),
        ),
      ]),
    );
  }

  Widget _buildPlaceholderTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _DS.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: const BoxDecoration(
            color: _DS.surfaceAlt,
            borderRadius: BorderRadius.vertical(top: Radius.circular(_DS.radiusMd)),
            border: Border(bottom: BorderSide(color: _DS.border)),
          ),
          child: Row(children: [
            Expanded(flex: 4, child: _headerCell('STUDENT')),
            Expanded(flex: 2, child: _headerCell('ID')),
            Expanded(flex: 3, child: _headerCell('PROGRAM / TEAM')),
            Expanded(flex: 2, child: _headerCell('YEAR')),
            Expanded(flex: 2, child: _headerCell('TIME IN')),
            Expanded(flex: 2, child: _headerCell('STATUS')),
          ]),
        ),
        Expanded(child: _buildEmptyTableState(message: 'No check-ins yet. Event data still syncing.')),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: _DS.border)),
            color: _DS.surfaceAlt,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusMd)),
          ),
          child: Row(children: [
            const Icon(Icons.people_outline_rounded, size: 14, color: _DS.textMuted),
            const SizedBox(width: 6),
            Text('0 attendees recorded', style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textSecondary)),
            const Spacer(),
            _FooterButton(icon: Icons.download_outlined, label: 'CSV', onTap: () => _showExportDialog(asPdf: false)),
            const SizedBox(width: 8),
            _FooterButton(icon: Icons.picture_as_pdf_outlined, label: 'PDF', onTap: () => _showExportDialog(asPdf: true)),
          ]),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Event day state pill — shows contextual status (Today / Future / Ended / Live)
// ─────────────────────────────────────────────────────────────────────────────
class _EventDayStatePill extends StatelessWidget {
  final EventModel event;
  final DocumentSnapshot? eventDocSnapshot;
  const _EventDayStatePill({required this.event, this.eventDocSnapshot});

  @override
  Widget build(BuildContext context) {
    final isActiveFlag = (eventDocSnapshot?.data() as Map?)?['isActive'] == true;
    final state = _computeEventDayState(event, isActiveOverride: isActiveFlag ? true : null);

    String label;
    Color bg, fg;
    IconData icon;

    switch (state) {
      case _EventDayState.todayActive:
        label = 'LIVE — Scanning Active';
        bg = _DS.greenBg; fg = _DS.green; icon = Icons.sensors_rounded;
        break;
      case _EventDayState.todayInactive:
        label = 'TODAY — Open to enable scanning';
        bg = _DS.amberBg; fg = _DS.amber; icon = Icons.today_rounded;
        break;
      case _EventDayState.future:
        final diff = event.date.difference(DateTime.now()).inDays + 1;
        label = 'In $diff day${diff == 1 ? '' : 's'}';
        bg = _DS.blueBg; fg = _DS.blue; icon = Icons.event_rounded;
        break;
      case _EventDayState.ended:
        label = 'ENDED — Read-only';
        bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280);
        icon = Icons.lock_outline_rounded;
        break;
      default:
        label = 'Unavailable';
        bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280);
        icon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (state == _EventDayState.todayActive)
          _PulsingDot(color: fg)
        else
          Icon(icon, size: 11, color: fg),
        const SizedBox(width: 5),
        Flexible(child: Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 10, fontWeight: FontWeight.w700, color: fg,
        ))),
      ]),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: 7, height: 7,
      decoration: BoxDecoration(
        color: widget.color.withOpacity(_anim.value),
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _EventStatusChip extends StatelessWidget {
  final _EventDayState state;
  final bool isActive;
  const _EventStatusChip({required this.state, required this.isActive});

  @override
  Widget build(BuildContext context) {
    String label;
    Color bg, fg;
    Widget leading;

    if (isActive || state == _EventDayState.todayActive) {
      label = 'LIVE';
      bg = _DS.greenBg; fg = _DS.green;
      leading = _PulsingDot(color: fg);
    } else if (state == _EventDayState.todayInactive) {
      label = 'TODAY';
      bg = _DS.amberBg; fg = _DS.amber;
      leading = Icon(Icons.today_rounded, size: 11, color: fg);
    } else if (state == _EventDayState.future) {
      label = 'UPCOMING';
      bg = _DS.blueBg; fg = _DS.blue;
      leading = Icon(Icons.upcoming_rounded, size: 11, color: fg);
    } else {
      label = 'ENDED';
      bg = const Color(0xFFF3F4F6); fg = const Color(0xFF6B7280);
      leading = Icon(Icons.lock_outline_rounded, size: 11, color: fg);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        leading,
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 10, fontWeight: FontWeight.w800, color: fg, letterSpacing: 0.6,
        )),
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
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: _DS.border),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: UpriseColors.primaryDark),
          ),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.spaceGrotesk(
            fontSize: 13, fontWeight: FontWeight.w700, color: _DS.textPrimary,
          )),
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Footer button
// ─────────────────────────────────────────────────────────────────────────────
class _FooterButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _FooterButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 13),
      label: Text(label, style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.w600)),
      style: OutlinedButton.styleFrom(
        foregroundColor: UpriseColors.primaryDark,
        side: BorderSide(color: UpriseColors.primaryDark.withOpacity(0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Avatar
// ─────────────────────────────────────────────────────────────────────────────
class _StudentAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _StudentAvatar({required this.name, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark.withOpacity(0.09),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: Text(initials, style: GoogleFonts.spaceGrotesk(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w700,
          color: UpriseColors.primaryDark,
        )),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Attendance Chart
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceChart extends StatelessWidget {
  final List<DocumentSnapshot> attendanceDocs;
  const _AttendanceChart({required this.attendanceDocs});

  @override
  Widget build(BuildContext context) {
    if (attendanceDocs.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(child: Text('No data yet',
            style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textMuted))),
      );
    }

    final Map<DateTime, int> countByDate = {};
    for (final doc in attendanceDocs) {
      final ts = (doc.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
      if (ts == null) continue;
      final d    = ts.toDate();
      final date = DateTime(d.year, d.month, d.day);
      countByDate[date] = (countByDate[date] ?? 0) + 1;
    }

        if (countByDate.isEmpty) {
          return SizedBox(
            height: 140,
            child: Center(child: Text('No data yet',
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: _DS.textMuted))),
          );
        }

    final sortedDates = countByDate.keys.toList()..sort();
    final maxY = countByDate.values.reduce((a, b) => a > b ? a : b).toDouble();
    final spots = List.generate(sortedDates.length,
        (i) => FlSpot(i.toDouble(), countByDate[sortedDates[i]]!.toDouble()));

    return SizedBox(
      height: 140,
      child: LineChart(LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: _DS.borderLight, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (value, _) {
              final i = value.toInt();
              if (i < 0 || i >= sortedDates.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(DateFormat('d/M').format(sortedDates[i]),
                    style: GoogleFonts.spaceGrotesk(fontSize: 9, color: _DS.textMuted)),
              );
            },
          )),
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (v, _) => Text('${v.toInt()}',
                style: GoogleFonts.spaceGrotesk(fontSize: 9, color: _DS.textMuted)),
          )),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: _DS.border),
            left: BorderSide(color: _DS.border),
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
            barWidth: 2,
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
              color: UpriseColors.primaryDark.withOpacity(0.07),
            ),
          ),
        ],
      )),
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

// ─────────────────────────────────────────────────────────────────────────────
// Event Dropdown Item — shows event title + date + day state indicator
// ─────────────────────────────────────────────────────────────────────────────
class _EventDropdownItem extends StatelessWidget {
  final EventModel event;
  const _EventDropdownItem({required this.event});

  @override
  Widget build(BuildContext context) {
    final state = _computeEventDayState(event);
    Color dotColor;
    switch (state) {
      case _EventDayState.todayActive:   dotColor = _DS.green; break;
      case _EventDayState.todayInactive: dotColor = _DS.amber; break;
      case _EventDayState.future:        dotColor = _DS.blue;  break;
      default:                           dotColor = _DS.textMuted;
    }
    return Row(children: [
      Container(width: 7, height: 7,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(event.title,
          style: GoogleFonts.spaceGrotesk(fontSize: 13),
          overflow: TextOverflow.ellipsis)),
      Text(DateFormat('MMM d').format(event.date),
          style: GoogleFonts.spaceGrotesk(fontSize: 11, color: _DS.textMuted)),
    ]);
  }
}