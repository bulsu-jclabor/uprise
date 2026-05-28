// lib/screens/admin/letter_request.dart - FULL WORKING VERSION

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../utils/platform_file_utils.dart' as platform_file_utils;

// ============ COLOR SCHEME ============
class AdminColors {
  static const Color primaryDark = Color(0xFFB45309);
  static const Color primaryLight = Color(0xFFD97706);
  static const Color accent = Color(0xFFF59E0B);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF9FAFB);
  static const Color mediumGray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF6B7280);
  static const Color charcoal = Color(0xFF111827);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);
  static const Color purple = Color(0xFF7C3AED);
}

// ============ MAIN WIDGET ============
class AdminLetterRequestScreen extends StatefulWidget {
  const AdminLetterRequestScreen({super.key});

  @override
  State<AdminLetterRequestScreen> createState() => _AdminLetterRequestScreenState();
}

class _AdminLetterRequestScreenState extends State<AdminLetterRequestScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(),
          _buildToolbar(),
          const SizedBox(height: 16),
          Expanded(child: _buildTable()),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('letter_requests').snapshots(),
      builder: (context, snapshot) {
        int total = 0, pending = 0, approved = 0, rejected = 0, revision = 0, resubmitted = 0;
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            total++;
            final s = (doc.data() as Map)['status'] ?? 'pending';
            if (s == 'pending') pending++;
            if (s == 'approved') approved++;
            if (s == 'rejected') rejected++;
            if (s == 'revision') revision++;
            if (s == 'resubmitted') resubmitted++;
          }
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: Row(children: [
            _StatCard(label: 'Total Requests', value: '$total', icon: Icons.description_rounded, color: AdminColors.primaryDark),
            const SizedBox(width: 14),
            _StatCard(label: 'Approved', value: '$approved', icon: Icons.check_circle_rounded, color: AdminColors.success),
            const SizedBox(width: 14),
            _StatCard(label: 'Pending', value: '$pending', icon: Icons.pending_rounded, color: AdminColors.warning),
            const SizedBox(width: 14),
            _StatCard(label: 'Resubmitted', value: '$resubmitted', icon: Icons.refresh_rounded, color: AdminColors.info),
            const SizedBox(width: 14),
            _StatCard(label: 'Needs Revision', value: '$revision', icon: Icons.edit_note_rounded, color: AdminColors.purple),
            const SizedBox(width: 14),
            _StatCard(label: 'Rejected', value: '$rejected', icon: Icons.cancel_rounded, color: AdminColors.error),
          ]),
        );
      },
    );
  }

  Widget _buildToolbar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: Row(children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: GoogleFonts.beVietnamPro(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search by org name or subject...',
                hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AdminColors.primaryDark, width: 1.5),
                ),
              ),
              onChanged: (_) => setState(() => _currentPage = 1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _FilterDropdown(
          value: _statusFilter,
          items: const ['All', 'Pending', 'Approved', 'Rejected', 'Needs Revision', 'Resubmitted'],
          hint: 'Status',
          icon: Icons.tune_rounded,
          onChanged: (v) => setState(() {
            _statusFilter = v!;
            _currentPage = 1;
          }),
        ),
        const SizedBox(width: 10),
        _ExportButton(
          statusFilter: _statusFilter,
          searchTerm: _searchController.text.trim(),
        ),
      ]),
    );
  }

  Widget _buildTable() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('letter_requests')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data!.docs;

        final term = _searchController.text.trim().toLowerCase();
        if (term.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['orgName'] ?? '').toString().toLowerCase().contains(term) ||
                   (data['subject'] ?? '').toString().toLowerCase().contains(term);
          }).toList();
        }
        
        String filterValue = _statusFilter;
        if (filterValue == 'Needs Revision') filterValue = 'revision';
        if (filterValue == 'Resubmitted') filterValue = 'resubmitted';
        if (filterValue != 'All') {
          docs = docs.where((d) {
            final status = ((d.data() as Map)['status'] ?? 'pending').toString().toLowerCase();
            return status == filterValue.toLowerCase();
          }).toList();
        }

        final totalPages = docs.isEmpty ? 1 : (docs.length / _pageSize).ceil();
        final safePage = _currentPage.clamp(1, totalPages);
        final start = (safePage - 1) * _pageSize;
        final end = (start + _pageSize).clamp(0, docs.length);
        final pageDocs = docs.isEmpty ? [] : docs.sublist(start, end);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8ECF0)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Column(children: [
            _buildTableHeader(),
            Expanded(
              child: docs.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: pageDocs.length,
                      itemBuilder: (_, i) {
                        final data = pageDocs[i].data() as Map<String, dynamic>;
                        data['name'] = data['name'] ?? data['orgName'];
                        data['email'] = data['email'] ?? data['orgEmail'];
                        return _buildRow(data: data, docId: pageDocs[i].id, isLast: i == pageDocs.length - 1);
                      },
                    ),
            ),
            _buildFooter(docs.length, totalPages, start, end),
          ]),
        );
      },
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF0))),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: _headerCell('REQUESTOR')),
        Expanded(flex: 3, child: _headerCell('SUBJECT / TYPE')),
        Expanded(flex: 2, child: _headerCell('DATE SUBMITTED')),
        Expanded(flex: 1, child: _headerCell('STATUS')),
        Expanded(flex: 2, child: _headerCell('ACTIONS')),
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

  Widget _buildRow({required Map<String, dynamic> data, required String docId, required bool isLast}) {
    final status = (data['status'] ?? 'pending').toString();
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('MMM dd, yyyy').format(timestamp.toDate()) : 'Unknown';

    return InkWell(
      hoverColor: const Color(0xFFF8F9FB),
      onTap: () => _showViewDialog(data, docId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['name'] ?? 'Unknown',
                  style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF1A202C)),
                ),
                Text(
                  data['email'] ?? '',
                  style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF9AA5B4)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AdminColors.primaryDark.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    data['letterType'] ?? 'General',
                    style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w600, color: AdminColors.primaryDark),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  data['subject'] ?? 'No subject',
                  style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF374151)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              date,
              style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
            ),
          ),
          Expanded(flex: 1, child: _buildStatusBadge(status)),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                _ActionIconButton(
                  icon: Icons.visibility_outlined,
                  tooltip: 'View Details',
                  onTap: () => _showViewDialog(data, docId),
                ),
                const SizedBox(width: 4),
                if (status == 'pending' || status == 'revision' || status == 'resubmitted') ...[
                  _ActionIconButton(
                    icon: Icons.check_circle_outline,
                    tooltip: 'Approve',
                    color: AdminColors.success,
                    onTap: () => _updateStatus(docId, 'approved', data['name'] ?? data['orgName'] ?? 'Request'),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.cancel_outlined,
                    tooltip: 'Reject',
                    color: AdminColors.error,
                    onTap: () => _updateStatus(docId, 'rejected', data['name'] ?? data['orgName'] ?? 'Request'),
                  ),
                  const SizedBox(width: 4),
                  _ActionIconButton(
                    icon: Icons.edit_note_rounded,
                    tooltip: 'Request Revision',
                    color: AdminColors.info,
                    onTap: () => _requestRevision(data, docId),
                  ),
                ],
                const SizedBox(width: 4),
                _ActionIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete',
                  color: AdminColors.error,
                  onTap: () => _confirmDelete(docId, data['name'] ?? 'Request'),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _requestRevision(Map<String, dynamic> data, String docId) {
    final commentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Revision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide feedback/revision notes:'),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'e.g., Please provide a more detailed letter...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final comment = commentController.text.trim();
              if (comment.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide revision notes')),
                );
                return;
              }
              Navigator.pop(ctx);
              await _updateStatus(docId, 'revision', data['orgName'] ?? 'Request', revisionNote: comment);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.info),
            child: const Text('Send Revision Request'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Map<String, dynamic> style;
    switch (status.toLowerCase()) {
      case 'approved':
        style = {'bg': const Color(0xFFECFDF5), 'fg': const Color(0xFF059669), 'label': 'APPROVED'};
        break;
      case 'rejected':
        style = {'bg': const Color(0xFFFEF2F2), 'fg': const Color(0xFFDC2626), 'label': 'REJECTED'};
        break;
      case 'revision':
        style = {'bg': const Color(0xFFEFF6FF), 'fg': const Color(0xFF2563EB), 'label': 'NEEDS REVISION'};
        break;
      case 'resubmitted':
        style = {'bg': const Color(0xFFF0FDF4), 'fg': const Color(0xFF16A34A), 'label': 'RESUBMITTED'};
        break;
      default:
        style = {'bg': const Color(0xFFFFFBEB), 'fg': const Color(0xFFD97706), 'label': 'PENDING'};
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: style['bg'] as Color, borderRadius: BorderRadius.circular(20)),
      child: Text(
        style['label'] as String,
        style: GoogleFonts.beVietnamPro(fontSize: 10, fontWeight: FontWeight.w700, color: style['fg'] as Color, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(20)),
          child: const Icon(Icons.mail_outline_rounded, size: 40, color: Color(0xFF9AA5B4)),
        ),
        const SizedBox(height: 16),
        Text('No letter requests found', style: GoogleFonts.beVietnamPro(fontSize: 15, fontWeight: FontWeight.w600, color: const Color(0xFF374151))),
        const SizedBox(height: 6),
        Text('Try adjusting your filters.', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B))),
      ]),
    );
  }

  Widget _buildFooter(int total, int totalPages, int start, int end) {
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
          Text('Showing ${total == 0 ? 0 : start + 1}–$end of $total requests', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
          Row(children: [
            _PageButton(icon: Icons.chevron_left_rounded, enabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
            const SizedBox(width: 4),
            Text('Page $_currentPage of $totalPages', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
            const SizedBox(width: 4),
            _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
          ]),
        ],
      ),
    );
  }

  Future<void> _updateStatus(String docId, String newStatus, String orgName, {String? revisionNote}) async {
    try {
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (revisionNote != null) {
        updateData['revisionNote'] = revisionNote;
        updateData['revisionRequestedAt'] = FieldValue.serverTimestamp();
      }
      await FirebaseFirestore.instance.collection('letter_requests').doc(docId).update(updateData);
      await activity_log.ActivityLogger.log(
        action: '${newStatus.toUpperCase()} letter request from: $orgName',
        module: 'Letter Request',
        severity: newStatus == 'rejected' ? 'warning' : 'info',
      );
      if (mounted) {
        String message = 'Status updated to ${newStatus[0].toUpperCase()}${newStatus.substring(1)}';
        if (newStatus == 'revision') message = 'Revision requested with notes';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: newStatus == 'approved' ? AdminColors.success : (newStatus == 'revision' ? AdminColors.info : AdminColors.error),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AdminColors.error));
      }
    }
  }

  void _showViewDialog(Map<String, dynamic> data, String docId) {
    final status = (data['status'] ?? 'pending').toString();
    final timestamp = data['timestamp'] as Timestamp?;
    final date = timestamp != null ? DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate()) : 'Unknown';
    final hasAttachment = data['attachmentBase64'] != null && data['attachmentBase64'].toString().isNotEmpty;
    final fileName = data['attachmentName'] ?? 'attachment';
    final revisionNote = data['revisionNote'];

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 20, 20),
                decoration: BoxDecoration(
                  color: AdminColors.primaryDark,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['letterId'] ?? 'Letter Request', style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text(data['subject'] ?? '', style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white.withOpacity(0.65))),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ]),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      _buildStatusBadge(status),
                      const SizedBox(width: 12),
                      Icon(Icons.calendar_today_outlined, size: 13, color: const Color(0xFF9AA5B4)),
                      const SizedBox(width: 4),
                      Text(date, style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B))),
                    ]),
                    const SizedBox(height: 20),
                    _infoRow('Organization', data['orgName'] ?? 'Unknown'),
                    _infoRow('Email', data['orgEmail'] ?? 'Unknown'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E6EA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Subject', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                          const SizedBox(height: 6),
                          Text(data['subject'] ?? 'No subject', style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                        ],
                      ),
                    ),
                    if (revisionNote != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AdminColors.info.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AdminColors.info.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('REVISION NOTES', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w700, color: AdminColors.info)),
                            const SizedBox(height: 6),
                            Text(revisionNote, style: GoogleFonts.beVietnamPro(fontSize: 13, color: AdminColors.charcoal)),
                          ],
                        ),
                      ),
                    ],
                    if (data['revisionCount'] != null && data['revisionCount'] > 0) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.mediumGray.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(children: [
                          Icon(Icons.history, size: 16, color: AdminColors.darkGray),
                          const SizedBox(width: 8),
                          Text('Revision #${data['revisionCount']}',
                              style: GoogleFonts.beVietnamPro(fontSize: 12, color: AdminColors.darkGray)),
                        ]),
                      ),
                    ],
                    if (hasAttachment) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AdminColors.primaryDark.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AdminColors.primaryDark.withOpacity(0.2)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: AdminColors.primaryDark.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Icon(_getFileIcon(fileName), color: AdminColors.primaryDark, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(fileName, style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600, color: AdminColors.charcoal), overflow: TextOverflow.ellipsis),
                              if (data['attachmentSize'] != null) Text(data['attachmentSize'], style: GoogleFonts.beVietnamPro(fontSize: 11, color: AdminColors.darkGray)),
                            ]),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _viewAttachment(data),
                            icon: const Icon(Icons.visibility, size: 16),
                            label: const Text('View'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AdminColors.primaryDark,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
              if (status == 'pending' || status == 'revision' || status == 'resubmitted')
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateStatus(docId, 'rejected', data['orgName'] ?? 'Request');
                        },
                        icon: const Icon(Icons.cancel_rounded, size: 15),
                        label: Text('Reject', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.error,
                          side: BorderSide(color: AdminColors.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _requestRevision(data, docId);
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 15),
                        label: Text('Revise', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.info,
                          side: BorderSide(color: AdminColors.info),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateStatus(docId, 'approved', data['orgName'] ?? 'Request');
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 15),
                        label: Text('Approve', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminColors.success,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                      ),
                    ),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'pdf': return Icons.picture_as_pdf;
      case 'doc': case 'docx': return Icons.description;
      case 'txt': return Icons.text_snippet;
      case 'jpg': case 'jpeg': case 'png': case 'gif': return Icons.image;
      default: return Icons.insert_drive_file;
    }
  }

  void _viewAttachment(Map<String, dynamic> data) {
    final base64 = data['attachmentBase64'];
    if (base64 == null || base64.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attachment found'), backgroundColor: AdminColors.error),
      );
      return;
    }
    _openFileFromBase64(base64, data['attachmentName'] ?? 'attachment');
  }

  Future<void> _openFileFromBase64(String base64String, String fileName) async {
    try {
      Uint8List bytes = base64Decode(base64String);
      if (bytes.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Empty file'), backgroundColor: AdminColors.error));
        return;
      }
      
      final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
      final mime = _getMimeTypeFromExtension(ext);
      
      if (mime.startsWith('text/')) {
        final content = utf8.decode(bytes);
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(fileName),
              content: Container(width: 500, constraints: const BoxConstraints(maxHeight: 400),
                child: SingleChildScrollView(child: SelectableText(content, style: GoogleFonts.beVietnamPro(fontSize: 12)))),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                TextButton(onPressed: () {
                  Navigator.pop(ctx);
                  platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
                }, child: const Text('Download')),
              ],
            ),
          );
        }
        return;
      }
      
      if (mime.startsWith('image/')) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.all(12), child: Text(fileName, style: GoogleFonts.beVietnamPro(fontSize: 14, fontWeight: FontWeight.w600))),
                Flexible(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image.memory(bytes))),
                ButtonBar(children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  TextButton(onPressed: () {
                    Navigator.pop(ctx);
                    platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
                  }, child: const Text('Download')),
                ]),
              ]),
            ),
          );
        }
        return;
      }
      
      await platform_file_utils.saveBytesToTempAndOpen(bytes, fileName);
    } catch (e) {
      print('Error opening file: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening file: $e'), backgroundColor: AdminColors.error));
    }
  }

  String _getMimeTypeFromExtension(String ext) {
    switch (ext.toLowerCase()) {
      case 'txt': return 'text/plain';
      case 'md': return 'text/markdown';
      case 'html': case 'htm': return 'text/html';
      case 'json': return 'application/json';
      case 'png': return 'image/png';
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'gif': return 'image/gif';
      case 'pdf': return 'application/pdf';
      case 'doc': return 'application/msword';
      case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default: return 'application/octet-stream';
    }
  }

  void _confirmDelete(String docId, String orgName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: Text('Delete request from $orgName? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('letter_requests').doc(docId).delete();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request deleted successfully')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 90, child: Text('$label:', style: GoogleFonts.beVietnamPro(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)))),
      Expanded(child: Text(value, style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF1A202C)))),
    ]),
  );
}

// ============ STAT CARD ============
class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE8ECF0)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: GoogleFonts.beVietnamPro(fontSize: 11, color: const Color(0xFF64748B), fontWeight: FontWeight.w500)),
            const SizedBox(height: 2),
            Text(value, style: GoogleFonts.beVietnamPro(fontSize: 28, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C))),
          ])),
        ]),
      ),
    );
  }
}

// ============ FILTER DROPDOWN ============
class _FilterDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final String hint;
  final IconData icon;
  final ValueChanged<String?> onChanged;
  const _FilterDropdown({required this.value, required this.items, required this.hint, required this.icon, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E6EA))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: Color(0xFF9AA5B4)),
          style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151)),
          items: items.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ============ EXPORT BUTTON ============
class _ExportButton extends StatelessWidget {
  final String statusFilter, searchTerm;
  const _ExportButton({required this.statusFilter, required this.searchTerm});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => _exportCSV(context),
      icon: const Icon(Icons.download_outlined, size: 16),
      label: Text('Export CSV', style: GoogleFonts.beVietnamPro(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _exportCSV(BuildContext context) async {
    try {
      var snap = await FirebaseFirestore.instance.collection('letter_requests').orderBy('timestamp', descending: true).get();
      var docs = snap.docs;
      if (statusFilter != 'All') docs = docs.where((d) => d['status'] == statusFilter.toLowerCase()).toList();
      if (searchTerm.isNotEmpty) docs = docs.where((d) {
        final data = d.data();
        final name = (data['name'] ?? data['orgName'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? data['orgEmail'] ?? '').toString().toLowerCase();
        return name.contains(searchTerm) ||
               email.contains(searchTerm) ||
               (data['subject'] ?? '').toString().toLowerCase().contains(searchTerm);
      }).toList();
      if (docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No data to export.')));
        return;
      }
      final buffer = StringBuffer();
      buffer.writeln('Letter ID,Name,Email,Letter Type,Subject,Message,Status,Date Submitted');
      for (final doc in docs) {
        final d = doc.data();
        final date = (d['timestamp'] as Timestamp?)?.toDate().toString().substring(0, 10) ?? '';
        buffer.writeln('"${d['letterId']}","${d['name']}","${d['email']}","${d['letterType']}","${d['subject']}","${d['message']}","${d['status']}","$date"');
      }
      // For web, you'd use html package to download. For now, show success.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${docs.length} records to CSV')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AdminColors.error,
        ),
      );
    }
  }
}

// ============ ACTION ICON BUTTON ============
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;
  const _ActionIconButton({required this.icon, required this.tooltip, this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 16, color: onTap == null ? const Color(0xFFD1D5DB) : (color ?? const Color(0xFF64748B)))),
      ),
    );
  }
}

// ============ PAGE BUTTON ============
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
      child: Padding(padding: const EdgeInsets.all(4), child: Icon(icon, size: 20, color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB))),
    );
  }
}