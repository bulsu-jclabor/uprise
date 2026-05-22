import 'dart:convert' show JsonEncoder;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import '../../theme/app_theme.dart';
import '../../../services/activity_logger.dart' as activity_log;

// ─────────────────────────────────────────────────────────────────────────────
// Design tokens (mirrors student_accounts.dart)
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const double radiusSm   = 8;
  static const double radiusMd   = 12;
  static const double radiusLg   = 16;
  static const double radiusPill = 100;

  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Severity badge
// ─────────────────────────────────────────────────────────────────────────────
class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge(this.severity);

  @override
  Widget build(BuildContext context) {
    final Map<String, _Style> styles = {
      'info':     _Style(const Color(0xFFEFF6FF), const Color(0xFF2563EB), 'INFO'),
      'warning':  _Style(const Color(0xFFFFFBEB), const Color(0xFFD97706), 'WARNING'),
      'error':    _Style(const Color(0xFFFEF2F2), const Color(0xFFDC2626), 'ERROR'),
      'critical': _Style(const Color(0xFFFDF2F8), const Color(0xFF9333EA), 'CRITICAL'),
    };
    final s = styles[severity.toLowerCase()] ??
        _Style(const Color(0xFFF3F4F6), const Color(0xFF6B7280), severity.toUpperCase());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: s.bg,
        borderRadius: BorderRadius.circular(_DS.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: s.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            s.label,
            style: GoogleFonts.beVietnamPro(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: s.fg,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _Style {
  final Color bg, fg;
  final String label;
  const _Style(this.bg, this.fg, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Widget
// ─────────────────────────────────────────────────────────────────────────────
class ActivityLogs extends StatefulWidget {
  const ActivityLogs({super.key});

  @override
  _ActivityLogsState createState() => _ActivityLogsState();
}

class _ActivityLogsState extends State<ActivityLogs> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedModule = 'All Modules';
  String _dateRange     = 'Today';
  String _severity      = 'All Severities';
  int    _currentPage   = 1;
  static const int _pageSize = 10;

  // ── Dropdown options ──────────────────────────────────────────────
  static const List<String> _modules = [
    'All Modules', 'System', 'Admin Dashboard', 'User Directory',
    'Organizations', 'Event Management', 'Letter Request', 'Reports',
    'Adviser Roles', 'Admin Settings', 'External Account', 'Event Calendar',
    'Broadcast', 'Announcements', 'Certificates', 'Finance', 'Merchandise',
    'Attendance QR', 'Event Analytics', 'Event Proposals', 'Events Schedule',
    'Org Profile', 'Org Settings', 'Adviser Approvals', 'Adviser Signing',
  ];
  static const List<String> _dateRanges  = ['Today', 'Yesterday', 'This Week', 'Last Week', 'All'];
  static const List<String> _severities  = ['All Severities', 'info', 'warning', 'error', 'critical'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

  // ── Page header ───────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: UpriseColors.primaryDark.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.history_rounded, color: UpriseColors.primaryDark, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'System Activity Audit Logs',
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A202C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Track and monitor all administrative changes across the UPRISE platform.',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('activity_logs').snapshots(),
      builder: (context, snapshot) {
        int total24h = 0, critical = 0, failed = 0, warnings = 0;

        if (snapshot.hasData) {
          final now             = DateTime.now();
          final twentyFourHoursAgo = now.subtract(const Duration(days: 1));
          for (final doc in snapshot.data!.docs) {
            final data     = doc.data() as Map<String, dynamic>;
            final severity = (data['severity'] ?? 'info').toString();
            final action   = (data['action'] ?? '').toString();
            DateTime? ts;
            final tsField = data['timestamp'];
            if (tsField is Timestamp) ts = tsField.toDate();
            else if (tsField is DateTime) ts = tsField;

            if (ts != null && ts.isAfter(twentyFourHoursAgo)) total24h++;
            if (severity == 'critical') critical++;
            if (severity == 'warning') warnings++;
            if (action.contains('failed') ||
                action.contains('unauthorized') ||
                severity == 'error') failed++;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
          child: Row(children: [
            _StatCard(
              label: 'Logs (Last 24 h)',
              value: '$total24h',
              icon: Icons.receipt_long_rounded,
              color: UpriseColors.primaryDark,
              subtitle: 'Recent activity',
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Critical Actions',
              value: '$critical',
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFF9333EA),
              subtitle: 'Require review',
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Warnings',
              value: '$warnings',
              icon: Icons.info_outline_rounded,
              color: const Color(0xFFD97706),
              subtitle: 'Flagged events',
            ),
            const SizedBox(width: 14),
            _StatCard(
              label: 'Failed Attempts',
              value: '$failed',
              icon: Icons.block_rounded,
              color: const Color(0xFFDC2626),
              subtitle: 'Errors & unauthorized',
            ),
          ]),
        );
      },
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.beVietnamPro(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search user, action, module, org…',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E6EA)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: UpriseColors.primaryDark, width: 1.5),
                  ),
                ),
                onChanged: (_) => setState(() => _currentPage = 1),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _selectedModule,
            items: _modules,
            hint: 'Module',
            onChanged: (v) => setState(() { _selectedModule = v!; _currentPage = 1; }),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _dateRange,
            items: _dateRanges,
            hint: 'Date',
            onChanged: (v) => setState(() { _dateRange = v!; _currentPage = 1; }),
          ),
          const SizedBox(width: 10),
          _FilterDropdown(
            value: _severity,
            items: _severities,
            hint: 'Severity',
            onChanged: (v) => setState(() { _severity = v!; _currentPage = 1; }),
          ),
          const SizedBox(width: 10),
          _ExportLogsButton(),
        ],
      ),
    );
  }

  // ── Table ─────────────────────────────────────────────────────────
  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final now            = DateTime.now();
        final today          = DateTime(now.year, now.month, now.day);
        final yesterday      = today.subtract(const Duration(days: 1));
        final thisWeekStart  = today.subtract(Duration(days: now.weekday - 1));
        final lastWeekStart  = thisWeekStart.subtract(const Duration(days: 7));
        final lastWeekEnd    = thisWeekStart.subtract(const Duration(days: 1));

        List<Map<String, dynamic>> logs = [];

        for (final doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;

          // Timestamp
          DateTime? ts;
          final tsField = data['timestamp'];
          if (tsField is Timestamp) ts = tsField.toDate();
          else if (tsField is DateTime) ts = tsField;

          // Date filter
          if (_dateRange != 'All') {
            if (ts == null) continue;
            final logDate = DateTime(ts.year, ts.month, ts.day);
            if (_dateRange == 'Today'     && logDate != today) continue;
            if (_dateRange == 'Yesterday' && logDate != yesterday) continue;
            if (_dateRange == 'This Week' && logDate.isBefore(thisWeekStart)) continue;
            if (_dateRange == 'Last Week' &&
                (logDate.isBefore(lastWeekStart) || logDate.isAfter(lastWeekEnd))) continue;
          }

          // Module filter
          if (_selectedModule != 'All Modules') {
            final m = (data['module'] ?? '').toString();
            if (!_matchesModule(_selectedModule, m)) continue;
          }

          // Severity filter
          if (_severity != 'All Severities' && data['severity'] != _severity) continue;

          // Search
          final term = _searchController.text.trim().toLowerCase();
          if (term.isNotEmpty) {
            final user   = (data['user'] ?? '').toString().toLowerCase();
            final action = (data['action'] ?? '').toString().toLowerCase();
            final module = (data['module'] ?? '').toString().toLowerCase();
            final orgId  = _extractOrgId(data).toLowerCase();
            if (!user.contains(term) &&
                !action.contains(term) &&
                !module.contains(term) &&
                !orgId.contains(term)) continue;
          }

          logs.add({...data, '_ts': ts});
        }

        if (logs.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8ECF0)),
              boxShadow: _DS.cardShadow,
            ),
            child: Column(
              children: [
                _buildTableHeader(),
                Expanded(child: _buildEmptyState()),
              ],
            ),
          );
        }

        final totalPages = (logs.length / _pageSize).ceil();
        final safePage   = _currentPage.clamp(1, totalPages);
        final start      = (safePage - 1) * _pageSize;
        final end        = (start + _pageSize).clamp(0, logs.length);
        final pageLogs   = logs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: _DS.cardShadow,
          ),
          child: Column(
            children: [
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: pageLogs.length,
                  itemBuilder: (_, i) => _buildLogRow(
                    data: pageLogs[i],
                    timestamp: pageLogs[i]['_ts'] as DateTime?,
                    isLast: i == pageLogs.length - 1,
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: _headerCell('USER')),
        Expanded(flex: 5, child: _headerCell('ACTION')),
        Expanded(flex: 2, child: _headerCell('ORG')),
        Expanded(flex: 3, child: _headerCell('MODULE')),
        Expanded(flex: 2, child: _headerCell('SEVERITY')),
        Expanded(flex: 3, child: _headerCell('TIMESTAMP')),
      ]),
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

  Widget _buildLogRow({
    required Map<String, dynamic> data,
    required DateTime? timestamp,
    required bool isLast,
  }) {
    final user     = (data['user'] ?? 'Unknown').toString();
    final action   = (data['action'] ?? 'Unknown action').toString();
    final module   = (data['module'] ?? 'General').toString();
    final severity = (data['severity'] ?? 'info').toString();
    final orgId    = _extractOrgId(data);

    final formattedDate = timestamp != null
        ? DateFormat('MMM dd, yyyy').format(timestamp)
        : '—';
    final formattedTime = timestamp != null
        ? DateFormat('hh:mm a').format(timestamp)
        : '—';

    return InkWell(
      hoverColor: const Color(0xFFF8F9FB),
      onTap: () => _showLogDetailDialog(
        user: user,
        action: action,
        module: module,
        severity: severity,
        orgId: orgId,
        timestamp: timestamp,
        data: data,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(children: [
          // User
          Expanded(
            flex: 3,
            child: Row(children: [
              _UserAvatar(name: user),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  user,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: UpriseColors.primaryDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          // Action
          Expanded(
            flex: 5,
            child: Text(
              action,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                color: const Color(0xFF374151),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
          // Org
          Expanded(
            flex: 2,
            child: Text(
              orgId.isNotEmpty ? orgId : '—',
              style: GoogleFonts.beVietnamPro(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Module
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: UpriseColors.primaryDark.withOpacity(0.07),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                module,
                style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: UpriseColors.primaryDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Severity
          Expanded(
            flex: 2,
            child: _SeverityBadge(severity),
          ),
          // Timestamp
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formattedDate,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedTime,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 11,
                    color: const Color(0xFF9AA5B4),
                  ),
                ),
              ],
            ),
          ),
        ]),
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
            child: const Icon(Icons.history_rounded, size: 40, color: Color(0xFF9AA5B4)),
          ),
          const SizedBox(height: 16),
          Text(
            'No activity logs found',
            style: GoogleFonts.beVietnamPro(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try adjusting your filters or date range.',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage  = (firstPage + maxVisible - 1).clamp(1, totalPages);
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
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total entries',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          Row(children: [
            _PageButton(
              icon: Icons.chevron_left_rounded,
              enabled: _currentPage > 1,
              onTap: () => setState(() => _currentPage--),
            ),
            const SizedBox(width: 4),
            ...pages.map((p) => _PageNumButton(
                  page: p,
                  isActive: p == _currentPage,
                  onTap: () => setState(() => _currentPage = p),
                )),
            if (lastPage < totalPages) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('…',
                    style: GoogleFonts.beVietnamPro(
                        color: const Color(0xFF64748B), fontSize: 12)),
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
          ]),
        ],
      ),
    );
  }

  // ── Log detail dialog ─────────────────────────────────────────────
  void _showLogDetailDialog({
    required String user,
    required String action,
    required String module,
    required String severity,
    required String orgId,
    required DateTime? timestamp,
    required Map<String, dynamic> data,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
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
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Activity Log Detail',
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          module,
                          style: GoogleFonts.beVietnamPro(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _detailItem('User', user, Icons.person_outline_rounded)),
                        const SizedBox(width: 16),
                        Expanded(child: _detailItem('Module', module, Icons.apps_rounded)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _detailItem('Action', action, Icons.bolt_rounded),
                    const SizedBox(height: 14),
                    Row(children: [
                      Expanded(child: _detailItem(
                        'Severity',
                        severity.toUpperCase(),
                        Icons.flag_outlined,
                        valueWidget: _SeverityBadge(severity),
                      )),
                      const SizedBox(width: 16),
                      Expanded(child: _detailItem('Org ID', orgId.isNotEmpty ? orgId : '—', Icons.business_outlined)),
                    ]),
                    if (timestamp != null) ...[
                      const SizedBox(height: 14),
                      _detailItem(
                        'Timestamp',
                        '${DateFormat('MMM dd, yyyy').format(timestamp)}  •  ${DateFormat('hh:mm:ss a').format(timestamp)}',
                        Icons.access_time_rounded,
                      ),
                    ],
                    if (data['ipAddress'] != null) ...[
                      const SizedBox(height: 14),
                      _detailItem('IP Address', data['ipAddress'].toString(), Icons.router_outlined),
                    ],
                  ],
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: UpriseColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    child: Text('Close',
                        style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value, IconData icon, {Widget? valueWidget}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 13, color: const Color(0xFF9AA5B4)),
          const SizedBox(width: 5),
          Text(label,
              style: GoogleFonts.beVietnamPro(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF64748B),
                  letterSpacing: 0.4)),
        ]),
        const SizedBox(height: 4),
        valueWidget ??
            Text(
              value,
              style: GoogleFonts.beVietnamPro(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF1A202C),
              ),
            ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────
  String _extractOrgId(Map<String, dynamic> data) {
    return (data['orgId'] ??
            (data['details'] is Map ? data['details']['orgId'] : null) ??
            '')
        .toString();
  }

  bool _matchesModule(String selected, String value) {
    final a = value.toLowerCase().replaceAll('_', ' ').trim();
    final b = selected.toLowerCase().trim();
    return a == b || a.contains(b) || b.contains(a);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stat card
// ─────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, subtitle;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
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
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A202C))),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: GoogleFonts.beVietnamPro(
                        fontSize: 10,
                        color: const Color(0xFF9AA5B4))),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter dropdown
// ─────────────────────────────────────────────────────────────────────────────
class _FilterDropdown extends StatelessWidget {
  final String value, hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({
    required this.value,
    required this.items,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
          items: items
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Text(s, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Export button
// ─────────────────────────────────────────────────────────────────────────────
class _ExportLogsButton extends StatelessWidget {
  const _ExportLogsButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E6EA)),
      ),
      child: PopupMenuButton<String>(
        onSelected: (choice) => _doExport(context, choice),
        itemBuilder: (_) => [
          _item('csv',  Icons.table_chart_rounded,  'Export as CSV'),
          _item('json', Icons.data_object_rounded,  'Export as JSON'),
        ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            const Icon(Icons.download_rounded, size: 16, color: Color(0xFF374151)),
            const SizedBox(width: 6),
            Text('Export',
                style: GoogleFonts.beVietnamPro(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF374151))),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF9AA5B4)),
          ]),
        ),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.beVietnamPro(fontSize: 13)),
      ]),
    );
  }

  Future<void> _doExport(BuildContext context, String format) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('activity_logs')
          .orderBy('timestamp', descending: true)
          .get();

      if (snap.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No data to export.'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        return;
      }

      String content, fileName;
      final now = DateTime.now().toString().substring(0, 10);

      if (format == 'csv') {
        final buf = StringBuffer();
        buf.writeln('User,Action,Module,Severity,Timestamp,IP Address,Org ID');
        for (final doc in snap.docs) {
          final d = doc.data();
          dynamic tsField = d['timestamp'];
          String tsStr = '';
          if (tsField is Timestamp) tsStr = tsField.toDate().toIso8601String();

          String esc(String s) => '"${s.replaceAll('"', '""')}"';
          final orgId = (d['orgId'] ??
                  (d['details'] is Map ? d['details']['orgId'] : '') ??
                  '')
              .toString();
          buf.writeln([
            esc(d['user']      ?? ''),
            esc(d['action']    ?? ''),
            esc(d['module']    ?? ''),
            esc(d['severity']  ?? ''),
            esc(tsStr),
            esc(d['ipAddress'] ?? ''),
            esc(orgId),
          ].join(','));
        }
        content  = buf.toString();
        fileName = 'activity_logs_$now.csv';
      } else {
        final list = snap.docs.map((doc) {
          final d = doc.data();
          dynamic tsField = d['timestamp'];
          String tsStr = '';
          if (tsField is Timestamp) tsStr = tsField.toDate().toIso8601String();
          return {
            'id':        doc.id,
            'user':      d['user']      ?? '',
            'action':    d['action']    ?? '',
            'module':    d['module']    ?? '',
            'severity':  d['severity']  ?? '',
            'timestamp': tsStr,
            'ipAddress': d['ipAddress'] ?? '',
            'orgId':     d['orgId']     ?? '',
          };
        }).toList();
        content  = const JsonEncoder.withIndent('  ').convert(list);
        fileName = 'activity_logs_$now.json';
      }

      if (kIsWeb) {
        await Share.share(content, subject: fileName);
      } else {
        final file = File('${Directory.systemTemp.path}/$fileName');
        await file.writeAsString(content);
        await Share.shareXFiles([XFile(file.path)], subject: fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: UpriseColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// User avatar
// ─────────────────────────────────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final String name;
  const _UserAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final parts    = name.trim().split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : (name.isNotEmpty ? name[0].toUpperCase() : '?');
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: UpriseColors.primaryDark.withOpacity(0.1),
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

// ─────────────────────────────────────────────────────────────────────────────
// Pagination widgets
// ─────────────────────────────────────────────────────────────────────────────
class _PageButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  const _PageButton({required this.icon, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 20,
            color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB)),
      ),
    );
  }
}

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumButton({required this.page, required this.isActive, required this.onTap});

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