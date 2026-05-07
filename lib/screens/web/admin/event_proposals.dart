import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../theme/app_theme.dart';

class EventProposals extends StatefulWidget {
  const EventProposals({super.key});

  @override
  _EventProposalsState createState() => _EventProposalsState();
}

class _EventProposalsState extends State<EventProposals> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All'; // All, Pending, Approved, Rejected, Archived
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: UpriseColors.lightGray,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildStatsRow(),        // now a StreamBuilder – real‑time
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Event Proposals',
                style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: UpriseColors.charcoal)),
            const SizedBox(height: 4),
            Text('Manage and review pending event applications from CICT student organizations.',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: UpriseColors.darkGray)),
          ]),
        ],
      ),
    );
  }

  // ---------- REAL‑TIME STATS (StreamBuilder) ----------
  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('event_proposals').snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0, archived = 0;
        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          total = docs.length;
          for (var doc in docs) {
            final status = (doc.data() as Map)['status'] ?? 'pending';
            switch (status) {
              case 'pending': pending++; break;
              case 'approved': approved++; break;
              case 'rejected': rejected++; break;
              case 'archived': archived++; break;
            }
          }
        }
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(children: [
            _statCard('TOTAL PROPOSALS', '$total', UpriseColors.primaryDark),
            const SizedBox(width: 16),
            _statCard('PENDING', '$pending', UpriseColors.warning),
            const SizedBox(width: 16),
            _statCard('APPROVED', '$approved', UpriseColors.success),
            const SizedBox(width: 16),
            _statCard('REJECTED', '$rejected', UpriseColors.error),
            const SizedBox(width: 16),
            _statCard('ARCHIVED', '$archived', UpriseColors.darkGray),
          ]),
        );
      },
    );
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  // ---------- TOOLBAR ----------
  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search events...',
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray),
                  prefixIcon: Icon(Icons.search, size: 18, color: UpriseColors.darkGray),
                  filled: true,
                  fillColor: UpriseColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: UpriseColors.mediumGray),
                  ),
                  enabledBorder: OutlineInputBorder(
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
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: UpriseColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: UpriseColors.mediumGray),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _statusFilter,
                items: ['All', 'Pending', 'Approved', 'Rejected', 'Archived']
                    .map((status) => DropdownMenuItem(
                          value: status,
                          child: Row(children: [
                            Icon(_statusIcon(status), size: 16, color: _statusColor(status)),
                            const SizedBox(width: 8),
                            Text(status, style: GoogleFonts.beVietnamPro(fontSize: 13)),
                          ]),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _statusFilter = value!;
                  _currentPage = 1;
                }),
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.charcoal),
                icon: Icon(Icons.arrow_drop_down, color: UpriseColors.darkGray),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _exportToCSV,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: UpriseColors.primaryDark,
              side: BorderSide(color: UpriseColors.mediumGray),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'Pending': return Icons.pending_actions;
      case 'Approved': return Icons.check_circle;
      case 'Rejected': return Icons.cancel;
      case 'Archived': return Icons.archive;
      default: return Icons.list;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending': return UpriseColors.warning;
      case 'Approved': return UpriseColors.success;
      case 'Rejected': return UpriseColors.error;
      case 'Archived': return UpriseColors.darkGray;
      default: return UpriseColors.primaryDark;
    }
  }

  // ---------- TABLE ----------
  Widget _buildTable() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: UpriseColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: UpriseColors.mediumGray),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: UpriseColors.lightGray,
            border: Border(bottom: BorderSide(color: UpriseColors.mediumGray)),
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
          ),
          child: Row(children: [
            Expanded(flex: 3, child: Text('EVENT TITLE & ACADEMIC YEAR', style: _headerStyle())),
            Expanded(flex: 2, child: Text('ORGANIZATION', style: _headerStyle())),
            Expanded(flex: 1, child: Text('DATE', style: _headerStyle())),
            Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
            Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
          ]),
        ),
        // Body
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('event_proposals')
                .orderBy('createdAt', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: UpriseColors.primaryDark));
              }
              if (snap.hasError) {
                return Center(child: Text('Error: ${snap.error}', style: TextStyle(color: UpriseColors.error)));
              }
              var docs = snap.data!.docs;
              // Filter by status
              if (_statusFilter != 'All') {
                docs = docs.where((d) => (d.data() as Map)['status'] == _statusFilter.toLowerCase()).toList();
              }
              // Search by title or org name
              final term = _searchController.text.trim().toLowerCase();
              if (term.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final org = (data['orgName'] ?? '').toString().toLowerCase();
                  return title.contains(term) || org.contains(term);
                }).toList();
              }
              if (docs.isEmpty) return _emptyState();

              final totalPages = (docs.length / _pageSize).ceil();
              final safePage = _currentPage.clamp(1, totalPages);
              final start = (safePage - 1) * _pageSize;
              final end = (start + _pageSize).clamp(0, docs.length);
              final pageDocs = docs.sublist(start, end);

              return Column(children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: pageDocs.length,
                    itemBuilder: (_, i) {
                      final data = pageDocs[i].data() as Map<String, dynamic>;
                      final docId = pageDocs[i].id;
                      return _buildRow(data, docId);
                    },
                  ),
                ),
                _buildFooter(docs.length, totalPages, start, end),
              ]);
            },
          ),
        ),
      ]),
    );
  }

  TextStyle _headerStyle() => GoogleFonts.beVietnamPro(
      fontSize: 11, fontWeight: FontWeight.w700, color: UpriseColors.darkGray, letterSpacing: 0.5);

  Widget _buildRow(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'pending';
    final statusColor = status == 'approved'
        ? UpriseColors.success
        : status == 'rejected'
            ? UpriseColors.error
            : status == 'archived'
                ? UpriseColors.darkGray
                : UpriseColors.warning;
    final statusLabel = status.toUpperCase();
    final dateStr = _formatDate(data['date']);
    final academicYear = data['academicYear'] ?? '1ST SEM 2024-2025';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: UpriseColors.mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'] ?? 'Untitled',
                style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: UpriseColors.charcoal)),
            const SizedBox(height: 2),
            Text(academicYear, style: GoogleFonts.beVietnamPro(fontSize: 11, color: UpriseColors.darkGray)),
          ]),
        ),
        Expanded(flex: 2, child: Text(data['orgName'] ?? 'Unknown', style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(flex: 1, child: Text(dateStr, style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray))),
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text(statusLabel,
                textAlign: TextAlign.center,
                style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
          ),
        ),
        Expanded(
          flex: 1,
          child: Row(children: [
            IconButton(
                icon: Icon(Icons.visibility_outlined, size: 18, color: UpriseColors.darkGray),
                onPressed: () => _showViewDialog(data, docId),
                tooltip: 'View'),
            if (status != 'approved' && status != 'rejected' && status != 'archived')
              IconButton(
                  icon: Icon(Icons.check_circle_outline, size: 18, color: UpriseColors.success),
                  onPressed: () => _setStatus(docId, 'approved'),
                  tooltip: 'Approve'),
            if (status != 'approved' && status != 'rejected' && status != 'archived')
              IconButton(
                  icon: Icon(Icons.cancel_outlined, size: 18, color: UpriseColors.error),
                  onPressed: () => _setStatus(docId, 'rejected'),
                  tooltip: 'Reject'),
            if (status != 'archived')
              IconButton(
                  icon: Icon(Icons.archive_outlined, size: 18, color: UpriseColors.darkGray),
                  onPressed: () => _setStatus(docId, 'archived'),
                  tooltip: 'Archive'),
          ]),
        ),
      ]),
    );
  }

  Widget _emptyState() {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.event_busy, size: 64, color: UpriseColors.mediumGray),
      const SizedBox(height: 16),
      Text('No proposals found', style: GoogleFonts.beVietnamPro(color: UpriseColors.darkGray, fontSize: 15)),
    ]));
  }

  // ---------- FIXED PAGINATION (sliding window) ----------
  Widget _buildFooter(int total, int totalPages, int start, int end) {
    const int maxVisible = 5;
    int firstPage = (_currentPage - maxVisible ~/ 2).clamp(1, totalPages);
    int lastPage = (firstPage + maxVisible - 1).clamp(1, totalPages);
    if (lastPage - firstPage + 1 < maxVisible && firstPage > 1) {
      firstPage = (lastPage - maxVisible + 1).clamp(1, totalPages);
    }
    final pages = List.generate(lastPage - firstPage + 1, (i) => firstPage + i);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: UpriseColors.mediumGray)),
        color: UpriseColors.lightGray,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total proposals',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: UpriseColors.darkGray)),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            color: _currentPage > 1 ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          ...pages.map((page) => GestureDetector(
                onTap: () => setState(() => _currentPage = page),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: page == _currentPage ? UpriseColors.primaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$page',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: page == _currentPage ? Colors.white : UpriseColors.charcoal,
                        fontWeight: page == _currentPage ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              )),
          if (lastPage < totalPages) ...[
            Text('...', style: TextStyle(color: UpriseColors.darkGray)),
            GestureDetector(
              onTap: () => setState(() => _currentPage = totalPages),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('$totalPages',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: UpriseColors.charcoal)),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            color: _currentPage < totalPages ? UpriseColors.charcoal : UpriseColors.mediumGray,
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ]),
      ]),
    );
  }

  Future<void> _setStatus(String docId, String newStatus) async {
    await FirebaseFirestore.instance.collection('event_proposals').doc(docId).update({'status': newStatus});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proposal ${newStatus.toUpperCase()}')));
    // Stats update automatically because of StreamBuilder
  }

  // ---------- VIEW DIALOG ----------
  void _showViewDialog(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'pending';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.event_note, color: UpriseColors.primaryDark),
          const SizedBox(width: 8),
          Expanded(child: Text(data['title'] ?? 'Event Proposal', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold))),
        ]),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 450,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _detailRow('Organization', data['orgName'] ?? '—'),
              _detailRow('Academic Year', data['academicYear'] ?? '—'),
              _detailRow('Proposed Date', _formatDate(data['date'])),
              _detailRow('Estimated Budget', data['budget'] != null ? '₱${data['budget']}' : '—'),
              _detailRow('Description', data['description'] ?? 'No description provided.'),
              if (data['goal'] != null && data['goal'].toString().isNotEmpty) _detailRow('Goal', data['goal']),
              const SizedBox(height: 12),
              const Divider(),
              _detailRow('Status', status.toUpperCase(),
                  isStatus: true,
                  statusColor: status == 'approved'
                      ? UpriseColors.success
                      : status == 'rejected'
                          ? UpriseColors.error
                          : UpriseColors.warning),
              _detailRow('Submitted', _formatTimestamp(data['createdAt'])),
              if (data['reviewedAt'] != null) _detailRow('Reviewed', _formatTimestamp(data['reviewedAt'])),
            ]),
          ),
        ),
        actions: [
          if (status == 'pending') ...[
            TextButton.icon(
              onPressed: () async {
                await _setStatus(docId, 'approved');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.check_circle, color: UpriseColors.success),
              label: Text('Approve', style: TextStyle(color: UpriseColors.success)),
            ),
            TextButton.icon(
              onPressed: () async {
                await _setStatus(docId, 'rejected');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.cancel, color: UpriseColors.error),
              label: Text('Reject', style: TextStyle(color: UpriseColors.error)),
            ),
          ],
          if (status != 'archived')
            TextButton.icon(
              onPressed: () async {
                await _setStatus(docId, 'archived');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.archive, color: UpriseColors.darkGray),
              label: Text('Archive', style: TextStyle(color: UpriseColors.darkGray)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: UpriseColors.primaryDark),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 120,
            child: Text('$label:',
                style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: UpriseColors.darkGray))),
        Expanded(
          child: isStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                      color: statusColor?.withOpacity(0.1) ?? Colors.transparent, borderRadius: BorderRadius.circular(4)),
                  child: Text(value,
                      style: GoogleFonts.beVietnamPro(fontSize: 12, color: statusColor, fontWeight: FontWeight.w600)),
                )
              : Text(value, style: GoogleFonts.beVietnamPro(fontSize: 12)),
        ),
      ]),
    );
  }

  // ---------- SAFE DATE FORMATTING ----------
  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'TBD';
    if (dateField is Timestamp) {
      final date = dateField.toDate();
      return '${date.month}/${date.day}/${date.year}';
    }
    return dateField.toString(); // fallback for string dates
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      final date = ts.toDate();
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return ts.toString();
  }

  // ---------- EXPORT ----------
  Future<void> _exportToCSV() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('event_proposals').get();
      final lines = <String>['Title,Organization,Academic Year,Date,Status,Budget,Description'];
      for (var doc in snap.docs) {
        final d = doc.data();
        lines.add([
          d['title'] ?? '',
          d['orgName'] ?? '',
          d['academicYear'] ?? '',
          _formatDate(d['date']),
          d['status'] ?? 'pending',
          d['budget'] ?? '',
          (d['description'] ?? '').replaceAll(',', ';'),
        ].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/event_proposals.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'Event Proposals Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: UpriseColors.error));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}