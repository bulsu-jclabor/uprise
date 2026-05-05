// lib/screens/admin/reports_management.dart
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

class ReportsManagement extends StatefulWidget {
  @override
  _ReportsManagementState createState() => _ReportsManagementState();
}

class _ReportsManagementState extends State<ReportsManagement> {
  // Report configuration
  String _dateRange = 'Current Semester';
  String _selectedOrg = 'All Organizations';
  String _eventType = 'All Types';
  String _reportView = 'By Event';
  List<Map<String, String>> _organizations = [];
  List<EventReportData> _eventsData = [];
  bool _isLoading = true;

  // Stats
  int _totalEvents = 0;
  int _totalRegistrants = 0;
  int _totalAttendees = 0;

  @override
  void initState() {
    super.initState();
    _loadOrganizations();
    _loadReportData();
  }

  Future<void> _loadOrganizations() async {
  final snap = await FirebaseFirestore.instance.collection('organizations').get();
  setState(() {
    _organizations = snap.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>; // explicit cast
      return {
        'id': doc.id,
        'name': data['name']?.toString() ?? 'Unknown',
      };
    }).toList();
  });
}

 Future<void> _loadReportData() async {
  setState(() => _isLoading = true);
  try {
    Query query = FirebaseFirestore.instance.collection('events').where('status', isEqualTo: 'approved');
    if (_eventType != 'All Types') {
      query = query.where('type', isEqualTo: _eventType);
    }
    if (_selectedOrg != 'All Organizations') {
      final org = _organizations.firstWhere((o) => o['name'] == _selectedOrg);
      if (org['id'] != null) query = query.where('orgId', isEqualTo: org['id']);
    }
    final eventsSnap = await query.get();

    _eventsData = [];
    _totalRegistrants = 0;
    _totalAttendees = 0;

    for (var doc in eventsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final eventId = doc.id;
      int registrants = 0;
      int attendees = 0;
      final regSnap = await FirebaseFirestore.instance
          .collection('registrations')
          .where('eventId', isEqualTo: eventId)
          .get();
      registrants = regSnap.docs.length;
      attendees = regSnap.docs.where((r) => (r.data() as Map<String, dynamic>)['attended'] == true).length;

      _eventsData.add(EventReportData(
        id: eventId,
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
    setState(() => _isLoading = false);
  } catch (e) {
    print('Error loading report data: $e');
    setState(() => _isLoading = false);
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildReportConfig(),
            _buildStatsRow(),
            _buildEventTable(),
            _buildRecentReports(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reports Management',
            style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
          ),
          SizedBox(height: 4),
          Text(
            'Create and export comprehensive analysis on student organization performance, attendance rates, and financial auditing.',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
          ),
        ],
      ),
    );
  }

  Widget _buildReportConfig() {
    return Container(
      margin: EdgeInsets.all(24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Report Configuration',
              style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
          SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildFilterDropdown('DATE RANGE', _dateRange, ['Current Semester', 'Last Semester', 'Academic Year 2024-2025'], (v) => setState(() => _dateRange = v!)),
              _buildFilterDropdown('ORGANIZATION', _selectedOrg, ['All Organizations', ..._organizations.map((o) => o['name']!)], (v) => setState(() { _selectedOrg = v!; _loadReportData(); })),
              _buildFilterDropdown('EVENT TYPE', _eventType, ['All Types', 'In Person', 'Virtual', 'Workshop', 'Seminar', 'Competition'], (v) => setState(() { _eventType = v!; _loadReportData(); })),
              _buildFilterDropdown('REPORT VIEW', _reportView, ['By Event', 'By Organization', 'By Month'], (v) => setState(() => _reportView = v!)),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () => _showAdvancedFilters(),
                icon: Icon(Icons.tune, size: 18),
                label: Text('Advanced Filters'),
                style: TextButton.styleFrom(foregroundColor: UpriseColors.primaryDark),
              ),
              ElevatedButton.icon(
                onPressed: _showGenerateReportDialog,
                icon: Icon(Icons.insert_drive_file),
                label: Text('Generate Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: UpriseColors.primaryDark,
                  foregroundColor: UpriseColors.white,
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
          SizedBox(height: 4),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: UpriseColors.mediumGray),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: GoogleFonts.beVietnamPro(fontSize: 13)))).toList(),
                onChanged: onChanged,
                isExpanded: true,
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancedFilters() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Advanced Filters', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          // Additional filters can be added here
          Text('Additional filter options coming soon...', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Row(children: [
        _statCard('Total Events', '$_totalEvents', UpriseColors.primaryDark),
        SizedBox(width: 16),
        _statCard('Total Registrants', '$_totalRegistrants', UpriseColors.success),
        SizedBox(width: 16),
        _statCard('Total Attendees', '$_totalAttendees', UpriseColors.accent),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Widget _buildEventTable() {
    if (_isLoading) {
      return Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark)),
      );
    }
    if (_eventsData.isEmpty) {
      return Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: UpriseColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: UpriseColors.mediumGray),
        ),
        child: Center(
          child: Column(children: [
            Icon(Icons.bar_chart, size: 64, color: UpriseColors.mediumGray),
            SizedBox(height: 16),
            Text('No events match the selected filters', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
          ]),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: UpriseColors.lightGray,
            border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(flex: 2, child: Text('EVENT NAME', style: _headerStyle())),
            Expanded(flex: 1, child: Text('ORGANIZATION', style: _headerStyle())),
            Expanded(flex: 1, child: Text('TYPE', style: _headerStyle())),
            Expanded(flex: 1, child: Text('DATE', style: _headerStyle())),
            Expanded(flex: 1, child: Text('REGISTRANTS', style: _headerStyle())),
            Expanded(flex: 1, child: Text('ATTENDEES', style: _headerStyle())),
            Expanded(flex: 1, child: Text('RATIO', style: _headerStyle())),
          ]),
        ),
        // Body
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: _eventsData.length,
          itemBuilder: (context, index) {
            final event = _eventsData[index];
            final ratio = event.registrants > 0 ? ((event.attendees / event.registrants) * 100).toStringAsFixed(0) : '0';
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
              child: Row(children: [
                Expanded(flex: 2, child: Text(event.name, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500))),
                Expanded(flex: 1, child: Text(event.organization, style: GoogleFonts.beVietnamPro(fontSize: 12))),
                Expanded(flex: 1, child: Text(event.type, style: GoogleFonts.beVietnamPro(fontSize: 12))),
                Expanded(flex: 1, child: Text(DateFormat('MMM dd, yyyy').format(event.date), style: GoogleFonts.beVietnamPro(fontSize: 12))),
                Expanded(flex: 1, child: Text('${event.registrants}', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Text('${event.attendees}', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600))),
                Expanded(flex: 1, child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: UpriseColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text('$ratio%', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.success), textAlign: TextAlign.center),
                )),
              ]),
            );
          },
        ),
        // Footer
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
            color: UpriseColors.lightGray,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Showing ${_eventsData.length} of ${_eventsData.length} events',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
              OutlinedButton.icon(
                onPressed: _exportCurrentTableAsCSV,
                icon: Icon(Icons.download, size: 16),
                label: Text('Export Table'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: UpriseColors.primaryDark,
                  side: BorderSide(color: UpriseColors.primaryDark),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildRecentReports() {
    return Container(
      margin: EdgeInsets.all(24),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent Reports', style: GoogleFonts.beVietnamPro(fontSize: 18, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
          SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('generated_reports')
                .orderBy('generatedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) {
                return Center(child: Text('No reports generated yet', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)));
              }
              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return ListTile(
                    leading: Icon(Icons.picture_as_pdf, color: UpriseColors.primaryDark),
                    title: Text(data['fileName'] ?? 'Report', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w500)),
                    subtitle: Text(DateFormat('MMM dd, yyyy hh:mm a').format((data['generatedAt'] as Timestamp).toDate())),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: Icon(Icons.visibility, size: 18), onPressed: () => _viewGeneratedReport(data), tooltip: 'View'),
                      IconButton(icon: Icon(Icons.download, size: 18), onPressed: () => _downloadGeneratedReport(data), tooltip: 'Download'),
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

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(
    fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5);

  void _showGenerateReportDialog() {
    String _selectedFormat = 'PDF'; // PDF or CSV
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDlg) {
          return AlertDialog(
            title: Text('Generate Report', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report Summary', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                _summaryRow('Date Range:', _dateRange),
                _summaryRow('Organization:', _selectedOrg),
                _summaryRow('Event Type:', _eventType),
                _summaryRow('Report View:', _reportView),
                SizedBox(height: 16),
                Text('Report Format', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Row(children: [
                  Expanded(child: RadioListTile(
                    title: Text('PDF'),
                    value: 'PDF', groupValue: _selectedFormat,
                    onChanged: (v) => setStateDlg(() => _selectedFormat = v!),
                    activeColor: UpriseColors.primaryDark,
                  )),
                  Expanded(child: RadioListTile(
                    title: Text('CSV'),
                    value: 'CSV', groupValue: _selectedFormat,
                    onChanged: (v) => setStateDlg(() => _selectedFormat = v!),
                    activeColor: UpriseColors.primaryDark,
                  )),
                ]),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (_selectedFormat == 'PDF') {
                    await _generatePDFReport();
                  } else {
                    await _generateCSVReport();
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
                child: Text('Generate & Download'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 100, child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray))),
        Text(value, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Future<void> _generatePDFReport() async {
    final pdfDoc = pdf.Document();
    // Add content
    pdfDoc.addPage(pdf.MultiPage(
      build: (context) => [
        pdf.Header(level: 0, child: pdf.Text('UPRISE Event Report', style: pdf.TextStyle(fontSize: 24, fontWeight: pdf.FontWeight.bold))),
        pdf.SizedBox(height: 10),
        pdf.Text('Generated on: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}'),
        pdf.SizedBox(height: 20),
        pdf.Header(level: 1, child: pdf.Text('Report Configuration')),
        ..._reportConfigToPdf(),
        pdf.SizedBox(height: 20),
        pdf.Header(level: 1, child: pdf.Text('Event Performance')),
        ..._eventsToPdf(),
      ],
    ));

    // Save to temp file and share
    final output = await Printing.sharePdf(
      bytes: await pdfDoc.save(),
      filename: 'uprise_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
    // Save metadata to Firestore
    await FirebaseFirestore.instance.collection('generated_reports').add({
      'fileName': 'uprise_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      'dateRange': _dateRange,
      'organization': _selectedOrg,
      'eventType': _eventType,
      'reportView': _reportView,
      'generatedAt': FieldValue.serverTimestamp(),
      'format': 'PDF',
    });
  }

  List<pdf.Widget> _reportConfigToPdf() {
    return [
      pdf.Row(children: [pdf.Text('Date Range: '), pdf.Text(_dateRange)]),
      pdf.Row(children: [pdf.Text('Organization: '), pdf.Text(_selectedOrg)]),
      pdf.Row(children: [pdf.Text('Event Type: '), pdf.Text(_eventType)]),
      pdf.Row(children: [pdf.Text('Report View: '), pdf.Text(_reportView)]),
    ];
  }

  List<pdf.Widget> _eventsToPdf() {
    return [
      pdf.Table(
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
            pdf.Text('Event Name', style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Organization', style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Registrants', style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Attendees', style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
            pdf.Text('Ratio', style: pdf.TextStyle(fontWeight: pdf.FontWeight.bold)),
          ]),
          ..._eventsData.map((event) {
            final ratio = event.registrants > 0 ? ((event.attendees / event.registrants) * 100).toStringAsFixed(0) : '0';
            return pdf.TableRow(children: [
              pdf.Text(event.name),
              pdf.Text(event.organization),
              pdf.Text('${event.registrants}'),
              pdf.Text('${event.attendees}'),
              pdf.Text('$ratio%'),
            ]);
          }).toList(),
        ],
      ),
    ];
  }

  Future<void> _generateCSVReport() async {
    // Build CSV
    final rows = <List<String>>[];
    rows.add(['Event Name', 'Organization', 'Type', 'Date', 'Registrants', 'Attendees', 'Ratio']);
    for (var event in _eventsData) {
      final ratio = event.registrants > 0 ? ((event.attendees / event.registrants) * 100).toStringAsFixed(0) : '0';
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
    final tempFile = await File('${Directory.systemTemp.path}/uprise_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv')
        .writeAsString(csvContent);
    await Share.shareXFiles([XFile(tempFile.path)], text: 'UPRISE Event Report');
    // Save metadata
    await FirebaseFirestore.instance.collection('generated_reports').add({
      'fileName': 'uprise_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv',
      'dateRange': _dateRange,
      'organization': _selectedOrg,
      'eventType': _eventType,
      'reportView': _reportView,
      'generatedAt': FieldValue.serverTimestamp(),
      'format': 'CSV',
    });
  }

  Future<void> _exportCurrentTableAsCSV() async {
    final rows = <List<String>>[];
    rows.add(['Event Name', 'Organization', 'Type', 'Date', 'Registrants', 'Attendees', 'Ratio']);
    for (var event in _eventsData) {
      final ratio = event.registrants > 0 ? ((event.attendees / event.registrants) * 100).toStringAsFixed(0) : '0';
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
    final tempFile = await File('${Directory.systemTemp.path}/events_table_export.csv').writeAsString(csvContent);
    await Share.shareXFiles([XFile(tempFile.path)], text: 'Events Table Export');
  }

  void _viewGeneratedReport(Map<String, dynamic> report) {
    // For demo, show a detailed view dialog
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => ReportDetailPage(
          reportData: report,
          eventsData: _eventsData,
          config: {
            'dateRange': _dateRange,
            'organization': _selectedOrg,
            'eventType': _eventType,
            'reportView': _reportView,
          },
        ),
      ),
    );
  }

  Future<void> _downloadGeneratedReport(Map<String, dynamic> report) async {
    // Re‑generate based on stored config, or retrieve file from storage
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download started')));
  }
}

// Report Detail Page (matches the detailed view in your image)
class ReportDetailPage extends StatelessWidget {
  final Map<String, dynamic> reportData;
  final List<EventReportData> eventsData;
  final Map<String, String> config;

  ReportDetailPage({required this.reportData, required this.eventsData, required this.config});

  @override
  Widget build(BuildContext context) {
    // For demonstration, pick the first event or a sample.
    final sampleEvent = eventsData.isNotEmpty ? eventsData.first : null;
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      appBar: AppBar(
        title: Text('Report Details', style: GoogleFonts.beVietnamPro()),
        backgroundColor: UpriseColors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: UpriseColors.charcoal),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back to list button (if needed)
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: UpriseColors.primaryDark),
                  onPressed: () => Navigator.pop(context),
                ),
                Text('Back to Reports List', style: GoogleFonts.beVietnamPro(color: UpriseColors.primaryDark)),
              ],
            ),
            SizedBox(height: 16),
            // Event name header
            Text(sampleEvent?.name ?? 'Event Report',
                style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
            Text(sampleEvent?.organization ?? 'Organization Name',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
            SizedBox(height: 24),
            // Event Information card
            _infoCard('Event Information', [
              _infoRow('EVENT NAME', sampleEvent?.name ?? '—'),
              _infoRow('DATE & TIME', sampleEvent != null ? DateFormat('MMMM d, yyyy').format(sampleEvent.date) : '—'),
              _infoRow('EVENT TYPE', sampleEvent?.type ?? '—'),
              _infoRow('VENUE', 'AVR 1, Engineering Building'),
              _infoRow('SUBMITTED ON', DateFormat('MMMM d, yyyy').format(DateTime.now())),
              _infoRow('ORGANIZATION', sampleEvent?.organization ?? '—'),
            ]),
            SizedBox(height: 24),
            // Key Metrics table
            _infoCard('Key Metrics', [
              _metricsRow('Metric', 'Target', 'Actual'),
              _metricsRow('Venue', '150', '138'),
              _metricsRow('Submitted On', DateFormat('MMMM d, yyyy').format(DateTime.now()), ''),
              _metricsRow('CICT Students', '98', '40'),
              _metricsRow('Guests', '5', ''),
            ]),
            SizedBox(height: 24),
            // Event Summary
            _infoCard('Event Summary', [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Tech Nexus 2023 served as the flagship technical seminar for this semester, specifically designed to bridge the gap between academic theories and industry practices. The event successfully covered emerging technologies including Artificial Intelligence, Machine Learning foundations, and Cloud Computing architectures. With a total of 138 attendees, the seminar featured three keynote speakers from leading tech firms who provided hands-on demonstrations and career roadmaps for aspiring developers.',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, height: 1.5),
                ),
              ),
            ]),
            SizedBox(height: 24),
            // Issues Encountered
            _infoCard('Issues Encountered', [
              _bulletPoint('Audio equipment malfunction during the second keynote session.'),
              _bulletPoint('Limited seating capacity for late registrants.'),
              _bulletPoint('Unstable Wi-Fi connectivity for the interactive workshop part.'),
            ]),
            SizedBox(height: 24),
            // Recommendations
            _infoCard('Recommendations', [
              _bulletPoint('Prepare backup wireless audio systems.'),
              _bulletPoint('Request larger venues for popular technical seminars.'),
              _bulletPoint('Pre-event technical Wi-Fi stress tests.'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray))),
          Expanded(child: Text(value, style: GoogleFonts.beVietnamPro(fontSize: 12))),
        ],
      ),
    );
  }

  Widget _metricsRow(String col1, String col2, String col3) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(flex: 2, child: Text(col1, style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600))),
        Expanded(flex: 1, child: Text(col2, style: GoogleFonts.beVietnamPro(fontSize: 12))),
        Expanded(flex: 1, child: Text(col3, style: GoogleFonts.beVietnamPro(fontSize: 12))),
      ]),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('• ', style: GoogleFonts.beVietnamPro(fontSize: 13)),
        Expanded(child: Text(text, style: GoogleFonts.beVietnamPro(fontSize: 13))),
      ]),
    );
  }
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