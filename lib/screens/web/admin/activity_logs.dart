import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  ACTIVITY LOGGER – use in any screen to track events
// ═══════════════════════════════════════════════════════════════
class ActivityLogger {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Log an activity to the 'activity_logs' collection.
  /// Call this method anywhere in the app.
  static Future<void> log({
    required String action,
    required String module,
    String severity = 'info',
    Map<String, dynamic>? details,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.email ?? 'Admin (not logged in)';

    await _firestore.collection('activity_logs').add({
      'user': userName,
      'action': action,
      'module': module,
      'severity': severity,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '', // optionally use an IP fetching package
      'details': details,
    });
  }
}

// ═══════════════════════════════════════════════════════════════
//  ACTIVITY LOGS PAGE
// ═══════════════════════════════════════════════════════════════
class ActivityLogs extends StatefulWidget {
  const ActivityLogs({super.key});

  @override
  _ActivityLogsState createState() => _ActivityLogsState();
}

class _ActivityLogsState extends State<ActivityLogs> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedModule = 'All Modules';
  String _dateRange = 'Today';
  String _severity = 'All Severities';
  int _currentPage = 1;
  static const int _pageSize = 10;

  int _totalLogs24h = 0;
  int _criticalActions = 0;
  int _failedAttempts = 0;
  int _activeAdmins = 3; // optional – fetch from a separate 'online_sessions' collection

  List<String> get _modules => [
        'All Modules',
        'Event Management',
        'Organizations',
        'User Directory',
        'Authentication',
        'Letter Request',
        'Adviser Roles',
        'Reports',
        'System',
      ];

  List<String> get _dateRanges => ['Today', 'Yesterday', 'This Week', 'Last Week', 'All'];
  List<String> get _severities => ['All Severities', 'info', 'warning', 'error', 'critical'];

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical': return UpriseColors.error;
      case 'error': return UpriseColors.error;
      case 'warning': return UpriseColors.warning;
      default: return UpriseColors.success;
    }
  }

  @override
  void initState() {
    super.initState();
    // optional: log that admin viewed the logs
    // ActivityLogger.log(action: 'Viewed activity logs', module: 'System', severity: 'info');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        children: [
          _buildHeader(),
          _buildStatsRow(),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                  'System Activity Audit Logs',
                  style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal),
                  softWrap: true,
                ),
                const SizedBox(height: 4),
                Text(
                  'Track and monitor all administrative changes across the UPRISE platform.',
                  style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray),
                  softWrap: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- HORIZONTAL STATS ROW (fixes layout issue) ----------
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activity_logs').snapshots(),
      builder: (context, snapshot) {
        int total24h = 0;
        int critical = 0;
        int failed = 0;

        if (snapshot.hasData) {
          final now = DateTime.now();
          final twentyFourHoursAgo = now.subtract(const Duration(days: 1));
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            dynamic tsField = data['timestamp'];
            DateTime? timestamp;
            if (tsField is Timestamp) timestamp = tsField.toDate();
            else if (tsField is DateTime) timestamp = tsField;
            if (timestamp != null && timestamp.isAfter(twentyFourHoursAgo)) total24h++;
            final severity = data['severity'] ?? 'info';
            if (severity == 'critical' || severity == 'high') critical++;
            final action = data['action'] ?? '';
            if (action.contains('failed') || action.contains('unauthorized') || severity == 'error') failed++;
          }
          _totalLogs24h = total24h;
          _criticalActions = critical;
          _failedAttempts = failed;
        }

        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: 4,
            itemBuilder: (_, index) {
              switch (index) {
                case 0: return _statCard('TOTAL LOGS (24H)', '$_totalLogs24h', UpriseColors.primaryDark, '+12% from yesterday');
                case 1: return _statCard('CRITICAL ACTIONS', '$_criticalActions', UpriseColors.error, 'Require immediate review');
                case 2: return _statCard('ACTIVE ADMINS', '$_activeAdmins', UpriseColors.success, 'Current online sessions');
                default: return _statCard('FAILED ATTEMPTS', '$_failedAttempts', UpriseColors.warning, 'In unauthorized modules');
              }
            },
          ),
        );
      },
    );
  }

  Widget _statCard(String label, String value, Color color, String subtitle) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.primaryDark, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(subtitle, style: GoogleFonts.beVietnamPro(fontSize: 10, color: UpriseColors.darkGray)),
        ],
      ),
    );
  }

  // ---------- TOOLBAR (responsive) ----------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return Column(
              children: [
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search user, action, module...',
                      hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                      prefixIcon: const Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                      filled: true,
                      fillColor: UpriseColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: UpriseColors.mediumGray),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (_) => setState(() => _currentPage = 1),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildFilterDropdown('Module', _selectedModule, _modules, (v) => setState(() { _selectedModule = v!; _currentPage = 1; }))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFilterDropdown('Date', _dateRange, _dateRanges, (v) => setState(() { _dateRange = v!; _currentPage = 1; }))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFilterDropdown('Severity', _severity, _severities, (v) => setState(() { _severity = v!; _currentPage = 1; }))),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _exportToCSV,
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Export'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: UpriseColors.primaryDark,
                        side: BorderSide(color: UpriseColors.mediumGray),
                      ),
                    ),
                  ],
                ),
              ],
            );
          } else {
            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search user, action, module...',
                        hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                        prefixIcon: const Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                        filled: true,
                        fillColor: UpriseColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: UpriseColors.mediumGray),
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (_) => setState(() => _currentPage = 1),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                _buildFilterDropdown('Module', _selectedModule, _modules, (v) => setState(() { _selectedModule = v!; _currentPage = 1; })),
                const SizedBox(width: 16),
                _buildFilterDropdown('Date', _dateRange, _dateRanges, (v) => setState(() { _dateRange = v!; _currentPage = 1; })),
                const SizedBox(width: 16),
                _buildFilterDropdown('Severity', _severity, _severities, (v) => setState(() { _severity = v!; _currentPage = 1; })),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _exportToCSV,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Export'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: UpriseColors.primaryDark,
                    side: BorderSide(color: UpriseColors.mediumGray),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: UpriseColors.darkGray)),
        const SizedBox(height: 4),
        Container(
          height: 40,
          constraints: const BoxConstraints(minWidth: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: UpriseColors.primaryDark, width: 1),
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

  // ---------- TABLE (with null‑safe timestamps) ----------
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activity_logs').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: TextStyle(color: UpriseColors.error)));

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));
        final thisWeekStart = today.subtract(Duration(days: now.weekday - 1));
        final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));

        List<Map<String, dynamic>> logs = [];
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          dynamic tsField = data['timestamp'];
          DateTime? timestamp;
          if (tsField is Timestamp) timestamp = tsField.toDate();
          else if (tsField is DateTime) timestamp = tsField;

          if (_dateRange != 'All' && timestamp == null) continue;
          if (timestamp != null) {
            final logDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
            if (_dateRange == 'Today' && logDate != today) continue;
            if (_dateRange == 'Yesterday' && logDate != yesterday) continue;
            if (_dateRange == 'This Week' && logDate.isBefore(thisWeekStart)) continue;
            if (_dateRange == 'Last Week' && (logDate.isBefore(lastWeekStart) || logDate.isAfter(thisWeekStart.subtract(const Duration(days: 1))))) continue;
          }
          if (_selectedModule != 'All Modules' && data['module'] != _selectedModule) continue;
          if (_severity != 'All Severities' && data['severity'] != _severity) continue;

          final term = _searchController.text.trim().toLowerCase();
          if (term.isNotEmpty) {
            final user = (data['user'] ?? '').toString().toLowerCase();
            final action = (data['action'] ?? '').toString().toLowerCase();
            final module = (data['module'] ?? '').toString().toLowerCase();
            if (!user.contains(term) && !action.contains(term) && !module.contains(term)) continue;
          }
          logs.add(data);
        }

        if (logs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: UpriseColors.primaryDark, width: 1),
            ),
            child: Column(
              children: [
                _buildTableHeader(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 64, color: UpriseColors.mediumGray),
                        const SizedBox(height: 16),
                        Text('No activity logs found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final totalPages = (logs.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, logs.length);
        final pageLogs = logs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: UpriseColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: UpriseColors.primaryDark, width: 1),
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: pageLogs.length,
                  itemBuilder: (_, i) {
                    final data = pageLogs[i];
                    dynamic tsField = data['timestamp'];
                    DateTime? timestamp;
                    if (tsField is Timestamp) timestamp = tsField.toDate();
                    else if (tsField is DateTime) timestamp = tsField;
                    final severity = data['severity'] ?? 'info';
                    return _buildRow(
                      user: data['user'] ?? 'Unknown',
                      action: data['action'] ?? 'Unknown action',
                      module: data['module'] ?? 'General',
                      severity: severity,
                      timestamp: timestamp,
                    );
                  },
                ),
              ),
              _buildFooter(logs.length, totalPages, start, end),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: UpriseColors.lightGray,
        border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 160, child: Text('USER', style: _headerStyle())),
            SizedBox(width: 280, child: Text('ACTION', style: _headerStyle())),
            SizedBox(width: 180, child: Text('MODULE', style: _headerStyle())),
            SizedBox(width: 120, child: Text('DATE', style: _headerStyle())),
            SizedBox(width: 100, child: Text('TIME', style: _headerStyle())),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
        color: UpriseColors.lightGray,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total entries', style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
          Row(children: [
            IconButton(icon: const Icon(Icons.chevron_left, size: 20), color: _currentPage > 1 ? UpriseColors.charcoal : UpriseColors.mediumGray, onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null),
            ...pages.map((page) => GestureDetector(
              onTap: () => setState(() => _currentPage = page),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: page == _currentPage ? UpriseColors.primaryDark : Colors.transparent, borderRadius: BorderRadius.circular(4)),
                child: Text('$page', style: GoogleFonts.beVietnamPro(fontSize: 12, color: page == _currentPage ? Colors.white : UpriseColors.charcoal, fontWeight: page == _currentPage ? FontWeight.w600 : FontWeight.normal)),
              ),
            )),
            if (lastPage < totalPages) ...[
              Text('...', style: TextStyle(color: UpriseColors.darkGray)),
              GestureDetector(
                onTap: () => setState(() => _currentPage = totalPages),
                child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text('$totalPages', style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.charcoal))),
              ),
            ],
            IconButton(icon: const Icon(Icons.chevron_right, size: 20), color: _currentPage < totalPages ? UpriseColors.charcoal : UpriseColors.mediumGray, onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
          ]),
        ],
      ),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildRow({required String user, required String action, required String module, required String severity, DateTime? timestamp}) {
    String formattedDate = '—';
    String formattedTime = '—';
    if (timestamp != null) {
      formattedDate = DateFormat('MMM dd, yyyy').format(timestamp);
      formattedTime = DateFormat('hh:mm a').format(timestamp);
    }
    final severityColor = _severityColor(severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 160, child: Text(user, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500))),
            SizedBox(width: 280, child: Text(action, style: GoogleFonts.beVietnamPro(fontSize: 13))),
            SizedBox(width: 180, child: Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: severityColor, shape: BoxShape.circle)), const SizedBox(width: 8), Expanded(child: Text(module, style: GoogleFonts.beVietnamPro(fontSize: 13)))])),
            SizedBox(width: 120, child: Text(formattedDate, style: GoogleFonts.beVietnamPro(fontSize: 12))),
            SizedBox(width: 100, child: Text(formattedTime, style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.darkGray))),
          ],
        ),
      ),
    );
  }

  // ---------- EXPORT ----------
  Future<void> _exportToCSV() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('activity_logs').get();
      final lines = <String>['User,Action,Module,Severity,Timestamp,IP Address'];
      for (var doc in snapshot.docs) {
        final d = doc.data();
        dynamic tsField = d['timestamp'];
        String timestampStr = '';
        if (tsField is Timestamp) timestampStr = tsField.toDate().toIso8601String();
        else if (tsField is DateTime) timestampStr = tsField.toIso8601String();
        lines.add([d['user'] ?? '', d['action'] ?? '', d['module'] ?? '', d['severity'] ?? '', timestampStr, d['ipAddress'] ?? ''].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/activity_logs_export.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'Activity Logs Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e'), backgroundColor: UpriseColors.error));
    }
  }
}
