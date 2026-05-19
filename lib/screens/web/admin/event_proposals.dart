import 'dart:io';
import 'dart:typed_data';  // 👈 ADD THIS FOR Uint8List
import 'dart:convert';      // 👈 FOR base64Decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/activity_logger.dart' as activity_log;
import 'package:share_plus/share_plus.dart';
import 'dart:html' as html;  // 👈 OK lang to, ignore ang warning

class EventProposals extends StatefulWidget {
  const EventProposals({super.key});

  @override
  State<EventProposals> createState() => _EventProposalsState();
}

class _EventProposalsState extends State<EventProposals> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  // Colors
  final Color primaryDark = const Color(0xFFB45309);
  final Color primaryLight = const Color(0xFFD97706);
  final Color lightGray = const Color(0xFFF9FAFB);
  final Color mediumGray = const Color(0xFFE5E7EB);
  final Color darkGray = const Color(0xFF6B7280);
  final Color charcoal = const Color(0xFF111827);
  final Color success = const Color(0xFF10B981);
  final Color warning = const Color(0xFFF59E0B);
  final Color error = const Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGray,
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: mediumGray)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Event Proposals',
                style: GoogleFonts.beVietnamPro(fontSize: 24, fontWeight: FontWeight.bold, color: charcoal)),
            const SizedBox(height: 4),
            Text('Manage and review pending event applications from CICT student organizations.',
                style: GoogleFonts.beVietnamPro(fontSize: 14, color: darkGray)),
          ]),
        ],
      ),
    );
  }

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
            _statCard('TOTAL PROPOSALS', '$total', primaryDark),
            const SizedBox(width: 16),
            _statCard('PENDING', '$pending', warning),
            const SizedBox(width: 16),
            _statCard('APPROVED', '$approved', success),
            const SizedBox(width: 16),
            _statCard('REJECTED', '$rejected', error),
            const SizedBox(width: 16),
            _statCard('ARCHIVED', '$archived', darkGray),
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryDark, width: 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: darkGray, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

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
                  hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: darkGray),
                  prefixIcon: Icon(Icons.search, size: 18, color: darkGray),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: mediumGray),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: mediumGray),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: primaryDark, width: 1),
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
                style: GoogleFonts.beVietnamPro(fontSize: 13, color: charcoal),
                icon: Icon(Icons.arrow_drop_down, color: darkGray),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: _exportToCSV,
            icon: const Icon(Icons.download, size: 16),
            label: const Text('Export'),
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryDark,
              side: BorderSide(color: mediumGray),
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
      case 'Pending': return warning;
      case 'Approved': return success;
      case 'Rejected': return error;
      case 'Archived': return darkGray;
      default: return primaryDark;
    }
  }

  Widget _buildTable() {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: primaryDark, width: 1),
    ),
    child: Column(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: lightGray,
          border: Border(bottom: BorderSide(color: mediumGray)),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
        ),
        child: Row(children: [
          Expanded(flex: 3, child: Text('EVENT TITLE', style: _headerStyle())),
          Expanded(flex: 2, child: Text('ORGANIZATION', style: _headerStyle())),
          Expanded(flex: 1, child: Text('DATE', style: _headerStyle())),
          Expanded(flex: 1, child: Text('STATUS', style: _headerStyle())),
          Expanded(flex: 1, child: Text('ACTIONS', style: _headerStyle())),
        ]),
      ),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          // 👇 REMOVE orderBy MUNA PARA MAKITA LAHAT
          stream: FirebaseFirestore.instance
              .collection('event_proposals')
              .snapshots(),  // 👈 TANGGALIN MUNA ANG .orderBy
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryDark));
            }
            if (snap.hasError) {
              print('❌ Error: ${snap.error}');
              return Center(child: Text('Error: ${snap.error}', style: TextStyle(color: error)));
            }
            
            var docs = snap.data!.docs;
            print('📊 Total proposals in Firebase: ${docs.length}');  // 👈 CHECK ITO
            
            if (_statusFilter != 'All') {
              docs = docs.where((d) => (d.data() as Map)['status'] == _statusFilter.toLowerCase()).toList();
            }
            final term = _searchController.text.trim().toLowerCase();
            if (term.isNotEmpty) {
              docs = docs.where((d) {
                final data = d.data() as Map;
                final title = (data['title'] ?? '').toString().toLowerCase();
                final org = (data['orgName'] ?? '').toString().toLowerCase();
                return title.contains(term) || org.contains(term);
              }).toList();
            }
            
            print('📊 After filter: ${docs.length} proposals');
            
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
                    print('📄 Showing: ${data['title']} - ${data['orgName']}');  // 👈 CHECK ITO
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
      fontSize: 11, fontWeight: FontWeight.w700, color: darkGray, letterSpacing: 0.5);

  Widget _buildRow(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'pending';
    final statusColor = status == 'approved'
        ? success
        : status == 'rejected'
            ? error
            : status == 'archived'
                ? darkGray
                : warning;
    final statusLabel = status.toUpperCase();
    final dateStr = _formatDate(data['date']);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: mediumGray.withOpacity(0.5)))),
      child: Row(children: [
        Expanded(
          flex: 3,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(data['title'] ?? 'Untitled',
                style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600, color: charcoal)),
            const SizedBox(height: 2),
            Text(data['category'] ?? 'No category', 
                style: GoogleFonts.beVietnamPro(fontSize: 11, color: darkGray)),
          ]),
        ),
        Expanded(flex: 2, child: Text(data['orgName'] ?? 'Unknown', style: GoogleFonts.beVietnamPro(fontSize: 13))),
        Expanded(flex: 1, child: Text(dateStr, style: GoogleFonts.beVietnamPro(fontSize: 13, color: darkGray))),
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
                icon: Icon(Icons.visibility_outlined, size: 18, color: darkGray),
                onPressed: () => _showViewDialog(data, docId),
                tooltip: 'View'),
            if (status != 'approved' && status != 'rejected' && status != 'archived')
              IconButton(
                  icon: Icon(Icons.check_circle_outline, size: 18, color: success),
                  onPressed: () => _setStatus(docId, 'approved'),
                  tooltip: 'Approve'),
            if (status != 'approved' && status != 'rejected' && status != 'archived')
              IconButton(
                  icon: Icon(Icons.cancel_outlined, size: 18, color: error),
                  onPressed: () => _setStatus(docId, 'rejected'),
                  tooltip: 'Reject'),
            if (status != 'archived')
              IconButton(
                  icon: Icon(Icons.archive_outlined, size: 18, color: darkGray),
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
      Icon(Icons.event_busy, size: 64, color: mediumGray),
      const SizedBox(height: 16),
      Text('No proposals found', style: GoogleFonts.beVietnamPro(color: darkGray, fontSize: 15)),
    ]));
  }

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
        border: Border(top: BorderSide(color: mediumGray)),
        color: lightGray,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total proposals',
            style: GoogleFonts.beVietnamPro(fontSize: 13, color: darkGray)),
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, size: 20),
            color: _currentPage > 1 ? charcoal : mediumGray,
            onPressed: _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          ...pages.map((page) => GestureDetector(
                onTap: () => setState(() => _currentPage = page),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: page == _currentPage ? primaryDark : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('$page',
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 12,
                        color: page == _currentPage ? Colors.white : charcoal,
                        fontWeight: page == _currentPage ? FontWeight.w600 : FontWeight.normal,
                      )),
                ),
              )),
          if (lastPage < totalPages) ...[
            Text('...', style: TextStyle(color: darkGray)),
            GestureDetector(
              onTap: () => setState(() => _currentPage = totalPages),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text('$totalPages',
                    style: GoogleFonts.beVietnamPro(fontSize: 12, color: charcoal)),
              ),
            ),
          ],
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            color: _currentPage < totalPages ? charcoal : mediumGray,
            onPressed: _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ]),
      ]),
    );
  }

  Future<void> _setStatus(String docId, String newStatus) async {
    String title = '';
    try {
      final docSnap = await FirebaseFirestore.instance.collection('event_proposals').doc(docId).get();
      title = docSnap.data()?['title'] ?? 'Unknown event';
    } catch (e) {
      title = 'Unknown event';
    }

    await FirebaseFirestore.instance.collection('event_proposals').doc(docId).update({
      'status': newStatus,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': FirebaseAuth.instance.currentUser?.uid ?? '',
    });

    await activity_log.ActivityLogger.log(
      action: '${newStatus.toUpperCase()} proposal: $title',
      module: 'Event Management',
      severity: newStatus == 'rejected' ? 'warning' : 'info',
      details: {'proposalId': docId},
    );

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Proposal ${newStatus.toUpperCase()}')));
  }

  void _showViewDialog(Map<String, dynamic> data, String docId) {
    final status = data['status'] ?? 'pending';
    final hasAttachment = data['attachmentBase64'] != null && data['attachmentBase64'].toString().isNotEmpty;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.event_note, color: primaryDark),
          const SizedBox(width: 8),
          Expanded(child: Text(data['title'] ?? 'Event Proposal', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.bold))),
        ]),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 500,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              _detailRow('Organization', data['orgName'] ?? '—'),
              _detailRow('Category', data['category'] ?? '—'),
              _detailRow('Audience', data['audience'] ?? 'Public'),
              _detailRow('Proposed Date', _formatDate(data['date'])),
              _detailRow('Time', data['time'] ?? '—'),
              _detailRow('Location', data['location'] ?? '—'),
              _detailRow('Description', data['description'] ?? 'No description provided.'),
              _detailRow('Submitted By', data['submittedByEmail'] ?? '—'),
              const SizedBox(height: 12),
              const Divider(),
              _detailRow('Status', status.toUpperCase(),
                  isStatus: true,
                  statusColor: status == 'approved'
                      ? success
                      : status == 'rejected'
                          ? error
                          : warning),
              _detailRow('Submitted', _formatTimestamp(data['createdAt'])),
              if (data['reviewedAt'] != null) _detailRow('Reviewed', _formatTimestamp(data['reviewedAt'])),
              
              if (hasAttachment) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text('Attachment', style: GoogleFonts.beVietnamPro(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: lightGray,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.insert_drive_file, size: 24, color: primaryDark),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['attachmentName'] ?? 'Attached File',
                            style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          if (data['attachmentSize'] != null)
                            Text(
                              data['attachmentSize'],
                              style: GoogleFonts.beVietnamPro(fontSize: 11, color: darkGray),
                            ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _viewAttachment(data),
                      icon: Icon(Icons.visibility, size: 16),
                      label: Text('View'),
                      style: TextButton.styleFrom(foregroundColor: primaryDark),
                    ),
                  ]),
                ),
              ],
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
              icon: Icon(Icons.check_circle, color: success),
              label: Text('Approve', style: TextStyle(color: success)),
            ),
            TextButton.icon(
              onPressed: () async {
                await _setStatus(docId, 'rejected');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.cancel, color: error),
              label: Text('Reject', style: TextStyle(color: error)),
            ),
          ],
          if (status != 'archived')
            TextButton.icon(
              onPressed: () async {
                await _setStatus(docId, 'archived');
                Navigator.pop(ctx);
              },
              icon: Icon(Icons.archive, color: darkGray),
              label: Text('Archive', style: TextStyle(color: darkGray)),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: primaryDark),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 👇 FIXED: Ito ang may error dati
  void _viewAttachment(Map<String, dynamic> data) {
    final String base64String = data['attachmentBase64'];
    final String fileName = data['attachmentName'] ?? 'document';
    final String fileExtension = fileName.split('.').last.toLowerCase();
    
    try {
      final Uint8List fileBytes = base64Decode(base64String);  // 👈 FIXED: base64Decode hindi base64.decode
      
      String contentType;
      switch (fileExtension) {
        case 'pdf':
          contentType = 'application/pdf';
          break;
        case 'doc':
          contentType = 'application/msword';
          break;
        case 'docx':
          contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
          break;
        case 'txt':
          contentType = 'text/plain';
          break;
        case 'jpg':
        case 'jpeg':
          contentType = 'image/jpeg';
          break;
        case 'png':
          contentType = 'image/png';
          break;
        default:
          contentType = 'application/octet-stream';
      }
      
      final blob = html.Blob([fileBytes], contentType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Open File: $fileName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.insert_drive_file, size: 48, color: primaryDark),
              const SizedBox(height: 16),
              Text('File size: ${data['attachmentSize'] ?? 'Unknown'}'),
              const SizedBox(height: 8),
              Text('Extension: $fileExtension', style: GoogleFonts.beVietnamPro(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                final anchor = html.AnchorElement(href: url)
                  ..setAttribute('download', fileName)
                  ..click();
                html.Url.revokeObjectUrl(url);
                Navigator.pop(ctx);
              },
              child: const Text('Download'),
            ),
            TextButton(
              onPressed: () {
                html.window.open(url, '_blank');
                html.Url.revokeObjectUrl(url);
                Navigator.pop(ctx);
              },
              child: const Text('View'),
            ),
            TextButton(
              onPressed: () {
                html.Url.revokeObjectUrl(url);
                Navigator.pop(ctx);
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e'), backgroundColor: error),
      );
    }
  }

  Widget _detailRow(String label, String value, {bool isStatus = false, Color? statusColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 120,
            child: Text('$label:',
                style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: darkGray))),
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

  String _formatDate(dynamic dateField) {
    if (dateField == null) return 'TBD';
    if (dateField is Timestamp) {
      final date = dateField.toDate();
      return '${date.month}/${date.day}/${date.year}';
    }
    return dateField.toString();
  }

  String _formatTimestamp(dynamic ts) {
    if (ts == null) return '—';
    if (ts is Timestamp) {
      final date = ts.toDate();
      return '${date.month}/${date.day}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    return ts.toString();
  }

  Future<void> _exportToCSV() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('event_proposals').get();
      final lines = <String>['Title,Organization,Category,Date,Status,Description'];
      for (var doc in snap.docs) {
        final d = doc.data();
        lines.add([
          d['title'] ?? '',
          d['orgName'] ?? '',
          d['category'] ?? '',
          _formatDate(d['date']),
          d['status'] ?? 'pending',
          (d['description'] ?? '').replaceAll(',', ';'),
        ].map((v) => '"$v"').join(','));
      }
      final file = File('${Directory.systemTemp.path}/event_proposals.csv');
      await file.writeAsString(lines.join('\n'));
      await Share.shareXFiles([XFile(file.path)], text: 'Event Proposals Export');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: error));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}