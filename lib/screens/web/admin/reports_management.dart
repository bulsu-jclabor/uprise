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
import 'dart:convert'; // for base64Decode, utf8
import '../../../utils/platform_file_utils.dart' as platform_file_utils; // adjust path if needed

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
  static const Color primary = Color(0xFFF97316);
  static const Color primaryDark = Color(0xFFEA580C);
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
  static const Color warning = Color(0xFFFB923C);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFEFF6FF);
}

// ─────────────────────────────────────────────────────────────────────────────
// Admin Report Model
// ─────────────────────────────────────────────────────────────────────────────
class AdminReport {
  final String id;
  final String orgId;
  final String orgName;
  final String eventTitle;
  final String type;
  final String description;
  final DateTime submittedAt;
  final String? fileBase64;
  final String? fileName;
  final String? fileSize;
  final bool archived;

  AdminReport({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.eventTitle,
    required this.type,
    required this.description,
    required this.submittedAt,
    this.fileBase64,
    this.fileName,
    this.fileSize,
    this.archived = false,
  });

  factory AdminReport.fromFirestore(DocumentSnapshot doc, Map<String, String> orgMap) {
    final data = doc.data() as Map<String, dynamic>;
    final orgId = data['orgId']?.toString() ?? '';
    return AdminReport(
      id: doc.id,
      orgId: orgId,
      orgName: orgMap[orgId] ?? 'Unknown',
      eventTitle: data['title']?.toString() ?? 'Untitled',
      type: data['type']?.toString() ?? 'financial',
      description: data['description']?.toString() ?? '',
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fileBase64: data['fileBase64'] as String?,
      fileName: data['fileName'] as String?,
      fileSize: data['fileSize'] as String?,
      archived: data['archived'] as bool? ?? false,
    );
  }
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
    'on time': _BadgeStyle(
      UpriseColors.successBg,
      UpriseColors.success,
      'ON TIME',
    ),
    'late': _BadgeStyle(
      UpriseColors.warningBg,
      UpriseColors.warning,
      'LATE',
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
// Data Models for Events
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
  // Admin override for this specific org's deadline, if they ever edited it.
  // Falls back to the automatic 7-day rule when null.
  final DateTime? deadlineOverride;

  OrgSubmission({
    required this.orgId,
    required this.orgName,
    this.submittedAt,
    this.fileUrl,
    this.submissionId,
    this.eventId,
    this.eventTitle,
    this.eventDate,
    this.deadlineOverride,
  });

  bool get hasApprovedEvent => eventDate != null && eventTitle != null;

  // Submission deadline rule: automatically 1 week AFTER the event date,
  // unless an admin has set a per-org override for this report type.
  DateTime? get eventDeadline =>
      deadlineOverride ?? eventDate?.add(const Duration(days: 7));

  bool get isLate =>
      submittedAt != null &&
      eventDeadline != null &&
      submittedAt!.isAfter(eventDeadline!);
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

  String? _getOrgLogo(String orgId) {
    // Find the organization with this ID
    final org = _organizations.firstWhere(
      (o) => o['id'] == orgId,
      orElse: () => <String, dynamic>{},
    );
    // Return its logo URL (or null if not found)
    return org['logoUrl'] as String?;
  }

  final TextEditingController _eventSearchController = TextEditingController();
  final TextEditingController _reportSearchController = TextEditingController();

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

  List<EventReport> _events = [];
  List<Map<String, dynamic>> _organizations = [];
  bool _loadingEvents = true;

  // Admin reports for financial and accomplishment
  List<AdminReport> _financialReports = [];
  List<AdminReport> _accomplishmentReports = [];
  bool _loadingFinancial = true;
  bool _loadingAccomplishment = true;

  // Keep these for submission tracker tab
  List<OrgSubmission> _financialSubs = [];
  List<OrgSubmission> _accomplishmentSubs = [];
  bool _loadingFinancialSubs = true;
  bool _loadingAccomplishmentSubs = true;
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
    _loadFinancialReports();
    _loadAccomplishmentReports();
    _loadEvents();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _eventSearchController.dispose();
    _reportSearchController.dispose();
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
      _organizations = snap.docs.map((doc) {
        final data = doc.data();
        return <String, dynamic>{
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unknown',
          'logoUrl': data['logoUrl'] as String?,
        };
      }).toList();
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
      if (_filterType != 'All Types') {
        query = query.where('type', isEqualTo: _filterType);
      }
      if (_filterOrg != 'All Organizations') {
        final org = _organizations.firstWhere(
          (o) => o['name'] == _filterOrg,
          orElse: () => <String, dynamic>{'id': '', 'name': ''},
        );
        if ((org['id'] as String).isNotEmpty) {
          query = query.where('orgId', isEqualTo: org['id']);
        }
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

  // ── Load Financial Reports ──────────────────────────────────
  Future<void> _loadFinancialReports() async {
    if (!mounted) return;
    setState(() => _loadingFinancial = true);
    try {
      // Query WITHOUT the 'archived' filter
      final reportsSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('type', isEqualTo: 'financial')
          .get();

      final orgsSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .get();
      final orgMap = {
        for (var doc in orgsSnap.docs) doc.id: doc.data()['name']?.toString() ?? 'Unknown'
      };

      final allReports = reportsSnap.docs
          .map((doc) => AdminReport.fromFirestore(doc, orgMap))
          .toList();

      // Filter out archived reports in memory
      final activeReports = allReports.where((r) => !r.archived).toList();

      if (!mounted) return;
      setState(() {
        _financialReports = activeReports;
        _loadingFinancial = false;
      });
    } catch (e) {
      debugPrint('Error loading financial reports: $e');
      if (mounted) {
        setState(() => _loadingFinancial = false);
        // Show a snackbar to let you know something went wrong
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load financial reports: $e'),
            backgroundColor: UpriseColors.error,
          ),
        );
      }
    }
  }

  // ── Load Accomplishment Reports ─────────────────────────────
  Future<void> _loadAccomplishmentReports() async {
    if (!mounted) return;
    setState(() => _loadingAccomplishment = true);
    try {
      // Query WITHOUT the 'archived' filter
      final reportsSnap = await FirebaseFirestore.instance
          .collection('reports')
          .where('type', isEqualTo: 'accomplishment')
          .get();

      final orgsSnap = await FirebaseFirestore.instance
          .collection('organizations')
          .get();
      final orgMap = {
        for (var doc in orgsSnap.docs) doc.id: doc.data()['name']?.toString() ?? 'Unknown'
      };

      final allReports = reportsSnap.docs
          .map((doc) => AdminReport.fromFirestore(doc, orgMap))
          .toList();

      // Filter out archived reports in memory
      final activeReports = allReports.where((r) => !r.archived).toList();

      if (!mounted) return;
      setState(() {
        _accomplishmentReports = activeReports;
        _loadingAccomplishment = false;
      });
    } catch (e) {
      debugPrint('Error loading accomplishment reports: $e');
      if (mounted) {
        setState(() => _loadingAccomplishment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load accomplishment reports: $e'),
            backgroundColor: UpriseColors.error,
          ),
        );
      }
    }
  }

  // ── Archive Report ────────────────────────────────────────────────
  Future<void> _archiveReport(AdminReport report) async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _ConfirmDialog(
        title: 'Archive Report',
        message: 'Are you sure you want to archive "${report.eventTitle}" from ${report.orgName}?',
        confirmLabel: 'Archive',
        destructive: false,
      ),
    );
    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(report.id)
          .update({'archived': true});

      await activity_log.ActivityLogger.log(
        action: 'archive_report',
        module: 'Reports',
        details: {
          'reportId': report.id,
          'orgId': report.orgId,
          'eventTitle': report.eventTitle,
        },
      );

      // Remove from the active list
      setState(() {
        if (report.type == 'financial') {
          _financialReports.removeWhere((r) => r.id == report.id);
        } else {
          _accomplishmentReports.removeWhere((r) => r.id == report.id);
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Report archived successfully'),
          backgroundColor: UpriseColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error archiving report: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_DS.radiusSm),
          ),
        ),
      );
    }
  }

  // ── View Report Modal ─────────────────────────────────────────────
  void _viewReport(AdminReport report) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _ViewAdminReportModal(report: report),
    );
  }

  // Reports are only due once an event has actually happened, so the
  // tracker is keyed off each org's most recently FINISHED approved event
  // (not an upcoming one — there's nothing to report on yet for those).
  Future<Map<String, Map<String, dynamic>>>
  _loadLastFinishedEventsByOrg() async {
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
      if (orgId == null || orgId.isEmpty || date == null || !date.isBefore(now)) {
        continue;
      }

      final existing = eventInfo[orgId];
      if (existing == null ||
          date.isAfter(existing['eventDate'] as DateTime)) {
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

  // Per-org/type deadline overrides an admin has set, keyed '{orgId}_{type}'.
  Future<Map<String, DateTime>> _loadDeadlineOverrides(String type) async {
    final snap = await FirebaseFirestore.instance
        .collection('report_deadline_overrides')
        .where('type', isEqualTo: type)
        .get();
    final map = <String, DateTime>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final orgId = data['orgId']?.toString();
      final deadline = (data['deadline'] as Timestamp?)?.toDate();
      if (orgId != null && deadline != null) map[orgId] = deadline;
    }
    return map;
  }

  Future<void> _saveDeadlineOverride(
    OrgSubmission sub,
    String type,
    DateTime? deadline,
  ) async {
    final docId = '${sub.orgId}_$type';
    final ref = FirebaseFirestore.instance
        .collection('report_deadline_overrides')
        .doc(docId);
    if (deadline == null) {
      await ref.delete();
    } else {
      await ref.set({
        'orgId': sub.orgId,
        'type': type,
        'deadline': Timestamp.fromDate(deadline),
        'eventId': sub.eventId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await activity_log.ActivityLogger.log(
      action: deadline == null
          ? 'Cleared $type report deadline override for ${sub.orgName}'
          : 'Set $type report deadline for ${sub.orgName} to ${DateFormat('yyyy-MM-dd').format(deadline)}',
      module: 'Reports',
      severity: 'info',
      details: {'orgId': sub.orgId, 'type': type},
    );
    if (type == 'financial') {
      await _loadFinancialSubmissions();
    } else {
      await _loadAccomplishmentSubmissions();
    }
  }

  Future<void> _showEditDeadlineDialog(OrgSubmission sub, String type) async {
    DateTime? picked = sub.deadlineOverride;
    final autoDeadline = sub.eventDate?.add(const Duration(days: 7));
    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit ${type == 'financial' ? 'Financial' : 'Accomplishment'} Deadline',
                  style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  sub.orgName,
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                if (autoDeadline != null)
                  Text(
                    'Default (7 days after event): ${DateFormat('MMM dd, yyyy').format(autoDeadline)}',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF9AA5B4)),
                  ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(_DS.radiusSm),
                    border: Border.all(color: const Color(0xFFE2E6EA)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          picked != null
                              ? DateFormat('MMMM dd, yyyy').format(picked!)
                              : 'Using default',
                          style: GoogleFonts.beVietnamPro(fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_rounded, size: 18, color: UpriseColors.primaryDark),
                        onPressed: () async {
                          final result = await showDatePicker(
                            context: ctx,
                            initialDate: picked ?? autoDeadline ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (result != null) setDlg(() => picked = result);
                        },
                      ),
                      if (picked != null)
                        IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF9AA5B4)),
                          tooltip: 'Reset to default',
                          onPressed: () => setDlg(() => picked = null),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Cancel', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _saveDeadlineOverride(sub, type, picked);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: UpriseColors.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Save', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Keep these for submission tracker tab
  Future<void> _loadFinancialSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingFinancialSubs = true);
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
      final eventInfo = await _loadLastFinishedEventsByOrg();
      final overrides = await _loadDeadlineOverrides('financial');
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
            deadlineOverride: overrides[org['id']],
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingFinancialSubs = false);
    }
  }

  Future<void> _loadAccomplishmentSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingAccomplishmentSubs = true);
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
      final eventInfo = await _loadLastFinishedEventsByOrg();
      final overrides = await _loadDeadlineOverrides('accomplishment');
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
            deadlineOverride: overrides[org['id']],
          );
        }).toList();
      });
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _loadingAccomplishmentSubs = false);
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
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: _detailEvent != null
          ? _buildDetailView(_detailEvent!)
          : _buildMainView(),
    );
  }

  static const List<String> _tabSubtitles = [
    'Build a custom analytics report filtered by organization, event type, and semester.',
    'Accomplishment reports submitted by organizations, for your review.',
    'Financial reports submitted by organizations, for your review.',
    'Track which organizations have met their financial and accomplishment report deadlines.',
  ];

  // Page-level overview, visible regardless of which tab is active — same
  // pattern as the stats row on event_proposals.dart / external_account.dart.
  Widget _buildPageStatsRow() {
    final trackedFin = _financialSubs.where((s) => s.hasApprovedEvent).toList();
    final trackedAcc = _accomplishmentSubs.where((s) => s.hasApprovedEvent).toList();
    final overdue = trackedFin.where((s) => s.submittedAt == null && s.eventDeadline != null && DateTime.now().isAfter(s.eventDeadline!)).length +
        trackedAcc.where((s) => s.submittedAt == null && s.eventDeadline != null && DateTime.now().isAfter(s.eventDeadline!)).length;
    final late = trackedFin.where((s) => s.isLate).length + trackedAcc.where((s) => s.isLate).length;

    final cards = [
      _StatCard(
        label: 'Financial Reports',
        value: '${_financialReports.length}',
        icon: Icons.attach_money_rounded,
        color: UpriseColors.success,
      ),
      _StatCard(
        label: 'Accomplishment Reports',
        value: '${_accomplishmentReports.length}',
        icon: Icons.assignment_rounded,
        color: UpriseColors.info,
      ),
      _StatCard(
        label: 'Late Submissions',
        value: '$late',
        icon: Icons.history_toggle_off_rounded,
        color: UpriseColors.warning,
      ),
      _StatCard(
        label: 'Overdue (Not Submitted)',
        value: '$overdue',
        icon: Icons.error_outline_rounded,
        color: UpriseColors.error,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 14),
            cards[i],
          ],
        ],
      ),
    );
  }

  Widget _buildMainView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPageStatsRow(),
        const SizedBox(height: 16),
        _buildTabBar(),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildEventSummaryTab(),
              _buildReportTab('Accomplishment', _accomplishmentReports, _loadingAccomplishment),
              _buildReportTab('Financial', _financialReports, _loadingFinancial),
              _buildSubmissionTrackerTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Tab Bar ───────────────────────────────────────────────────────
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
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

  // ── Report Tab (Accomplishment / Financial) ──────────────────────
  // Pure viewing of whatever orgs have uploaded — filters apply live, no
  // "generate" step needed since the data already exists.
  Widget _buildReportTab(String reportType, List<AdminReport> reports, bool loading) {
    final filtered = _applyReportFilters(reports);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildReportFilterRow(),
          const SizedBox(height: 16),
          _buildReportTable(reportType, filtered, loading),
        ],
      ),
    );
  }

  List<AdminReport> _applyReportFilters(List<AdminReport> reports) {
    var filtered = reports;
    final term = _reportSearchController.text.trim().toLowerCase();
    if (term.isNotEmpty) {
      filtered = filtered
          .where((r) =>
              r.orgName.toLowerCase().contains(term) ||
              r.eventTitle.toLowerCase().contains(term))
          .toList();
    }
    if (_filterOrg != 'All Organizations') {
      filtered = filtered.where((r) => r.orgName == _filterOrg).toList();
    }
    final (start, end) = _computeDateRange();
    if (start != null) {
      filtered = filtered.where((r) => !r.submittedAt.isBefore(start)).toList();
    }
    if (end != null) {
      filtered = filtered.where((r) => !r.submittedAt.isAfter(end)).toList();
    }
    return filtered;
  }

  // Same bare search-field-plus-dropdowns layout as the other admin
  // tables — no card wrapper, no section label.
  Widget _buildReportFilterRow() {
    final orgNames = [
      'All Organizations',
      ..._organizations.map((o) => o['name'] as String),
    ];

    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: _reportSearchController,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by event or organization…',
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );

    final filters = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FilterDropdown(
          value: _filterOrg,
          items: orgNames,
          hint: 'Organization',
          icon: Icons.business_rounded,
          onChanged: (v) => setState(() => _filterOrg = v!),
        ),
        _FilterDropdown(
          value: _filterAcademicYear,
          items: _academicYears,
          hint: 'Academic Year',
          icon: Icons.school_rounded,
          onChanged: (v) => setState(() => _filterAcademicYear = v!),
        ),
        _FilterDropdown(
          value: _filterSemester,
          items: _semesters,
          hint: 'Semester',
          icon: Icons.calendar_view_month_rounded,
          onChanged: (v) => setState(() => _filterSemester = v!),
        ),
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [searchField, const SizedBox(height: 10), filters],
        );
      }
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 10),
          filters,
        ],
      );
    });
  }

  // ── Report Table ─────────────────────────────────────────────────
  Widget _buildReportTable(String reportType, List<AdminReport> reports, bool loading) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final sorted = List<AdminReport>.from(reports)
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

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
              color: Color(0xFFFFF7ED),
              borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
              border: Border(bottom: BorderSide(color: Color(0xFFFB923C))),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _headerCell('ORGANIZATION')),
                Expanded(flex: 3, child: _headerCell('EVENT')),
                Expanded(flex: 2, child: _headerCell('TYPE')),
                Expanded(flex: 3, child: _headerCell('DESCRIPTION')),
                Expanded(flex: 2, child: _headerCell('DATE SUBMITTED')),
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
          if (sorted.isEmpty)
            _buildEmptyState()
          else
            ...sorted.asMap().entries.map((entry) {
              final i = entry.key;
              final report = entry.value;
              final isLast = i == sorted.length - 1;
              return InkWell(
                hoverColor: const Color(0xFFF8F9FB),
                onTap: () => _viewReport(report),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    border: isLast
                        ? null
                        : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            _OrgAvatar(
                              name: report.orgName,
                              imageUrl: _getOrgLogo(report.orgId),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                report.orgName,
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
                        flex: 3,
                        child: Text(
                          report.eventTitle,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF1A202C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: report.type == 'financial'
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            report.type == 'financial' ? 'Financial' : 'Accomplishment',
                            style: GoogleFonts.beVietnamPro(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: report.type == 'financial'
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF2563EB),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          report.description,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          DateFormat('MMM dd, yyyy').format(report.submittedAt),
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            _ActionIconButton(
                              icon: Icons.visibility_outlined,
                              tooltip: 'View Report',
                              onTap: () => _viewReport(report),
                            ),
                            const SizedBox(width: 4),
                            _ActionIconButton(
                              icon: Icons.archive_outlined,
                              tooltip: 'Archive Report',
                              color: UpriseColors.warning,
                              onTap: () => _archiveReport(report),
                            ),
                          ],
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
                  'Showing ${sorted.length} reports',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
                AdminExportButton(
                  onSelected: (choice) async {
                    if (choice == 'csv') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Exporting $reportType reports as CSV...'),
                          backgroundColor: UpriseColors.primaryDark,
                        ),
                      );
                    } else if (choice == 'pdf') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Exporting $reportType reports as PDF...'),
                          backgroundColor: UpriseColors.primaryDark,
                        ),
                      );
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

  // ── Event Summary Tab ─────────────────────────────────────────────
  Widget _buildEventSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventSummaryToolbar(),
          const SizedBox(height: 16),
          _loadingEvents
              ? const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _buildEventSummaryResults(),
        ],
      ),
    );
  }

  List<EventReport> get _filteredEvents {
    final term = _eventSearchController.text.trim().toLowerCase();
    if (term.isEmpty) return _events;
    return _events
        .where((e) =>
            e.title.toLowerCase().contains(term) ||
            e.orgName.toLowerCase().contains(term))
        .toList();
  }

  // Live analytics, filtered as you go — same idea as the org-side Event
  // Analytics screen, but aggregated across every organization instead of
  // just one. No "generate" step: each filter re-queries immediately. Same
  // bare search-field-plus-dropdowns layout as the other admin tables
  // (no card wrapper, no section label).
  Widget _buildEventSummaryToolbar() {
    final orgNames = [
      'All Organizations',
      ..._organizations.map((o) => o['name'] as String),
    ];

    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: _eventSearchController,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by event or organization…',
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5)),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );

    final filters = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FilterDropdown(
          value: _filterOrg,
          items: orgNames,
          hint: 'Organization',
          icon: Icons.business_rounded,
          onChanged: (v) {
            setState(() => _filterOrg = v!);
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterType,
          items: const [
            'All Types', 'Seminar', 'Workshop', 'Exhibition',
            'Social', 'Cultural', 'Competition',
          ],
          hint: 'Event Type',
          icon: Icons.category_rounded,
          onChanged: (v) {
            setState(() => _filterType = v!);
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterAcademicYear,
          items: _academicYears,
          hint: 'Academic Year',
          icon: Icons.school_rounded,
          onChanged: (v) {
            setState(() => _filterAcademicYear = v!);
            _loadEvents();
          },
        ),
        _FilterDropdown(
          value: _filterSemester,
          items: _semesters,
          hint: 'Semester',
          icon: Icons.calendar_view_month_rounded,
          onChanged: (v) {
            setState(() => _filterSemester = v!);
            _loadEvents();
          },
        ),
        _ExportButton(
          onExportCsv: _exportFinancialCSV,
          onExportPdf: _generatePDFReport,
        ),
      ],
    );

    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth < 760) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [searchField, const SizedBox(height: 10), filters],
        );
      }
      return Row(
        children: [
          Expanded(child: searchField),
          const SizedBox(width: 10),
          filters,
        ],
      );
    });
  }

  Widget _buildEventSummaryResults() {
    final events = _filteredEvents;
    final typeCount = <String, int>{};
    final orgCount = <String, int>{};

    for (final e in events) {
      typeCount[e.type] = (typeCount[e.type] ?? 0) + 1;
      orgCount[e.orgName] = (orgCount[e.orgName] ?? 0) + 1;
    }

    final sortedTypes = typeCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sortedOrgs = orgCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxTypeCount = sortedTypes.isEmpty ? 1 : sortedTypes.first.value;
    final maxOrgCount = sortedOrgs.isEmpty ? 1 : sortedOrgs.first.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8ECF0)),
                      boxShadow: _DS.cardShadow,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Events by Type', icon: Icons.category_rounded),
                      if (sortedTypes.isEmpty)
                        Text('No events to display.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)))
                      else
                        ...sortedTypes.map((entry) {
                          final r = maxTypeCount > 0 ? entry.value / maxTypeCount : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Text(entry.key, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151))),
                                Text('${entry.value}', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.primaryDark)),
                              ]),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(value: r.toDouble(), backgroundColor: const Color(0xFFE8ECF0), color: UpriseColors.primaryDark, minHeight: 6),
                              ),
                            ]),
                          );
                        }),
                    ]),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8ECF0)),
                      boxShadow: _DS.cardShadow,
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _sectionLabel('Events by Organization', icon: Icons.business_rounded),
                      if (sortedOrgs.isEmpty)
                        Text('No events to display.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)))
                      else
                        ...sortedOrgs.take(6).map((entry) {
                          final r = maxOrgCount > 0 ? entry.value / maxOrgCount : 0.0;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                Expanded(child: Text(entry.key, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151)), overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 8),
                                Text('${entry.value}', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w700, color: UpriseColors.info)),
                              ]),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(value: r.toDouble(), backgroundColor: const Color(0xFFE8ECF0), color: UpriseColors.info, minHeight: 6),
                              ),
                            ]),
                          );
                        }),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
        _buildEventsTable(events, showFinancial: false, showCountdown: false),
      ],
    );
  }

  // ── Events Table ──────────────────────────────────────────────────
  // Plain Column of mapped rows, no ListView/Expanded — same structural
  // pattern as _buildReportTable/_buildSubmissionTable elsewhere in this
  // file, so it doesn't need a height-bounded ancestor (that mismatch was
  // the cause of the bottom overflow).
  Widget _buildEventsTable(
    List<EventReport> events, {
    required bool showFinancial,
    required bool showCountdown,
  }) {
    if (_loadingEvents) return const Center(child: CircularProgressIndicator());
    final totalPages = events.isEmpty ? 1 : (events.length / _pageSize).ceil();
    final safePage = _currentPage.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, events.length);
    final pageItems = events.isEmpty ? <EventReport>[] : events.sublist(start, end);

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
          if (events.isEmpty)
            _buildEmptyState()
          else
            ...pageItems.asMap().entries.map((entry) => _buildEventRow(
                  event: entry.value,
                  isLast: entry.key == pageItems.length - 1,
                  showFinancial: showFinancial,
                  showCountdown: showCountdown,
                )),
          _buildTableFooter(events.length, totalPages, start, end),
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
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFFB923C))),
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
                      child: Align(
                        alignment: Alignment.centerLeft,
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
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _EventCategoryChip(type: event.type),
                    ),
                  ),
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
            'No reports found',
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
            _loadingFinancialSubs,
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
            _loadingAccomplishmentSubs,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 8),
          Text(
            'Defaults to 7 days after each event unless set here, or overridden for a specific organization using the "Edit Deadline" icon in its row below.',
            style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4)),
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

  // Orgs with no finished event yet have nothing due, so they're excluded
  // from every count here — matches what _buildSubmissionTable shows.
  Widget _buildTrackerStats() {
    final fin = _financialSubs.where((s) => s.hasApprovedEvent).toList();
    final acc = _accomplishmentSubs.where((s) => s.hasApprovedEvent).toList();
    final tracked = fin.length;

    final onTime = fin.where((s) => s.submittedAt != null && !s.isLate).length +
        acc.where((s) => s.submittedAt != null && !s.isLate).length;
    final late = fin.where((s) => s.isLate).length + acc.where((s) => s.isLate).length;
    final overdue = fin.where((s) => s.submittedAt == null && s.eventDeadline != null && DateTime.now().isAfter(s.eventDeadline!)).length +
        acc.where((s) => s.submittedAt == null && s.eventDeadline != null && DateTime.now().isAfter(s.eventDeadline!)).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _StatCard(
            label: 'Orgs Tracked',
            value: '$tracked',
            icon: Icons.business_rounded,
            color: UpriseColors.primaryDark,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Submitted On Time',
            value: '$onTime',
            icon: Icons.check_circle_rounded,
            color: UpriseColors.success,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Submitted Late',
            value: '$late',
            icon: Icons.history_toggle_off_rounded,
            color: UpriseColors.warning,
          ),
          const SizedBox(width: 14),
          _StatCard(
            label: 'Overdue (Not Submitted)',
            value: '$overdue',
            icon: Icons.error_outline_rounded,
            color: UpriseColors.error,
          ),
        ],
      ),
    );
  }

  // ── Submission Table ──────────────────────────────────────────────
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

    final type = title.toLowerCase();

    // Only orgs whose event has actually finished have a report due — an
    // org with no finished event yet has nothing to track here.
    final sorted = submissions.where((s) => s.hasApprovedEvent).toList()
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
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFFB923C))),
            ),
            child: Row(
              children: [
                Expanded(flex: 3, child: _headerCell('ORGANIZATION')),
                Expanded(flex: 2, child: _headerCell('EVENT DATE')),
                Expanded(flex: 2, child: _headerCell('DEADLINE')),
                Expanded(flex: 2, child: _headerCell('SUBMITTED ON')),
                Expanded(flex: 2, child: _headerCell('STATUS')),
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _headerCell('ACTIONS'),
                  ),
                ),
              ],
            ),
          ),
          // Rows
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No organizations with a finished event yet.',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
            )
          else
          ...sorted.asMap().entries.map((entry) {
            final i = entry.key;
            final sub = entry.value;
            final isSubmitted = sub.submittedAt != null;
            // Precedence: this org's own override beats the blanket global
            // deadline, which beats the automatic 7-days-after-event rule.
            final rowDeadline =
                sub.deadlineOverride ?? deadline ?? sub.eventDate!.add(const Duration(days: 7));
            final isOverdue = !isSubmitted && DateTime.now().isAfter(rowDeadline);
            final isLate = isSubmitted && sub.submittedAt!.isAfter(rowDeadline);
            final daysLeft = !isSubmitted
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              DateFormat('MMM dd, yyyy').format(rowDeadline),
                              style: GoogleFonts.beVietnamPro(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (sub.deadlineOverride != null) ...[
                            const SizedBox(width: 4),
                            const Tooltip(
                              message: 'Custom deadline set by admin',
                              child: Icon(Icons.push_pin_rounded, size: 12, color: UpriseColors.primaryDark),
                            ),
                          ],
                        ],
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
                          ? _statusBadge(isLate ? 'late' : 'on time')
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
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isSubmitted)
                            _ActionIconButton(
                              icon: Icons.visibility_outlined,
                              tooltip: 'View Report',
                              onTap: () => _viewSubmission(sub, title),
                            )
                          else
                            _ActionIconButton(
                              icon: Icons.send_outlined,
                              tooltip: 'Send Reminder',
                              onTap: () => _sendReminder(sub, title),
                            ),
                          const SizedBox(width: 4),
                          _ActionIconButton(
                            icon: Icons.edit_calendar_outlined,
                            tooltip: 'Edit Deadline',
                            color: UpriseColors.primaryDark,
                            onTap: () => _showEditDeadlineDialog(sub, type),
                          ),
                        ],
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
                      await _exportSubmissionCSV(title, sorted, deadline);
                    } else if (choice == 'pdf') {
                      await _exportSubmissionPdf(title, sorted, deadline);
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
// View Admin Report Modal
// ─────────────────────────────────────────────────────────────────────────────
class _ViewAdminReportModal extends StatelessWidget {
  final AdminReport report;
  const _ViewAdminReportModal({required this.report});

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
                          report.orgName,
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
                  // Event Title
                  Text(
                    report.eventTitle,
                    style: GoogleFonts.beVietnamPro(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1A202C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _detailItem(
                          'Organization',
                          report.orgName,
                          Icons.business_rounded,
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
                          ).format(report.submittedAt),
                          Icons.calendar_today_outlined,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _detailItem(
                          'Event',
                          report.eventTitle,
                          Icons.event_rounded,
                        ),
                      ),
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
                  // File Attachment
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
                              color: UpriseColors.primaryDark.withAlpha(26),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.insert_drive_file_rounded,
                              size: 20,
                              color: UpriseColors.primaryDark,
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
                              foregroundColor: UpriseColors.primaryDark,
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
        // Use platform_file_utils if available, otherwise fallback
        try {
          await platform_file_utils.saveBytesToTempAndOpen(bytes, name, mimeType: mime);
        } catch (e) {
          // Fallback: download via HTML
          final anchor = html.AnchorElement(
            href: 'data:$mime;base64,$b64',
          )
            ..download = name
            ..target = '_blank';
          html.document.body?.append(anchor);
          anchor.click();
          anchor.remove();
        }
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
// Confirm Dialog
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
                  color: destructive ? const Color(0xFFFEF2F2) : UpriseColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  destructive
                      ? Icons.delete_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: destructive ? const Color(0xFFDC2626) : UpriseColors.primaryDark,
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
                      : UpriseColors.primaryDark,
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
// Reusable Widgets
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

// Shared event-category styling — used by both the icon badge next to the
// event title and the category chip in the TYPE column, so they always
// agree with each other.
_IconStyle _eventTypeStyle(String type) {
  const styles = {
    'Seminar': _IconStyle(
      Color(0xFFEFF6FF),
      Color(0xFF2563EB),
      Icons.mic_rounded,
    ),
    'Workshop': _IconStyle(
      Color(0xFFFFF7ED),
      Color(0xFFEA580C),
      Icons.build_rounded,
    ),
    'Exhibition': _IconStyle(
      Color(0xFFF5F3FF),
      Color(0xFF7C3AED),
      Icons.museum_rounded,
    ),
    'Social': _IconStyle(
      Color(0xFFFCE7F3),
      Color(0xFFDB2777),
      Icons.people_rounded,
    ),
    'Cultural': _IconStyle(
      Color(0xFFF0FDF4),
      Color(0xFF16A34A),
      Icons.celebration_rounded,
    ),
    'Competition': _IconStyle(
      Color(0xFFFEFCE8),
      Color(0xFFCA8A04),
      Icons.emoji_events_rounded,
    ),
  };
  return styles[type] ??
      const _IconStyle(
        Color(0xFFF3F4F6),
        Color(0xFF6B7280),
        Icons.event_rounded,
      );
}

class _EventIcon extends StatelessWidget {
  final String type;
  const _EventIcon({required this.type});

  @override
  Widget build(BuildContext context) {
    final s = _eventTypeStyle(type);
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

// Category chip for the TYPE column — shrink-wraps to its text (via the
// Align wrapper at the call site) instead of stretching the whole column,
// matching the category-chip convention used on the other admin pages.
class _EventCategoryChip extends StatelessWidget {
  final String type;
  const _EventCategoryChip({required this.type});

  @override
  Widget build(BuildContext context) {
    final s = _eventTypeStyle(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        type,
        style: GoogleFonts.beVietnamPro(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: s.fg,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _IconStyle {
  final Color bg, fg;
  final IconData icon;
  const _IconStyle(this.bg, this.fg, this.icon);
}

class _OrgAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  const _OrgAvatar({required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: NetworkImage(imageUrl!),
            fit: BoxFit.cover,
          ),
        ),
      );
    }
    // fallback: initials
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
  const _ActionIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = onTap == null
        ? const Color(0xFFD1D5DB)
        : (color ?? const Color(0xFF64748B));
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: effectiveColor.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: effectiveColor),
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