import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:universal_html/html.dart' as html;
import 'package:uprise/screens/web/admin/export_pdf.dart' show AdminExportPdf;
import 'export_util.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens — mirrors student_accounts.dart exactly
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withAlpha(15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme Colors
// ─────────────────────────────────────────────────────────────────────────────
class UpriseColors {
  static const Color primary = Color(0xFFE87722);
  static const Color primaryDark = Color(0xFFC45E00);
  static const Color primaryLight = Color(0xFFFFF3E8);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF7F8FA);
  static const Color mediumGray = Color(0xFFE2E6EA);
  static const Color darkGray = Color(0xFF6B7280);
  static const Color charcoal = Color(0xFF1F2937);
  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEF2F2);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFEFF6FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────────────────────
Widget _sectionLabel(String text, {IconData? icon}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
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
      ],
    ),
  );
}

Widget _statusBadge(String status) {
  final Map<String, _BadgeStyle> styles = {
    'submitted': _BadgeStyle(
      UpriseColors.successBg,
      UpriseColors.success,
      'SUBMITTED',
    ),
    'pending': _BadgeStyle(
      UpriseColors.warningBg,
      UpriseColors.warning,
      'PENDING',
    ),
    'overdue': _BadgeStyle(UpriseColors.errorBg, UpriseColors.error, 'OVERDUE'),
    'approved': _BadgeStyle(
      UpriseColors.successBg,
      UpriseColors.success,
      'APPROVED',
    ),
    'no events': _BadgeStyle(
      const Color(0xFFF3F4F6),
      const Color(0xFF6B7280),
      'NO EVENTS',
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
// Data Models
// ─────────────────────────────────────────────────────────────────────────────
class EventReport {
  final String id, title, orgId, orgName, type, status;
  final DateTime date;
  final double totalIncome, totalExpenses, budgetVariance;
  final int registrants, attendees;
  final String submittedBy, reportPeriod;
  final DateTime? submittedDate;
  final List<Map<String, dynamic>> incomeBreakdown,
      expenseBreakdown,
      attachments;
  final List<String> financialNotes, recommendations;

  EventReport({
    required this.id,
    required this.title,
    required this.orgId,
    required this.orgName,
    required this.type,
    required this.date,
    required this.status,
    this.totalIncome = 0,
    this.totalExpenses = 0,
    this.budgetVariance = 0,
    this.registrants = 0,
    this.attendees = 0,
    this.submittedBy = '',
    this.reportPeriod = '',
    this.submittedDate,
    this.incomeBreakdown = const [],
    this.expenseBreakdown = const [],
    this.attachments = const [],
    this.financialNotes = const [],
    this.recommendations = const [],
  });

  double get netAmount => totalIncome - totalExpenses;
  int get attendanceRatio =>
      registrants > 0 ? ((attendees / registrants) * 100).round() : 0;

  factory EventReport.fromFirestore(
    DocumentSnapshot doc,
    String orgName,
    int registrants,
    int attendees,
  ) {
    final d = doc.data() as Map<String, dynamic>;
    return EventReport(
      id: doc.id,
      title: d['title']?.toString() ?? 'Untitled',
      orgId: d['orgId']?.toString() ?? '',
      orgName: orgName,
      type: d['type']?.toString() ?? 'Others',
      date: (d['date'] as Timestamp).toDate(),
      status: d['status']?.toString() ?? 'approved',
      totalIncome: (d['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpenses: (d['totalExpenses'] as num?)?.toDouble() ?? 0,
      budgetVariance: (d['budgetVariance'] as num?)?.toDouble() ?? 0,
      registrants: registrants,
      attendees: attendees,
      submittedBy: d['submittedBy']?.toString() ?? '',
      submittedDate: (d['submittedDate'] as Timestamp?)?.toDate(),
      reportPeriod: d['reportPeriod']?.toString() ?? '',
      incomeBreakdown: List<Map<String, dynamic>>.from(
        d['incomeBreakdown'] ?? [],
      ),
      expenseBreakdown: List<Map<String, dynamic>>.from(
        d['expenseBreakdown'] ?? [],
      ),
      financialNotes: List<String>.from(d['financialNotes'] ?? []),
      recommendations: List<String>.from(d['recommendations'] ?? []),
      attachments: List<Map<String, dynamic>>.from(d['attachments'] ?? []),
    );
  }
}

class OrgSubmission {
  final String orgId, orgName;
  final DateTime? submittedAt;
  final String? fileUrl, submissionId;
  final String? eventId, eventTitle;
  final DateTime? eventDate;

  OrgSubmission({
    required this.orgId,
    required this.orgName,
    this.submittedAt,
    this.fileUrl,
    this.submissionId,
    this.eventId,
    this.eventTitle,
    this.eventDate,
  });

  bool get hasApprovedEvent => eventDate != null && eventTitle != null;
  DateTime? get eventDeadline => eventDate?.subtract(const Duration(days: 7));
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class ReportsManagement extends StatefulWidget {
  const ReportsManagement({super.key});
  @override
  State<ReportsManagement> createState() => _ReportsManagementState();
}

class _ReportsManagementState extends State<ReportsManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _filterOrg = 'All Organizations';
  String _filterType = 'All Types';
  String _filterRange = 'All Time';
  String _filterAcademicYear = 'All Years';
  String _filterSemester = 'All Semesters';
  String _filterStatus = 'All';
  final String _reportView = 'By Event';

  static const List<String> _academicYears = [
    'All Years', '2025-2026', '2024-2025', '2023-2024',
  ];
  static const List<String> _semesters = [
    'All Semesters', '1st Semester', '2nd Semester', 'Summer',
  ];
  static const List<String> _statusOptions = [
    'All', 'Approved', 'Pending', 'Rejected',
  ];

  List<EventReport> _events = [];
  List<Map<String, dynamic>> _organizations = [];
  bool _loadingEvents = true;

  List<OrgSubmission> _financialSubs = [];
  List<OrgSubmission> _accomplishmentSubs = [];
  bool _loadingFinancial = true;
  bool _loadingAccomplishment = true;
  DateTime? _financialDeadline;
  DateTime? _accomplishmentDeadline;
  bool _loadingDeadlines = true;

  EventReport? _detailEvent;
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(
      () => setState(() {
        _detailEvent = null;
        _currentPage = 1;
      }),
    );
    _loadOrganizations();
    _loadDeadlines();
    _loadSubmissionData();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Date range helper ─────────────────────────────────────────────

  (DateTime?, DateTime?) _computeDateRange() {
    final now = DateTime.now();
    int startYear;
    int endYear;

    if (_filterAcademicYear == 'All Years') {
      if (_filterSemester == 'All Semesters' && _filterRange == 'All Time') {
        return (null, null);
      }
    }

    if (_filterAcademicYear != 'All Years') {
      final parts = _filterAcademicYear.split('-');
      startYear = int.tryParse(parts[0]) ?? now.year;
      endYear = int.tryParse(parts[1]) ?? now.year + 1;
    } else {
      // Use current academic year based on month
      startYear = now.month >= 8 ? now.year : now.year - 1;
      endYear = startYear + 1;
    }

    switch (_filterSemester) {
      case '1st Semester':
        return (DateTime(startYear, 8, 1), DateTime(startYear + 1, 1, 31, 23, 59));
      case '2nd Semester':
        return (DateTime(startYear + 1, 2, 1), DateTime(startYear + 1, 6, 30, 23, 59));
      case 'Summer':
        return (DateTime(startYear + 1, 6, 1), DateTime(startYear + 1, 8, 31, 23, 59));
      default: // All Semesters within academic year
        if (_filterAcademicYear != 'All Years') {
          return (DateTime(startYear, 8, 1), DateTime(endYear, 7, 31, 23, 59));
        }
    }

    // Fall back to _filterRange
    switch (_filterRange) {
      case 'Last 30 Days':
        return (now.subtract(const Duration(days: 30)), now);
      case 'Last 90 Days':
        return (now.subtract(const Duration(days: 90)), now);
      case 'This Year':
        return (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31, 23, 59));
      default:
        return (null, null);
    }
  }

  // ── Firebase loaders ──────────────────────────────────────────────

  Future<void> _loadOrganizations() async {
    final snap = await FirebaseFirestore.instance
        .collection('organizations')
        .get();
    if (!mounted) return;
    setState(() {
      _organizations = snap.docs
          .map(
            (doc) => {
              'id': doc.id,
              'name': doc.data()['name']?.toString() ?? 'Unknown',
            },
          )
          .toList();
    });
  }

  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _loadingEvents = true);
    try {
      Query query = FirebaseFirestore.instance.collection('events');
      if (_filterStatus != 'All') {
        query = query.where('status', isEqualTo: _filterStatus.toLowerCase());
      }
      if (_filterType != 'All Types')
        query = query.where('type', isEqualTo: _filterType);
      if (_filterOrg != 'All Organizations') {
        final org = _organizations.firstWhere(
          (o) => o['name'] == _filterOrg,
          orElse: () => {'id': '', 'name': ''},
        );
        if ((org['id'] as String).isNotEmpty)
          query = query.where('orgId', isEqualTo: org['id']);
      }
      final (rangeStart, rangeEnd) = _computeDateRange();
      if (rangeStart != null) {
        query = query.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(rangeStart));
      }
      if (rangeEnd != null) {
        query = query.where('date', isLessThanOrEqualTo: Timestamp.fromDate(rangeEnd));
      }
      final eventsSnap = await query.get();
      final orgMap = {
        for (var o in _organizations) o['id'] as String: o['name'] as String,
      };
      final List<EventReport> loaded = [];
      for (final doc in eventsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final orgId = data['orgId']?.toString() ?? '';
        final orgName =
            orgMap[orgId] ?? data['orgName']?.toString() ?? 'Unknown';
        final regSnap = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: doc.id)
            .get();
        final registrants = regSnap.docs.length;
        final attendees = regSnap.docs
            .where((r) => (r.data())['attended'] == true)
            .length;
        loaded.add(
          EventReport.fromFirestore(doc, orgName, registrants, attendees),
        );
      }
      if (!mounted) return;
      setState(() => _events = loaded);
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<Map<String, Map<String, dynamic>>>
  _loadNextApprovedEventsByOrg() async {
    final now = DateTime.now();
    final eventsSnap = await FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved')
        .get();

    final Map<String, Map<String, dynamic>> eventInfo = {};
    for (final doc in eventsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final orgId = data['orgId']?.toString();
      final date = (data['date'] as Timestamp?)?.toDate();
      if (orgId == null || orgId.isEmpty || date == null || date.isBefore(now))
        continue;

      final existing = eventInfo[orgId];
      if (existing == null ||
          date.isBefore(existing['eventDate'] as DateTime)) {
        eventInfo[orgId] = {
          'eventId': doc.id,
          'eventTitle': data['title']?.toString() ?? 'Untitled Event',
          'eventDate': date,
        };
      }
    }
    return eventInfo;
  }

  Future<void> _loadDeadlines() async {
    if (!mounted) return;
    setState(() => _loadingDeadlines = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('report_deadlines')
          .doc('deadlines')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _financialDeadline = (data['financial'] as Timestamp?)?.toDate();
        _accomplishmentDeadline = (data['accomplishment'] as Timestamp?)
            ?.toDate();
      }
    } catch (e) {
      debugPrint('Error loading deadlines: $e');
    } finally {
      if (mounted) setState(() => _loadingDeadlines = false);
    }
  }

  Future<void> _saveDeadlines() async {
    if (_financialDeadline == null || _accomplishmentDeadline == null) return;
    await FirebaseFirestore.instance
        .collection('report_deadlines')
        .doc('deadlines')
        .set({
          'financial': Timestamp.fromDate(_financialDeadline!),
          'accomplishment': Timestamp.fromDate(_accomplishmentDeadline!),
        });
    await activity_log.ActivityLogger.log(
      action:
          'Updated report deadlines: Financial → ${DateFormat('yyyy-MM-dd').format(_financialDeadline!)}, '
          'Accomplishment → ${DateFormat('yyyy-MM-dd').format(_accomplishmentDeadline!)}',
      module: 'Reports',
      severity: 'info',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Deadlines updated successfully'),
          backgroundColor: UpriseColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
    }
  }

  Future<void> _loadSubmissionData() async {
    await Future.wait([
      _loadFinancialSubmissions(),
      _loadAccomplishmentSubmissions(),
    ]);
  }

  Future<void> _loadFinancialSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingFinancial = true);
    try {
      final orgsSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .get();
      final allOrgs = orgsSnap.docs
          .map(
            (doc) => {
              'id': doc.id,
              'name': doc.data()['name']?.toString() ?? 'Unknown',
            },
          )
          .toList();
      final eventInfo = await _loadNextApprovedEventsByOrg();
      final subsSnap = await FirebaseFirestore.instance
          .collection('financial_submissions')
          .get();
      final subsMap = <String, Map<String, dynamic>>{};
      for (final doc in subsSnap.docs) {
        final data = doc.data();
        subsMap[data['orgId']?.toString() ?? ''] = {
          'submittedAt': (data['submittedAt'] as Timestamp).toDate(),
          'fileUrl': data['fileUrl'],
          'submissionId': doc.id,
        };
      }
      if (!mounted) return;
      setState(() {
        _financialSubs = allOrgs.map((org) {
          final info = eventInfo[org['id']];
          return OrgSubmission(
            orgId: org['id']!,
            orgName: org['name']!,
            submittedAt: subsMap[org['id']]?['submittedAt'] as DateTime?,
            fileUrl: subsMap[org['id']]?['fileUrl'] as String?,
            submissionId: subsMap[org['id']]?['submissionId'] as String?,
            eventId: info?['eventId'] as String?,
            eventTitle: info?['eventTitle'] as String?,
            eventDate: info?['eventDate'] as DateTime?,
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingFinancial = false);
    }
  }

  Future<void> _loadAccomplishmentSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingAccomplishment = true);
    try {
      final orgsSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .get();
      final allOrgs = orgsSnap.docs
          .map(
            (doc) => {
              'id': doc.id,
              'name': doc.data()['name']?.toString() ?? 'Unknown',
            },
          )
          .toList();
      final eventInfo = await _loadNextApprovedEventsByOrg();
      final subsSnap = await FirebaseFirestore.instance
          .collection('accomplishment_submissions')
          .get();
      final subsMap = <String, Map<String, dynamic>>{};
      for (final doc in subsSnap.docs) {
        final data = doc.data();
        subsMap[data['orgId']?.toString() ?? ''] = {
          'submittedAt': (data['submittedAt'] as Timestamp).toDate(),
          'fileUrl': data['fileUrl'],
          'submissionId': doc.id,
        };
      }
      if (!mounted) return;
      setState(() {
        _accomplishmentSubs = allOrgs.map((org) {
          final info = eventInfo[org['id']];
          return OrgSubmission(
            orgId: org['id']!,
            orgName: org['name']!,
            submittedAt: subsMap[org['id']]?['submittedAt'] as DateTime?,
            fileUrl: subsMap[org['id']]?['fileUrl'] as String?,
            submissionId: subsMap[org['id']]?['submissionId'] as String?,
            eventId: info?['eventId'] as String?,
            eventTitle: info?['eventTitle'] as String?,
            eventDate: info?['eventDate'] as DateTime?,
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingAccomplishment = false);
    }
  }

  // ── Export / PDF ──────────────────────────────────────────────────

  Future<void> _logGeneratedReport(
    String fileName,
    String format,
    String type,
  ) async {
    await FirebaseFirestore.instance.collection('generated_reports').add({
      'fileName': fileName,
      'dateRange': _filterRange,
      'academicYear': _filterAcademicYear,
      'semester': _filterSemester,
      'organization': _filterOrg,
      'eventType': _filterType,
      'status': _filterStatus,
      'reportView': _reportView,
      'generatedAt': FieldValue.serverTimestamp(),
      'format': format,
      'reportType': type,
    });
    await activity_log.ActivityLogger.log(
      action: 'Generated $type report in $format format',
      module: 'Reports',
      severity: 'info',
      details: {
        'fileName': fileName,
        'filters': 'Org: $_filterOrg, Type: $_filterType, AY: $_filterAcademicYear, Sem: $_filterSemester, Status: $_filterStatus',
      },
    );
  }

  Future<void> _generatePDFReport() async {
    final now = DateTime.now();
    final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'financial_report_$ts.pdf';

    final rows = _events.map((e) {
      return [
        e.title,
        e.orgName,
        e.type,
        DateFormat('yyyy-MM-dd').format(e.date),
        '₱${_fmt(e.totalIncome)}',
        '₱${_fmt(e.totalExpenses)}',
        '₱${_fmt(e.netAmount)}',
      ];
    }).toList();

    final pdfBytes = await AdminExportPdf.generateTablePdf(
      title: 'UPRISE Financial Report',
      headers: const [
        'Event',
        'Organization',
        'Type',
        'Date',
        'Income',
        'Expenses',
        'Net',
      ],
      rows: rows,
      subtitle:
          'Date Range: $_filterRange  |  Organization: $_filterOrg  |  Event Type: $_filterType',
    );

    await AdminExportUtil.saveBytes(
      pdfBytes,
      fileName,
      mimeType: 'application/pdf',
    );
    await _logGeneratedReport(fileName, 'PDF', 'Financial');
  }

  Future<void> _exportFinancialCSV() async {
    final rows = <List<String>>[
      [
        'Event Name',
        'Organization',
        'Type',
        'Date',
        'Income',
        'Expenses',
        'Net Amount',
      ],
    ];
    for (final e in _events) {
      rows.add([
        e.title,
        e.orgName,
        e.type,
        DateFormat('yyyy-MM-dd').format(e.date),
        e.totalIncome.toStringAsFixed(2),
        e.totalExpenses.toStringAsFixed(2),
        e.netAmount.toStringAsFixed(2),
      ]);
    }
    final csv = rows.map((r) => r.join(',')).join('\n');
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'financial_report_$ts.csv';
    await AdminExportUtil.saveText(csv, fileName, mimeType: 'text/csv');
    await _logGeneratedReport(fileName, 'CSV', 'Financial');
  }

  // ignore: unused_element
  Future<void> _exportAccomplishmentCSV() async {
    final rows = <List<String>>[
      [
        'Event Name',
        'Organization',
        'Type',
        'Date',
        'Registrants',
        'Attendees',
        'Ratio',
      ],
    ];
    for (final e in _events) {
      rows.add([
        e.title,
        e.orgName,
        e.type,
        DateFormat('yyyy-MM-dd').format(e.date),
        '${e.registrants}',
        '${e.attendees}',
        '${e.attendanceRatio}%',
      ]);
    }
    final csv = rows.map((r) => r.join(',')).join('\n');
    final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'accomplishment_report_$ts.csv';
    await AdminExportUtil.saveText(csv, fileName, mimeType: 'text/csv');
    await _logGeneratedReport(fileName, 'CSV', 'Accomplishment');
  }

  Future<void> _exportSubmissionCSV(
    String reportType,
    List<OrgSubmission> submissions,
    DateTime? deadline,
  ) async {
    final rows = <List<String>>[
      ['Organization', 'Deadline', 'Submitted On', 'Status'],
    ];
    for (final sub in submissions) {
      final isSubmitted = sub.submittedAt != null;
      final isOverdue =
          deadline != null && !isSubmitted && DateTime.now().isAfter(deadline);
      rows.add([
        sub.orgName,
        deadline != null ? DateFormat('yyyy-MM-dd').format(deadline) : '',
        isSubmitted ? DateFormat('yyyy-MM-dd').format(sub.submittedAt!) : '',
        isSubmitted ? 'Submitted' : (isOverdue ? 'Overdue' : 'Pending'),
      ]);
    }
    final csv = rows.map((r) => r.join(',')).join('\n');
    await AdminExportUtil.saveText(
      csv,
      '${reportType.toLowerCase()}_submissions.csv',
      mimeType: 'text/csv',
    );
    await _logGeneratedReport(
      '${reportType.toLowerCase()}_submissions.csv',
      'CSV',
      'Submission',
    );
  }

  Future<void> _exportSubmissionPdf(
    String reportType,
    List<OrgSubmission> submissions,
    DateTime? deadline,
  ) async {
    final rows = <List<String>>[
      ['Organization', 'Deadline', 'Submitted On', 'Status'],
    ];
    for (final sub in submissions) {
      final isSubmitted = sub.submittedAt != null;
      final isOverdue =
          deadline != null && !isSubmitted && DateTime.now().isAfter(deadline);
      rows.add([
        sub.orgName,
        deadline != null ? DateFormat('yyyy-MM-dd').format(deadline) : '',
        isSubmitted ? DateFormat('yyyy-MM-dd').format(sub.submittedAt!) : '',
        isSubmitted ? 'Submitted' : (isOverdue ? 'Overdue' : 'Pending'),
      ]);
    }

    final pdfBytes = await AdminExportPdf.generateTablePdf(
      title: '$reportType Submission Report',
      headers: const ['Organization', 'Deadline', 'Submitted On', 'Status'],
      rows: rows,
    );
    final fileName =
        '${reportType.toLowerCase().replaceAll(' ', '_')}_submissions.pdf';
    await AdminExportUtil.saveBytes(
      pdfBytes,
      fileName,
      mimeType: 'application/pdf',
    );
    await _logGeneratedReport(fileName, 'PDF', 'Submission');
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final isTablet = width >= 720 && width < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: _detailEvent != null
          ? _buildDetailView(_detailEvent!)
          : _buildMainView(isMobile, isTablet),
    );
  }

  Widget _buildMainView(bool isMobile, bool isTablet) {
    return Column(
      children: [
        _buildStatsRow(isMobile, isTablet),
        _buildToolbar(isMobile, isTablet),
        _buildTabBar(),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildEventsTable(showFinancial: true, showCountdown: true),
              _buildEventsTable(showFinancial: false, showCountdown: false),
              _buildFinancialTab(),
              _buildSubmissionTrackerTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(bool isMobile, bool isTablet) {
    final totalEvents = _events.length;
    final totalIncome = _events.fold<double>(0, (s, e) => s + e.totalIncome);
    final totalExpenses = _events.fold<double>(0, (s, e) => s + e.totalExpenses);

    // Submission stats from both collections
    final finSubmitted = _financialSubs.where((s) => s.submittedAt != null).length;
    final accSubmitted = _accomplishmentSubs.where((s) => s.submittedAt != null).length;
    final totalOrgs = _financialSubs.length;
    final pendingCount = totalOrgs > 0
        ? (totalOrgs - finSubmitted) + (totalOrgs - accSubmitted)
        : 0;

    final cards = [
      _StatCard(label: 'Total Events', value: '$totalEvents', icon: Icons.event_rounded, color: UpriseColors.primaryDark),
      _StatCard(label: 'Total Income', value: '₱${_fmtK(totalIncome)}', icon: Icons.attach_money_rounded, color: UpriseColors.success),
      _StatCard(label: 'Total Expenses', value: '₱${_fmtK(totalExpenses)}', icon: Icons.money_off_rounded, color: UpriseColors.error),
      _StatCard(label: 'Reports Submitted', value: '${finSubmitted + accSubmitted}', icon: Icons.assignment_turned_in_rounded, color: UpriseColors.info),
      _StatCard(label: 'Pending Reports', value: '$pendingCount', icon: Icons.pending_actions_rounded, color: UpriseColors.warning),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 10),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    SizedBox(width: 180, child: cards[i]),
                    if (i < cards.length - 1) const SizedBox(width: 14),
                  ],
                ],
              ),
            )
          : Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  Expanded(child: cards[i]),
                  if (i < cards.length - 1) const SizedBox(width: 14),
                ],
              ],
            ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolbar(bool isMobile, bool isTablet) {
    final orgNames = [
      'All Organizations',
      ..._organizations.map((o) => o['name'] as String),
    ];

    final filtersWrap = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterDropdown(
          value: _filterOrg,
          items: orgNames,
          hint: 'Organization',
          icon: Icons.business_rounded,
          onChanged: (v) {
            setState(() { _filterOrg = v!; _currentPage = 1; });
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterType,
          items: const ['All Types', 'Seminar', 'Workshop', 'Exhibition', 'Social', 'Cultural', 'Competition'],
          hint: 'Report Type',
          icon: Icons.category_rounded,
          onChanged: (v) {
            setState(() { _filterType = v!; _currentPage = 1; });
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterAcademicYear,
          items: _academicYears,
          hint: 'Academic Year',
          icon: Icons.school_rounded,
          onChanged: (v) {
            setState(() { _filterAcademicYear = v!; _currentPage = 1; });
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterSemester,
          items: _semesters,
          hint: 'Semester',
          icon: Icons.calendar_view_month_rounded,
          onChanged: (v) {
            setState(() { _filterSemester = v!; _currentPage = 1; });
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterStatus,
          items: _statusOptions,
          hint: 'Status',
          icon: Icons.tune_rounded,
          onChanged: (v) {
            setState(() { _filterStatus = v!; _currentPage = 1; });
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterRange,
          items: const ['All Time', 'Last 30 Days', 'Last 90 Days', 'This Year'],
          hint: 'Date Range',
          icon: Icons.date_range_rounded,
          onChanged: (v) {
            setState(() { _filterRange = v!; _currentPage = 1; });
            _loadEvents();
          },
        ),
      ],
    );

    final bool collapseActions = isMobile || isTablet;

    final Widget actionsRow = collapseActions
        ? PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'set_deadlines',
                child: Text('Set Deadlines'),
              ),
              const PopupMenuItem(
                value: 'generate_report',
                child: Text('Generate Report'),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: Text('Export CSV'),
              ),
              const PopupMenuItem(
                value: 'export_pdf',
                child: Text('Export PDF'),
              ),
            ],
            onSelected: (v) async {
              if (v == 'export_csv') await _exportFinancialCSV();
              if (v == 'export_pdf') await _generatePDFReport();
              if (v == 'set_deadlines') _showDeadlineDialog();
              if (v == 'generate_report') _showGenerateReportDialog();
            },
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ToolbarButton(
                label: 'Set Deadlines',
                icon: Icons.edit_calendar_rounded,
                onPressed: _showDeadlineDialog,
                outlined: true,
              ),
              const SizedBox(width: 6),
              _ToolbarButton(
                label: 'Generate Report',
                icon: Icons.insert_drive_file_rounded,
                onPressed: _showGenerateReportDialog,
              ),
              const SizedBox(width: 6),
              _ExportButton(
                onExportCsv: _exportFinancialCSV,
                onExportPdf: _generatePDFReport,
              ),
            ],
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                filtersWrap,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actionsRow),
              ],
            )
          : Row(
              children: [
                Expanded(child: filtersWrap),
                const SizedBox(width: 12),
                actionsRow,
              ],
            ),
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_DS.radiusMd),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: _DS.cardShadow,
        ),
        child: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Event Summary'),
            Tab(text: 'Accomplishment Reports'),
            Tab(text: 'Financial Reports'),
            Tab(text: 'Submission Tracker'),
          ],
          labelColor: UpriseColors.primaryDark,
          unselectedLabelColor: const Color(0xFF64748B),
          indicator: BoxDecoration(
            color: UpriseColors.primaryLight,
            borderRadius: BorderRadius.circular(_DS.radiusMd - 2),
            border: Border.all(color: UpriseColors.primaryDark.withAlpha(76)),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelStyle: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 13),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.all(4),
        ),
      ),
    );
  }

  // ── Financial Tab (with recent reports bar) ───────────────────────
  Widget _buildFinancialTab() {
    return Column(
      children: [
        Expanded(
          child: _buildEventsTable(showFinancial: true, showCountdown: false),
        ),
        _buildRecentReportsBar(),
      ],
    );
  }

  // ── Events Table — full StudentAccounts-style implementation ──────
  Widget _buildEventsTable({
    required bool showFinancial,
    required bool showCountdown,
  }) {
    if (_loadingEvents) return const Center(child: CircularProgressIndicator());
    final totalPages = _events.isEmpty
        ? 1
        : (_events.length / _pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _events.length);
    final pageItems = _events.isEmpty
        ? <EventReport>[]
        : _events.sublist(start, end);

    return Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        children: [
          _buildTableHeader(
            showFinancial: showFinancial,
            showCountdown: showCountdown,
          ),
          Expanded(
            child: _events.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: pageItems.length,
                    itemBuilder: (_, i) => _buildEventRow(
                      event: pageItems[i],
                      isLast: i == pageItems.length - 1,
                      showFinancial: showFinancial,
                      showCountdown: showCountdown,
                    ),
                  ),
          ),
          _buildTableFooter(_events.length, totalPages, start, end),
        ],
      ),
    );
  }

  Widget _buildTableHeader({
    required bool showFinancial,
    required bool showCountdown,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(
        children: showFinancial
            ? [
                Expanded(flex: 3, child: _headerCell('EVENT NAME')),
                Expanded(flex: 2, child: _headerCell('ORGANIZATION')),
                Expanded(flex: 2, child: _headerCell('INCOME')),
                Expanded(flex: 2, child: _headerCell('EXPENSES')),
                Expanded(flex: 2, child: _headerCell('NET AMOUNT')),
                if (showCountdown)
                  Expanded(flex: 2, child: _headerCell('DAYS TO EVENT')),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _headerCell('ACTIONS'),
                  ),
                ),
              ]
            : [
                Expanded(flex: 3, child: _headerCell('EVENT NAME')),
                Expanded(flex: 2, child: _headerCell('ORGANIZATION')),
                Expanded(flex: 2, child: _headerCell('TYPE')),
                Expanded(flex: 2, child: _headerCell('DATE')),
                Expanded(flex: 1, child: _headerCell('REG.')),
                Expanded(flex: 1, child: _headerCell('ATT.')),
                Expanded(flex: 2, child: _headerCell('RATIO')),
                Expanded(
                  flex: 1,
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

  Widget _buildEventRow({
    required EventReport event,
    required bool isLast,
    required bool showFinancial,
    required bool showCountdown,
  }) {
    final now = DateTime.now();
    final daysUntil = event.date.difference(now).inDays;
    final String countdownText = daysUntil < 0
        ? 'Passed'
        : daysUntil == 0
        ? 'Today'
        : '$daysUntil days';
    final Color countdownColor = daysUntil < 0
        ? const Color(0xFF9AA5B4)
        : daysUntil == 0
        ? UpriseColors.success
        : daysUntil <= 7
        ? UpriseColors.warning
        : UpriseColors.primaryDark;

    return InkWell(
      hoverColor: const Color(0xFFF8F9FB),
      onTap: () => setState(() => _detailEvent = event),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: showFinancial
              ? [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        _EventIcon(type: event.type),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            event.title,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A202C),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      event.orgName,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '₱${_fmt(event.totalIncome)}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: UpriseColors.success,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '₱${_fmt(event.totalExpenses)}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: UpriseColors.error,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '₱${_fmt(event.netAmount)}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: event.netAmount >= 0
                            ? UpriseColors.success
                            : UpriseColors.error,
                      ),
                    ),
                  ),
                  if (showCountdown)
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: countdownColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          countdownText,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: countdownColor,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ActionIconButton(
                        icon: Icons.visibility_outlined,
                        tooltip: 'View Report',
                        onTap: () => setState(() => _detailEvent = event),
                      ),
                    ),
                  ),
                ]
              : [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        _EventIcon(type: event.type),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            event.title,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1A202C),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      event.orgName,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(flex: 2, child: _TypeBadge(type: event.type)),
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(event.date),
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${event.registrants}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${event.attendees}',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF1A202C),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: event.attendanceRatio / 100,
                              backgroundColor: const Color(0xFFE8ECF0),
                              color: UpriseColors.primaryDark,
                              minHeight: 6,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${event.attendanceRatio}%',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: UpriseColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _ActionIconButton(
                        icon: Icons.visibility_outlined,
                        tooltip: 'View Report',
                        onTap: () => setState(() => _detailEvent = event),
                      ),
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
              Icons.bar_chart_rounded,
              size: 40,
              color: Color(0xFF9AA5B4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No events found',
            style: GoogleFonts.beVietnamPro(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters.',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableFooter(int total, int totalPages, int start, int end) {
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
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total events',
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

  // ── Recent Reports Bar ────────────────────────────────────────────
  Widget _buildRecentReportsBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: UpriseColors.primaryDark,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recently Generated Reports',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: UpriseColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('generated_reports')
                .orderBy('generatedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snap.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No reports generated yet.',
                    style: GoogleFonts.beVietnamPro(
                      color: const Color(0xFF64748B),
                      fontSize: 13,
                    ),
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final doc = entry.value;
                  final d = doc.data() as Map<String, dynamic>;
                  final generatedAt = (d['generatedAt'] as Timestamp?)
                      ?.toDate();
                  final isPdf = d['format'] == 'PDF';
                  final isLast = i == snap.data!.docs.length - 1;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: isLast
                          ? null
                          : const Border(
                              bottom: BorderSide(color: Color(0xFFF1F5F9)),
                            ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isPdf
                                ? UpriseColors.errorBg
                                : UpriseColors.successBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isPdf
                                ? Icons.picture_as_pdf_rounded
                                : Icons.table_chart_rounded,
                            size: 16,
                            color: isPdf
                                ? UpriseColors.error
                                : UpriseColors.success,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            d['fileName'] ?? 'Report',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                        ),
                        Text(
                          generatedAt != null
                              ? DateFormat(
                                  'MMM dd, yyyy hh:mm a',
                                ).format(generatedAt)
                              : '—',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: isPdf
                                ? UpriseColors.errorBg
                                : UpriseColors.successBg,
                            borderRadius: BorderRadius.circular(_DS.radiusPill),
                          ),
                          child: Text(
                            d['format'] ?? '',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isPdf
                                  ? UpriseColors.error
                                  : UpriseColors.success,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Submission Tracker Tab ─────────────────────────────────────────
  Widget _buildSubmissionTrackerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeadlineBar(),
          const SizedBox(height: 16),
          _buildTrackerStats(),
          const SizedBox(height: 20),
          _sectionLabel(
            'Financial Report Submissions',
            icon: Icons.attach_money_rounded,
          ),
          _buildSubmissionTable(
            'Financial',
            _financialSubs,
            _financialDeadline,
            _loadingFinancial,
          ),
          const SizedBox(height: 24),
          _sectionLabel(
            'Accomplishment Report Submissions',
            icon: Icons.assignment_rounded,
          ),
          _buildSubmissionTable(
            'Accomplishment',
            _accomplishmentSubs,
            _accomplishmentDeadline,
            _loadingAccomplishment,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeadlineBar() {
    if (_loadingDeadlines) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_DS.radiusSm),
          child: const LinearProgressIndicator(),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_DS.radiusMd),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_outlined,
            color: UpriseColors.primaryDark,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                _deadlineInfo('Financial Deadline', _financialDeadline),
                _deadlineInfo(
                  'Accomplishment Deadline',
                  _accomplishmentDeadline,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          _ToolbarButton(
            label: 'Edit Deadlines',
            icon: Icons.edit_calendar_rounded,
            onPressed: _showDeadlineDialog,
            outlined: true,
          ),
        ],
      ),
    );
  }

  Widget _deadlineInfo(String label, DateTime? date) {
    if (date == null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'Not set',
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              color: const Color(0xFF9AA5B4),
            ),
          ),
        ],
      );
    }
    final days = date.difference(DateTime.now()).inDays;
    final overdue = days < 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          DateFormat('MMM dd, yyyy').format(date),
          style: GoogleFonts.beVietnamPro(fontSize: 13),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: overdue ? UpriseColors.errorBg : UpriseColors.warningBg,
            borderRadius: BorderRadius.circular(_DS.radiusPill),
          ),
          child: Text(
            overdue ? 'Overdue' : '⏱ $days days left',
            style: GoogleFonts.beVietnamPro(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: overdue ? UpriseColors.error : UpriseColors.warning,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackerStats() {
    final finSubmitted = _financialSubs
        .where((s) => s.submittedAt != null)
        .length;
    final accSubmitted = _accomplishmentSubs
        .where((s) => s.submittedAt != null)
        .length;
    final total = _financialSubs.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _StatCard(
            label: 'Total Organizations',
            value: '$total',
            icon: Icons.business_rounded,
            color: UpriseColors.primaryDark,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Financial Submitted',
            value: '$finSubmitted/$total',
            icon: Icons.attach_money_rounded,
            color: UpriseColors.success,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Accomplishment Submitted',
            value: '$accSubmitted/$total',
            icon: Icons.assignment_turned_in_rounded,
            color: UpriseColors.info,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Pending',
            value: '${(total - finSubmitted) + (total - accSubmitted)}',
            icon: Icons.pending_actions_rounded,
            color: UpriseColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTable(
    String title,
    List<OrgSubmission> submissions,
    DateTime? deadline,
    bool loading,
  ) {
    if (loading)
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );

    final sorted = List<OrgSubmission>.from(submissions)
      ..sort((a, b) {
        final now = DateTime.now();
        final aS = a.submittedAt != null;
        final bS = b.submittedAt != null;
        final aDeadline = deadline ?? a.eventDeadline;
        final bDeadline = deadline ?? b.eventDeadline;
        final aO = aDeadline != null && !aS && now.isAfter(aDeadline);
        final bO = bDeadline != null && !bS && now.isAfter(bDeadline);
        if (aO && !bO) return -1;
        if (!aO && bO) return 1;
        if (aS && !bS) return 1;
        if (!aS && bS) return -1;
        return 0;
      });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F9FB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _headerCell('ORGANIZATION')),
                Expanded(flex: 2, child: _headerCell('EVENT DATE')),
                Expanded(flex: 2, child: _headerCell('SUBMITTED ON')),
                Expanded(flex: 2, child: _headerCell('STATUS')),
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _headerCell('ACTIONS'),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final sub = entry.value;
            final isSubmitted = sub.submittedAt != null;
            final rowDeadline = deadline ?? sub.eventDeadline;
            final isOverdue =
                rowDeadline != null &&
                !isSubmitted &&
                DateTime.now().isAfter(rowDeadline);
            final daysLeft = rowDeadline != null && !isSubmitted
                ? rowDeadline.difference(DateTime.now()).inDays
                : 0;
            final isLast = i == sorted.length - 1;
            return InkWell(
              hoverColor: const Color(0xFFF8F9FB),
              onTap: isSubmitted ? () => _viewSubmission(sub, title) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : const Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _OrgAvatar(name: sub.orgName),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  sub.orgName,
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF1A202C),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          if (sub.hasApprovedEvent) ...[
                            const SizedBox(height: 6),
                            Text(
                              sub.eventTitle ?? '',
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 11,
                                color: const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        sub.eventDate != null
                            ? DateFormat('MMM dd, yyyy').format(sub.eventDate!)
                            : '—',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        isSubmitted
                            ? DateFormat(
                                'MMM dd, yyyy',
                              ).format(sub.submittedAt!)
                            : '—',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 12,
                          color: isSubmitted
                              ? const Color(0xFF374151)
                              : const Color(0xFF9AA5B4),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: isSubmitted
                          ? _statusBadge('submitted')
                          : !sub.hasApprovedEvent
                          ? _statusBadge('no events')
                          : isOverdue
                          ? _statusBadge('overdue')
                          : Row(
                              children: [
                                _statusBadge('pending'),
                                const SizedBox(width: 6),
                                Text(
                                  daysLeft > 0 ? '$daysLeft d left' : 'today',
                                  style: GoogleFonts.beVietnamPro(
                                    fontSize: 10,
                                    color: UpriseColors.warning,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: isSubmitted
                            ? _ActionIconButton(
                                icon: Icons.visibility_outlined,
                                tooltip: 'View Report',
                                onTap: () => _viewSubmission(sub, title),
                              )
                            : sub.hasApprovedEvent
                            ? _ActionIconButton(
                                icon: Icons.send_outlined,
                                tooltip: 'Send Reminder',
                                onTap: () => _sendReminder(sub, title),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          // Footer
          Container(
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
                  'Showing ${sorted.length} organizations',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                AdminExportButton(
                  onSelected: (choice) async {
                    if (choice == 'csv') {
                      await _exportSubmissionCSV(title, submissions, deadline);
                    } else if (choice == 'pdf') {
                      await _exportSubmissionPdf(title, submissions, deadline);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail View ───────────────────────────────────────────────────
  Widget _buildDetailView(EventReport event) {
    final net = event.netAmount;
    final maxInc = event.incomeBreakdown.isEmpty
        ? 1.0
        : event.incomeBreakdown
              .map((i) => (i['amount'] as num?)?.toDouble() ?? 0.0)
              .reduce((a, b) => a > b ? a : b);
    final maxExp = event.expenseBreakdown.isEmpty
        ? 1.0
        : event.expenseBreakdown
              .map((i) => (i['amount'] as num?)?.toDouble() ?? 0.0)
              .reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        children: [
          // Detail header
          Container(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _detailEvent = null),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back to Reports List',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: UpriseColors.primaryDark.withAlpha(26),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: UpriseColors.primaryDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF1A202C),
                            ),
                          ),
                          Text(
                            '${event.orgName} • ${event.type} • ${DateFormat('MMM dd, yyyy').format(event.date)}',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.archive_outlined, size: 15),
                          label: Text(
                            'Archive',
                            style: GoogleFonts.beVietnamPro(fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE2E6EA)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_DS.radiusSm),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _generatePDFReport,
                          icon: const Icon(Icons.download_rounded, size: 15),
                          label: Text(
                            'Download PDF',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: UpriseColors.primaryDark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(_DS.radiusSm),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Detail body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  // Meta grid
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8ECF0)),
                      boxShadow: _DS.cardShadow,
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            _metaCell('EVENT NAME', event.title),
                            _metaCell('ORGANIZATION', event.orgName),
                            _metaCell(
                              'REPORT TYPE',
                              'Event Financial Report',
                              last: true,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            _metaCell(
                              'REPORT PERIOD',
                              event.reportPeriod.isNotEmpty
                                  ? event.reportPeriod
                                  : DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(event.date),
                            ),
                            _metaCell(
                              'SUBMITTED DATE',
                              event.submittedDate != null
                                  ? DateFormat(
                                      'MMM dd, yyyy',
                                    ).format(event.submittedDate!)
                                  : '—',
                            ),
                            _metaCell(
                              'SUBMITTED BY',
                              event.submittedBy.isNotEmpty
                                  ? event.submittedBy
                                  : '—',
                              last: true,
                              lastRow: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Financial stats
                  Row(
                    children: [
                      _detailStatCard(
                        'Total Income',
                        '₱${_fmt(event.totalIncome)}',
                        UpriseColors.success,
                        UpriseColors.successBg,
                        Icons.trending_up_rounded,
                      ),
                      const SizedBox(width: 14),
                      _detailStatCard(
                        'Total Expenses',
                        '₱${_fmt(event.totalExpenses)}',
                        UpriseColors.error,
                        UpriseColors.errorBg,
                        Icons.trending_down_rounded,
                      ),
                      const SizedBox(width: 14),
                      _detailStatCard(
                        'Net Amount',
                        '₱${_fmt(net)}',
                        net >= 0 ? UpriseColors.success : UpriseColors.error,
                        net >= 0
                            ? UpriseColors.successBg
                            : UpriseColors.errorBg,
                        Icons.account_balance_wallet_rounded,
                      ),
                      const SizedBox(width: 14),
                      _detailStatCard(
                        'Budget Variance',
                        '₱${_fmt(event.budgetVariance)}',
                        UpriseColors.primaryDark,
                        UpriseColors.primaryLight,
                        Icons.balance_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Breakdowns
                  Row(
                    children: [
                      Expanded(
                        child: _breakdownCard(
                          'Income Breakdown',
                          event.incomeBreakdown,
                          maxInc,
                          UpriseColors.success,
                          Icons.trending_up_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _breakdownCard(
                          'Expense Breakdown',
                          event.expenseBreakdown,
                          maxExp,
                          UpriseColors.error,
                          Icons.trending_down_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _notesCard(
                          'Financial Notes',
                          event.financialNotes,
                          Icons.notes_rounded,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _notesCard(
                          'Recommendations',
                          event.recommendations,
                          Icons.lightbulb_outline_rounded,
                        ),
                      ),
                    ],
                  ),
                  if (event.attachments.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _attachmentsCard(event.attachments),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailStatCard(
    String label,
    String value,
    Color color,
    Color bgColor,
    IconData icon,
  ) {
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
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
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: color,
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

  Widget _breakdownCard(
    String title,
    List<Map<String, dynamic>> items,
    double maxVal,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(title, icon: icon),
          if (items.isEmpty)
            Text(
              'No breakdown data.',
              style: GoogleFonts.beVietnamPro(
                color: const Color(0xFF64748B),
                fontSize: 13,
              ),
            )
          else
            ...items.map((item) {
              final amt = (item['amount'] as num?)?.toDouble() ?? 0;
              final ratio = maxVal > 0 ? amt / maxVal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['name']?.toString() ?? '',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          '₱${_fmt(amt)}',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio.toDouble(),
                        backgroundColor: const Color(0xFFE8ECF0),
                        color: color,
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _notesCard(String title, List<String> notes, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(title, icon: icon),
          if (notes.isEmpty)
            Text(
              'No entries recorded.',
              style: GoogleFonts.beVietnamPro(
                color: const Color(0xFF64748B),
                fontSize: 13,
              ),
            )
          else
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 3,
                      height: 42,
                      margin: const EdgeInsets.only(right: 10, top: 2),
                      decoration: BoxDecoration(
                        color: UpriseColors.primaryDark.withAlpha(76),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        note,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          color: const Color(0xFF374151),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _attachmentsCard(List<Map<String, dynamic>> attachments) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8ECF0)),
        boxShadow: _DS.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Attachments', icon: Icons.attach_file_rounded),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: attachments.map((att) {
              final name = att['name']?.toString() ?? 'File';
              final size = att['size']?.toString() ?? '';
              final fileUrl = att['fileUrl']?.toString() ?? '';
              return GestureDetector(
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Opening: $fileUrl'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_DS.radiusSm),
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E6EA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: UpriseColors.infoBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.insert_drive_file_outlined,
                          color: UpriseColors.info,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            size,
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.download_outlined,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _metaCell(
    String key,
    String value, {
    bool last = false,
    bool lastRow = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            right: last
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFE8ECF0)),
            bottom: lastRow
                ? BorderSide.none
                : const BorderSide(color: Color(0xFFE8ECF0)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              key,
              style: GoogleFonts.beVietnamPro(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────
  void _showDeadlineDialog() {
    DateTime? tempFin = _financialDeadline;
    DateTime? tempAcc = _accomplishmentDeadline;
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark,
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
                          Icons.edit_calendar_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Set Submission Deadlines',
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
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _deadlineTile(
                        'Financial Report Deadline',
                        tempFin,
                        Icons.attach_money_rounded,
                        ctx,
                        (p) => setDlg(() => tempFin = p),
                      ),
                      const SizedBox(height: 12),
                      _deadlineTile(
                        'Accomplishment Report Deadline',
                        tempAcc,
                        Icons.assignment_rounded,
                        ctx,
                        (p) => setDlg(() => tempAcc = p),
                      ),
                    ],
                  ),
                ),
                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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
                        onPressed: () => Navigator.pop(ctx),
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
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _financialDeadline = tempFin;
                            _accomplishmentDeadline = tempAcc;
                          });
                          await _saveDeadlines();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UpriseColors.primaryDark,
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
                          'Save Deadlines',
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
        ),
      ),
    );
  }

  Widget _deadlineTile(
    String label,
    DateTime? date,
    IconData icon,
    BuildContext ctx,
    void Function(DateTime) onPicked,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withAlpha(26),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: UpriseColors.primaryDark, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF374151),
                  ),
                ),
                Text(
                  date != null
                      ? DateFormat('MMMM dd, yyyy').format(date)
                      : 'Not set',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    color: date != null
                        ? const Color(0xFF1A202C)
                        : const Color(0xFF9AA5B4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.calendar_today_rounded,
              color: UpriseColors.primaryDark,
              size: 18,
            ),
            onPressed: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (picked != null) onPicked(picked);
            },
          ),
        ],
      ),
    );
  }

  void _showGenerateReportDialog() {
    String fmt = 'PDF';
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                  decoration: BoxDecoration(
                    color: UpriseColors.primaryDark,
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
                          Icons.insert_drive_file_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Generate Report',
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
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionLabel(
                        'Report Parameters',
                        icon: Icons.tune_rounded,
                      ),
                      _summaryRow('Date Range', _filterRange),
                      const SizedBox(height: 8),
                      _summaryRow('Organization', _filterOrg),
                      const SizedBox(height: 8),
                      _summaryRow('Event Type', _filterType),
                      const SizedBox(height: 8),
                      _summaryRow('Report View', _reportView),
                      const SizedBox(height: 20),
                      _sectionLabel(
                        'Output Format',
                        icon: Icons.file_download_rounded,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDlg(() => fmt = 'PDF'),
                              child: _formatOption(
                                'PDF',
                                Icons.picture_as_pdf_rounded,
                                UpriseColors.error,
                                UpriseColors.errorBg,
                                fmt == 'PDF',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDlg(() => fmt = 'CSV'),
                              child: _formatOption(
                                'CSV',
                                Icons.table_chart_rounded,
                                UpriseColors.success,
                                UpriseColors.successBg,
                                fmt == 'CSV',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
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
                        onPressed: () => Navigator.pop(ctx),
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
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (fmt == 'PDF') {
                            await _generatePDFReport();
                          } else {
                            await _exportFinancialCSV();
                          }
                        },
                        icon: Icon(
                          fmt == 'PDF'
                              ? Icons.picture_as_pdf_rounded
                              : Icons.download_rounded,
                          size: 16,
                        ),
                        label: Text(
                          'Generate & Download',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: UpriseColors.primaryDark,
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
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _formatOption(
    String label,
    IconData icon,
    Color color,
    Color bgColor,
    bool selected,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? bgColor : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(_DS.radiusSm),
        border: Border.all(
          color: selected ? color : const Color(0xFFE2E6EA),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: selected ? color : const Color(0xFF9AA5B4),
            size: 20,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? color : const Color(0xFF64748B),
            ),
          ),
          const Spacer(),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color, size: 16),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Row(
    children: [
      SizedBox(
        width: 120,
        child: Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
        ),
      ),
      Text(
        value,
        style: GoogleFonts.beVietnamPro(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );

  void _viewSubmission(OrgSubmission sub, String reportType) {
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
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: UpriseColors.successBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.assignment_turned_in_rounded,
                      color: UpriseColors.success,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$reportType Report',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A202C),
                          ),
                        ),
                        Text(
                          sub.orgName,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _credentialRow(
                label: 'Submitted On',
                value: DateFormat(
                  'MMMM dd, yyyy HH:mm',
                ).format(sub.submittedAt!),
                icon: Icons.calendar_today_rounded,
              ),
              const SizedBox(height: 12),
              _credentialRow(
                label: 'File',
                value: sub.fileUrl != null && sub.fileUrl!.isNotEmpty
                    ? sub.fileUrl!
                    : 'No file attached.',
                icon: Icons.attach_file_rounded,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (sub.fileUrl != null && sub.fileUrl!.isNotEmpty) ...[
                    ElevatedButton.icon(
                      onPressed: () => _openSubmissionFile(sub.fileUrl!),
                      icon: const Icon(Icons.open_in_new_rounded, size: 15),
                      label: Text(
                        'Open File',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
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
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _downloadSubmissionFile(sub.fileUrl!),
                      icon: const Icon(Icons.download_rounded, size: 15),
                      label: Text(
                        'Download File',
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
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
                    ),
                  ],
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
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
                      'Close',
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
      ),
    );
  }

  Widget _credentialRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.beVietnamPro(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E6EA)),
          ),
          child: SelectableText(
            value,
            style: GoogleFonts.beVietnamPro(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF1A202C),
            ),
          ),
        ),
      ],
    );
  }

  void _openSubmissionFile(String url) {
    try {
      html.window.open(url, '_blank');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Opening file in a new tab...'),
          backgroundColor: UpriseColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
    }
  }

  void _downloadSubmissionFile(String url) {
    try {
      final anchor = html.AnchorElement(href: url)
        ..target = '_blank'
        ..download = '';
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Download started...'),
          backgroundColor: UpriseColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not download file: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
    }
  }

  void _sendReminder(OrgSubmission sub, String reportType) {
    if (!sub.hasApprovedEvent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No approved event found for ${sub.orgName}. Reminder not sent.',
          ),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
      return;
    }

    final eventLabel = sub.eventTitle != null ? ' (${sub.eventTitle})' : '';
    final when = sub.eventDate != null
        ? ' on ${DateFormat('MMM dd, yyyy').format(sub.eventDate!)}'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Reminder sent to ${sub.orgName}$eventLabel for $reportType report$when',
        ),
        backgroundColor: UpriseColors.primaryDark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_DS.radiusSm),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _fmt(double value) => NumberFormat('#,##0.00', 'en_PH').format(value);
  String _fmtK(double value) {
    if (value.abs() >= 1000000)
      return '${NumberFormat('#,##0.0', 'en_PH').format(value / 1000000)}M';
    if (value.abs() >= 1000)
      return '${NumberFormat('#,##0.0', 'en_PH').format(value / 1000)}K';
    return NumberFormat('#,##0.00', 'en_PH').format(value);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable Widgets — identical pattern to student_accounts.dart
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
                      fontSize: 22,
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
}

class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String hint;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.icon,
    required this.onChanged,
  });

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
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: Color(0xFF9AA5B4),
          ),
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            color: const Color(0xFF374151),
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
        label: Text(
          label,
          style: GoogleFonts.beVietnamPro(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: UpriseColors.primaryDark,
          side: BorderSide(color: UpriseColors.primaryDark),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
    return ElevatedButton.icon(
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
}

class _ExportButton extends StatelessWidget {
  final VoidCallback onExportCsv, onExportPdf;
  const _ExportButton({required this.onExportCsv, required this.onExportPdf});

  @override
  Widget build(BuildContext context) {
    return AdminExportButton(
      onSelected: (choice) {
        if (choice == 'csv') onExportCsv();
        if (choice == 'pdf') onExportPdf();
      },
    );
  }
}

class _EventIcon extends StatelessWidget {
  final String type;
  const _EventIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final Map<String, _IconStyle> styles = {
      'Seminar': _IconStyle(
        const Color(0xFFEFF6FF),
        const Color(0xFF2563EB),
        Icons.mic_rounded,
      ),
      'Workshop': _IconStyle(
        const Color(0xFFFFF7ED),
        const Color(0xFFEA580C),
        Icons.build_rounded,
      ),
      'Exhibition': _IconStyle(
        const Color(0xFFF5F3FF),
        const Color(0xFF7C3AED),
        Icons.museum_rounded,
      ),
      'Social': _IconStyle(
        const Color(0xFFFCE7F3),
        const Color(0xFFDB2777),
        Icons.people_rounded,
      ),
      'Cultural': _IconStyle(
        const Color(0xFFF0FDF4),
        const Color(0xFF16A34A),
        Icons.celebration_rounded,
      ),
      'Competition': _IconStyle(
        const Color(0xFFFEFCE8),
        const Color(0xFFCA8A04),
        Icons.emoji_events_rounded,
      ),
    };
    final s =
        styles[type] ??
        _IconStyle(
          const Color(0xFFF3F4F6),
          const Color(0xFF6B7280),
          Icons.event_rounded,
        );
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(s.icon, color: s.fg, size: 15),
    );
  }
}

class _IconStyle {
  final Color bg, fg;
  final IconData icon;
  const _IconStyle(this.bg, this.fg, this.icon);
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: UpriseColors.infoBg,
        borderRadius: BorderRadius.circular(_DS.radiusPill),
      ),
      child: Text(
        type,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: UpriseColors.info,
        ),
      ),
    );
  }
}

class _OrgAvatar extends StatelessWidget {
  final String name;
  const _OrgAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark.withAlpha(26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.beVietnamPro(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: UpriseColors.primaryDark,
          ),
        ),
      ),
    );
  }
}

class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  // ignore: unused_element_parameter
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            icon,
            size: 16,
            color: onTap == null
                ? const Color(0xFFD1D5DB)
                : (color ?? const Color(0xFF64748B)),
          ),
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
  Widget build(BuildContext context) {
    return InkWell(
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? UpriseColors.primaryDark : Colors.transparent,
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
}
