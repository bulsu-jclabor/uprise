import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ============ ACTIVITY LOGGER ============
class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email ?? 'Unknown User';
    await _firestore.collection('activity_logs').add({
      'user': userName,
      'action': action,
      'module': module,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '',
      'details': details,
    });
  }
}

// ─────────────────────────────────────────────
//  THEME COLORS  (matches UPRISE orange palette)
// ─────────────────────────────────────────────
class UpriseColors {
  static const Color primary      = Color(0xFFE87722);
  static const Color primaryDark  = Color(0xFFC45E00);
  static const Color primaryLight = Color(0xFFFFF3E8);
  static const Color white        = Color(0xFFFFFFFF);
  static const Color lightGray    = Color(0xFFF7F8FA);
  static const Color mediumGray   = Color(0xFFE2E6EA);
  static const Color darkGray     = Color(0xFF6B7280);
  static const Color charcoal     = Color(0xFF1F2937);
  static const Color success      = Color(0xFF16A34A);
  static const Color successBg    = Color(0xFFDCFCE7);
  static const Color error        = Color(0xFFDC2626);
  static const Color errorBg      = Color(0xFFFEE2E2);
  static const Color warning      = Color(0xFFD97706);
  static const Color warningBg    = Color(0xFFFEF3C7);
  static const Color info         = Color(0xFF2563EB);
  static const Color infoBg       = Color(0xFFDBEAFE);
}

// ─────────────────────────────────────────────
//  DATA MODELS
// ─────────────────────────────────────────────
class EventReport {
  final String id;
  final String title;
  final String orgId;
  final String orgName;
  final String type;
  final DateTime date;
  final String status;
  // financial
  final double totalIncome;
  final double totalExpenses;
  final double budgetVariance;
  // attendance
  final int registrants;
  final int attendees;
  // detail fields
  final String submittedBy;
  final DateTime? submittedDate;
  final String reportPeriod;
  final List<Map<String, dynamic>> incomeBreakdown;
  final List<Map<String, dynamic>> expenseBreakdown;
  final List<String> financialNotes;
  final List<String> recommendations;
  final List<Map<String, dynamic>> attachments;

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
    this.submittedDate,
    this.reportPeriod = '',
    this.incomeBreakdown = const [],
    this.expenseBreakdown = const [],
    this.financialNotes = const [],
    this.recommendations = const [],
    this.attachments = const [],
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
      id:              doc.id,
      title:           d['title']?.toString() ?? 'Untitled',
      orgId:           d['orgId']?.toString() ?? '',
      orgName:         orgName,
      type:            d['type']?.toString() ?? 'Others',
      date:            (d['date'] as Timestamp).toDate(),
      status:          d['status']?.toString() ?? 'approved',
      totalIncome:     (d['totalIncome'] as num?)?.toDouble() ?? 0,
      totalExpenses:   (d['totalExpenses'] as num?)?.toDouble() ?? 0,
      budgetVariance:  (d['budgetVariance'] as num?)?.toDouble() ?? 0,
      registrants:     registrants,
      attendees:       attendees,
      submittedBy:     d['submittedBy']?.toString() ?? '',
      submittedDate:   (d['submittedDate'] as Timestamp?)?.toDate(),
      reportPeriod:    d['reportPeriod']?.toString() ?? '',
      incomeBreakdown:  List<Map<String, dynamic>>.from(d['incomeBreakdown'] ?? []),
      expenseBreakdown: List<Map<String, dynamic>>.from(d['expenseBreakdown'] ?? []),
      financialNotes:   List<String>.from(d['financialNotes'] ?? []),
      recommendations:  List<String>.from(d['recommendations'] ?? []),
      attachments:      List<Map<String, dynamic>>.from(d['attachments'] ?? []),
    );
  }
}

class OrgSubmission {
  final String orgId;
  final String orgName;
  final DateTime? submittedAt;
  final String? fileUrl;
  final String? submissionId;

  OrgSubmission({
    required this.orgId,
    required this.orgName,
    this.submittedAt,
    this.fileUrl,
    this.submissionId,
  });
}

// ─────────────────────────────────────────────
//  MAIN WIDGET
// ─────────────────────────────────────────────
class ReportsManagement extends StatefulWidget {
  const ReportsManagement({super.key});

  @override
  State<ReportsManagement> createState() => _ReportsManagementState();
}

class _ReportsManagementState extends State<ReportsManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ── filters (only used for Event Summary) ──
  String _filterOrg   = 'All Organizations';
  String _filterType  = 'All Types';
  String _filterRange = 'Current Semester';
  String _reportView  = 'By Event';

  // ── report data ──
  List<EventReport>    _events         = [];
  List<Map<String, dynamic>> _organizations = [];
  bool _loadingEvents  = true;

  // ── submission tracker ──
  List<OrgSubmission> _financialSubs      = [];
  List<OrgSubmission> _accomplishmentSubs = [];
  bool _loadingFinancial      = true;
  bool _loadingAccomplishment = true;
  DateTime? _financialDeadline;
  DateTime? _accomplishmentDeadline;
  bool _loadingDeadlines = true;

  // ── detail view ──
  EventReport? _detailEvent;

  // ── pagination ──
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {
      _detailEvent = null;
      _currentPage = 1;
    }));
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

  // ══════════════════════════════════════════
  //  FIREBASE — ORGANIZATIONS
  // ══════════════════════════════════════════
  Future<void> _loadOrganizations() async {
    final snap = await FirebaseFirestore.instance.collection('organizations').get();
    if (!mounted) return;
    setState(() {
      _organizations = snap.docs.map((doc) => {
        'id':   doc.id,
        'name': doc.data()['name']?.toString() ?? 'Unknown',
      }).toList();
    });
  }

  // ══════════════════════════════════════════
  //  FIREBASE — EVENTS
  // ══════════════════════════════════════════
  Future<void> _loadEvents() async {
    if (!mounted) return;
    setState(() => _loadingEvents = true);
    try {
      Query query = FirebaseFirestore.instance
          .collection('events')
          .where('status', isEqualTo: 'approved');

      if (_filterType != 'All Types') {
        query = query.where('type', isEqualTo: _filterType);
      }
      if (_filterOrg != 'All Organizations') {
        final org = _organizations.firstWhere(
          (o) => o['name'] == _filterOrg,
          orElse: () => {'id': '', 'name': ''},
        );
        if ((org['id'] as String).isNotEmpty) {
          query = query.where('orgId', isEqualTo: org['id']);
        }
      }

      final eventsSnap = await query.get();
      final List<EventReport> loaded = [];

      final orgMap = {for (var o in _organizations) o['id'] as String: o['name'] as String};

      for (final doc in eventsSnap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final orgId   = data['orgId']?.toString() ?? '';
        final orgName = orgMap[orgId] ?? data['orgName']?.toString() ?? 'Unknown';

        final regSnap = await FirebaseFirestore.instance
            .collection('registrations')
            .where('eventId', isEqualTo: doc.id)
            .get();
        final registrants = regSnap.docs.length;
        final attendees   = regSnap.docs
            .where((r) => (r.data())['attended'] == true)
            .length;

        loaded.add(EventReport.fromFirestore(doc, orgName, registrants, attendees));
      }

      if (!mounted) return;
      setState(() => _events = loaded);
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  // ══════════════════════════════════════════
  //  FIREBASE — DEADLINES
  // ══════════════════════════════════════════
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
        _financialDeadline      = (data['financial'] as Timestamp?)?.toDate();
        _accomplishmentDeadline = (data['accomplishment'] as Timestamp?)?.toDate();
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
      'financial':      Timestamp.fromDate(_financialDeadline!),
      'accomplishment': Timestamp.fromDate(_accomplishmentDeadline!),
    });

    // Log deadline change
    await ActivityLogger.log(
      action: 'Updated report deadlines: Financial → ${DateFormat('yyyy-MM-dd').format(_financialDeadline!)}, Accomplishment → ${DateFormat('yyyy-MM-dd').format(_accomplishmentDeadline!)}',
      module: 'Reports',
      severity: 'info',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deadlines updated successfully')),
      );
    }
  }

  // ══════════════════════════════════════════
  //  FIREBASE — SUBMISSIONS
  // ══════════════════════════════════════════
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
      final orgsSnap = await FirebaseFirestore.instance.collection('organizations').get();
      final allOrgs  = orgsSnap.docs.map((doc) => {
        'id':   doc.id,
        'name': doc.data()['name']?.toString() ?? 'Unknown',
      }).toList();

      final subsSnap = await FirebaseFirestore.instance
          .collection('financial_submissions')
          .get();
      final subsMap = <String, Map<String, dynamic>>{};
      for (final doc in subsSnap.docs) {
        final data = doc.data();
        subsMap[data['orgId']?.toString() ?? ''] = {
          'submittedAt':  (data['submittedAt'] as Timestamp).toDate(),
          'fileUrl':      data['fileUrl'],
          'submissionId': doc.id,
        };
      }

      if (!mounted) return;
      setState(() {
        _financialSubs = allOrgs.map((org) => OrgSubmission(
          orgId:        org['id']!,
          orgName:      org['name']!,
          submittedAt:  subsMap[org['id']]?['submittedAt'] as DateTime?,
          fileUrl:      subsMap[org['id']]?['fileUrl'] as String?,
          submissionId: subsMap[org['id']]?['submissionId'] as String?,
        )).toList();
      });
    } catch (e) {
      debugPrint('Error loading financial submissions: $e');
    } finally {
      if (mounted) setState(() => _loadingFinancial = false);
    }
  }

  Future<void> _loadAccomplishmentSubmissions() async {
    if (!mounted) return;
    setState(() => _loadingAccomplishment = true);
    try {
      final orgsSnap = await FirebaseFirestore.instance.collection('organizations').get();
      final allOrgs  = orgsSnap.docs.map((doc) => {
        'id':   doc.id,
        'name': doc.data()['name']?.toString() ?? 'Unknown',
      }).toList();

      final subsSnap = await FirebaseFirestore.instance
          .collection('accomplishment_submissions')
          .get();
      final subsMap = <String, Map<String, dynamic>>{};
      for (final doc in subsSnap.docs) {
        final data = doc.data();
        subsMap[data['orgId']?.toString() ?? ''] = {
          'submittedAt':  (data['submittedAt'] as Timestamp).toDate(),
          'fileUrl':      data['fileUrl'],
          'submissionId': doc.id,
        };
      }

      if (!mounted) return;
      setState(() {
        _accomplishmentSubs = allOrgs.map((org) => OrgSubmission(
          orgId:        org['id']!,
          orgName:      org['name']!,
          submittedAt:  subsMap[org['id']]?['submittedAt'] as DateTime?,
          fileUrl:      subsMap[org['id']]?['fileUrl'] as String?,
          submissionId: subsMap[org['id']]?['submissionId'] as String?,
        )).toList();
      });
    } catch (e) {
      debugPrint('Error loading accomplishment submissions: $e');
    } finally {
      if (mounted) setState(() => _loadingAccomplishment = false);
    }
  }

  // ══════════════════════════════════════════
  //  PDF / CSV GENERATION (Event Summary only) with logging
  // ══════════════════════════════════════════
  Future<void> _logGeneratedReport(String fileName, String format, String type) async {
    await FirebaseFirestore.instance.collection('generated_reports').add({
      'fileName':    fileName,
      'dateRange':   _filterRange,
      'organization': _filterOrg,
      'eventType':   _filterType,
      'reportView':  _reportView,
      'generatedAt': FieldValue.serverTimestamp(),
      'format':      format,
      'reportType':  type,
    });
    // Also log to activity logs
    await ActivityLogger.log(
      action: 'Generated $type report in $format format',
      module: 'Reports',
      severity: 'info',
      details: {'fileName': fileName, 'filters': 'Org: $_filterOrg, Type: $_filterType, Range: $_filterRange'},
    );
  }

  Future<void> _generatePDFReport() async {
    final pdfDoc = pw.Document();
    final now    = DateTime.now();
    final ts     = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'financial_report_$ts.pdf';

    pdfDoc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => [
        pw.Header(
          level: 0,
          child: pw.Text('UPRISE Financial Report',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
        ),
        pw.SizedBox(height: 8),
        pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(now)}'),
        pw.Text('Date Range: $_filterRange  |  Organization: $_filterOrg  |  Event Type: $_filterType'),
        pw.SizedBox(height: 16),
        pw.Header(level: 1, child: pw.Text('Event Financial Summary')),
        _buildPdfFinancialTable(),
      ],
    ));

    await Printing.sharePdf(bytes: await pdfDoc.save(), filename: fileName);
    await _logGeneratedReport(fileName, 'PDF', 'Financial');
  }

  pw.Widget _buildPdfFinancialTable() {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(2),
        2: const pw.FlexColumnWidth(1.5),
        3: const pw.FlexColumnWidth(1.5),
        4: const pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Event', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Organization', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Income', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Net', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ]),
        ..._events.map((e) => pw.TableRow(children: [
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.title)),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(e.orgName)),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('₱${e.totalIncome.toStringAsFixed(2)}')),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('₱${e.totalExpenses.toStringAsFixed(2)}')),
          pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('₱${e.netAmount.toStringAsFixed(2)}')),
        ])),
      ],
    );
  }

  Future<void> _exportFinancialCSV() async {
    final rows = <List<String>>[
      ['Event Name', 'Organization', 'Type', 'Date', 'Income', 'Expenses', 'Net Amount']
    ];
    for (final e in _events) {
      rows.add([
        e.title, e.orgName, e.type,
        DateFormat('yyyy-MM-dd').format(e.date),
        e.totalIncome.toStringAsFixed(2),
        e.totalExpenses.toStringAsFixed(2),
        e.netAmount.toStringAsFixed(2),
      ]);
    }
    final csv  = rows.map((r) => r.join(',')).join('\n');
    final now  = DateTime.now();
    final ts   = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'financial_report_$ts.csv';
    final file = await File('${Directory.systemTemp.path}/$fileName').writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Financial Report');
    await _logGeneratedReport(fileName, 'CSV', 'Financial');
  }

  Future<void> _exportAccomplishmentCSV() async {
    final rows = <List<String>>[
      ['Event Name', 'Organization', 'Type', 'Date', 'Registrants', 'Attendees', 'Ratio']
    ];
    for (final e in _events) {
      rows.add([
        e.title, e.orgName, e.type,
        DateFormat('yyyy-MM-dd').format(e.date),
        '${e.registrants}', '${e.attendees}', '${e.attendanceRatio}%',
      ]);
    }
    final csv  = rows.map((r) => r.join(',')).join('\n');
    final now  = DateTime.now();
    final ts   = DateFormat('yyyyMMdd_HHmmss').format(now);
    final fileName = 'accomplishment_report_$ts.csv';
    final file = await File('${Directory.systemTemp.path}/$fileName').writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: 'Accomplishment Report');
    await _logGeneratedReport(fileName, 'CSV', 'Accomplishment');
  }

  Future<void> _exportSubmissionCSV(String reportType, List<OrgSubmission> submissions, DateTime? deadline) async {
    final rows = <List<String>>[
      ['Organization', 'Deadline', 'Submitted On', 'Status']
    ];
    for (final sub in submissions) {
      final isSubmitted = sub.submittedAt != null;
      final isOverdue   = deadline != null && !isSubmitted && DateTime.now().isAfter(deadline);
      rows.add([
        sub.orgName,
        deadline != null ? DateFormat('yyyy-MM-dd').format(deadline) : '',
        isSubmitted ? DateFormat('yyyy-MM-dd').format(sub.submittedAt!) : '',
        isSubmitted ? 'Submitted' : (isOverdue ? 'Overdue' : 'Pending'),
      ]);
    }
    final csv  = rows.map((r) => r.join(',')).join('\n');
    final file = await File('${Directory.systemTemp.path}/${reportType.toLowerCase()}_submissions.csv')
        .writeAsString(csv);
    await Share.shareXFiles([XFile(file.path)], text: '$reportType Submissions');
  }

  // ══════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════
  void _showDeadlineDialog() {
    DateTime? tempFin = _financialDeadline;
    DateTime? tempAcc = _accomplishmentDeadline;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Set Submission Deadlines',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 320,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _deadlineTile('Financial Report', tempFin, ctx, (p) => setDlg(() => tempFin = p)),
              _deadlineTile('Accomplishment Report', tempAcc, ctx, (p) => setDlg(() => tempAcc = p)),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primary),
              onPressed: () async {
                setState(() {
                  _financialDeadline      = tempFin;
                  _accomplishmentDeadline = tempAcc;
                });
                await _saveDeadlines();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  ListTile _deadlineTile(String label, DateTime? date, BuildContext ctx, void Function(DateTime) onPicked) {
    return ListTile(
      title: Text(label),
      subtitle: Text(date != null ? DateFormat('MMM dd, yyyy').format(date) : 'Not set'),
      trailing: IconButton(
        icon: const Icon(Icons.calendar_today, color: UpriseColors.primary),
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
    );
  }

  void _showGenerateReportDialog() {
    String fmt = 'PDF';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text('Generate Report', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            _summaryRow('Date Range', _filterRange),
            _summaryRow('Organization', _filterOrg),
            _summaryRow('Event Type', _filterType),
            _summaryRow('Report View', _reportView),
            const Divider(height: 24),
            Text('Format', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
            Row(children: [
              Expanded(child: RadioListTile(
                title: const Text('PDF'),
                value: 'PDF', groupValue: fmt,
                onChanged: (v) => setDlg(() => fmt = v!),
                activeColor: UpriseColors.primary,
              )),
              Expanded(child: RadioListTile(
                title: const Text('CSV'),
                value: 'CSV', groupValue: fmt,
                onChanged: (v) => setDlg(() => fmt = v!),
                activeColor: UpriseColors.primary,
              )),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                if (fmt == 'PDF') {
                  await _generatePDFReport();
                } else {
                  await _exportFinancialCSV();
                }
              },
              child: const Text('Generate & Download'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      SizedBox(width: 110, child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray))),
      Text(value, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  // ══════════════════════════════════════════
  //  MAIN BUILD
  // ══════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: _detailEvent != null ? _buildDetailView(_detailEvent!) : _buildMainView(),
    );
  }

  // ─────────────────────────────────────────────
  //  MAIN VIEW
  // ─────────────────────────────────────────────
  Widget _buildMainView() {
    return Column(children: [
      _buildHeader(),
      _buildTabBar(),
      Expanded(child: TabBarView(
        controller: _tabController,
        children: [
          _buildEventSummaryTab(),
          _buildAccomplishmentTab(),
          _buildFinancialTab(),
          _buildSubmissionTrackerTab(),
        ],
      )),
    ]);
  }

  Widget _buildHeader() {
    // Header buttons only appear on Event Summary tab (index 0)
    final isEventSummaryTab = _tabController.index == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      color: UpriseColors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Reports Management',
                style: GoogleFonts.beVietnamPro(fontSize: 22, fontWeight: FontWeight.w800, color: UpriseColors.charcoal)),
            const SizedBox(height: 3),
            Text('Create and export comprehensive analysis on student organization performance, attendance rates, and financial auditing.',
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
          ])),
          const SizedBox(width: 16),
          if (isEventSummaryTab)
            Row(children: [
              _outlineBtn(Icons.download_outlined, 'Export CSV', _exportFinancialCSV),
              const SizedBox(width: 8),
              _primaryBtn(Icons.picture_as_pdf_outlined, 'Export PDF', _showGenerateReportDialog),
            ]),
        ]),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: UpriseColors.white,
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: 'Event Summary'),
          Tab(text: 'Accomplishment Reports'),
          Tab(text: 'Financial Reports'),
          Tab(text: 'Submission Tracker'),
        ],
        labelColor: UpriseColors.primary,
        unselectedLabelColor: UpriseColors.darkGray,
        indicatorColor: UpriseColors.primary,
        indicatorWeight: 3,
        labelStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: GoogleFonts.beVietnamPro(fontSize: 13),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EVENT SUMMARY TAB (with config panel)
  // ─────────────────────────────────────────────
  Widget _buildEventSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildConfigPanel(),
        const SizedBox(height: 16),
        _buildEventStatCards(),
        const SizedBox(height: 16),
        _buildEventsTable(showFinancial: true),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  ACCOMPLISHMENT TAB (no config panel)
  // ─────────────────────────────────────────────
  Widget _buildAccomplishmentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildAccomplishmentStatCards(),
        const SizedBox(height: 16),
        _buildEventsTable(showFinancial: false),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  FINANCIAL TAB (no config panel)
  // ─────────────────────────────────────────────
  Widget _buildFinancialTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildEventStatCards(),
        const SizedBox(height: 16),
        _buildEventsTable(showFinancial: true),
        const SizedBox(height: 16),
        _buildRecentReports(),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  CONFIG PANEL (used only in Event Summary)
  // ─────────────────────────────────────────────
  Widget _buildConfigPanel() {
    final orgNames = ['All Organizations', ..._organizations.map((o) => o['name'] as String)];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.tune, size: 16, color: UpriseColors.primary),
          const SizedBox(width: 8),
          Text('Report Configuration',
              style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: UpriseColors.charcoal)),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 16, runSpacing: 16, children: [
          _filterDropdown('DATE RANGE', _filterRange,
              ['Current Semester', 'Last Semester', 'Academic Year 2024-2025'],
              (v) => setState(() => _filterRange = v!)),
          _filterDropdown('ORGANIZATION', _filterOrg, orgNames, (v) {
            setState(() { _filterOrg = v!; _currentPage = 1; });
            _loadEvents();
          }),
          _filterDropdown('EVENT TYPE', _filterType,
              ['All Types', 'Seminar', 'Workshop', 'Exhibition', 'Social', 'Cultural', 'Competition'],
              (v) {
            setState(() { _filterType = v!; _currentPage = 1; });
            _loadEvents();
          }),
          _filterDropdown('REPORT VIEW', _reportView,
              ['By Event', 'By Organization', 'By Month'],
              (v) => setState(() => _reportView = v!)),
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _primaryBtn(Icons.insert_drive_file_outlined, 'Generate Report', _showGenerateReportDialog),
          ),
        ]),
      ]),
    );
  }

  Widget _filterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 180,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: .5)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: UpriseColors.mediumGray),
            borderRadius: BorderRadius.circular(8),
            color: UpriseColors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  STAT CARDS
  // ─────────────────────────────────────────────
  Widget _buildEventStatCards() {
    final totalIncome   = _events.fold<double>(0, (s, e) => s + e.totalIncome);
    final totalExpenses = _events.fold<double>(0, (s, e) => s + e.totalExpenses);
    final netAmount     = totalIncome - totalExpenses;
    return Row(children: [
      _statCard('Total Income',   '₱${_fmt(totalIncome)}',   UpriseColors.primary),
      const SizedBox(width: 14),
      _statCard('Total Expenses', '₱${_fmt(totalExpenses)}', UpriseColors.error),
      const SizedBox(width: 14),
      _statCard('Net Amount',     '₱${_fmt(netAmount)}',     UpriseColors.success),
    ]);
  }

  Widget _buildAccomplishmentStatCards() {
    final totalReg = _events.fold<int>(0, (s, e) => s + e.registrants);
    final totalAtt = _events.fold<int>(0, (s, e) => s + e.attendees);
    final avgRatio = totalReg > 0 ? (totalAtt / totalReg * 100).round() : 0;
    return Row(children: [
      _statCard('Total Events',      '${_events.length}',          UpriseColors.primary),
      const SizedBox(width: 14),
      _statCard('Total Registrants', '$totalReg',                  UpriseColors.info),
      const SizedBox(width: 14),
      _statCard('Avg Attendance',    '$avgRatio%',                 UpriseColors.success),
    ]);
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 26, fontWeight: FontWeight.w800, color: color)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EVENTS TABLE (with countdown column in Event Summary)
  // ─────────────────────────────────────────────
  Widget _buildEventsTable({required bool showFinancial}) {
    if (_loadingEvents) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: UpriseColors.primary)));
    }
    if (_events.isEmpty) {
      return _emptyState('No events found matching the selected filters.');
    }

    final totalPages = (_events.length / _pageSize).ceil();
    final start      = (_currentPage - 1) * _pageSize;
    final end        = (start + _pageSize).clamp(0, _events.length);
    final pageEvents = _events.sublist(start, end);

    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(children: [
        // toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: UpriseColors.lightGray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: Row(children: [
            Expanded(child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: showFinancial
                ? [
                    _th('EVENT NAME', 200), _th('ORGANIZATION', 150),
                    _th('TOTAL INCOME', 130), _th('TOTAL EXPENSE', 130),
                    _th('NET AMOUNT', 120), _th('DAYS TO EVENT', 110), _th('ACTIONS', 80),
                  ]
                : [
                    _th('EVENT NAME', 200), _th('ORGANIZATION', 150),
                    _th('TYPE', 110), _th('DATE', 120),
                    _th('REGISTRANTS', 100), _th('ATTENDEES', 100),
                    _th('RATIO', 90), _th('ACTIONS', 80),
                  ],
            )),
        )]),
        ),
        // rows
        ...pageEvents.map((e) => _buildEventRow(e, showFinancial)),
        // footer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: UpriseColors.lightGray,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Showing ${start + 1}–$end of ${_events.length} events',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
            Row(children: [
              _pageBtn(Icons.chevron_left, _currentPage > 1, () => setState(() => _currentPage--)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$_currentPage / $totalPages',
                    style: GoogleFonts.beVietnamPro(fontSize: 13)),
              ),
              _pageBtn(Icons.chevron_right, _currentPage < totalPages, () => setState(() => _currentPage++)),
              const SizedBox(width: 12),
              _outlineBtn(Icons.download_outlined, 'Export',
                  showFinancial ? _exportFinancialCSV : _exportAccomplishmentCSV),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _buildEventRow(EventReport event, bool showFinancial) {
    // Countdown days until event
    final now = DateTime.now();
    final daysUntil = event.date.difference(now).inDays;
    String countdownText;
    Color countdownColor;
    if (daysUntil < 0) {
      countdownText = 'Passed';
      countdownColor = UpriseColors.darkGray;
    } else if (daysUntil == 0) {
      countdownText = 'Today';
      countdownColor = UpriseColors.success;
    } else {
      countdownText = '$daysUntil days';
      countdownColor = daysUntil <= 7 ? UpriseColors.warning : UpriseColors.primary;
    }

    return InkWell(
      onTap: () => setState(() => _detailEvent = event),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5))),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: showFinancial
            ? Row(children: [
                _td(event.title, 200, bold: true),
                _td(event.orgName, 150),
                _td('₱${_fmt(event.totalIncome)}', 130),
                _td('₱${_fmt(event.totalExpenses)}', 130),
                SizedBox(width: 120, child: Text(
                  '₱${_fmt(event.netAmount)}',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: event.netAmount >= 0 ? UpriseColors.success : UpriseColors.error,
                  ),
                )),
                SizedBox(width: 110, child: Text(
                  countdownText,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: countdownColor),
                )),
                SizedBox(width: 80, child: IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: UpriseColors.primaryDark),
                  onPressed: () => setState(() => _detailEvent = event),
                  tooltip: 'View Report',
                )),
              ])
            : Row(children: [
                _td(event.title, 200, bold: true),
                _td(event.orgName, 150),
                SizedBox(width: 110, child: _typeBadge(event.type)),
                _td(DateFormat('MMM dd, yyyy').format(event.date), 120),
                _td('${event.registrants}', 100),
                _td('${event.attendees}', 100),
                SizedBox(width: 90, child: _ratioBadge(event.attendanceRatio)),
                SizedBox(width: 80, child: IconButton(
                  icon: const Icon(Icons.visibility_outlined, size: 18, color: UpriseColors.primaryDark),
                  onPressed: () => setState(() => _detailEvent = event),
                  tooltip: 'View Report',
                )),
              ]),
        ),
      ),
    );
  }

  Widget _typeBadge(String type) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: UpriseColors.infoBg, borderRadius: BorderRadius.circular(20)),
    child: Text(type, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.info)),
  );

  Widget _ratioBadge(int ratio) => Row(children: [
    Expanded(child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: ratio / 100,
        backgroundColor: UpriseColors.mediumGray,
        color: UpriseColors.primary,
        minHeight: 6,
      ),
    )),
    const SizedBox(width: 6),
    Text('$ratio%', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.primary)),
  ]);

  // ─────────────────────────────────────────────
  //  RECENT REPORTS (Financial tab)
  // ─────────────────────────────────────────────
  Widget _buildRecentReports() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Recent Generated Reports',
            style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: UpriseColors.charcoal)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('generated_reports')
              .orderBy('generatedAt', descending: true)
              .limit(5)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: UpriseColors.primary));
            if (snap.data!.docs.isEmpty) {
              return Center(child: Text('No reports generated yet.',
                  style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)));
            }
            return Column(
              children: snap.data!.docs.map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final generatedAt = (d['generatedAt'] as Timestamp?)?.toDate();
                return ListTile(
                  leading: Icon(
                    d['format'] == 'PDF' ? Icons.picture_as_pdf : Icons.table_chart,
                    color: UpriseColors.primary,
                  ),
                  title: Text(d['fileName'] ?? 'Report',
                      style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
                  subtitle: Text(
                    generatedAt != null
                        ? DateFormat('MMM dd, yyyy hh:mm a').format(generatedAt)
                        : 'Unknown date',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray),
                  ),
                  trailing: Chip(
                    label: Text(d['format'] ?? ''),
                    backgroundColor: UpriseColors.primaryLight,
                    labelStyle: GoogleFonts.beVietnamPro(
                        fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.primary),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────
  //  SUBMISSION TRACKER TAB (unchanged)
  // ─────────────────────────────────────────────
  Widget _buildSubmissionTrackerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildDeadlineBar(),
        const SizedBox(height: 16),
        _buildTrackerStats(),
        const SizedBox(height: 20),
        _trackerSectionTitle(Icons.attach_money, 'Financial Report Submissions'),
        const SizedBox(height: 10),
        _buildSubmissionTable('Financial', _financialSubs, _financialDeadline, _loadingFinancial),
        const SizedBox(height: 24),
        _trackerSectionTitle(Icons.assignment, 'Accomplishment Report Submissions'),
        const SizedBox(height: 10),
        _buildSubmissionTable('Accomplishment', _accomplishmentSubs, _accomplishmentDeadline, _loadingAccomplishment),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildDeadlineBar() {
    if (_loadingDeadlines) return const LinearProgressIndicator(color: UpriseColors.primary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Row(children: [
        Expanded(child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            const Icon(Icons.timer_outlined, color: UpriseColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('Financial Deadline: ', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(_financialDeadline != null ? DateFormat('MMM dd, yyyy').format(_financialDeadline!) : 'Not set',
                style: GoogleFonts.beVietnamPro(fontSize: 13)),
            if (_financialDeadline != null) ...[
              const SizedBox(width: 8),
              _countdownChip(_financialDeadline!),
            ],
            const SizedBox(width: 24),
            const Icon(Icons.assignment_outlined, color: UpriseColors.primary, size: 18),
            const SizedBox(width: 8),
            Text('Accomplishment Deadline: ', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700, fontSize: 13)),
            Text(_accomplishmentDeadline != null ? DateFormat('MMM dd, yyyy').format(_accomplishmentDeadline!) : 'Not set',
                style: GoogleFonts.beVietnamPro(fontSize: 13)),
            if (_accomplishmentDeadline != null) ...[
              const SizedBox(width: 8),
              _countdownChip(_accomplishmentDeadline!),
            ],
          ]),
        )),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _showDeadlineDialog,
          icon: const Icon(Icons.edit_calendar, size: 16),
          label: const Text('Set Deadlines'),
          style: OutlinedButton.styleFrom(
            foregroundColor: UpriseColors.charcoal,
            side: const BorderSide(color: UpriseColors.mediumGray),
          ),
        ),
      ]),
    );
  }

  Widget _countdownChip(DateTime deadline) {
    final days = deadline.difference(DateTime.now()).inDays;
    final isOverdue = days < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isOverdue ? UpriseColors.errorBg : UpriseColors.warningBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOverdue ? 'Overdue' : '⏱ $days days left',
        style: GoogleFonts.beVietnamPro(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: isOverdue ? UpriseColors.error : UpriseColors.warning,
        ),
      ),
    );
  }

  Widget _buildTrackerStats() {
    final finSubmitted = _financialSubs.where((s) => s.submittedAt != null).length;
    final accSubmitted = _accomplishmentSubs.where((s) => s.submittedAt != null).length;
    final total        = _financialSubs.length;
    return Row(children: [
      _statCard('Total Organizations', '$total',              UpriseColors.primary),
      const SizedBox(width: 14),
      _statCard('Financial Submitted', '$finSubmitted/$total', UpriseColors.success),
      const SizedBox(width: 14),
      _statCard('Accomplishment Submitted', '$accSubmitted/$total', UpriseColors.info),
    ]);
  }

  Widget _trackerSectionTitle(IconData icon, String label) => Row(children: [
    Icon(icon, size: 16, color: UpriseColors.primary),
    const SizedBox(width: 8),
    Text(label, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700, color: UpriseColors.charcoal)),
  ]);

  Widget _buildSubmissionTable(
    String title,
    List<OrgSubmission> submissions,
    DateTime? deadline,
    bool loading,
  ) {
    if (loading) return const Center(child: CircularProgressIndicator(color: UpriseColors.primary));

    final sorted = List<OrgSubmission>.from(submissions)
      ..sort((a, b) {
        final aSubmitted = a.submittedAt != null;
        final bSubmitted = b.submittedAt != null;
        final now = DateTime.now();
        final aOverdue = deadline != null && !aSubmitted && now.isAfter(deadline);
        final bOverdue = deadline != null && !bSubmitted && now.isAfter(deadline);
        if (aOverdue && !bOverdue) return -1;
        if (!aOverdue && bOverdue) return 1;
        if (aSubmitted && !bSubmitted) return 1;
        if (!aSubmitted && bSubmitted) return -1;
        return 0;
      });

    return Container(
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: UpriseColors.lightGray,
            borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              _th('ORGANIZATION', 200), _th('DEADLINE', 150),
              _th('SUBMITTED ON', 150), _th('STATUS', 180), _th('ACTIONS', 100),
            ]),
          ),
        ),
        ...sorted.map((sub) {
          final isSubmitted = sub.submittedAt != null;
          final isOverdue   = deadline != null && !isSubmitted && DateTime.now().isAfter(deadline);
          final daysLeft    = deadline != null && !isSubmitted
              ? deadline.difference(DateTime.now()).inDays : 0;

          String statusText;
          Color statusColor;
          Color statusBg;
          if (isSubmitted) {
            statusText  = 'Submitted';
            statusColor = UpriseColors.success;
            statusBg    = UpriseColors.successBg;
          } else if (isOverdue) {
            statusText  = 'Overdue';
            statusColor = UpriseColors.error;
            statusBg    = UpriseColors.errorBg;
          } else {
            statusText  = 'Pending ($daysLeft days left)';
            statusColor = UpriseColors.warning;
            statusBg    = UpriseColors.warningBg;
          }

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _td(sub.orgName, 200, bold: true),
                _td(deadline != null ? DateFormat('MMM dd, yyyy').format(deadline) : 'No deadline', 150),
                _td(isSubmitted ? DateFormat('MMM dd, yyyy').format(sub.submittedAt!) : '—', 150),
                SizedBox(width: 180, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(statusText, style: GoogleFonts.beVietnamPro(
                      fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                )),
                SizedBox(width: 100, child: Row(children: [
                  if (isSubmitted)
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, size: 18, color: UpriseColors.primaryDark),
                      onPressed: () => _viewSubmission(sub, title),
                      tooltip: 'View Report',
                    ),
                  if (!isSubmitted)
                    IconButton(
                      icon: const Icon(Icons.send_outlined, size: 18, color: UpriseColors.primaryDark),
                      onPressed: () => _sendReminder(sub, title),
                      tooltip: 'Send Reminder',
                    ),
                ])),
              ]),
            ),
          );
        }),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(
            color: UpriseColors.lightGray,
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(10)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Showing ${sorted.length} organizations',
                style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray)),
            _outlineBtn(Icons.download_outlined, 'Export CSV',
                () => _exportSubmissionCSV(title, submissions, deadline)),
          ]),
        ),
      ]),
    );
  }

  void _viewSubmission(OrgSubmission sub, String reportType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$reportType Report — ${sub.orgName}',
            style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Submitted: ${DateFormat('MMMM dd, yyyy HH:mm').format(sub.submittedAt!)}'),
          const SizedBox(height: 16),
          if (sub.fileUrl != null && sub.fileUrl!.isNotEmpty)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primary),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening file: ${sub.fileUrl}')));
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open File'),
            )
          else
            const Text('No file attached.'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _sendReminder(OrgSubmission sub, String reportType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Reminder sent to ${sub.orgName} for $reportType report')),
    );
  }

  // ─────────────────────────────────────────────
  //  DETAIL VIEW (unchanged)
  // ─────────────────────────────────────────────
  Widget _buildDetailView(EventReport event) {
    final net = event.netAmount;
    final maxInc = event.incomeBreakdown.isEmpty ? 1.0
        : event.incomeBreakdown.map((i) => (i['amount'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b);
    final maxExp = event.expenseBreakdown.isEmpty ? 1.0
        : event.expenseBreakdown.map((i) => (i['amount'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
          color: UpriseColors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => setState(() => _detailEvent = null),
              child: Row(children: [
                const Icon(Icons.arrow_back, size: 16, color: UpriseColors.darkGray),
                const SizedBox(width: 6),
                Text('Back to Reports List',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray, fontWeight: FontWeight.w500)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Financial Report',
                    style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.w800, color: UpriseColors.charcoal)),
                Text('${event.title} • ${event.orgName}',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
              ])),
              Row(children: [
                _outlineBtn(Icons.archive_outlined, 'Archive', () {
                  // In production: update Firestore doc status to 'archived' and log
                }),
                const SizedBox(width: 8),
                _primaryBtn(Icons.download_outlined, 'Download PDF',
                    () => _generatePDFReport()),
              ]),
            ]),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(children: [
            Container(
              decoration: BoxDecoration(
                color: UpriseColors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: UpriseColors.mediumGray),
              ),
              child: Column(children: [
                Row(children: [
                  _metaCell('EVENT NAME',      event.title),
                  _metaCell('ORGANIZATION',    event.orgName),
                  _metaCell('REPORT TYPE',     'Event Financial Report', last: true),
                ]),
                Row(children: [
                  _metaCell('REPORT PERIOD',   event.reportPeriod.isNotEmpty ? event.reportPeriod : DateFormat('MMM dd, yyyy').format(event.date)),
                  _metaCell('SUBMITTED DATE',  event.submittedDate != null ? DateFormat('MMM dd, yyyy').format(event.submittedDate!) : '—'),
                  _metaCell('SUBMITTED BY',    event.submittedBy.isNotEmpty ? event.submittedBy : '—', last: true, lastRow: true),
                ]),
              ]),
            ),
            const SizedBox(height: 16),
            Row(children: [
              _finStat('Total Income',    '₱${_fmt(event.totalIncome)}',   UpriseColors.primary),
              const SizedBox(width: 14),
              _finStat('Total Expenses',  '₱${_fmt(event.totalExpenses)}', UpriseColors.error),
              const SizedBox(width: 14),
              _finStat('Net Amount',      '₱${_fmt(net)}',                 net >= 0 ? UpriseColors.success : UpriseColors.error),
              const SizedBox(width: 14),
              _finStat('Budget Variance', '₱${_fmt(event.budgetVariance)}', UpriseColors.success),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.trending_up, size: 16, color: UpriseColors.success),
                  const SizedBox(width: 6),
                  Text('Income Breakdown', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                if (event.incomeBreakdown.isEmpty)
                  Text('No breakdown data.', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13))
                else
                  ...event.incomeBreakdown.map((item) {
                    final amt   = (item['amount'] as num?)?.toDouble() ?? 0;
                    final ratio = maxInc > 0 ? amt / maxInc : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(item['name']?.toString() ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                          Text('₱${_fmt(amt)}', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio.toDouble(),
                            backgroundColor: UpriseColors.mediumGray,
                            color: UpriseColors.success,
                            minHeight: 5,
                          ),
                        ),
                      ]),
                    );
                  }),
              ]))),
              const SizedBox(width: 14),
              Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.trending_down, size: 16, color: UpriseColors.error),
                  const SizedBox(width: 6),
                  Text('Expenses Breakdown', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 14),
                if (event.expenseBreakdown.isEmpty)
                  Text('No breakdown data.', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13))
                else
                  ...event.expenseBreakdown.map((item) {
                    final amt   = (item['amount'] as num?)?.toDouble() ?? 0;
                    final ratio = maxExp > 0 ? amt / maxExp : 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Text(item['name']?.toString() ?? '', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
                          Text('₱${_fmt(amt)}', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: ratio.toDouble(),
                            backgroundColor: UpriseColors.mediumGray,
                            color: UpriseColors.error,
                            minHeight: 5,
                          ),
                        ),
                      ]),
                    );
                  }),
              ]))),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Financial Notes', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (event.financialNotes.isEmpty)
                  Text('No notes recorded.', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13))
                else
                  ...event.financialNotes.map((note) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 3, height: 40, margin: const EdgeInsets.only(right: 10, top: 2), color: UpriseColors.mediumGray),
                      Expanded(child: Text(note, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray, height: 1.5))),
                    ]),
                  )),
              ]))),
              const SizedBox(width: 14),
              Expanded(child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Recommendations', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (event.recommendations.isEmpty)
                  Text('No recommendations recorded.', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 13))
                else
                  ...event.recommendations.map((rec) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 3, height: 40, margin: const EdgeInsets.only(right: 10, top: 2), color: UpriseColors.mediumGray),
                      Expanded(child: Text(rec, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray, height: 1.5))),
                    ]),
                  )),
              ]))),
            ]),
            if (event.attachments.isNotEmpty) ...[
              const SizedBox(height: 16),
              _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Attachments', style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Wrap(spacing: 10, runSpacing: 10, children: event.attachments.map((att) {
                  final name    = att['name']?.toString() ?? 'File';
                  final size    = att['size']?.toString() ?? '';
                  final fileUrl = att['fileUrl']?.toString() ?? '';
                  return GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening: $fileUrl')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: UpriseColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: UpriseColors.mediumGray),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(color: UpriseColors.infoBg, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.insert_drive_file_outlined, color: UpriseColors.info, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(size, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
                        ]),
                        const SizedBox(width: 10),
                        const Icon(Icons.download_outlined, size: 16, color: UpriseColors.darkGray),
                      ]),
                    ),
                  );
                }).toList()),
              ])),
            ],
            const SizedBox(height: 24),
          ]),
        )),
      ]),
    );
  }

  Widget _finStat(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
        const SizedBox(height: 6),
        Text(value, style: GoogleFonts.beVietnamPro(fontSize: 20, fontWeight: FontWeight.w800, color: color)),
      ]),
    ),
  );

  Widget _metaCell(String key, String value, {bool last = false, bool lastRow = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          border: Border(
            right: last ? BorderSide.none : const BorderSide(color: UpriseColors.mediumGray),
            bottom: lastRow ? BorderSide.none : const BorderSide(color: UpriseColors.mediumGray),
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(key, style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700,
              color: UpriseColors.darkGray, letterSpacing: .5)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: UpriseColors.charcoal)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SHARED HELPERS
  // ─────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: UpriseColors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: UpriseColors.mediumGray),
    ),
    child: child,
  );

  Widget _th(String label, double width) => SizedBox(
    width: width,
    child: Text(label, style: GoogleFonts.beVietnamPro(
        fontSize: 10, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: .5)),
  );

  Widget _td(String text, double width, {bool bold = false}) => SizedBox(
    width: width,
    child: Text(text, style: TextStyle(
        fontSize: 13,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: UpriseColors.charcoal,
        overflow: TextOverflow.ellipsis)),
  );

  Widget _primaryBtn(IconData icon, String label, VoidCallback onTap) => ElevatedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: ElevatedButton.styleFrom(
      backgroundColor: UpriseColors.primary,
      foregroundColor: UpriseColors.white,
      textStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  Widget _outlineBtn(IconData icon, String label, VoidCallback onTap) => OutlinedButton.icon(
    onPressed: onTap,
    icon: Icon(icon, size: 16),
    label: Text(label),
    style: OutlinedButton.styleFrom(
      foregroundColor: UpriseColors.charcoal,
      textStyle: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
      side: const BorderSide(color: UpriseColors.mediumGray),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );

  Widget _pageBtn(IconData icon, bool enabled, VoidCallback onTap) => IconButton(
    icon: Icon(icon, size: 20),
    color: enabled ? UpriseColors.charcoal : UpriseColors.mediumGray,
    onPressed: enabled ? onTap : null,
  );

  Widget _emptyState(String message) => Container(
    margin: const EdgeInsets.symmetric(vertical: 16),
    padding: const EdgeInsets.all(48),
    decoration: BoxDecoration(
      color: UpriseColors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: UpriseColors.mediumGray),
    ),
    child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.bar_chart_outlined, size: 56, color: UpriseColors.mediumGray),
      const SizedBox(height: 14),
      Text(message, style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
    ])),
  );

  String _fmt(double value) {
    return NumberFormat('#,##0.00', 'en_PH').format(value);
  }
}