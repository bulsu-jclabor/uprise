import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pdf;
import '../../theme/app_theme.dart';

// -------------------- ENUMS --------------------
enum ReportGeneratorType {
  eventPerformance,
  financialSummary,
  accomplishmentSummary,
}

// -------------------- DATA MODELS --------------------
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

class EventReportData {
  final String id;
  final String name;
  final String organization;
  final String type;
  final DateTime date;
  final int registrants;
  final int attendees;
  EventReportData({
    required this.id,
    required this.name,
    required this.organization,
    required this.type,
    required this.date,
    required this.registrants,
    required this.attendees,
  });
}

class FinancialSummaryData {
  final String orgName;
  final DateTime submittedAt;
  final String? fileUrl;
  FinancialSummaryData({
    required this.orgName,
    required this.submittedAt,
    this.fileUrl,
  });
}

class AccomplishmentSummaryData {
  final String orgName;
  final DateTime submittedAt;
  final String? fileUrl;
  AccomplishmentSummaryData({
    required this.orgName,
    required this.submittedAt,
    this.fileUrl,
  });
}

// -------------------- MAIN WIDGET --------------------
class ReportsManagement extends StatefulWidget {
  const ReportsManagement({super.key});

  @override
  _ReportsManagementState createState() => _ReportsManagementState();
}

class _ReportsManagementState extends State<ReportsManagement>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ---------- SUBMISSION TRACKER DATA ----------
  DateTime? _financialDeadline;
  DateTime? _accomplishmentDeadline;
  bool _loadingDeadlines = true;
  List<OrgSubmission> _financialSubmissions = [];
  List<OrgSubmission> _accomplishmentSubmissions = [];
  bool _loadingFinancial = true;
  bool _loadingAccomplishment = true;

  // ---------- REPORT GENERATOR DATA ----------
  ReportGeneratorType _selectedReportType = ReportGeneratorType.eventPerformance;
  String _dateRange = 'Current Semester';
  String _selectedOrg = 'All Organizations';
  String _eventType = 'All Types';
  String _reportView = 'By Event';
  List<Map<String, String>> _organizations = [];

  List<EventReportData> _eventsData = [];
  List<FinancialSummaryData> _financialSummaryData = [];
  List<AccomplishmentSummaryData> _accomplishmentSummaryData = [];
  bool _isLoadingReport = true;
  int _totalEvents = 0, _totalRegistrants = 0, _totalAttendees = 0;

  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrganizations();
    _loadDeadlines();
    _loadSubmissionData();
    _loadReportDataForCurrentType();
  }

  // ==================== SUBMISSION TRACKER METHODS ====================
  Future<void> _loadDeadlines() async {
    setState(() => _loadingDeadlines = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('report_deadlines')
          .doc('deadlines')
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        _financialDeadline = (data['financial'] as Timestamp?)?.toDate();
        _accomplishmentDeadline =
            (data['accomplishment'] as Timestamp?)?.toDate();
      } else {
        final now = DateTime.now();
        _financialDeadline = DateTime(now.year, now.month + 1, 0);
        _accomplishmentDeadline = DateTime(now.year, now.month + 1, 0);
      }
    } catch (e) {
      debugPrint('Error loading deadlines: $e');
    }
    setState(() => _loadingDeadlines = false);
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deadlines updated')));
    }
  }

  Future<void> _loadSubmissionData() async {
    await Future.wait([
      _loadFinancialSubmissions(),
      _loadAccomplishmentSubmissions(),
    ]);
  }

  Future<void> _loadFinancialSubmissions() async {
    setState(() => _loadingFinancial = true);
    try {
      final orgsSnap =
          await FirebaseFirestore.instance.collection('organizations').get();
      final allOrgs = orgsSnap.docs.map((doc) => {
            'id': doc.id,
            'name': doc.data()['name']?.toString() ?? 'Unknown',
          }).toList();
      final subsSnap = await FirebaseFirestore.instance
          .collection('financial_submissions')
          .get();
      final submissionsMap = <String, Map<String, dynamic>>{};
      for (var doc in subsSnap.docs) {
        final data = doc.data();
        submissionsMap[data['orgId']] = {
          'submittedAt': (data['submittedAt'] as Timestamp).toDate(),
          'fileUrl': data['fileUrl'],
          'submissionId': doc.id,
        };
      }
      _financialSubmissions = allOrgs.map((org) => OrgSubmission(
            orgId: org['id']!,
            orgName: org['name']!,
            submittedAt: submissionsMap[org['id']]?['submittedAt'],
            fileUrl: submissionsMap[org['id']]?['fileUrl'],
            submissionId: submissionsMap[org['id']]?['submissionId'],
          )).toList();
    } catch (e) {
      debugPrint('Error loading financial submissions: $e');
    } finally {
      if (mounted) setState(() => _loadingFinancial = false);
    }
  }

  Future<void> _loadAccomplishmentSubmissions() async {
    setState(() => _loadingAccomplishment = true);
    try {
      final orgsSnap =
          await FirebaseFirestore.instance.collection('organizations').get();
      final allOrgs = orgsSnap.docs.map((doc) => {
            'id': doc.id,
            'name': doc.data()['name']?.toString() ?? 'Unknown',
          }).toList();
      final subsSnap = await FirebaseFirestore.instance
          .collection('accomplishment_submissions')
          .get();
      final submissionsMap = <String, Map<String, dynamic>>{};
      for (var doc in subsSnap.docs) {
        final data = doc.data();
        submissionsMap[data['orgId']] = {
          'submittedAt': (data['submittedAt'] as Timestamp).toDate(),
          'fileUrl': data['fileUrl'],
          'submissionId': doc.id,
        };
      }
      _accomplishmentSubmissions = allOrgs.map((org) => OrgSubmission(
            orgId: org['id']!,
            orgName: org['name']!,
            submittedAt: submissionsMap[org['id']]?['submittedAt'],
            fileUrl: submissionsMap[org['id']]?['fileUrl'],
            submissionId: submissionsMap[org['id']]?['submissionId'],
          )).toList();
    } catch (e) {
      debugPrint('Error loading accomplishment submissions: $e');
    } finally {
      if (mounted) setState(() => _loadingAccomplishment = false);
    }
  }

  void _showSetDeadlineDialog() {
    DateTime? tempFinancial = _financialDeadline;
    DateTime? tempAccomplishment = _accomplishmentDeadline;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) {
          return AlertDialog(
            title: const Text('Set Submission Deadlines'),
            content: SizedBox(
              width: 300,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ListTile(
                  title: const Text('Financial Report'),
                  subtitle: Text(tempFinancial != null
                      ? DateFormat('yyyy-MM-dd').format(tempFinancial!)
                      : 'Not set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: tempFinancial ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setStateDlg(() => tempFinancial = picked);
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Accomplishment Report'),
                  subtitle: Text(tempAccomplishment != null
                      ? DateFormat('yyyy-MM-dd').format(tempAccomplishment!)
                      : 'Not set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: tempAccomplishment ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setStateDlg(() => tempAccomplishment = picked);
                      }
                    },
                  ),
                ),
              ]),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  setState(() {
                    _financialDeadline = tempFinancial;
                    _accomplishmentDeadline = tempAccomplishment;
                  });
                  await _saveDeadlines();
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmissionTable(String title, List<OrgSubmission> submissions,
      DateTime? deadline, bool loading) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final sorted = List<OrgSubmission>.from(submissions);
    sorted.sort((a, b) {
      final aSubmitted = a.submittedAt != null;
      final bSubmitted = b.submittedAt != null;
      final aOverdue =
          deadline != null && !aSubmitted && DateTime.now().isAfter(deadline);
      final bOverdue =
          deadline != null && !bSubmitted && DateTime.now().isAfter(deadline);
      if (aSubmitted && !bSubmitted) return 1;
      if (!aSubmitted && bSubmitted) return -1;
      if (aOverdue && !bOverdue) return -1;
      if (!aOverdue && bOverdue) return 1;
      return 0;
    });
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: UpriseColors.lightGray,
              border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(
                      width: 200,
                      child: Text('ORGANIZATION', style: _headerStyle())),
                  SizedBox(
                      width: 150,
                      child: Text('DEADLINE', style: _headerStyle())),
                  SizedBox(
                      width: 150,
                      child: Text('SUBMITTED ON', style: _headerStyle())),
                  SizedBox(
                      width: 180,
                      child: Text('STATUS', style: _headerStyle())),
                  SizedBox(
                      width: 100,
                      child: Text('ACTIONS', style: _headerStyle())),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final sub = sorted[index];
                final isSubmitted = sub.submittedAt != null;
                final isOverdue = deadline != null &&
                    !isSubmitted &&
                    DateTime.now().isAfter(deadline);
                final daysLeft = deadline != null && !isSubmitted
                    ? deadline.difference(DateTime.now()).inDays
                    : 0;
                String statusText;
                Color statusColor;
                if (isSubmitted) {
                  statusText = 'Submitted';
                  statusColor = UpriseColors.success;
                } else if (isOverdue) {
                  statusText = 'Overdue';
                  statusColor = UpriseColors.error;
                } else {
                  statusText = 'Pending ($daysLeft days left)';
                  statusColor = UpriseColors.warning;
                }
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(
                              color: UpriseColors.mediumGray.withOpacity(0.5)))),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SizedBox(
                            width: 200,
                            child: Text(sub.orgName,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w500))),
                        SizedBox(
                            width: 150,
                            child: Text(
                                deadline != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(deadline)
                                    : 'No deadline',
                                style: const TextStyle(fontSize: 12))),
                        SizedBox(
                            width: 150,
                            child: Text(
                                isSubmitted
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(sub.submittedAt!)
                                    : '—',
                                style: const TextStyle(fontSize: 12))),
                        SizedBox(
                            width: 180,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                statusText,
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor),
                              ),
                            )),
                        SizedBox(
                            width: 100,
                            child: Row(
                              children: [
                                if (isSubmitted)
                                  IconButton(
                                    icon: const Icon(Icons.visibility,
                                        size: 18,
                                        color: UpriseColors.primaryDark),
                                    onPressed: () =>
                                        _viewSubmission(sub, title),
                                    tooltip: 'View Report',
                                  ),
                                if (!isSubmitted)
                                  IconButton(
                                    icon: const Icon(Icons.send,
                                        size: 18,
                                        color: UpriseColors.primaryDark),
                                    onPressed: () =>
                                        _sendReminder(sub, title),
                                    tooltip: 'Send Reminder',
                                  ),
                              ],
                            )),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
              color: UpriseColors.lightGray,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing ${sorted.length} organizations',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, color: UpriseColors.darkGray)),
                OutlinedButton.icon(
                  onPressed: () =>
                      _exportSubmissionToCSV(title, submissions, deadline),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _viewSubmission(OrgSubmission sub, String reportType) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$reportType Report - ${sub.orgName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Submitted on: ${DateFormat('MMMM dd, yyyy HH:mm').format(sub.submittedAt!)}'),
            const SizedBox(height: 16),
            if (sub.fileUrl != null)
              ElevatedButton.icon(
                onPressed: () async {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Download feature: open URL')));
                },
                icon: const Icon(Icons.download),
                label: const Text('Download File'),
              )
            else
              const Text('No file attached.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _sendReminder(OrgSubmission sub, String reportType) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Reminder sent to ${sub.orgName} for $reportType report')));
  }

  Future<void> _exportSubmissionToCSV(String reportType,
      List<OrgSubmission> submissions, DateTime? deadline) async {
    final rows = <List<String>>[];
    rows.add(['Organization', 'Deadline', 'Submitted On', 'Status']);
    for (var sub in submissions) {
      final isSubmitted = sub.submittedAt != null;
      final isOverdue = deadline != null &&
          !isSubmitted &&
          DateTime.now().isAfter(deadline);
      String status;
      if (isSubmitted)
        status = 'Submitted';
      else if (isOverdue)
        status = 'Overdue';
      else
        status = 'Pending';
      rows.add([
        sub.orgName,
        deadline != null ? DateFormat('yyyy-MM-dd').format(deadline) : '',
        isSubmitted ? DateFormat('yyyy-MM-dd').format(sub.submittedAt!) : '',
        status,
      ]);
    }
    final csvContent = rows.map((row) => row.join(',')).join('\n');
    final tempFile = await File(
            '${Directory.systemTemp.path}/${reportType.toLowerCase()}_submissions.csv')
        .writeAsString(csvContent);
    await Share.shareXFiles([XFile(tempFile.path)],
        text: '$reportType Report Submissions');
  }

  // ==================== REPORT GENERATOR METHODS ====================
  Future<void> _loadOrganizations() async {
    final snap =
        await FirebaseFirestore.instance.collection('organizations').get();
    setState(() {
      _organizations = snap.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name']?.toString() ?? 'Unknown',
        };
      }).toList();
    });
  }

  Future<void> _loadReportDataForCurrentType() async {
    setState(() => _isLoadingReport = true);
    try {
      if (_selectedReportType == ReportGeneratorType.eventPerformance) {
        await _loadEventPerformanceData();
      } else if (_selectedReportType == ReportGeneratorType.financialSummary) {
        await _loadFinancialSummaryData();
      } else if (_selectedReportType ==
          ReportGeneratorType.accomplishmentSummary) {
        await _loadAccomplishmentSummaryData();
      }
    } catch (e) {
      debugPrint('Error loading report data: $e');
    } finally {
      setState(() => _isLoadingReport = false);
    }
  }

  Future<void> _loadEventPerformanceData() async {
    Query query = FirebaseFirestore.instance
        .collection('events')
        .where('status', isEqualTo: 'approved');
    if (_eventType != 'All Types') {
      query = query.where('type', isEqualTo: _eventType);
    }
    if (_selectedOrg != 'All Organizations') {
      final org = _organizations.firstWhere((o) => o['name'] == _selectedOrg);
      if (org['id'] != null) {
        query = query.where('orgId', isEqualTo: org['id']);
      }
    }
    final eventsSnap = await query.get();
    _eventsData = [];
    _totalRegistrants = 0;
    _totalAttendees = 0;
    for (var doc in eventsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final regSnap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: doc.id)
          .get();
      final registrants = regSnap.docs.length;
      final attendees =
          regSnap.docs.where((r) => (r.data())['attended'] == true).length;
      _eventsData.add(EventReportData(
        id: doc.id,
        name: data['title']?.toString() ?? 'Untitled',
        organization: data['orgName']?.toString() ?? 'Unknown',
        type: data['type']?.toString() ?? 'Others',
        date: (data['date'] as Timestamp).toDate(),
        registrants: registrants,
        attendees: attendees,
      ));
      _totalRegistrants += registrants;
      _totalAttendees += attendees;
    }
    _totalEvents = _eventsData.length;
  }

  Future<void> _loadFinancialSummaryData() async {
    final subsSnap = await FirebaseFirestore.instance
        .collection('financial_submissions')
        .get();
    final submissions = <FinancialSummaryData>[];
    for (var doc in subsSnap.docs) {
      final data = doc.data();
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(data['orgId'])
          .get();
      final orgName = orgDoc.exists
          ? (orgDoc.data()?['name'] ?? 'Unknown')
          : 'Unknown';
      submissions.add(FinancialSummaryData(
        orgName: orgName,
        submittedAt: (data['submittedAt'] as Timestamp).toDate(),
        fileUrl: data['fileUrl'],
      ));
    }
    _financialSummaryData = submissions;
  }

  Future<void> _loadAccomplishmentSummaryData() async {
    final subsSnap = await FirebaseFirestore.instance
        .collection('accomplishment_submissions')
        .get();
    final submissions = <AccomplishmentSummaryData>[];
    for (var doc in subsSnap.docs) {
      final data = doc.data();
      final orgDoc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(data['orgId'])
          .get();
      final orgName = orgDoc.exists
          ? (orgDoc.data()?['name'] ?? 'Unknown')
          : 'Unknown';
      submissions.add(AccomplishmentSummaryData(
        orgName: orgName,
        submittedAt: (data['submittedAt'] as Timestamp).toDate(),
        fileUrl: data['fileUrl'],
      ));
    }
    _accomplishmentSummaryData = submissions;
  }

  Widget _buildReportGeneratorUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildReportTypeSelector(),
        _buildReportConfig(),
        _buildStatsRow(),
        if (_selectedReportType == ReportGeneratorType.eventPerformance)
          _buildEventTable()
        else if (_selectedReportType == ReportGeneratorType.financialSummary)
          _buildFinancialSummaryTable()
        else
          _buildAccomplishmentSummaryTable(),
        _buildRecentReports(),
      ],
    );
  }

  Widget _buildReportTypeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.assignment, color: UpriseColors.primaryDark),
          const SizedBox(width: 12),
          Text('Report Type:',
              style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
          const SizedBox(width: 16),
          Expanded(
            child: SegmentedButton<ReportGeneratorType>(
              segments: const [
                ButtonSegment(
                    value: ReportGeneratorType.eventPerformance,
                    label: Text('Event Performance')),
                ButtonSegment(
                    value: ReportGeneratorType.financialSummary,
                    label: Text('Financial Summary')),
                ButtonSegment(
                    value: ReportGeneratorType.accomplishmentSummary,
                    label: Text('Accomplishment Summary')),
              ],
              selected: {_selectedReportType},
              onSelectionChanged: (Set<ReportGeneratorType> selection) {
                setState(() {
                  _selectedReportType = selection.first;
                  _currentPage = 1;
                  _loadReportDataForCurrentType();
                });
              },
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor:
                    UpriseColors.primaryDark.withOpacity(0.1),
                selectedForegroundColor: UpriseColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportConfig() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Configuration',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: UpriseColors.charcoal)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildFilterDropdown(
                  'DATE RANGE', _dateRange,
                  ['Current Semester', 'Last Semester', 'Academic Year 2024-2025'],
                  (v) => setState(() => _dateRange = v!)),
              _buildFilterDropdown(
                  'ORGANIZATION', _selectedOrg,
                  ['All Organizations', ..._organizations.map((o) => o['name']!)],
                  (v) => setState(() {
                    _selectedOrg = v!;
                    _loadReportDataForCurrentType();
                  })),
              if (_selectedReportType == ReportGeneratorType.eventPerformance)
                _buildFilterDropdown(
                    'EVENT TYPE', _eventType,
                    ['All Types', 'In Person', 'Virtual', 'Workshop', 'Seminar', 'Competition'],
                    (v) => setState(() {
                      _eventType = v!;
                      _loadReportDataForCurrentType();
                    })),
              _buildFilterDropdown(
                  'REPORT VIEW', _reportView,
                  ['By Event', 'By Organization', 'By Month'],
                  (v) => setState(() => _reportView = v!)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _showGenerateReportDialog,
                icon: const Icon(Icons.insert_drive_file),
                label: const Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  foregroundColor: UpriseColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items,
      ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: UpriseColors.darkGray)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
                border: Border.all(color: UpriseColors.mediumGray),
                borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                items: items
                    .map((item) => DropdownMenuItem(
                          value: item,
                          child: Text(item,
                              style: GoogleFonts.beVietnamPro(fontSize: 13)),
                        ))
                    .toList(),
                onChanged: onChanged,
                isExpanded: true,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13, color: UpriseColors.charcoal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_selectedReportType == ReportGeneratorType.eventPerformance) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          _statCard('Total Events', '$_totalEvents', UpriseColors.primaryDark),
          const SizedBox(width: 16),
          _statCard('Total Registrants', '$_totalRegistrants',
              UpriseColors.success),
          const SizedBox(width: 16),
          _statCard('Total Attendees', '$_totalAttendees', UpriseColors.accent),
        ]),
      );
    } else if (_selectedReportType == ReportGeneratorType.financialSummary) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          _statCard('Total Submissions', '${_financialSummaryData.length}',
              UpriseColors.primaryDark),
          const SizedBox(width: 16),
          _statCard('With Files',
              '${_financialSummaryData.where((e) => e.fileUrl != null).length}',
              UpriseColors.success),
          const SizedBox(width: 16),
          _statCard('Date Range', _dateRange, UpriseColors.accent),
        ]),
      );
    } else {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(children: [
          _statCard('Total Submissions', '${_accomplishmentSummaryData.length}',
              UpriseColors.primaryDark),
          const SizedBox(width: 16),
          _statCard(
              'With Files',
              '${_accomplishmentSummaryData.where((e) => e.fileUrl != null).length}',
              UpriseColors.success),
          const SizedBox(width: 16),
          _statCard('Date Range', _dateRange, UpriseColors.accent),
        ]),
      );
    }
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: UpriseColors.darkGray)),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventTable() {
    if (_isLoadingReport) return const Center(child: CircularProgressIndicator());
    if (_eventsData.isEmpty)
      return _emptyWidget('No events match the selected filters');
    final totalPages = (_eventsData.length / _pageSize).ceil();
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _eventsData.length);
    final pageEvents = _eventsData.sublist(start, end);
    return _buildTableContainer(
      header: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          SizedBox(width: 200, child: Text('EVENT NAME', style: _headerStyle())),
          SizedBox(
              width: 150, child: Text('ORGANIZATION', style: _headerStyle())),
          SizedBox(width: 120, child: Text('TYPE', style: _headerStyle())),
          SizedBox(width: 120, child: Text('DATE', style: _headerStyle())),
          SizedBox(width: 100, child: Text('REGISTRANTS', style: _headerStyle())),
          SizedBox(width: 100, child: Text('ATTENDEES', style: _headerStyle())),
          SizedBox(width: 80, child: Text('RATIO', style: _headerStyle())),
        ]),
      ),
      body: Column(
          children: pageEvents.map((event) => _buildEventRow(event)).toList()),
      totalCount: _eventsData.length,
      start: start,
      end: end,
      totalPages: totalPages,
      onExport: _exportCurrentTableAsCSV,
    );
  }

  Widget _buildEventRow(EventReportData event) {
    final ratio = event.registrants > 0
        ? ((event.attendees / event.registrants) * 100).toStringAsFixed(0)
        : '0';
    return _tableRow(children: [
      SizedBox(
          width: 200,
          child: Text(event.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      SizedBox(
          width: 150,
          child: Text(event.organization,
              style: const TextStyle(fontSize: 12))),
      SizedBox(
          width: 120,
          child:
              Text(event.type, style: const TextStyle(fontSize: 12))),
      SizedBox(
          width: 120,
          child: Text(DateFormat('MMM dd, yyyy').format(event.date),
              style: const TextStyle(fontSize: 12))),
      SizedBox(
          width: 100,
          child: Text('${event.registrants}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      SizedBox(
          width: 100,
          child: Text('${event.attendees}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
      SizedBox(
          width: 80,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: UpriseColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Text('$ratio%',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: UpriseColors.success),
                textAlign: TextAlign.center),
          )),
    ]);
  }

  Widget _buildFinancialSummaryTable() {
    if (_isLoadingReport) return const Center(child: CircularProgressIndicator());
    if (_financialSummaryData.isEmpty)
      return _emptyWidget('No financial submissions found');
    final totalPages = (_financialSummaryData.length / _pageSize).ceil();
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _financialSummaryData.length);
    final pageData = _financialSummaryData.sublist(start, end);
    return _buildTableContainer(
      header: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          SizedBox(
              width: 200, child: Text('ORGANIZATION', style: _headerStyle())),
          SizedBox(
              width: 150, child: Text('SUBMITTED ON', style: _headerStyle())),
          SizedBox(width: 100, child: Text('FILE', style: _headerStyle())),
        ]),
      ),
      body: Column(
          children: pageData.map((item) => _financialSummaryRow(item)).toList()),
      totalCount: _financialSummaryData.length,
      start: start,
      end: end,
      totalPages: totalPages,
      onExport: _exportFinancialSummary,
    );
  }

  Widget _financialSummaryRow(FinancialSummaryData item) {
    return _tableRow(children: [
      SizedBox(
          width: 200,
          child: Text(item.orgName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      SizedBox(
          width: 150,
          child: Text(DateFormat('MMM dd, yyyy').format(item.submittedAt),
              style: const TextStyle(fontSize: 12))),
      SizedBox(
          width: 100,
          child: item.fileUrl != null
              ? const Icon(Icons.attach_file, color: UpriseColors.primaryDark)
              : const Text('No file')),
    ]);
  }

  Widget _buildAccomplishmentSummaryTable() {
    if (_isLoadingReport) return const Center(child: CircularProgressIndicator());
    if (_accomplishmentSummaryData.isEmpty)
      return _emptyWidget('No accomplishment submissions found');
    final totalPages = (_accomplishmentSummaryData.length / _pageSize).ceil();
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _accomplishmentSummaryData.length);
    final pageData = _accomplishmentSummaryData.sublist(start, end);
    return _buildTableContainer(
      header: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          SizedBox(
              width: 200, child: Text('ORGANIZATION', style: _headerStyle())),
          SizedBox(
              width: 150, child: Text('SUBMITTED ON', style: _headerStyle())),
          SizedBox(width: 100, child: Text('FILE', style: _headerStyle())),
        ]),
      ),
      body: Column(
          children: pageData.map((item) => _accomplishmentSummaryRow(item)).toList()),
      totalCount: _accomplishmentSummaryData.length,
      start: start,
      end: end,
      totalPages: totalPages,
      onExport: _exportAccomplishmentSummary,
    );
  }

  Widget _accomplishmentSummaryRow(AccomplishmentSummaryData item) {
    return _tableRow(children: [
      SizedBox(
          width: 200,
          child: Text(item.orgName,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      SizedBox(
          width: 150,
          child: Text(DateFormat('MMM dd, yyyy').format(item.submittedAt),
              style: const TextStyle(fontSize: 12))),
      SizedBox(
          width: 100,
          child: item.fileUrl != null
              ? const Icon(Icons.attach_file, color: UpriseColors.primaryDark)
              : const Text('No file')),
    ]);
  }

  Widget _buildTableContainer({
    required Widget header,
    required Widget body,
    required int totalCount,
    required int start,
    required int end,
    required int totalPages,
    required VoidCallback onExport,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: UpriseColors.lightGray,
              border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12)),
            ),
            child: header,
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 500),
            child:
                SingleChildScrollView(scrollDirection: Axis.vertical, child: body),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
              color: UpriseColors.lightGray,
              borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing ${start + 1}–$end of $totalCount items',
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 13, color: UpriseColors.darkGray)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left, size: 20),
                      color: _currentPage > 1
                          ? UpriseColors.charcoal
                          : UpriseColors.mediumGray,
                      onPressed: _currentPage > 1
                          ? () => setState(() => _currentPage--)
                          : null,
                    ),
                    Text('$_currentPage / $totalPages',
                        style: GoogleFonts.beVietnamPro(fontSize: 13)),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, size: 20),
                      color: _currentPage < totalPages
                          ? UpriseColors.charcoal
                          : UpriseColors.mediumGray,
                      onPressed: _currentPage < totalPages
                          ? () => setState(() => _currentPage++)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: onExport,
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export Table'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableRow({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }

  Widget _emptyWidget(String message) => Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: UpriseColors.mediumGray)),
        child: Center(
          child: Column(children: [
            Icon(Icons.bar_chart, size: 64, color: UpriseColors.mediumGray),
            const SizedBox(height: 16),
            Text(message,
                style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
          ]),
        ),
      );

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: UpriseColors.darkGray,
      letterSpacing: 0.5);

  // ---------- EXPORT FUNCTIONS FOR GENERATOR ----------
  Future<void> _exportCurrentTableAsCSV() async {
    final rows = <List<String>>[];
    rows.add([
      'Event Name',
      'Organization',
      'Type',
      'Date',
      'Registrants',
      'Attendees',
      'Ratio'
    ]);
    for (var event in _eventsData) {
      final ratio = event.registrants > 0
          ? ((event.attendees / event.registrants) * 100).toStringAsFixed(0)
          : '0';
      rows.add([
        event.name,
        event.organization,
        event.type,
        DateFormat('yyyy-MM-dd').format(event.date),
        event.registrants.toString(),
        event.attendees.toString(),
        '$ratio%',
      ]);
    }
    final csvContent = rows.map((row) => row.join(',')).join('\n');
    final tempFile = await File('${Directory.systemTemp.path}/event_performance.csv')
        .writeAsString(csvContent);
    await Share.shareXFiles([XFile(tempFile.path)],
        text: 'Event Performance Report');
  }

  Future<void> _exportFinancialSummary() async {
    final rows = <List<String>>[];
    rows.add(['Organization', 'Submitted On', 'Has File']);
    for (var item in _financialSummaryData) {
      rows.add([
        item.orgName,
        DateFormat('yyyy-MM-dd').format(item.submittedAt),
        item.fileUrl != null ? 'Yes' : 'No'
      ]);
    }
    final csvContent = rows.map((row) => row.join(',')).join('\n');
    final tempFile = await File('${Directory.systemTemp.path}/financial_summary.csv')
        .writeAsString(csvContent);
    await Share.shareXFiles([XFile(tempFile.path)],
        text: 'Financial Summary Report');
  }

  Future<void> _exportAccomplishmentSummary() async {
    final rows = <List<String>>[];
    rows.add(['Organization', 'Submitted On', 'Has File']);
    for (var item in _accomplishmentSummaryData) {
      rows.add([
        item.orgName,
        DateFormat('yyyy-MM-dd').format(item.submittedAt),
        item.fileUrl != null ? 'Yes' : 'No'
      ]);
    }
    final csvContent = rows.map((row) => row.join(',')).join('\n');
    final tempFile = await File(
            '${Directory.systemTemp.path}/accomplishment_summary.csv')
        .writeAsString(csvContent);
    await Share.shareXFiles([XFile(tempFile.path)],
        text: 'Accomplishment Summary Report');
  }

  // ---------- GENERATE PDF/CSV (system-wide) ----------
  void _showGenerateReportDialog() {
    String selectedFormat = 'PDF';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) {
          return AlertDialog(
            title: Text(
                'Generate ${_selectedReportType.toString().split('.').last} Report',
                style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report Summary',
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _summaryRow('Date Range:', _dateRange),
                _summaryRow('Organization:', _selectedOrg),
                if (_selectedReportType ==
                    ReportGeneratorType.eventPerformance)
                  _summaryRow('Event Type:', _eventType),
                _summaryRow('Report View:', _reportView),
                const SizedBox(height: 16),
                Text('Report Format',
                    style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: RadioListTile(
                          title: const Text('PDF'),
                          value: 'PDF',
                          groupValue: selectedFormat,
                          onChanged: (v) =>
                              setStateDlg(() => selectedFormat = v!),
                          activeColor: UpriseColors.primaryDark)),
                  Expanded(
                      child: RadioListTile(
                          title: const Text('CSV'),
                          value: 'CSV',
                          groupValue: selectedFormat,
                          onChanged: (v) =>
                              setStateDlg(() => selectedFormat = v!),
                          activeColor: UpriseColors.primaryDark)),
                ]),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (selectedFormat == 'PDF') {
                    await _generatePDFReport();
                  } else {
                    await _generateCSVReport();
                  }
                },
                child: const Text('Generate & Download'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(
            width: 100,
            child: Text(label,
                style: GoogleFonts.beVietnamPro(
                    fontSize: 12, color: UpriseColors.darkGray))),
        Text(value,
            style: GoogleFonts.beVietnamPro(
                fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _generatePDFReport() async {
    final pdfDoc = pdf.Document();
    pdfDoc.addPage(pdf.MultiPage(
      build: (context) => [
        pdf.Header(
            level: 0,
            child: pdf.Text(
                'UPRISE ${_selectedReportType.toString().split('.').last} Report',
                style: pdf.TextStyle(
                    fontSize: 24, fontWeight: pdf.FontWeight.bold))),
        pdf.SizedBox(height: 10),
        pdf.Text(
            'Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}'),
        pdf.SizedBox(height: 20),
        pdf.Header(level: 1, child: pdf.Text('Report Configuration')),
        pdf.Row(children: [pdf.Text('Date Range: '), pdf.Text(_dateRange)]),
        pdf.Row(
            children: [pdf.Text('Organization: '), pdf.Text(_selectedOrg)]),
        if (_selectedReportType == ReportGeneratorType.eventPerformance)
          pdf.Row(children: [pdf.Text('Event Type: '), pdf.Text(_eventType)]),
        pdf.Row(children: [pdf.Text('Report View: '), pdf.Text(_reportView)]),
        pdf.SizedBox(height: 20),
        pdf.Header(level: 1, child: pdf.Text('Data')),
        _buildPdfTable(),
      ],
    ));
    await Printing.sharePdf(
      bytes: await pdfDoc.save(),
      filename:
          '${_selectedReportType.toString().split('.').last}_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
    await FirebaseFirestore.instance.collection('generated_reports').add({
      'fileName':
          '${_selectedReportType.toString().split('.').last}_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      'dateRange': _dateRange,
      'organization': _selectedOrg,
      'eventType': _eventType,
      'reportView': _reportView,
      'generatedAt': FieldValue.serverTimestamp(),
      'format': 'PDF',
      'reportType': _selectedReportType.toString().split('.').last,
    });
  }

  pdf.Widget _buildPdfTable() {
    if (_selectedReportType == ReportGeneratorType.eventPerformance) {
      return pdf.Table(
        border: pdf.TableBorder.all(),
        columnWidths: {
          0: pdf.FlexColumnWidth(2),
          1: pdf.FlexColumnWidth(2),
          2: pdf.FlexColumnWidth(1),
          3: pdf.FlexColumnWidth(1),
          4: pdf.FlexColumnWidth(1),
        },
        children: [
          pdf.TableRow(children: [
            pdf.Text('Event Name',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Organization',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Registrants',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Attendees',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Ratio',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
          ]),
          ..._eventsData.map((event) {
            final ratio = event.registrants > 0
                ? ((event.attendees / event.registrants) * 100)
                    .toStringAsFixed(0)
                : '0';
            return pdf.TableRow(children: [
              pdf.Text(event.name),
              pdf.Text(event.organization),
              pdf.Text('${event.registrants}'),
              pdf.Text('${event.attendees}'),
              pdf.Text('$ratio%'),
            ]);
          }),
        ],
      );
    } else if (_selectedReportType == ReportGeneratorType.financialSummary) {
      return pdf.Table(
        border: pdf.TableBorder.all(),
        columnWidths: {
          0: pdf.FlexColumnWidth(2),
          1: pdf.FlexColumnWidth(2),
          2: pdf.FlexColumnWidth(1),
        },
        children: [
          pdf.TableRow(children: [
            pdf.Text('Organization',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Submitted On',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Has File',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
          ]),
          ..._financialSummaryData.map((item) => pdf.TableRow(children: [
                pdf.Text(item.orgName),
                pdf.Text(DateFormat('yyyy-MM-dd').format(item.submittedAt)),
                pdf.Text(item.fileUrl != null ? 'Yes' : 'No'),
              ])),
        ],
      );
    } else {
      return pdf.Table(
        border: pdf.TableBorder.all(),
        columnWidths: {
          0: pdf.FlexColumnWidth(2),
          1: pdf.FlexColumnWidth(2),
          2: pdf.FlexColumnWidth(1),
        },
        children: [
          pdf.TableRow(children: [
            pdf.Text('Organization',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Submitted On',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Has File',
                style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
          ]),
          ..._accomplishmentSummaryData.map((item) => pdf.TableRow(children: [
                pdf.Text(item.orgName),
                pdf.Text(DateFormat('yyyy-MM-dd').format(item.submittedAt)),
                pdf.Text(item.fileUrl != null ? 'Yes' : 'No'),
              ])),
        ],
      );
    }
  }

  Future<void> _generateCSVReport() async {
    List<List<String>> rows;
    if (_selectedReportType == ReportGeneratorType.eventPerformance) {
      rows = [
        [
          'Event Name',
          'Organization',
          'Type',
          'Date',
          'Registrants',
          'Attendees',
          'Ratio'
        ]
      ];
      for (var event in _eventsData) {
        final ratio = event.registrants > 0
            ? ((event.attendees / event.registrants) * 100).toStringAsFixed(0)
            : '0';
        rows.add([
          event.name,
          event.organization,
          event.type,
          DateFormat('yyyy-MM-dd').format(event.date),
          event.registrants.toString(),
          event.attendees.toString(),
          '$ratio%',
        ]);
      }
    } else if (_selectedReportType == ReportGeneratorType.financialSummary) {
      rows = [['Organization', 'Submitted On', 'Has File']];
      for (var item in _financialSummaryData) {
        rows.add([
          item.orgName,
          DateFormat('yyyy-MM-dd').format(item.submittedAt),
          item.fileUrl != null ? 'Yes' : 'No'
        ]);
      }
    } else {
      rows = [['Organization', 'Submitted On', 'Has File']];
      for (var item in _accomplishmentSummaryData) {
        rows.add([
          item.orgName,
          DateFormat('yyyy-MM-dd').format(item.submittedAt),
          item.fileUrl != null ? 'Yes' : 'No'
        ]);
      }
    }
    final csvContent = rows.map((row) => row.join(',')).join('\n');
    final tempFile = await File(
            '${Directory.systemTemp.path}/${_selectedReportType.toString().split('.').last}_report.csv')
        .writeAsString(csvContent);
    await Share.shareXFiles([XFile(tempFile.path)],
        text: '${_selectedReportType.toString().split('.').last} Report');
    await FirebaseFirestore.instance.collection('generated_reports').add({
      'fileName':
          '${_selectedReportType.toString().split('.').last}_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      'dateRange': _dateRange,
      'organization': _selectedOrg,
      'eventType': _eventType,
      'reportView': _reportView,
      'generatedAt': FieldValue.serverTimestamp(),
      'format': 'CSV',
      'reportType': _selectedReportType.toString().split('.').last,
    });
  }

  Widget _buildRecentReports() {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Reports',
              style: GoogleFonts.beVietnamPro(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: UpriseColors.charcoal)),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('generated_reports')
                .orderBy('generatedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.data!.docs.isEmpty) {
                return Center(
                    child: Text('No reports generated yet',
                        style: GoogleFonts.beVietnamPro(
                            color: UpriseColors.darkGray)));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final data =
                      snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(Icons.picture_as_pdf,
                        color: UpriseColors.primaryDark),
                    title: Text(data['fileName'] ?? 'Report',
                        style: GoogleFonts.beVietnamPro(
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                        DateFormat('MMM dd, yyyy hh:mm a').format(
                            (data['generatedAt'] as Timestamp).toDate())),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                          icon: const Icon(Icons.visibility, size: 18),
                          onPressed: () => _viewGeneratedReport(data),
                          tooltip: 'View'),
                      IconButton(
                          icon: const Icon(Icons.download, size: 18),
                          onPressed: () => _downloadGeneratedReport(data),
                          tooltip: 'Download'),
                    ]),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _viewGeneratedReport(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(report['fileName'] ?? 'Report'),
        content: Text('Report generated on ${report['generatedAt']?.toDate()}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  Future<void> _downloadGeneratedReport(Map<String, dynamic> report) async {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download started (simulated)')));
  }

  // ==================== MAIN BUILD ====================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        children: [
          _buildMainHeader(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Submission Tracker'),
              Tab(text: 'Generate Reports'),
            ],
            labelColor: UpriseColors.primaryDark,
            unselectedLabelColor: UpriseColors.darkGray,
            indicatorColor: UpriseColors.primaryDark,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSubmissionTracker(),
                _buildReportGeneratorUI(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reports Management',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: UpriseColors.charcoal),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  'Track organization submissions and generate system‑wide reports',
                  style: GoogleFonts.beVietnamPro(
                      fontSize: 14, color: UpriseColors.darkGray),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionTracker() {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildDeadlineBar(),
          const SizedBox(height: 16),
          _buildSubmissionTable('Financial', _financialSubmissions,
              _financialDeadline, _loadingFinancial),
          const SizedBox(height: 24),
          _buildSubmissionTable('Accomplishment', _accomplishmentSubmissions,
              _accomplishmentDeadline, _loadingAccomplishment),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDeadlineBar() {
    if (_loadingDeadlines) return const LinearProgressIndicator();
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.timer, color: UpriseColors.primaryDark),
                  const SizedBox(width: 8),
                  Text('Financial Deadline: ',
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w600)),
                  Text(_financialDeadline != null
                      ? DateFormat('MMM dd, yyyy').format(_financialDeadline!)
                      : 'Not set'),
                  const SizedBox(width: 24),
                  const Icon(Icons.assignment, color: UpriseColors.primaryDark),
                  const SizedBox(width: 8),
                  Text('Accomplishment Deadline: ',
                      style: GoogleFonts.beVietnamPro(
                          fontWeight: FontWeight.w600)),
                  Text(_accomplishmentDeadline != null
                      ? DateFormat('MMM dd, yyyy')
                          .format(_accomplishmentDeadline!)
                      : 'Not set'),
                ],
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showSetDeadlineDialog,
            icon: const Icon(Icons.edit_calendar, size: 18),
            label: const Text('Set Deadlines'),
          ),
        ],
      ),
    );
  }
}