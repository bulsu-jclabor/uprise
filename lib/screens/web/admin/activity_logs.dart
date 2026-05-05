// lib/screens/admin/activity_logs.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

class ActivityLogs extends StatefulWidget {
  @override
  _ActivityLogsState createState() => _ActivityLogsState();
}

class _ActivityLogsState extends State<ActivityLogs> {
  String _selectedModule = 'All Modules';
  String _dateRange = 'Today';
  String _severity = 'All Severities';
  final TextEditingController _searchController = TextEditingController();
  int _currentPage = 1;
  static const int _pageSize = 10;
  List<LogEntry> _allLogs = [];
  List<LogEntry> _filteredLogs = [];
  bool _isLoading = true;

  // Stats
  int _totalLogs24h = 0;
  int _criticalActions = 0;
  int _activeAdmins = 0;
  int _failedAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .get();
      final now = DateTime.now();
      final twentyFourHoursAgo = now.subtract(Duration(days: 1));

      _allLogs = snapshot.docs.map((doc) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        return LogEntry(
          id: doc.id,
          user: data['user'] ?? 'Unknown',
          action: data['action'] ?? 'Unknown action',
          module: data['module'] ?? 'General',
          severity: data['severity'] ?? 'info',
          timestamp: timestamp,
          ipAddress: data['ipAddress'] ?? '',
        );
      }).toList();

      // Calculate stats
      _totalLogs24h = _allLogs.where((log) => log.timestamp.isAfter(twentyFourHoursAgo)).length;
      _criticalActions = _allLogs.where((log) => log.severity == 'critical' || log.severity == 'high').length;
      _failedAttempts = _allLogs.where((log) => log.action.contains('failed') || log.action.contains('unauthorized') || log.severity == 'error').length;
      // Mock active admins – you'd typically query online sessions from another collection
      _activeAdmins = 3;

      _applyFilters();
    } catch (e) {
      print('Error loading logs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLogs = _allLogs.where((log) {
        if (_selectedModule != 'All Modules' && log.module != _selectedModule) return false;
        if (_severity != 'All Severities' && log.severity != _severity) return false;
        if (_dateRange != 'All') {
          final now = DateTime.now();
          final logDate = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
          final today = DateTime(now.year, now.month, now.day);
          final yesterday = today.subtract(Duration(days: 1));
          final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));
          if (_dateRange == 'Today' && logDate != today) return false;
          if (_dateRange == 'Yesterday' && logDate != yesterday) return false;
          if (_dateRange == 'This Week' && logDate.isBefore(thisWeekStart)) return false;
        }
        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          return log.user.toLowerCase().contains(term) ||
              log.action.toLowerCase().contains(term) ||
              log.module.toLowerCase().contains(term);
        }
        return true;
      }).toList();
      _currentPage = 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = (_filteredLogs.length / _pageSize).ceil();
    final start = (_currentPage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, _filteredLogs.length);
    final pageLogs = _filteredLogs.sublist(start, end);

    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatsRow(),
          _buildFilterBar(),
          Expanded(child: _buildTable(pageLogs, totalPages, start, end)),
          SizedBox(height: 24),
        ],
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
            'System Activity Audit Logs',
            style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
          ),
          SizedBox(height: 4),
          Text(
            'Track and monitor all administrative changes across the UPRISE platform.',
            style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Row(children: [
        _statCard('TOTAL LOGS (24H)', '$_totalLogs24h', UpriseColors.primaryDark, '+12% from yesterday'),
        SizedBox(width: 16),
        _statCard('CRITICAL ACTIONS', '$_criticalActions', UpriseColors.error, 'Require immediate review'),
        SizedBox(width: 16),
        _statCard('ACTIVE ADMINS', '$_activeAdmins', UpriseColors.success, 'Current online sessions'),
        SizedBox(width: 16),
        _statCard('FAILED ATTEMPTS', '$_failedAttempts', UpriseColors.warning, 'In unauthorized modules'),
      ]),
    );
  }

  Widget _statCard(String label, String value, Color color, String subtitle) {
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
          Row(children: [
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
            if (subtitle.isNotEmpty && label == 'TOTAL LOGS (24H)')
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.success)),
              ),
          ]),
          if (subtitle.isNotEmpty && label != 'TOTAL LOGS (24H)')
            Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray)),
        ]),
      ),
    );
  }

  Widget _buildFilterBar() {
    final modules = ['All Modules', 'Event Management', 'Organizations', 'User Directory', 'Authentication', 'Core Engine'];
    final dateRanges = ['Today', 'Yesterday', 'This Week', 'Last Week', 'All'];
    final severities = ['All Severities', 'info', 'warning', 'error', 'critical'];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _filterDropdown('Module', _selectedModule, modules, (v) => setState(() { _selectedModule = v!; _applyFilters(); })),
            SizedBox(width: 16),
            _filterDropdown('Date Range', _dateRange, dateRanges, (v) => setState(() { _dateRange = v!; _applyFilters(); })),
            SizedBox(width: 16),
            _filterDropdown('Severity', _severity, severities, (v) => setState(() { _severity = v!; _applyFilters(); })),
            SizedBox(width: 16),
            Container(
              width: 260,
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search user, action, module...',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                  prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                  filled: true,
                  fillColor: UpriseColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: UpriseColors.mediumGray),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (_) => _applyFilters(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
        SizedBox(height: 4),
        Container(
          height: 40,
          padding: EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: UpriseColors.mediumGray),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: GoogleFonts.beVietnamPro(fontSize: 13)))).toList(),
              onChanged: onChanged,
              style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
              icon: Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTable(List<LogEntry> logs, int totalPages, int start, int end) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark));
    }
    if (logs.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.history, size: 64, color: UpriseColors.mediumGray),
          SizedBox(height: 16),
          Text('No activity logs found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray)),
        ]),
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
        // Table Header
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: UpriseColors.lightGray,
            border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(flex: 2, child: Text('USER', style: _headerStyle())),
            Expanded(flex: 3, child: Text('ACTION', style: _headerStyle())),
            Expanded(flex: 2, child: Text('MODULE', style: _headerStyle())),
            Expanded(flex: 1, child: Text('DATE', style: _headerStyle())),
            Expanded(flex: 1, child: Text('TIME', style: _headerStyle())),
          ]),
        ),
        // Table Body
        Expanded(
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return _buildRow(log);
            },
          ),
        ),
        // Pagination Footer
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
              Text('Showing ${_filteredLogs.isEmpty ? 0 : start + 1} to $end of ${_filteredLogs.length} entries',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
              Row(children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, size: 20),
                  onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
                ),
                ...List.generate(totalPages.clamp(1, 5), (i) {
                  final page = i + 1;
                  final sel = page == _currentPage;
                  return GestureDetector(
                    onTap: () => setState(() => _currentPage = page),
                    child: Container(
                      margin: EdgeInsets.symmetric(horizontal: 2),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: sel ? UpriseColors.primaryDark : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('$page', style: GoogleFonts.beVietnamPro(
                        fontSize: 12, color: sel ? Colors.white : UpriseColors.charcoal,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      )),
                    ),
                  );
                }),
                IconButton(
                  icon: Icon(Icons.chevron_right, size: 20),
                  onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(
    fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildRow(LogEntry log) {
    final formattedDate = DateFormat('MMM dd, yyyy').format(log.timestamp);
    final formattedTime = DateFormat('hh:mm a').format(log.timestamp);
    final severityColor = log.severity == 'critical' ? UpriseColors.error
        : log.severity == 'error' ? UpriseColors.error
        : log.severity == 'warning' ? UpriseColors.warning
        : UpriseColors.success;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(flex: 2, child: Text(log.user, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500))),
        Expanded(flex: 3, child: Text(log.action, style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(flex: 2, child: Row(children: [
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(color: severityColor, shape: BoxShape.circle),
          ),
          SizedBox(width: 8),
          Expanded(child: Text(log.module, style: GoogleFonts.beVietnamPro(fontSize: 13))),
        ])),
        Expanded(flex: 1, child: Text(formattedDate, style: GoogleFonts.beVietnamPro(fontSize: 12))),
        Expanded(flex: 1, child: Text(formattedTime, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray))),
      ]),
    );
  }
}

class LogEntry {
  final String id;
  final String user;
  final String action;
  final String module;
  final String severity;
  final DateTime timestamp;
  final String ipAddress;

  LogEntry({
    required this.id,
    required this.user,
    required this.action,
    required this.module,
    required this.severity,
    required this.timestamp,
    required this.ipAddress,
  });
}