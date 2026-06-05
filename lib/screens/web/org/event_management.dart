import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../theme/app_theme.dart';
import '../../../widgets/admin_export_button.dart';
import 'export_pdf.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusXl   = 20;
  static const double radiusPill = 100;

  // Refined card shadow — softer, more layered
  static final cardShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1)),
    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 6)),
  ];

  // Elevated card shadow for modals / featured cards
  static final elevatedShadow = [
    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
    BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 30, offset: const Offset(0, 12)),
  ];

  static InputDecoration inputDeco(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null
          ? Padding(
              padding: const EdgeInsets.only(left: 14, right: 10),
              child: Icon(icon, size: 17, color: const Color(0xFFB0BAC8)),
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      labelStyle: GoogleFonts.beVietnamPro(fontSize: 12.5, color: const Color(0xFF8492A6), fontWeight: FontWeight.w500),
      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFFB0BAC8)),
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE4E8EF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE4E8EF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE5484D)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE5484D), width: 1.5),
      ),
    );
  }

  static InputDecoration searchDeco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFFB0BAC8)),
    prefixIcon: const Padding(
      padding: EdgeInsets.only(left: 14, right: 10),
      child: Icon(Icons.search_rounded, size: 17, color: Color(0xFFB0BAC8)),
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE4E8EF))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: const BorderSide(color: Color(0xFFE4E8EF))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusSm),
        borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text, {IconData? icon}) => Padding(
  padding: const EdgeInsets.only(bottom: 14),
  child: Row(children: [
    if (icon != null) ...[
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: UpriseColors.primaryDark.withOpacity(0.09),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 13, color: UpriseColors.primaryDark),
      ),
      const SizedBox(width: 9),
    ],
    Text(text,
        style: GoogleFonts.beVietnamPro(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF64748B),
            letterSpacing: 0.6)),
    const SizedBox(width: 12),
    const Expanded(child: Divider(color: Color(0xFFEEF0F4), thickness: 1)),
  ]),
);

Widget _headerCell(String text) => Text(text,
    style: GoogleFonts.beVietnamPro(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF94A3B8),
        letterSpacing: 0.8));

Widget _attBadge(String status) {
  final Map<String, (Color, Color, Color, String)> s = {
    'present': (const Color(0xFFECFDF5), const Color(0xFF059669), const Color(0xFFBBF7D0), 'PRESENT'),
    'late':    (const Color(0xFFFFFBEB), const Color(0xFFD97706), const Color(0xFFFDE68A), 'LATE'),
    'absent':  (const Color(0xFFFEF2F2), const Color(0xFFDC2626), const Color(0xFFFECACA), 'ABSENT'),
  };
  final style = s[status.toLowerCase()] ??
      (const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFFE5E7EB), status.toUpperCase());
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
    decoration: BoxDecoration(
        color: style.$1,
        border: Border.all(color: style.$3, width: 1),
        borderRadius: BorderRadius.circular(_DS.radiusPill)),
    child: Text(style.$4,
        style: GoogleFonts.beVietnamPro(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: style.$2,
            letterSpacing: 0.6)),
  );
}

Widget _certBadge(String status) {
  final Map<String, (Color, Color, Color, String)> s = {
    'distributed': (const Color(0xFFECFDF5), const Color(0xFF059669), const Color(0xFFBBF7D0), 'DISTRIBUTED'),
    'pending':     (const Color(0xFFFFFBEB), const Color(0xFFD97706), const Color(0xFFFDE68A), 'PENDING'),
    'draft':       (const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFFE5E7EB), 'DRAFT'),
  };
  final style = s[status.toLowerCase()] ??
      (const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFFE5E7EB), status.toUpperCase());
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
    decoration: BoxDecoration(
        color: style.$1,
        border: Border.all(color: style.$3, width: 1),
        borderRadius: BorderRadius.circular(_DS.radiusPill)),
    child: Text(style.$4,
        style: GoogleFonts.beVietnamPro(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: style.$2,
            letterSpacing: 0.6)),
  );
}

void _toast(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(msg,
            style: GoogleFonts.beVietnamPro(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: error ? const Color(0xFFDC2626) : const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ));
}

// ─────────────────────────────────────────────────────────────────────────────
// MODELS (unchanged)
// ─────────────────────────────────────────────────────────────────────────────
class EventModel {
  final String id, title, location, startTime, endTime;
  final int capacity;
  final DateTime date;
  const EventModel({
    required this.id, required this.title, required this.location,
    required this.startTime, required this.endTime,
    required this.capacity, required this.date,
  });
  factory EventModel.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return EventModel(
      id: d.id, title: m['title'] ?? 'Untitled', location: m['location'] ?? 'TBA',
      startTime: m['startTime'] ?? '—', endTime: m['endTime'] ?? '—',
      capacity: (m['capacity'] as num?)?.toInt() ?? 0,
      date: (m['date'] as Timestamp).toDate(),
    );
  }
}

class CertRecord {
  final String id, certId, eventName, org, type, status, templateType;
  final int recipients;
  final DateTime date;
  final String? templateUrl;
  const CertRecord({
    required this.id, required this.certId, required this.eventName,
    required this.org, required this.type, required this.status,
    required this.templateType, required this.recipients, required this.date,
    this.templateUrl,
  });
  factory CertRecord.fromDoc(DocumentSnapshot d) {
    final m = d.data() as Map<String, dynamic>;
    return CertRecord(
      id: d.id, certId: 'CERT-${d.id.substring(0, 4).toUpperCase()}',
      eventName: m['eventName'] ?? 'Untitled', org: m['organization'] ?? 'N/A',
      type: m['type'] ?? 'Participation', status: m['status'] ?? 'draft',
      templateType: m['templateType'] ?? 'Classic',
      recipients: (m['recipients'] as num?)?.toInt() ?? 0,
      date: (m['issuedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      templateUrl: m['templateFileUrl'],
    );
  }
}

enum _EState { future, todayInactive, active, ended }

_EState _eventState(EventModel e, {bool? activeOverride}) {
  if (activeOverride == true) return _EState.active;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final eDay = DateTime(e.date.year, e.date.month, e.date.day);
  if (eDay.isAfter(today)) return _EState.future;
  if (eDay.isBefore(today)) return _EState.ended;
  try {
    final s = DateFormat.jm().parse(e.startTime);
    final en = DateFormat.jm().parse(e.endTime);
    final startDt = DateTime(e.date.year, e.date.month, e.date.day, s.hour, s.minute);
    var endDt = DateTime(e.date.year, e.date.month, e.date.day, en.hour, en.minute);
    if (endDt.isBefore(startDt)) endDt = endDt.add(const Duration(days: 1));
    if (now.isAfter(endDt.add(const Duration(minutes: 15)))) return _EState.ended;
    if (now.isAfter(startDt.subtract(const Duration(minutes: 15)))) return _EState.active;
  } catch (_) {}
  return _EState.todayInactive;
}

// ─────────────────────────────────────────────────────────────────────────────
// ROOT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class EventManagementScreen extends StatefulWidget {
  final String orgId;
  final int initialTabIndex;
  const EventManagementScreen({super.key, required this.orgId, this.initialTabIndex = 0});

  @override
  State<EventManagementScreen> createState() => _EventManagementScreenState();
}

class _EventManagementScreenState extends State<EventManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  EventModel? _event;
  String? _eventDocId;

  Stream<QuerySnapshot> get _eventsStream => FirebaseFirestore.instance
      .collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('date')
      .snapshots();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this, initialIndex: widget.initialTabIndex.clamp(0, 1));
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _selectEvent(EventModel e) async {
    setState(() { _event = e; _eventDocId = null; });
    final q = await FirebaseFirestore.instance
        .collection('events')
        .where('createdFromProposalId', isEqualTo: e.id)
        .limit(1).get();
    if (mounted && q.docs.isNotEmpty) setState(() => _eventDocId = q.docs.first.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header control panel ──
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_DS.radiusXl),
                border: Border.all(color: const Color(0xFFEBEEF3)),
                boxShadow: _DS.cardShadow,
              ),
              child: Column(children: [
                // Event selector row
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _eventsStream,
                    builder: (ctx, snap) {
                      final events = (snap.data?.docs ?? []).map((d) => EventModel.fromDoc(d)).toList();
                      if (events.isNotEmpty && _event == null) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) { if (mounted) _selectEvent(events.first); });
                      }
                      return Row(children: [
                        // Label pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: UpriseColors.primaryDark.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(children: [
                            Icon(Icons.event_rounded, size: 13, color: UpriseColors.primaryDark),
                            const SizedBox(width: 5),
                            Text('EVENT',
                                style: GoogleFonts.beVietnamPro(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: UpriseColors.primaryDark,
                                    letterSpacing: 0.7)),
                          ]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: events.isEmpty
                              ? Text('No approved events available',
                                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFFB0BAC8)))
                              : DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _event?.id,
                                    isExpanded: true,
                                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFFB0BAC8)),
                                    style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C)),
                                    items: events.map((e) => DropdownMenuItem(value: e.id, child: Text(e.title))).toList(),
                                    onChanged: (v) { if (v != null) _selectEvent(events.firstWhere((e) => e.id == v)); },
                                  ),
                                ),
                        ),
                        if (_event != null) ...[
                          const SizedBox(width: 12),
                          _StatePill(_event!),
                        ],
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Tab bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF1F4F8),
                          borderRadius: BorderRadius.circular(_DS.radiusSm)),
                      child: IntrinsicWidth(
                        child: TabBar(
                          controller: _tab,
                          indicator: BoxDecoration(
                            color: UpriseColors.primaryDark,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(color: UpriseColors.primaryDark.withOpacity(0.25),
                                  blurRadius: 6, offset: const Offset(0, 2)),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                          labelColor: Colors.white,
                          unselectedLabelColor: const Color(0xFF8492A6),
                          labelStyle: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700),
                          unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500),
                          indicatorPadding: const EdgeInsets.all(2),
                          tabAlignment: TabAlignment.start,
                          isScrollable: true,
                          padding: EdgeInsets.zero,
                          tabs: [
                            Tab(
                              height: 30,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.qr_code_scanner_rounded, size: 13),
                                  const SizedBox(width: 5),
                                  Text('Attendance', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                            Tab(
                              height: 30,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  const Icon(Icons.workspace_premium_outlined, size: 13),
                                  const SizedBox(width: 5),
                                  Text('Certificates', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                                ]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(controller: _tab, children: [
              AttendanceTab(key: const PageStorageKey('att'), orgId: widget.orgId, event: _event, eventDocId: _eventDocId),
              CertificatesTab(key: const PageStorageKey('cert'), orgId: widget.orgId, event: _event, eventDocId: _eventDocId),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE PILL — improved with dot indicator
// ─────────────────────────────────────────────────────────────────────────────
class _StatePill extends StatelessWidget {
  final EventModel event;
  const _StatePill(this.event);

  @override
  Widget build(BuildContext context) {
    final state = _eventState(event);
    final (Color bg, Color fg, Color border, String txt, IconData icon) = switch (state) {
      _EState.active        => (const Color(0xFFECFDF5), const Color(0xFF059669), const Color(0xFFBBF7D0), 'LIVE', Icons.fiber_manual_record),
      _EState.todayInactive => (const Color(0xFFFFFBEB), const Color(0xFFD97706), const Color(0xFFFDE68A), 'TODAY', Icons.today_rounded),
      _EState.future        => (const Color(0xFFEFF6FF), const Color(0xFF2563EB), const Color(0xFFBFD7FF), 'UPCOMING', Icons.event_rounded),
      _EState.ended         => (const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFFE5E7EB), 'ENDED', Icons.lock_outline_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(100)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: state == _EState.active ? 8 : 11, color: fg),
        const SizedBox(width: 5),
        Text(txt,
            style: GoogleFonts.beVietnamPro(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.7)),
      ]),
    );
  }
}

// =============================================================================
// ATTENDANCE TAB
// =============================================================================
class AttendanceTab extends StatefulWidget {
  final String orgId;
  final EventModel? event;
  final String? eventDocId;
  const AttendanceTab({super.key, required this.orgId, this.event, this.eventDocId});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _scanner    = MobileScannerController();
  final _search     = TextEditingController();
  final _manualCtrl = TextEditingController();

  bool   _scanning     = true;
  String _lastCode     = '';
  String _query        = '';
  String _statusFilter = 'All';
  int    _inputMode    = 0;
  int    _subTab       = 0;

  @override
  void dispose() { _scanner.dispose(); _search.dispose(); _manualCtrl.dispose(); super.dispose(); }

  Stream<QuerySnapshot>? get _attStream => widget.eventDocId == null ? null
      : FirebaseFirestore.instance.collection('events').doc(widget.eventDocId)
          .collection('attendances').orderBy('timestamp').snapshots();

  Stream<QuerySnapshot>? get _regStream => widget.eventDocId == null ? null
      : FirebaseFirestore.instance.collection('registrations')
          .where('eventId', isEqualTo: widget.eventDocId).snapshots();

  Stream<DocumentSnapshot>? get _eventStream => widget.eventDocId == null ? null
      : FirebaseFirestore.instance.collection('events').doc(widget.eventDocId).snapshots();

  bool _isActive(DocumentSnapshot? doc) {
    if (doc == null) return false;
    if ((doc.data() as Map?)?['isActive'] == true) return true;
    if (widget.event == null) return false;
    return _eventState(widget.event!) == _EState.active;
  }

  bool get _isEventDay {
    if (widget.event == null) return false;
    final now = DateTime.now();
    final eventDate = widget.event!.date;
    return now.year == eventDate.year && now.month == eventDate.month && now.day == eventDate.day;
  }

  Future<void> _markAttendance(String uid, {bool isManual = false}) async {
    if (widget.eventDocId == null || widget.event == null) return;
    try {
      final evDoc = await FirebaseFirestore.instance.collection('events').doc(widget.eventDocId).get();
      if (!_isActive(evDoc)) throw Exception('Attendance is not open for this event');

      DocumentSnapshot? userDoc;
      final direct = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (direct.exists && (direct.data() as Map?)?['orgId'] == widget.orgId) {
        userDoc = direct;
      } else {
        final q = await FirebaseFirestore.instance.collection('users')
            .where('studentId', isEqualTo: uid).where('orgId', isEqualTo: widget.orgId).limit(1).get();
        if (q.docs.isNotEmpty) userDoc = q.docs.first;
      }
      if (userDoc == null) throw Exception('Student not found or not in your organization');

      final existing = await FirebaseFirestore.instance.collection('events')
          .doc(widget.eventDocId).collection('attendances')
          .where('studentId', isEqualTo: userDoc.id).get();
      if (existing.docs.isNotEmpty) {
        throw Exception('${(userDoc.data() as Map)['name'] ?? 'Student'} already marked');
      }

      String status = 'present';
      try {
        final s = DateFormat.jm().parse(widget.event!.startTime);
        final startDt = DateTime(widget.event!.date.year, widget.event!.date.month,
            widget.event!.date.day, s.hour, s.minute);
        if (DateTime.now().isAfter(startDt.add(const Duration(minutes: 15)))) status = 'late';
      } catch (_) {}

      final data = userDoc.data() as Map<String, dynamic>;
      await FirebaseFirestore.instance.collection('events').doc(widget.eventDocId)
          .collection('attendances').add({
        'studentId': userDoc.id, 'studentName': data['name'] ?? data['email'] ?? 'Unknown',
        'studentEmail': data['email'] ?? '', 'program': data['program'] ?? 'N/A',
        'yearLevel': data['yearLevel'] ?? '', 'timestamp': FieldValue.serverTimestamp(),
        'status': status, 'method': isManual ? 'manual' : 'qr',
      });

      await activity_log.ActivityLogger.log(
        action: 'mark_attendance', module: 'attendance',
        details: { 'orgId': widget.orgId, 'eventId': widget.eventDocId,
            'studentId': userDoc.id, 'status': status, 'method': isManual ? 'manual' : 'qr' },
      );
      if (mounted) _toast(context,
          '${data['name'] ?? 'Student'} marked ${status.toUpperCase()} ${status == 'late' ? '⏰' : '✓'}');
    } catch (e) {
      if (mounted) _toast(context, e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Future<void> _onScan(BarcodeCapture cap) async {
    if (!_scanning) return;
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || code == _lastCode) return;
    _lastCode = code;
    setState(() => _scanning = false);
    await _markAttendance(code);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() { _scanning = true; _lastCode = ''; });
  }

  Future<void> _toggleActive(bool currentlyActive) async {
    if (widget.eventDocId == null) return;
    if (!currentlyActive && !_isEventDay) {
      throw Exception('Attendance can only be opened on the day of the event.');
    }
    await FirebaseFirestore.instance.collection('events').doc(widget.eventDocId).update({
      'isActive': !currentlyActive,
      if (!currentlyActive) 'startedAt': FieldValue.serverTimestamp(),
      if (currentlyActive) 'endedAt': FieldValue.serverTimestamp(),
    });
    if (mounted) _toast(context, currentlyActive ? 'Attendance closed' : 'Attendance opened — scanning enabled');
  }

  List<QueryDocumentSnapshot> _filterAttendanceDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      if (_query.isNotEmpty) {
        final name = (m['studentName'] ?? '').toString().toLowerCase();
        final id = (m['studentId'] ?? '').toString().toLowerCase();
        if (!name.contains(_query) && !id.contains(_query)) return false;
      }
      if (_statusFilter != 'All' && m['status'] != _statusFilter) return false;
      return true;
    }).toList();
  }

  List<QueryDocumentSnapshot> _filterRegistrantDocs(List<QueryDocumentSnapshot> regs, List<QueryDocumentSnapshot> attDocs) {
    final attMap = {
      for (final d in attDocs)
        (d.data() as Map)['studentId']?.toString() ?? '': (d.data() as Map)['status']?.toString() ?? 'absent'
    };
    return regs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      if (_query.isNotEmpty) {
        final name = (m['studentName'] ?? '').toString().toLowerCase();
        final id = (m['studentId'] ?? '').toString().toLowerCase();
        if (!name.contains(_query) && !id.contains(_query)) return false;
      }
      final status = attMap[(m['studentId'] ?? '').toString()] ?? 'absent';
      if (_statusFilter != 'All' && status != _statusFilter) return false;
      return true;
    }).toList();
  }

  Future<void> _exportAttendanceCsv(List<QueryDocumentSnapshot> docs) async {
    final rows = [
      ['Student Name', 'Student ID', 'Program', 'Year Level', 'Time In', 'Status', 'Method'],
      ...docs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final ts = (m['timestamp'] as Timestamp?)?.toDate();
        return [
          m['studentName'] ?? '',
          m['studentId'] ?? '',
          m['program'] ?? '',
          m['yearLevel'] ?? '',
          ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts) : '',
          m['status'] ?? '',
          m['method'] ?? 'qr',
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await FileSaver.instance.saveAs(
      name: 'attendance_${(widget.event?.title ?? 'export').replaceAll(' ', '_')}',
      bytes: Uint8List.fromList(utf8.encode(csv)), file: 'csv', mimeType: MimeType.csv,
    );
    if (mounted) _toast(context, 'Exported ${docs.length} records');
  }

  Future<void> _exportRegistrantCsv(List<QueryDocumentSnapshot> regs, List<QueryDocumentSnapshot> attDocs) async {
    final attMap = {
      for (final d in attDocs)
        (d.data() as Map)['studentId']?.toString() ?? '': (d.data() as Map)['status']?.toString() ?? 'absent'
    };
    final rows = [
      ['Student Name', 'Student ID', 'Program', 'Year Level', 'Registered At', 'Status'],
      ...regs.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final ts = (m['createdAt'] as Timestamp?)?.toDate();
        final status = attMap[(m['studentId'] ?? '').toString()] ?? 'absent';
        return [
          m['studentName'] ?? '',
          m['studentId'] ?? '',
          m['program'] ?? '',
          m['yearLevel'] ?? '',
          ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts) : '',
          status,
        ];
      }),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await FileSaver.instance.saveAs(
      name: 'registrants_${(widget.event?.title ?? 'export').replaceAll(' ', '_')}',
      bytes: Uint8List.fromList(utf8.encode(csv)), file: 'csv', mimeType: MimeType.csv,
    );
    if (mounted) _toast(context, 'Exported ${regs.length} records');
  }

  Future<void> _exportPdf({required String title, required List<String> headers, required List<List<String>> rows, required String filePrefix}) async {
    final pdfBytes = await OrgExportPdf.generateTablePdf(
      title: title,
      headers: headers,
      rows: rows,
    );
    await FileSaver.instance.saveAs(
      name: filePrefix,
      bytes: pdfBytes,
      file: 'pdf',
      mimeType: MimeType.pdf,
    );
    if (mounted) _toast(context, 'PDF exported successfully');
  }

  Future<void> _exportAttendancePdf(List<QueryDocumentSnapshot> docs) async {
    final rows = docs.map<List<String>>((d) {
      final m = d.data() as Map<String, dynamic>;
      final ts = (m['timestamp'] as Timestamp?)?.toDate();
      return <String>[
        m['studentName'] ?? '',
        m['studentId'] ?? '',
        m['program'] ?? '',
        m['yearLevel'] ?? '',
        ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts) : '',
        m['status'] ?? '',
        m['method'] ?? 'qr',
      ];
    }).toList();
    await _exportPdf(
      title: 'Attendance Report',
      headers: ['Student Name', 'Student ID', 'Program', 'Year Level', 'Time In', 'Status', 'Method'],
      rows: rows,
      filePrefix: 'attendance_${(widget.event?.title ?? 'export').replaceAll(' ', '_')}',
    );
  }

  Future<void> _exportRegistrantPdf(List<QueryDocumentSnapshot> regs, List<QueryDocumentSnapshot> attDocs) async {
    final attMap = {
      for (final d in attDocs)
        (d.data() as Map)['studentId']?.toString() ?? '': (d.data() as Map)['status']?.toString() ?? 'absent'
    };
    final rows = regs.map<List<String>>((d) {
      final m = d.data() as Map<String, dynamic>;
      final ts = (m['createdAt'] as Timestamp?)?.toDate();
      final status = attMap[(m['studentId'] ?? '').toString()] ?? 'absent';
      return <String>[
        m['studentName'] ?? '',
        m['studentId'] ?? '',
        m['program'] ?? '',
        m['yearLevel'] ?? '',
        ts != null ? DateFormat('yyyy-MM-dd HH:mm').format(ts) : '',
        status,
      ];
    }).toList();
    await _exportPdf(
      title: 'Registrant Report',
      headers: ['Student Name', 'Student ID', 'Program', 'Year Level', 'Registered At', 'Status'],
      rows: rows,
      filePrefix: 'registrants_${(widget.event?.title ?? 'export').replaceAll(' ', '_')}',
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<DocumentSnapshot>(
      stream: _eventStream,
      builder: (ctx, evSnap) {
        final active = _isActive(evSnap.data);
        return StreamBuilder<QuerySnapshot>(
          stream: _attStream,
          builder: (ctx, attSnap) {
            final attDocs = attSnap.data?.docs ?? [];
            final present = attDocs.where((d) => (d.data() as Map)['status'] == 'present').length;
            final late    = attDocs.where((d) => (d.data() as Map)['status'] == 'late').length;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildStatsRow(attDocs.length, present, late),
                const SizedBox(height: 20),
                if (widget.event != null) ...[
                  _buildEventBanner(active, evSnap.data),
                  const SizedBox(height: 16),
                ],
                _buildInputModeRow(active, attSnap.data),
                const SizedBox(height: 14),
                if (_inputMode == 0) _buildQRPanel(active, attSnap.data)
                else if (_inputMode == 1) _buildManualPanel(active)
                else _buildRollCallPanel(attSnap.data),
                const SizedBox(height: 24),
                _buildSubTabToolbar(attDocs.cast()),
                const SizedBox(height: 12),
                _subTab == 0
                    ? _AttendanceTable(docs: attDocs.cast(), query: _query, statusFilter: _statusFilter)
                    : _RegistrantsTable(stream: _regStream, attendanceDocs: attDocs.cast(), query: _query, statusFilter: _statusFilter),
              ]),
            );
          },
        );
      },
    );
  }

  Widget _buildStatsRow(int total, int present, int late) {
    return Row(children: [
      _StatCard(label: 'Total Check-ins', value: '$total', icon: Icons.people_alt_rounded, color: UpriseColors.primaryDark),
      const SizedBox(width: 14),
      _StatCard(label: 'Present', value: '$present', icon: Icons.check_circle_rounded, color: const Color(0xFF059669)),
      const SizedBox(width: 14),
      _StatCard(label: 'Late', value: '$late', icon: Icons.schedule_rounded, color: const Color(0xFFD97706)),
      const SizedBox(width: 14),
      _StatCard(label: 'Absent', value: '${total - present - late}', icon: Icons.cancel_rounded, color: const Color(0xFFDC2626)),
    ]);
  }

  Widget _buildEventBanner(bool active, DocumentSnapshot? evDoc) {
    final e = widget.event!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: active ? const Color(0xFF059669).withOpacity(0.35) : const Color(0xFFEBEEF3)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.09),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.event_rounded, size: 22, color: UpriseColors.primaryDark),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(e.title,
              style: GoogleFonts.beVietnamPro(fontSize: 14.5, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.location_on_outlined, size: 12, color: const Color(0xFFB0BAC8)),
            const SizedBox(width: 3),
            Text(e.location, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8))),
            const SizedBox(width: 12),
            Icon(Icons.schedule_outlined, size: 12, color: const Color(0xFFB0BAC8)),
            const SizedBox(width: 3),
            Text('${e.startTime} – ${e.endTime}', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8))),
            const SizedBox(width: 12),
            Icon(Icons.calendar_today_outlined, size: 12, color: const Color(0xFFB0BAC8)),
            const SizedBox(width: 3),
            Text(DateFormat('MMM dd, yyyy').format(e.date), style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8))),
          ]),
        ])),
        const SizedBox(width: 14),
        _PrimaryButton(
          label: active ? 'Close Attendance' : widget.eventDocId == null ? 'Sync Pending' : _isEventDay ? 'Open Attendance' : 'Open on Event Day',
          icon: active ? Icons.stop_circle_outlined : Icons.play_circle_outline_rounded,
          color: active ? const Color(0xFFDC2626) : UpriseColors.primaryDark,
          onPressed: active ? () => _toggleActive(active) : widget.eventDocId == null || !_isEventDay ? null : () => _toggleActive(active),
        ),
      ]),
    );
  }

  Widget _buildInputModeRow(bool active, QuerySnapshot? attSnap) {
    return Row(children: [
      for (final (i, lbl, ico) in [
        (0, 'QR Scan', Icons.qr_code_scanner_rounded),
        (1, 'Manual Entry', Icons.badge_outlined),
        (2, 'Roll Call', Icons.list_alt_rounded),
      ])
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: _ModeChip(label: lbl, icon: ico, selected: _inputMode == i,
              onTap: () => setState(() => _inputMode = i)),
        ),
    ]);
  }

  Widget _buildQRPanel(bool active, QuerySnapshot? attSnap) {
    final recent = (attSnap?.docs ?? []).reversed.take(3).toList();
    return SizedBox(
      height: 216,
      child: Row(children: [
        Expanded(child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_DS.radiusLg),
            border: Border.all(color: active ? const Color(0xFF059669).withOpacity(0.4) : const Color(0xFFEBEEF3)),
            boxShadow: _DS.cardShadow,
          ),
          child: Stack(children: [
            Positioned.fill(child: active
                ? MobileScanner(controller: _scanner, onDetect: _onScan)
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: [const Color(0xFF0F172A), const Color(0xFF1E293B)],
                      ),
                    ),
                    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                            color: UpriseColors.primaryDark.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16)),
                        child: Icon(Icons.qr_code_scanner_rounded, size: 32,
                            color: UpriseColors.primaryDark.withOpacity(0.6)),
                      ),
                      const SizedBox(height: 12),
                      Text('Open attendance to enable scanning',
                          style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: const Color(0xFF64748B)),
                          textAlign: TextAlign.center),
                    ])))),
            Positioned(bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.65)],
                  ),
                ),
                child: Row(children: [
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(
                          color: active ? const Color(0xFF059669) : const Color(0xFF6B7280),
                          shape: BoxShape.circle,
                          boxShadow: active ? [BoxShadow(color: const Color(0xFF059669).withOpacity(0.5), blurRadius: 4)] : [])),
                  const SizedBox(width: 7),
                  Text(active ? (_scanning ? 'Scanning…' : 'Processing…') : 'Scanner offline',
                      style: GoogleFonts.beVietnamPro(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w500)),
                  if (active) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: () => setState(() => _scanning = !_scanning),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(_scanning ? 'Pause' : 'Resume',
                            style: GoogleFonts.beVietnamPro(
                                fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ]),
              )),
          ]),
        )),
        const SizedBox(width: 14),
        SizedBox(width: 248, child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_DS.radiusLg),
            border: Border.all(color: const Color(0xFFEBEEF3)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF9AA5B4), shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text('RECENT CHECK-INS',
                  style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700,
                      color: const Color(0xFF94A3B8), letterSpacing: 0.8)),
            ]),
            const SizedBox(height: 12),
            if (recent.isEmpty)
              Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inbox_outlined, size: 28, color: const Color(0xFFD1D5DB)),
                const SizedBox(height: 6),
                Text('No check-ins yet', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFFB0BAC8))),
              ])))
            else
              Expanded(child: ListView.separated(
                itemCount: recent.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F8)),
                itemBuilder: (_, i) {
                  final d = recent[i].data() as Map<String, dynamic>;
                  final ts = (d['timestamp'] as Timestamp?)?.toDate();
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(children: [
                      _StudentAvatar(name: d['studentName'] ?? '', size: 30),
                      const SizedBox(width: 9),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(d['studentName'] ?? '—',
                            style: GoogleFonts.beVietnamPro(fontSize: 12.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C)),
                            overflow: TextOverflow.ellipsis),
                        Text(ts != null ? DateFormat('hh:mm a').format(ts) : '—',
                            style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFFB0BAC8))),
                      ])),
                      _attBadge(d['status'] ?? 'present'),
                    ]),
                  );
                },
              )),
          ]),
        )),
      ]),
    );
  }

  Widget _buildManualPanel(bool active) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: const Color(0xFFEBEEF3)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionLabel('Manual Attendance Entry', icon: Icons.badge_outlined),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _manualCtrl,
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: _DS.inputDeco('Student ID or UID', hint: 'Enter ID and press Enter', icon: Icons.badge_outlined),
              onSubmitted: (v) async {
                if (v.trim().isEmpty || !active) return;
                await _markAttendance(v.trim(), isManual: true);
                _manualCtrl.clear();
              },
            ),
          ),
          const SizedBox(width: 12),
          _PrimaryButton(
            label: 'Mark Present',
            icon: Icons.check_rounded,
            color: UpriseColors.primaryDark,
            onPressed: !active ? null : () async {
              final v = _manualCtrl.text.trim();
              if (v.isEmpty) return;
              await _markAttendance(v, isManual: true);
              _manualCtrl.clear();
            },
          ),
        ]),
        const SizedBox(height: 14),
        _InfoBanner(
          color: const Color(0xFFEFF6FF), border: const Color(0xFFBFD7FF),
          icon: Icons.info_outline_rounded, iconColor: const Color(0xFF2563EB),
          text: 'Enter the student\'s ID number or system UID. Attendance opens 15 min before start time. Check-ins after 15 min grace period are marked LATE.',
          textColor: const Color(0xFF1D4ED8),
        ),
      ]),
    );
  }

  Widget _buildRollCallPanel(QuerySnapshot? attSnap) {
    final marked = (attSnap?.docs ?? [])
        .map((d) => (d.data() as Map)['studentId']?.toString() ?? '').toSet();
    return StreamBuilder<QuerySnapshot>(
      stream: widget.eventDocId == null ? null
          : FirebaseFirestore.instance.collection('registrations')
              .where('eventId', isEqualTo: widget.eventDocId).snapshots(),
      builder: (ctx, snap) {
        final regs = snap.data?.docs ?? [];
        return Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_DS.radiusLg),
            border: Border.all(color: const Color(0xFFEBEEF3)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('Roll Call — Registered Participants', icon: Icons.list_alt_rounded),
            if (regs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No registered participants found.',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFFB0BAC8))),
              )
            else
              ...regs.map((reg) {
                final d = reg.data() as Map<String, dynamic>;
                final sid = (d['studentId'] ?? '') as String;
                final isMarked = marked.contains(sid);
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F8)))),
                  child: Row(children: [
                    _StudentAvatar(name: d['studentName'] ?? '', size: 36),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['studentName'] ?? '—',
                          style: GoogleFonts.beVietnamPro(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C))),
                      Text(d['studentId'] ?? '',
                          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8))),
                    ])),
                    isMarked ? _attBadge('present')
                        : _PrimaryButton(
                            label: 'Mark',
                            icon: Icons.check_rounded,
                            color: UpriseColors.primaryDark,
                            onPressed: () => _markAttendance(sid, isManual: true),
                            compact: true,
                          ),
                  ]),
                );
              }),
          ]),
        );
      },
    );
  }

  Widget _buildSubTabToolbar(List<QueryDocumentSnapshot> attDocs) {
    return StreamBuilder<QuerySnapshot?>(
      stream: _regStream,
      builder: (ctx, regSnap) {
        final regDocs = regSnap.data?.docs.cast<QueryDocumentSnapshot>() ?? [];
        final filteredAttDocs = _filterAttendanceDocs(attDocs);
        final filteredRegDocs = _filterRegistrantDocs(regDocs, attDocs);
        final canExport = _subTab == 0 ? filteredAttDocs.isNotEmpty : filteredRegDocs.isNotEmpty;

        return Row(children: [
          _SubTab('Attendance', _subTab == 0, () => setState(() => _subTab = 0)),
          const SizedBox(width: 8),
          _SubTab('Registered Participants', _subTab == 1, () => setState(() => _subTab = 1)),
          const Spacer(),
          SizedBox(
            width: 230, height: 40,
            child: TextField(
              controller: _search,
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: _DS.searchDeco('Search name or ID…'),
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
            ),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(value: _statusFilter, items: const ['All', 'present', 'late', 'absent'],
              hint: 'Status', onChanged: (v) => setState(() => _statusFilter = v ?? 'All')),
          const SizedBox(width: 10),
          AdminExportButton(
            enabled: canExport,
            label: 'Export',
            onSelected: (choice) {
              if (_subTab == 0) {
                if (choice == 'csv') _exportAttendanceCsv(filteredAttDocs);
                if (choice == 'pdf') _exportAttendancePdf(filteredAttDocs);
              } else {
                if (choice == 'csv') _exportRegistrantCsv(filteredRegDocs, attDocs);
                if (choice == 'pdf') _exportRegistrantPdf(filteredRegDocs, attDocs);
              }
            },
          ),
        ]);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceTable extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final String query, statusFilter;
  const _AttendanceTable({required this.docs, required this.query, required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    final filtered = docs.where((d) {
      final m = d.data() as Map<String, dynamic>;
      if (query.isNotEmpty) {
        final name = (m['studentName'] ?? '').toString().toLowerCase();
        final id   = (m['studentId']   ?? '').toString().toLowerCase();
        if (!name.contains(query) && !id.contains(query)) return false;
      }
      if (statusFilter != 'All' && m['status'] != statusFilter) return false;
      return true;
    }).toList();

    return _DataTable(
      columns: const [
        _Col('STUDENT', 4), _Col('STUDENT ID', 2), _Col('PROGRAM', 3),
        _Col('YEAR', 2),    _Col('TIME IN', 2),    _Col('METHOD', 2), _Col('STATUS', 2),
      ],
      isEmpty: filtered.isEmpty,
      emptyMessage: docs.isEmpty
          ? 'No check-ins yet. Open attendance and start scanning.'
          : 'No records match your filter.',
      footer: '${docs.length} attendee${docs.length == 1 ? '' : 's'} recorded',
      rows: filtered.map((d) {
        final m = d.data() as Map<String, dynamic>;
        final ts = (m['timestamp'] as Timestamp?)?.toDate();
        return _TableRow(
          cells: [
            _NameCell(m['studentName'] ?? '—', m['studentEmail'] ?? ''),
            _IdText(m['studentId'] ?? '—'),
            Text(m['program'] ?? 'N/A',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
                overflow: TextOverflow.ellipsis),
            Text(m['yearLevel'] ?? '—',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
            Text(ts != null ? DateFormat('hh:mm a').format(ts) : '—',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C))),
            _MethodBadge(m['method'] ?? 'qr'),
            _attBadge(m['status'] ?? 'present'),
          ],
          flex: const [4, 2, 3, 2, 2, 2, 2],
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REGISTRANTS TABLE
// ─────────────────────────────────────────────────────────────────────────────
class _RegistrantsTable extends StatelessWidget {
  final Stream<QuerySnapshot>? stream;
  final List<QueryDocumentSnapshot> attendanceDocs;
  final String query, statusFilter;
  const _RegistrantsTable({required this.stream, required this.attendanceDocs,
      required this.query, required this.statusFilter});

  @override
  Widget build(BuildContext context) {
    if (stream == null) return _EmptyState('Select a synced event to view registered participants.');
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
        }
        final regs = snap.data?.docs ?? [];
        final attMap = {
          for (final d in attendanceDocs)
            (d.data() as Map)['studentId']?.toString() ?? '':
                (d.data() as Map)['status']?.toString() ?? 'present'
        };
        final filtered = regs.where((d) {
          final m = d.data() as Map<String, dynamic>;
          if (query.isNotEmpty) {
            final name = (m['studentName'] ?? '').toString().toLowerCase();
            final id   = (m['studentId']   ?? '').toString().toLowerCase();
            if (!name.contains(query) && !id.contains(query)) return false;
          }
          final status = attMap[(m['studentId'] ?? '').toString()] ?? 'absent';
          if (statusFilter != 'All' && status != statusFilter) return false;
          return true;
        }).toList();

        return _DataTable(
          columns: const [
            _Col('STUDENT', 4), _Col('STUDENT ID', 2), _Col('PROGRAM', 3),
            _Col('REGISTERED AT', 3), _Col('STATUS', 2),
          ],
          isEmpty: filtered.isEmpty,
          emptyMessage: regs.isEmpty ? 'No registered participants yet.' : 'No records match your filter.',
          footer: '${regs.length} registered participant${regs.length == 1 ? '' : 's'}',
          rows: filtered.map((d) {
            final m = d.data() as Map<String, dynamic>;
            final sid = (m['studentId'] ?? '').toString();
            final status = attMap[sid] ?? 'absent';
            final reg = (m['createdAt'] as Timestamp?)?.toDate();
            return _TableRow(
              cells: [
                _NameCell(m['studentName'] ?? '—', m['studentEmail'] ?? ''),
                _IdText(sid),
                Text(m['program'] ?? 'N/A',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
                    overflow: TextOverflow.ellipsis),
                Text(reg != null ? DateFormat('MMM dd, hh:mm a').format(reg) : '—',
                    style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: const Color(0xFF64748B))),
                _attBadge(status),
              ],
              flex: const [4, 2, 3, 3, 2],
            );
          }).toList(),
        );
      },
    );
  }
}

// =============================================================================
// CERTIFICATES TAB
// =============================================================================
class CertificatesTab extends StatefulWidget {
  final String orgId;
  final EventModel? event;
  final String? eventDocId;
  const CertificatesTab({super.key, required this.orgId, this.event, this.eventDocId});

  @override
  State<CertificatesTab> createState() => _CertificatesTabState();
}

class _CertificatesTabState extends State<CertificatesTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _search = TextEditingController();
  String _query  = '';
  String _filter = 'All';
  int    _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('certificates')
      .where('orgId', isEqualTo: widget.orgId)
      .orderBy('issuedAt', descending: true)
      .snapshots();

  Future<void> _delete(CertRecord r) async {
    await FirebaseFirestore.instance.collection('certificates').doc(r.id).delete();
    await activity_log.ActivityLogger.log(
      action: 'delete_certificate', module: 'certificates',
      details: {'certId': r.id, 'eventName': r.eventName},
    );
    if (mounted) _toast(context, 'Certificate deleted');
  }

  Future<void> _exportCertificatesCsv(List<CertRecord> records) async {
    final rows = [
      ['Certificate ID', 'Event Name', 'Organization', 'Type', 'Status', 'Template', 'Recipients', 'Date Issued'],
      ...records.map((r) => [
        r.certId,
        r.eventName,
        r.org,
        r.type,
        r.status,
        r.templateType,
        r.recipients.toString(),
        DateFormat('yyyy-MM-dd HH:mm').format(r.date),
      ]),
    ];
    final csv = const ListToCsvConverter().convert(rows);
    await FileSaver.instance.saveAs(
      name: 'certificates_${(widget.event?.title ?? 'export').replaceAll(' ', '_')}',
      bytes: Uint8List.fromList(utf8.encode(csv)), file: 'csv', mimeType: MimeType.csv,
    );
    if (mounted) _toast(context, 'Exported ${records.length} records');
  }

  Future<void> _exportCertificatesPdf(List<CertRecord> records) async {
    final rows = records.map((r) => [
      r.certId,
      r.eventName,
      r.org,
      r.type,
      r.status,
      r.templateType,
      r.recipients.toString(),
      DateFormat('yyyy-MM-dd HH:mm').format(r.date),
    ]).toList();
    await _exportPdf(
      title: 'Certificates Report',
      headers: ['Certificate ID', 'Event Name', 'Organization', 'Type', 'Status', 'Template', 'Recipients', 'Date Issued'],
      rows: rows,
      filePrefix: 'certificates_${(widget.event?.title ?? 'export').replaceAll(' ', '_')}',
    );
  }

  Future<void> _exportPdf({required String title, required List<String> headers, required List<List<String>> rows, required String filePrefix}) async {
    final pdfBytes = await OrgExportPdf.generateTablePdf(
      title: title,
      headers: headers,
      rows: rows,
    );
    await FileSaver.instance.saveAs(
      name: filePrefix,
      bytes: pdfBytes,
      file: 'pdf',
      mimeType: MimeType.pdf,
    );
    if (mounted) _toast(context, 'PDF exported successfully');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<QuerySnapshot>(
      stream: _stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        var docs = (snap.data?.docs ?? []).cast<QueryDocumentSnapshot>();
        if (_filter != 'All') {
          docs = docs.where((d) => (d.data() as Map)['status']?.toString().toLowerCase() == _filter.toLowerCase()).toList();
        }
        if (_query.isNotEmpty) {
          docs = docs.where((d) {
            final m = d.data() as Map<String, dynamic>;
            return (m['eventName'] ?? '').toString().toLowerCase().contains(_query) ||
                   (m['organization'] ?? '').toString().toLowerCase().contains(_query);
          }).toList();
        }
        final records = docs.map((d) => CertRecord.fromDoc(d)).toList();
        final totalRec   = records.fold<int>(0, (s, r) => s + r.recipients);
        final distributed = records.where((r) => r.status == 'distributed').length;
        final pending     = records.where((r) => r.status == 'pending').length;
        final totalPages  = records.isEmpty ? 1 : (records.length / _pageSize).ceil();
        final safePage    = _currentPage.clamp(1, totalPages);
        final start       = (safePage - 1) * _pageSize;
        final end         = (start + _pageSize).clamp(0, records.length);
        final pageItems   = records.isEmpty ? <CertRecord>[] : records.sublist(start, end);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _buildStatsRow(records.length, totalRec, distributed, pending),
            const SizedBox(height: 20),
            _buildToolbar(records),
            const SizedBox(height: 16),
            _buildTable(pageItems, records.length, totalPages, start, end),
          ]),
        );
      },
    );
  }

  Widget _buildStatsRow(int total, int totalRec, int distributed, int pending) {
    return Row(children: [
      _StatCard(label: 'Total Certificates', value: '$total', icon: Icons.card_membership_outlined, color: UpriseColors.primaryDark),
      const SizedBox(width: 14),
      _StatCard(label: 'Total Recipients', value: '$totalRec', icon: Icons.people_outline_rounded, color: const Color(0xFF0891B2)),
      const SizedBox(width: 14),
      _StatCard(label: 'Distributed', value: '$distributed', icon: Icons.assignment_turned_in_outlined, color: const Color(0xFF059669)),
      const SizedBox(width: 14),
      _StatCard(label: 'Pending', value: '$pending', icon: Icons.pending_outlined, color: const Color(0xFFD97706)),
    ]);
  }

  Widget _buildToolbar(List<CertRecord> records) {
    return Row(children: [
      Expanded(child: SizedBox(height: 40,
          child: TextField(controller: _search, style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: _DS.searchDeco('Search by event name or organization…'),
              onChanged: (v) => setState(() { _query = v.toLowerCase(); _currentPage = 1; })))),
      const SizedBox(width: 10),
      if (widget.event != null) ...[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: UpriseColors.primaryDark.withOpacity(0.06),
            borderRadius: BorderRadius.circular(_DS.radiusSm),
            border: Border.all(color: UpriseColors.primaryDark.withOpacity(0.15)),
          ),
          child: Row(children: [
            Icon(Icons.event_rounded, size: 14, color: UpriseColors.primaryDark),
            const SizedBox(width: 7),
            Text(widget.event!.title,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark)),
          ]),
        ),
        const SizedBox(width: 10),
      ],
      _FilterDropdown(value: _filter, items: const ['All', 'distributed', 'pending', 'draft'],
          hint: 'Status', onChanged: (v) => setState(() { _filter = v ?? 'All'; _currentPage = 1; })),
      const SizedBox(width: 10),
      AdminExportButton(
        enabled: records.isNotEmpty,
        label: 'Export',
        onSelected: (choice) {
          if (choice == 'csv') _exportCertificatesCsv(records);
          if (choice == 'pdf') _exportCertificatesPdf(records);
        },
      ),
      const SizedBox(width: 10),
      _PrimaryButton(
        label: 'Generate Certificate',
        icon: Icons.add_rounded,
        color: UpriseColors.primaryDark,
        onPressed: () => showDialog(
          context: context, barrierDismissible: false, barrierColor: Colors.black54,
          builder: (_) => _CertGenerateModal(orgId: widget.orgId, event: widget.event, eventDocId: widget.eventDocId),
        ),
      ),
    ]);
  }

  Widget _buildTable(List<CertRecord> pageItems, int total, int totalPages, int start, int end) {
    return _DataTable(
      columns: const [
        _Col('CERT ID', 2), _Col('EVENT NAME', 3), _Col('ORGANIZATION', 2),
        _Col('TYPE', 2),    _Col('DATE ISSUED', 2), _Col('RECIP.', 1),
        _Col('STATUS', 2),  _Col('ACTIONS', 2, rightAlign: true),
      ],
      isEmpty: pageItems.isEmpty,
      emptyMessage: total == 0
          ? 'No certificates yet. Click "Generate Certificate" to create one.'
          : 'No certificates match your search or filter.',
      footer: null,
      customFooter: _buildFooter(total, totalPages, start, end),
      rows: pageItems.map((r) => _CertRow(
        record: r,
        onView: () => showDialog(context: context, barrierColor: Colors.black54,
            builder: (_) => _CertPreviewDialog(record: r)),
        onEdit: () => showDialog(context: context, barrierDismissible: false, barrierColor: Colors.black54,
            builder: (_) => _CertGenerateModal(orgId: widget.orgId, event: widget.event, eventDocId: widget.eventDocId, existing: r)),
        onDelete: () => showDialog(context: context, barrierColor: Colors.black54,
            builder: (_) => _ConfirmDeleteDialog(name: r.certId, onConfirm: () => _delete(r))),
      )).toList(),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage  = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEBEEF3))),
        color: Color(0xFFF7F8FA),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusMd)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
          'Showing ${total == 0 ? 0 : start + 1}–$end of $total certificates',
          style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8)),
        ),
        Row(children: [
          _PageButton(icon: Icons.chevron_left_rounded, enabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
          const SizedBox(width: 4),
          ...pages.map((p) => _PageNumButton(page: p, isActive: p == _currentPage, onTap: () => setState(() => _currentPage = p))),
          if (lastPage < totalPages) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text('…', style: GoogleFonts.beVietnamPro(color: const Color(0xFF94A3B8), fontSize: 12)),
            ),
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
// CERT ROW
// ─────────────────────────────────────────────────────────────────────────────
class _CertRow extends _TableRow {
  final CertRecord record;
  final VoidCallback onView, onEdit, onDelete;
  _CertRow({required this.record, required this.onView, required this.onEdit, required this.onDelete})
      : super(
          flex: const [2, 3, 2, 2, 2, 1, 2, 2],
          cells: [
            Text(record.certId,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
            Text(record.eventName,
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500, color: const Color(0xFF1A202C)),
                overflow: TextOverflow.ellipsis),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark.withOpacity(0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(record.org,
                  style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.primaryDark),
                  overflow: TextOverflow.ellipsis),
            ),
            Text(record.type, style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: const Color(0xFF64748B))),
            Text(DateFormat('MMM d, yyyy').format(record.date), style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: const Color(0xFF64748B))),
            Text('${record.recipients}',
                style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
            _certBadge(record.status),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _ActionIconButton(icon: Icons.visibility_outlined, tooltip: 'View', color: const Color(0xFF2563EB), onTap: onView),
              const SizedBox(width: 2),
              _ActionIconButton(icon: Icons.edit_outlined, tooltip: 'Edit', color: UpriseColors.primaryDark, onTap: onEdit),
              const SizedBox(width: 2),
              _ActionIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Delete', color: const Color(0xFFDC2626), onTap: onDelete),
            ]),
          ],
          onTap: onView,
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERATE / EDIT CERTIFICATE MODAL
// ─────────────────────────────────────────────────────────────────────────────
class _CertGenerateModal extends StatefulWidget {
  final String orgId;
  final EventModel? event;
  final String? eventDocId;
  final CertRecord? existing;
  const _CertGenerateModal({required this.orgId, this.event, this.eventDocId, this.existing});

  @override
  State<_CertGenerateModal> createState() => _CertGenerateModalState();
}

class _CertGenerateModalState extends State<_CertGenerateModal> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _orgCtrl   = TextEditingController();
  final _dateCtrl  = TextEditingController();
  final _sigCtrl   = TextEditingController();

  String  _template    = 'Classic';
  String? _templateUrl;
  String? _selEventId, _selEventDocId;
  bool    _evaluated = false;
  bool    _loading   = false;
  int     _recipients = 0;

  static const _templates = ['Classic', 'Modern', 'Vibrant'];
  static const Map<String, Map<String, Color>> _themes = {
    'Classic': {'bg': Color(0xFFFDF6EC), 'accent': Color(0xFFB45309), 'text': Color(0xFF1E293B)},
    'Modern':  {'bg': Color(0xFF1E1205), 'accent': Color(0xFFF59E0B), 'text': Colors.white},
    'Vibrant': {'bg': Color(0xFFFFF7ED), 'accent': Color(0xFFEA580C), 'text': Color(0xFF1E293B)},
  };

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('MM/dd/yyyy').format(DateTime.now());
    if (widget.existing != null) {
      _titleCtrl.text = widget.existing!.eventName;
      _orgCtrl.text   = widget.existing!.org;
      _dateCtrl.text  = DateFormat('MM/dd/yyyy').format(widget.existing!.date);
      _template    = widget.existing!.templateType;
      _templateUrl = widget.existing!.templateUrl;
    } else if (widget.event != null) {
      _titleCtrl.text = widget.event!.title;
      _selEventId     = widget.event!.id;
      _selEventDocId  = widget.eventDocId;
      _loadEventInfo(widget.event!.id);
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _orgCtrl.dispose(); _dateCtrl.dispose(); _sigCtrl.dispose(); super.dispose(); }

  Future<void> _loadEventInfo(String proposalId) async {
    try {
      final prop = await FirebaseFirestore.instance.collection('event_proposals').doc(proposalId).get();
      final data = prop.data() as Map<String, dynamic>?;
      if (data == null || !mounted) return;
      setState(() => _evaluated = data['evaluated'] == true);
      if (_selEventDocId == null) {
        final q = await FirebaseFirestore.instance.collection('events')
            .where('createdFromProposalId', isEqualTo: proposalId).limit(1).get();
        if (mounted && q.docs.isNotEmpty) {
          final docId = q.docs.first.id;
          setState(() => _selEventDocId = docId);
          final att = await FirebaseFirestore.instance.collection('events')
              .doc(docId).collection('attendances').get();
          if (mounted) setState(() => _recipients = att.docs.length);
        }
      }
    } catch (_) {}
  }

  Future<void> _submit(bool distribute) async {
    if (_formKey.currentState?.validate() != true) return;
    setState(() => _loading = true);
    try {
      final payload = <String, dynamic>{
        'orgId': widget.orgId, 'eventName': _titleCtrl.text.trim(),
        'organization': _orgCtrl.text.trim(), 'templateType': _template,
        'type': 'Participation', 'issuedAt': FieldValue.serverTimestamp(),
        'status': distribute ? 'distributed' : 'draft', 'recipients': _recipients,
        if (_templateUrl != null) 'templateFileUrl': _templateUrl,
        if (_selEventDocId != null) 'eventId': _selEventDocId,
      };
      if (widget.existing != null) {
        await FirebaseFirestore.instance.collection('certificates').doc(widget.existing!.id).update(payload);
      } else {
        await FirebaseFirestore.instance.collection('certificates').add(payload);
      }
      await activity_log.ActivityLogger.log(
        action: distribute ? 'distribute_cert' : 'draft_cert',
        module: 'certificates', details: {'orgId': widget.orgId},
      );
      if (mounted) { Navigator.pop(context); _toast(context, distribute ? 'Certificate distributed!' : 'Saved as draft'); }
    } catch (e) {
      if (mounted) _toast(context, 'Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importTemplate() async {
    final result = await showDialog<Map<String, String>?>(
        context: context, builder: (_) => _ImportTemplateModal(orgId: widget.orgId));
    if (result != null) setState(() { _template = result['name'] ?? _template; _templateUrl = result['url']; });
  }

  @override
  Widget build(BuildContext context) {
    final theme    = _themes[_template] ?? _themes['Classic']!;
    final canDistribute = _evaluated || widget.existing != null;
    final isEdit = widget.existing != null;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusXl)),
      elevation: 24,
      child: SizedBox(
        width: 840,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(_DS.radiusXl)),
            ),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isEdit ? 'Edit Certificate' : 'Generate Certificate',
                    style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                Text('Create and manage event participation certificates',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white.withOpacity(0.65))),
              ])),
              IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                  onPressed: _loading ? null : () => Navigator.pop(context)),
            ]),
          ),
          // Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(26),
              child: Form(
                key: _formKey,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Left: form
                  Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _sectionLabel('Event & Template', icon: Icons.event_outlined),
                        StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance.collection('event_proposals')
      .where('orgId', isEqualTo: widget.orgId)
      .where('status', isEqualTo: 'approved')
      .orderBy('date')
      .snapshots(),
  builder: (ctx, snap) {
    // I-filter manually dito
    var allEvents = snap.data?.docs ?? [];
    var events = allEvents.where((doc) {
  final data = doc.data() as Map<String, dynamic>;
  final issuesCert = data['issuesCertificate'];
  
  if (issuesCert == null) return false;
  if (issuesCert is bool) return issuesCert == true;
  if (issuesCert is String) return issuesCert.toLowerCase() == 'true';
  if (issuesCert is num) return issuesCert == 1;
  
  return false;
}).toList();
    
    return DropdownButtonFormField<String>(
      value: _selEventId,
      decoration: _DS.inputDeco('Select Event *', icon: Icons.event_rounded),
      style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)),
      hint: Text(events.isEmpty ? 'No eligible events' : 'Choose an approved event',
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFFB0BAC8))),
      items: events.map((doc) {
        final m = doc.data() as Map<String, dynamic>;
        return DropdownMenuItem(value: doc.id, child: Text(m['title'] ?? 'Untitled'));
      }).toList(),
      onChanged: (v) async {
        if (v == null) return;
        final doc = events.firstWhere((d) => d.id == v);
        final m = doc.data() as Map<String, dynamic>;
        setState(() { 
          _selEventId = v; 
          _titleCtrl.text = m['title'] ?? ''; 
          _evaluated = m['evaluated'] == true; 
          _selEventDocId = null; 
          _recipients = 0; 
        });
        _loadEventInfo(v);
      },
    );
  }),
                    const SizedBox(height: 14),
                    // Template selector
                    Row(children: [
                      for (final t in _templates)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _ModeChip(label: t, selected: _template == t && _templateUrl == null,
                              onTap: () => setState(() { _template = t; _templateUrl = null; })),
                        ),
                      _OutlineButton(label: 'Import', icon: Icons.upload_file_rounded, onPressed: _importTemplate, compact: true),
                    ]),
                    const SizedBox(height: 20),
                    _sectionLabel('Certificate Details', icon: Icons.description_outlined),
                    TextFormField(
                      controller: _titleCtrl, onChanged: (_) => setState(() {}),
                      decoration: _DS.inputDeco('Certificate Title *', hint: 'e.g., Certificate of Participation'),
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                      validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(child: TextFormField(
                        controller: _orgCtrl, onChanged: (_) => setState(() {}),
                        decoration: _DS.inputDeco('Organization *', icon: Icons.business_outlined),
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: TextFormField(
                        controller: _dateCtrl, readOnly: true, onChanged: (_) => setState(() {}),
                        decoration: _DS.inputDeco('Event Date *', icon: Icons.calendar_today_outlined),
                        style: GoogleFonts.beVietnamPro(fontSize: 13),
                        validator: (v) => v?.trim().isEmpty == true ? 'Required' : null,
                        onTap: () async {
                          final p = await showDatePicker(
                            context: context, initialDate: DateTime.now(),
                            firstDate: DateTime(2020), lastDate: DateTime(2030),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: UpriseColors.primaryDark)),
                              child: child!,
                            ),
                          );
                          if (p != null) setState(() => _dateCtrl.text = DateFormat('MM/dd/yyyy').format(p));
                        },
                      )),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sigCtrl,
                      decoration: _DS.inputDeco('Signatories', icon: Icons.draw_outlined),
                      style: GoogleFonts.beVietnamPro(fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (_selEventId != null)
                      _InfoBanner(
                        color: _evaluated ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                        border: _evaluated ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                        icon: _evaluated ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                        iconColor: _evaluated ? const Color(0xFF059669) : const Color(0xFFD97706),
                        text: _evaluated
                            ? 'Event has been evaluated — certificate distribution is unlocked.'
                            : 'Participants must complete the event evaluation before certificates can be distributed. You can still save a draft.',
                        textColor: _evaluated ? const Color(0xFF065F46) : const Color(0xFF92400E),
                      ),
                    if (_recipients > 0) ...[
                      const SizedBox(height: 10),
                      _InfoBanner(
                        color: const Color(0xFFEFF6FF), border: const Color(0xFFBFD7FF),
                        icon: Icons.group_rounded, iconColor: const Color(0xFF2563EB),
                        text: '$_recipients attendee${_recipients == 1 ? '' : 's'} detected from the attendance log.',
                        textColor: const Color(0xFF1D4ED8),
                      ),
                    ],
                  ])),
                  const SizedBox(width: 26),
                  // Right: live preview
                  Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _sectionLabel('Live Preview', icon: Icons.preview_outlined),
                    _CertPreview(
                      bg: theme['bg']!, accent: theme['accent']!, textColor: theme['text']!,
                      org: _orgCtrl.text.isNotEmpty ? _orgCtrl.text : 'Organization Name',
                      title: _titleCtrl.text.isNotEmpty ? _titleCtrl.text : 'Certificate of Participation',
                      date: _dateCtrl.text.isNotEmpty ? _dateCtrl.text : DateFormat('MMMM dd, yyyy').format(DateTime.now()),
                    ),
                  ])),
                ]),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFEBEEF3))),
              color: Color(0xFFF7F8FA),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusXl)),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              _OutlineButton(label: 'Save as Draft', onPressed: _loading ? null : () => _submit(false)),
              const SizedBox(width: 12),
              _PrimaryButton(
                label: 'Generate & Distribute',
                icon: Icons.send_rounded,
                color: UpriseColors.primaryDark,
                loading: _loading,
                onPressed: (_loading || !canDistribute) ? null : () => _submit(true),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CERT PREVIEW
// ─────────────────────────────────────────────────────────────────────────────
class _CertPreview extends StatelessWidget {
  final Color bg, accent, textColor;
  final String org, title, date;
  const _CertPreview({required this.bg, required this.accent, required this.textColor,
      required this.org, required this.title, required this.date});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(_DS.radiusMd),
      border: Border.all(color: accent.withOpacity(0.3), width: 1.5),
      boxShadow: [BoxShadow(color: accent.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(org.toUpperCase(),
          style: GoogleFonts.beVietnamPro(fontSize: 9.5, fontWeight: FontWeight.w800, color: accent, letterSpacing: 2.8),
          textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Divider(color: accent.withOpacity(0.25))),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Icon(Icons.workspace_premium_rounded, size: 22, color: accent)),
        Expanded(child: Divider(color: accent.withOpacity(0.25))),
      ]),
      const SizedBox(height: 14),
      Text('Certificate of', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w300, color: textColor)),
      Text('Participation',
          style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w800, color: accent, height: 1.1)),
      const SizedBox(height: 14),
      Text('This is to certify that',
          style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withOpacity(0.55))),
      const SizedBox(height: 7),
      Text('[Recipient Name]',
          style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.w700, color: textColor, fontStyle: FontStyle.italic),
          textAlign: TextAlign.center),
      const SizedBox(height: 10),
      Divider(color: accent.withOpacity(0.2)),
      const SizedBox(height: 8),
      Text('has successfully participated in',
          style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withOpacity(0.55))),
      const SizedBox(height: 5),
      Text(title,
          style: GoogleFonts.beVietnamPro(fontSize: 12.5, fontWeight: FontWeight.w700, color: textColor),
          textAlign: TextAlign.center),
      Text('held on $date',
          style: GoogleFonts.beVietnamPro(fontSize: 10, color: textColor.withOpacity(0.55))),
      const SizedBox(height: 18),
      Divider(color: accent.withOpacity(0.35), indent: 50, endIndent: 50),
      const SizedBox(height: 3),
      Text('Authorized Signatory',
          style: GoogleFonts.beVietnamPro(fontSize: 9, color: textColor.withOpacity(0.4), letterSpacing: 0.5)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CERT PREVIEW DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _CertPreviewDialog extends StatelessWidget {
  final CertRecord record;
  const _CertPreviewDialog({required this.record});

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusXl)),
    elevation: 24,
    child: SizedBox(width: 450,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
          decoration: BoxDecoration(
            color: UpriseColors.primaryDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_DS.radiusXl)),
          ),
          child: Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.card_membership_outlined, color: Colors.white, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.certId,
                  style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(record.eventName,
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white.withOpacity(0.65)),
                  overflow: TextOverflow.ellipsis),
            ])),
            _certBadge(record.status),
            const SizedBox(width: 10),
            IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: _CertPreview(
            bg: const Color(0xFFFDF6EC), accent: const Color(0xFFB45309), textColor: const Color(0xFF1A202C),
            org: record.org, title: record.eventName, date: DateFormat('MMMM dd, yyyy').format(record.date),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 22),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _PrimaryButton(label: 'Close', color: UpriseColors.primaryDark, onPressed: () => Navigator.pop(context)),
          ]),
        ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// IMPORT TEMPLATE MODAL
// ─────────────────────────────────────────────────────────────────────────────
class _ImportTemplateModal extends StatefulWidget {
  final String orgId;
  const _ImportTemplateModal({required this.orgId});

  @override
  State<_ImportTemplateModal> createState() => _ImportTemplateModalState();
}

class _ImportTemplateModalState extends State<_ImportTemplateModal> {
  String?       _name;
  PlatformFile? _file;
  bool          _uploading = false;

  Future<void> _pick() async {
    final res = await FilePicker.platform.pickFiles(
        withData: true, type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'pdf']);
    if (res != null && res.files.isNotEmpty) setState(() => _file = res.files.first);
  }

  Future<void> _upload() async {
    if (_file == null || (_name ?? '').trim().isEmpty) return;
    setState(() => _uploading = true);
    try {
      final path = 'certificate_templates/${widget.orgId}/${DateTime.now().millisecondsSinceEpoch}_${_file!.name}';
      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putData(_file!.bytes!,
          SettableMetadata(contentType: _file!.extension == 'pdf' ? 'application/pdf' : 'image/${_file!.extension}'));
      final url = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('certificate_templates').add({
        'orgId': widget.orgId, 'name': _name!.trim(), 'url': url, 'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context, {'name': _name!.trim(), 'url': url});
    } catch (e) {
      if (mounted) _toast(context, 'Upload failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusXl)),
    elevation: 24,
    child: SizedBox(width: 490,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(24, 22, 20, 22),
          decoration: BoxDecoration(
            color: UpriseColors.primaryDark,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_DS.radiusXl)),
          ),
          child: Row(children: [
            Container(width: 40, height: 40,
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.upload_file_rounded, color: Colors.white, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Text('Import Certificate Template',
                style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
            IconButton(icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                onPressed: _uploading ? null : () => Navigator.pop(context)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sectionLabel('Template Details', icon: Icons.info_outline_rounded),
            TextFormField(
              decoration: _DS.inputDeco('Template Name *', hint: 'e.g., University Formal Template'),
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              onChanged: (v) => setState(() => _name = v),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _uploading ? null : _pick,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _file == null ? const Color(0xFFF7F8FA) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(_DS.radiusMd),
                  border: Border.all(
                    color: _file == null ? const Color(0xFFE4E8EF) : const Color(0xFF059669),
                    width: _file == null ? 1.5 : 2,
                    style: _file == null ? BorderStyle.solid : BorderStyle.solid,
                  ),
                ),
                child: Column(children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: _file == null ? const Color(0xFFEEF0F4) : const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _file == null ? Icons.cloud_upload_rounded : Icons.check_circle_rounded,
                      size: 26, color: _file == null ? const Color(0xFF9AA5B4) : const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _file == null ? 'Click to browse file' : _file!.name,
                    style: GoogleFonts.beVietnamPro(fontSize: 13.5, fontWeight: FontWeight.w600,
                        color: _file == null ? const Color(0xFF64748B) : const Color(0xFF059669)),
                  ),
                  const SizedBox(height: 4),
                  Text('Supports .png, .jpg, .jpeg, .pdf',
                      style: GoogleFonts.beVietnamPro(fontSize: 11.5, color: const Color(0xFFB0BAC8))),
                ]),
              ),
            ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 22),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFEBEEF3))),
            color: Color(0xFFF7F8FA),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusXl)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            _OutlineButton(label: 'Cancel', onPressed: _uploading ? null : () => Navigator.pop(context)),
            const SizedBox(width: 12),
            _PrimaryButton(
              label: 'Upload & Save', icon: Icons.upload_rounded,
              color: UpriseColors.primaryDark, loading: _uploading,
              onPressed: (_file == null || (_name ?? '').trim().isEmpty || _uploading) ? null : _upload,
            ),
          ]),
        ),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM DELETE DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _ConfirmDeleteDialog extends StatelessWidget {
  final String name;
  final VoidCallback onConfirm;
  const _ConfirmDeleteDialog({required this.name, required this.onConfirm});

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusXl)),
    elevation: 24,
    child: Container(
      width: 420,
      padding: const EdgeInsets.all(30),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Delete Certificate',
                style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
            Text('This action cannot be undone',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8))),
          ]),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(_DS.radiusSm),
              border: Border.all(color: const Color(0xFFFECACA))),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Expanded(child: Text('Are you sure you want to delete "$name"?',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF991B1B), height: 1.4))),
          ]),
        ),
        const SizedBox(height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          _OutlineButton(label: 'Cancel', onPressed: () => Navigator.pop(context)),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); onConfirm(); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626), foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: Text('Delete', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    ),
  );
}

// =============================================================================
// GENERIC DATA TABLE WRAPPER
// =============================================================================
class _Col {
  final String label;
  final int flex;
  final bool rightAlign;
  const _Col(this.label, this.flex, {this.rightAlign = false});
}

class _DataTable extends StatelessWidget {
  final List<_Col> columns;
  final List<_TableRow> rows;
  final bool isEmpty;
  final String emptyMessage;
  final String? footer;
  final Widget? customFooter;

  const _DataTable({
    required this.columns,
    required this.rows,
    required this.isEmpty,
    required this.emptyMessage,
    required this.footer,
    this.customFooter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: const Color(0xFFEBEEF3)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(_DS.radiusMd)),
            border: Border(bottom: BorderSide(color: Color(0xFFEBEEF3))),
          ),
          child: Row(children: [
            for (final col in columns)
              Expanded(flex: col.flex, child: col.rightAlign
                  ? Align(alignment: Alignment.centerRight, child: _headerCell(col.label))
                  : _headerCell(col.label)),
          ]),
        ),
        // Rows or empty state
        if (isEmpty) _EmptyState(emptyMessage) else ...rows,
        // Footer
        customFooter ?? (footer != null ? _TableFooter(footer!) : const SizedBox.shrink()),
      ]),
    );
  }
}

// =============================================================================
// SHARED REUSABLE WIDGETS
// =============================================================================

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusLg),
        border: Border.all(color: const Color(0xFFEBEEF3)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: GoogleFonts.beVietnamPro(fontSize: 11.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C), height: 1.1)),
        ])),
      ]),
    ),
  );
}

class _StudentAvatar extends StatelessWidget {
  final String name;
  final double size;
  const _StudentAvatar({required this.name, this.size = 32});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final init = parts.length >= 2 ? '${parts[0][0]}${parts[1][0]}'.toUpperCase() : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: UpriseColors.primaryDark.withOpacity(0.09), borderRadius: BorderRadius.circular(size * 0.28)),
      child: Center(child: Text(init,
          style: GoogleFonts.beVietnamPro(fontSize: size * 0.36, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark))),
    );
  }
}

class _NameCell extends StatelessWidget {
  final String name, email;
  const _NameCell(this.name, this.email);
  @override
  Widget build(BuildContext context) => Row(children: [
    _StudentAvatar(name: name),
    const SizedBox(width: 10),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(name,
          style: GoogleFonts.beVietnamPro(fontSize: 13.5, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C)),
          overflow: TextOverflow.ellipsis),
      Text(email,
          style: GoogleFonts.beVietnamPro(fontSize: 11.5, color: const Color(0xFFB0BAC8)),
          overflow: TextOverflow.ellipsis),
    ])),
  ]);
}

class _IdText extends StatelessWidget {
  final String id;
  const _IdText(this.id);
  @override
  Widget build(BuildContext context) => Text(id,
      style: GoogleFonts.beVietnamPro(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: UpriseColors.primaryDark, letterSpacing: 0.2));
}

class _MethodBadge extends StatelessWidget {
  final String method;
  const _MethodBadge(this.method);
  @override
  Widget build(BuildContext context) {
    final isManual = method == 'manual';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
      decoration: BoxDecoration(
        color: isManual ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
        border: Border.all(color: isManual ? const Color(0xFFFDE68A) : const Color(0xFFBFD7FF)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(isManual ? 'Manual' : 'QR Scan',
          style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600,
              color: isManual ? const Color(0xFFD97706) : const Color(0xFF2563EB))),
    );
  }
}

class _TableRow extends StatelessWidget {
  final List<Widget> cells;
  final List<int> flex;
  final VoidCallback? onTap;
  const _TableRow({required this.cells, required this.flex, this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    hoverColor: const Color(0xFFF7F8FA),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF3F4F8)))),
      child: Row(children: [
        for (var i = 0; i < cells.length; i++) Expanded(flex: flex[i], child: cells[i]),
      ]),
    ),
  );
}

class _TableFooter extends StatelessWidget {
  final String text;
  const _TableFooter(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFEBEEF3))),
      color: Color(0xFFF7F8FA),
      borderRadius: BorderRadius.vertical(bottom: Radius.circular(_DS.radiusMd)),
    ),
    child: Text(text, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF94A3B8))),
  );
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState(this.message);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 48),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(color: const Color(0xFFF1F4F8), borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.inbox_rounded, size: 34, color: Color(0xFFCDD5DF)),
      ),
      const SizedBox(height: 14),
      Text(message,
          style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF374151)),
          textAlign: TextAlign.center),
    ])),
  );
}

class _InfoBanner extends StatelessWidget {
  final Color color, border, iconColor, textColor;
  final IconData icon;
  final String text;
  const _InfoBanner({required this.color, required this.border, required this.icon,
      required this.iconColor, required this.text, required this.textColor});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(_DS.radiusSm), border: Border.all(color: border)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: iconColor),
      const SizedBox(width: 9),
      Expanded(child: Text(text,
          style: GoogleFonts.beVietnamPro(fontSize: 12.5, color: textColor, height: 1.5))),
    ]),
  );
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionIconButton({required this.icon, required this.tooltip, required this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16,
            color: onTap == null ? const Color(0xFFD1D5DB) : (color ?? const Color(0xFF64748B))),
      ),
    ),
  );
}

class _SubTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubTab(this.label, this.selected, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? UpriseColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(color: selected ? UpriseColors.primaryDark : const Color(0xFFE4E8EF)),
        boxShadow: selected ? [BoxShadow(color: UpriseColors.primaryDark.withOpacity(0.20), blurRadius: 8, offset: const Offset(0, 3))] : [],
      ),
      child: Text(label,
          style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF64748B))),
    ),
  );
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  const _ModeChip({required this.label, required this.selected, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.symmetric(horizontal: icon != null ? 12 : 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? UpriseColors.primaryDark : Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(color: selected ? UpriseColors.primaryDark : const Color(0xFFE4E8EF)),
        boxShadow: selected ? [BoxShadow(color: UpriseColors.primaryDark.withOpacity(0.22), blurRadius: 8, offset: const Offset(0, 3))] : [],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: selected ? Colors.white : UpriseColors.primaryDark), const SizedBox(width: 6)],
        Text(label,
            style: GoogleFonts.beVietnamPro(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: selected ? Colors.white : UpriseColors.primaryDark)),
      ]),
    ),
  );
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String hint;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.items, required this.hint, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    height: 40,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_DS.radiusSm),
      border: Border.all(color: const Color(0xFFE4E8EF)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFFB0BAC8)),
        style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
        items: items.map((s) => DropdownMenuItem(
          value: s,
          child: Text(s == 'All' ? 'All Status' : s[0].toUpperCase() + s.substring(1),
              style: GoogleFonts.beVietnamPro(fontSize: 13)),
        )).toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED BUTTON COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;
  const _PrimaryButton({required this.label, this.icon, required this.color,
      this.onPressed, this.loading = false, this.compact = false});
  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      disabledBackgroundColor: color.withOpacity(0.45),
      disabledForegroundColor: Colors.white.withOpacity(0.7),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (loading)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
        )
      else if (icon != null) ...[
        Icon(icon, size: compact ? 14 : 15),
        const SizedBox(width: 6),
      ],
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool compact;
  const _OutlineButton({required this.label, this.icon, this.onPressed, this.compact = false});
  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: Color(0xFFE4E8EF)),
      foregroundColor: const Color(0xFF374151),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_DS.radiusSm)),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: compact ? 14 : 15), const SizedBox(width: 6)],
      Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
    ]),
  );
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
    child: Container(
      width: 28, height: 28, alignment: Alignment.center,
      decoration: BoxDecoration(
          color: enabled ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: enabled ? Border.all(color: const Color(0xFFE4E8EF)) : null),
      child: Icon(icon, size: 18, color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
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
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 30, height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive ? UpriseColors.primaryDark : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: isActive ? null : Border.all(color: const Color(0xFFE4E8EF)),
        boxShadow: isActive ? [BoxShadow(color: UpriseColors.primaryDark.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))] : [],
      ),
      child: Text('$page',
          style: GoogleFonts.beVietnamPro(
              fontSize: 12.5,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? Colors.white : const Color(0xFF374151))),
    ),
  );
}