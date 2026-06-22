// lib/screens/web/admin/letter_request.dart - CORRECTED VERSION

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uprise/widgets/admin_export_button.dart';
import 'package:intl/intl.dart';
import 'export_util.dart';
import 'export_pdf.dart';
import '../../../services/activity_logger.dart' as activity_log;
import '../../../services/firestore_collections.dart';
import '../../../utils/platform_file_utils.dart' as platform_file_utils;

// ============ COLOR SCHEME ============
class AdminColors {
  static const Color primaryDark = Color(0xFFEA580C);
  static const Color primaryLight = Color(0xFFFB923C);
  static const Color accent = Color(0xFFF97316);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF9FAFB);
  static const Color mediumGray = Color(0xFFE5E7EB);
  static const Color darkGray = Color(0xFF6B7280);
  static const Color charcoal = Color(0xFF111827);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFFB923C);
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
  String _statusFilter = 'All';
  int _currentPage = 1;
  static const int _pageSize = 10;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _orgLogoCache = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


  Future<String> _fetchOrgLogo(String orgId) async {
    if (_orgLogoCache.containsKey(orgId)) {
      return _orgLogoCache[orgId]!;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('organizations')
          .doc(orgId)
          .get();
      final logoUrl = doc.data()?['logoUrl'] ?? '';
      _orgLogoCache[orgId] = logoUrl;
      return logoUrl;
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 720;
    final isTablet = width >= 720 && width < 1200;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatsRow(isMobile, isTablet),
          _buildToolbar(isMobile, isTablet),
          const SizedBox(height: 16),
          Expanded(child: _buildTable(isMobile, isTablet)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStatsRow(bool isMobile, bool isTablet) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreCollections.letterRequests.snapshots(),
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

        final cards = [
          _StatCard(label: 'Total Requests', value: '$total', icon: Icons.description_rounded, color: AdminColors.primaryDark),
          _StatCard(label: 'Approved', value: '$approved', icon: Icons.check_circle_rounded, color: AdminColors.success),
          _StatCard(label: 'Pending', value: '$pending', icon: Icons.pending_rounded, color: AdminColors.warning),
          _StatCard(label: 'Resubmitted', value: '$resubmitted', icon: Icons.refresh_rounded, color: AdminColors.info),
          _StatCard(label: 'Needs Revision', value: '$revision', icon: Icons.edit_note_rounded, color: AdminColors.purple),
          _StatCard(label: 'Rejected', value: '$rejected', icon: Icons.cancel_rounded, color: AdminColors.error),
        ];

        return Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var card in cards) ...[
                      card,
                      const SizedBox(height: 14),
                    ],
                  ],
                )
              : Row(children: [
                  for (var card in cards) ...[
                    Expanded(child: card),
                    const SizedBox(width: 14),
                  ],
                ]),
        );
      },
    );
  }

  Widget _buildToolbar(bool isMobile, bool isTablet) {
    final searchField = SizedBox(
      height: 40,
      child: TextField(
        controller: _searchController,
        style: GoogleFonts.beVietnamPro(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search letter request…',
          hintStyle: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF9AA5B4)),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF9AA5B4)),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E6EA))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AdminColors.primaryDark, width: 1.5)),
        ),
        onChanged: (_) => setState(() => _currentPage = 1),
      ),
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _FilterDropdown(
          value: _statusFilter,
          items: const ['All', 'Pending', 'Approved', 'Rejected', 'Needs Revision', 'Resubmitted', 'Archived'],
          hint: 'Status',
          icon: Icons.tune_rounded,
          onChanged: (v) => setState(() {
            _statusFilter = v!;
            _currentPage = 1;
          }),
        ),
        _ExportButton(
          statusFilter: _statusFilter,
          searchTerm: _searchController.text.trim(),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [searchField, const SizedBox(height: 10), actions],
            )
          : Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 10),
                actions,
              ],
            ),
    );
  }

  Widget _buildTable(bool isMobile, bool isTablet) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreCollections.letterRequests.orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        var docs = snapshot.data!.docs;

        if (_statusFilter == 'Archived') {
          docs = docs.where((d) => (d.data() as Map)['isArchived'] == true).toList();
        } else {
          // Always hide archived items unless explicitly viewing them
          docs = docs.where((d) => (d.data() as Map)['isArchived'] != true).toList();
          if (_statusFilter != 'All') {
            String filterValue = _statusFilter;
            if (filterValue == 'Needs Revision') filterValue = 'revision';
            if (filterValue == 'Resubmitted') filterValue = 'resubmitted';
            docs = docs.where((d) {
              final status = ((d.data() as Map)['status'] ?? 'pending').toString().toLowerCase();
              return status == filterValue.toLowerCase();
            }).toList();
          }
        }

        final _searchTerm = _searchController.text.trim().toLowerCase();
        if (_searchTerm.isNotEmpty) {
          docs = docs.where((d) {
            final data = d.data() as Map;
            return (data['purpose'] ?? data['title'] ?? '').toString().toLowerCase().contains(_searchTerm) ||
                (data['orgName'] ?? '').toString().toLowerCase().contains(_searchTerm) ||
                (data['requestedBy'] ?? data['submittedBy'] ?? '').toString().toLowerCase().contains(_searchTerm);
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
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, 4))],
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
        color: Color(0xFFFFF7ED),
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        border: Border(bottom: BorderSide(color: Color(0xFFFB923C))),
      ),
      child: Row(children: [
        Expanded(flex: 3, child: _headerCell('REQUESTOR')),
        Expanded(flex: 2, child: _headerCell('LETTER ID')),
        Expanded(flex: 3, child: _headerCell('SUBJECT')),
        Expanded(flex: 2, child: _headerCell('DATE SUBMITTED')),
        Expanded(flex: 2, child: _headerCell('SIGNING DATE')),
        Expanded(flex: 1, child: _headerCell('STATUS')),
        Expanded(flex: 2, child: Align(alignment: Alignment.centerRight, child: _headerCell('ACTIONS'))),
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
    final orgId = data['orgId'] ?? '';
    final subject = data['subject'] ?? 'No subject';
    final letterId = data['letterId'] ?? 'N/A';
    final message = data['message'];

    // Signing appointment, if one was scheduled on approval — same
    // wetSignSchedule-style display as admin/org event_proposals.dart, so
    // it's easy to confirm the org actually received a signing date.
    final signingSchedule = data['signingSchedule'] as Map<String, dynamic>?;
    final signingTs = signingSchedule?['startDateTime'] as Timestamp?;
    final signingStr = signingTs != null
        ? DateFormat('MMM dd, yyyy').format(signingTs.toDate())
        : '—';
    final hasSigningDate = signingTs != null;
    
    return FutureBuilder<String>(
      future: _fetchOrgLogo(orgId),
      builder: (context, logoSnapshot) {
        final logoUrl = logoSnapshot.data ?? '';
        
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
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E6EA)),
                      ),
                      child: logoUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                logoUrl,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _defaultAvatar(),
                              ),
                            )
                          : _defaultAvatar(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        data['orgName'] ?? 'Unknown',
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
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AdminColors.primaryDark.withAlpha(18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      letterId,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AdminColors.primaryDark,
                        letterSpacing: 0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: GoogleFonts.beVietnamPro(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF1A202C),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message != null && message.toString().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message.length > 40 ? '${message.substring(0, 40)}...' : message,
                        style: GoogleFonts.beVietnamPro(
                          fontSize: 11,
                          color: const Color(0xFF9AA5B4),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  date,
                  style: GoogleFonts.beVietnamPro(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: hasSigningDate
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withAlpha(20),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Icon(Icons.edit_calendar_rounded, size: 11, color: Color(0xFF059669)),
                        ),
                        const SizedBox(width: 5),
                        Flexible(child: Text(signingStr,
                            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF059669), fontWeight: FontWeight.w500))),
                      ])
                    : Text('—', style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFFD1D5DB))),
              ),
              Expanded(flex: 1, child: _buildStatusBadge(status)),
              // ============ ACTIONS ============
              // "Request Revision" lives in the View dialog only (matches
              // admin/event_proposals.dart) — keeping it out of the row
              // frees up room so icons stop crowding/overlapping each other.
              Expanded(
                flex: 2,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // View button - always visible
                    _ActionIconButton(
                      icon: Icons.visibility_outlined,
                      tooltip: 'View Details',
                      color: const Color(0xFF3B82F6),
                      onTap: () => _showViewDialog(data, docId),
                    ),

                    // For PENDING or RESUBMITTED: Show Approve, Reject
                    if (status == 'pending' || status == 'resubmitted') ...[
                      const SizedBox(width: 6),
                      _ActionIconButton(
                        icon: Icons.check_circle_outline,
                        tooltip: 'Approve',
                        color: AdminColors.success,
                        onTap: () => _approveWithSigningSchedule(docId, data['orgName'] ?? 'Request'),
                      ),
                      const SizedBox(width: 6),
                      _ActionIconButton(
                        icon: Icons.cancel_outlined,
                        tooltip: 'Reject',
                        color: AdminColors.error,
                        onTap: () => _updateStatus(docId, 'rejected', data['orgName'] ?? 'Request'),
                      ),
                    ],

                    // Archive button - always visible for all statuses
                    const SizedBox(width: 6),
                    _ActionIconButton(
                      icon: Icons.archive_outlined,
                      tooltip: 'Archive',
                      color: AdminColors.warning,
                      onTap: () => _archiveRequest(docId, data['orgName'] ?? 'Request', subject),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }

  Widget _defaultAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AdminColors.primaryDark.withOpacity(0.1),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Icons.business_outlined,
        size: 18,
        color: AdminColors.primaryDark,
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
        style = {'bg': const Color(0xFFFFFBEB), 'fg': const Color(0xFFFB923C), 'label': 'PENDING'};
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
            'Showing ${total == 0 ? 0 : start + 1}–$end of $total requests',
            style: GoogleFonts.beVietnamPro(fontSize: 12, color: const Color(0xFF64748B)),
          ),
          Row(children: [
            _PageButton(icon: Icons.chevron_left_rounded, enabled: _currentPage > 1, onTap: () => setState(() => _currentPage--)),
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
            _PageButton(icon: Icons.chevron_right_rounded, enabled: _currentPage < totalPages, onTap: () => setState(() => _currentPage++)),
          ]),
        ],
      ),
    );
  }

  Future<void> _archiveRequest(String docId, String orgName, String subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive Request'),
        content: Text('Archive request from "$orgName" about "$subject"? You can still view it in the archived section.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AdminColors.warning),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await FirestoreCollections.letterRequests.doc(docId).update({
        'isArchived': true,
        'archivedAt': FieldValue.serverTimestamp(),
      });
      await activity_log.ActivityLogger.log(
        action: 'archive_letter_request',
        module: 'Letter Request',
        severity: 'warning',
        details: {'docId': docId, 'orgName': orgName},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request archived successfully'), backgroundColor: AdminColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AdminColors.error),
        );
      }
    }
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
      await FirestoreCollections.letterRequests.doc(docId).update(updateData);
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

  // ── Approve + schedule signing appointment, same flow as the wet-sign
  // scheduling popup in admin/event_proposals.dart's proposal approval. ──
  void _approveWithSigningSchedule(String docId, String orgName) {
    final dateCtrl = TextEditingController();
    final startTimeCtrl = TextEditingController();
    final endTimeCtrl = TextEditingController();
    final locationCtrl = TextEditingController(text: "Dean's Office");
    DateTime? selectedDate;
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Container(
              width: 500,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF059669), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Schedule Signing Appointment',
                        style: GoogleFonts.beVietnamPro(fontSize: 17, fontWeight: FontWeight.w700, color: const Color(0xFF1A202C)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 20),
                  Text(
                    'Set your office availability for $orgName to sign the letter.',
                    style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Select Date *',
                      hintText: 'MM/DD/YYYY',
                      prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) {
                        selectedDate = picked;
                        dateCtrl.text = DateFormat('MM/dd/yyyy').format(picked);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: startTimeCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Start Time *',
                      hintText: '-- : --',
                      prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                      if (picked != null) {
                        startTime = picked;
                        startTimeCtrl.text = picked.format(ctx);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: endTimeCtrl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'End Time *',
                      hintText: '-- : --',
                      prefixIcon: const Icon(Icons.access_time_rounded, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: startTime ?? TimeOfDay.now(),
                      );
                      if (picked != null) {
                        endTime = picked;
                        endTimeCtrl.text = picked.format(ctx);
                        setDialogState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: locationCtrl,
                    decoration: InputDecoration(
                      labelText: 'Office Location *',
                      hintText: "e.g., Dean's Office Room 101",
                      prefixIcon: const Icon(Icons.location_on_outlined, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _updateStatus(docId, 'approved', orgName);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E6EA)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        ),
                        child: Text('Skip', style: GoogleFonts.beVietnamPro(fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedDate == null || startTime == null || endTime == null) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Please fill all required fields'), backgroundColor: Colors.orange),
                            );
                            return;
                          }

                          final startDateTime = DateTime(
                            selectedDate!.year, selectedDate!.month, selectedDate!.day,
                            startTime!.hour, startTime!.minute,
                          );
                          final endDateTime = DateTime(
                            selectedDate!.year, selectedDate!.month, selectedDate!.day,
                            endTime!.hour, endTime!.minute,
                          );

                          await _saveSigningSchedule(
                            docId: docId,
                            orgName: orgName,
                            startDateTime: startDateTime,
                            endDateTime: endDateTime,
                            location: locationCtrl.text.trim(),
                          );

                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                        ),
                        child: Text('Save Schedule', style: GoogleFonts.beVietnamPro(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveSigningSchedule({
    required String docId,
    required String orgName,
    required DateTime startDateTime,
    required DateTime endDateTime,
    required String location,
  }) async {
    try {
      final signingSchedule = {
        'startDateTime': Timestamp.fromDate(startDateTime),
        'endDateTime': Timestamp.fromDate(endDateTime),
        'location': location,
        'status': 'scheduled',
        'scheduledBy': FirebaseAuth.instance.currentUser?.uid ?? '',
        'scheduledAt': FieldValue.serverTimestamp(),
      };

      await FirestoreCollections.letterRequests.doc(docId).update({
        'status': 'approved',
        'signingSchedule': signingSchedule,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await activity_log.ActivityLogger.log(
        action: 'schedule_letter_signing',
        module: 'Letter Request',
        details: {
          'docId': docId,
          'orgName': orgName,
          'startDateTime': startDateTime.toIso8601String(),
          'location': location,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Approved and signing appointment scheduled!'),
            backgroundColor: AdminColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AdminColors.error),
        );
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
    final message = data['message'];
    final orgId = data['orgId'] ?? '';
    final orgName = data['orgName'] ?? 'Unknown';
    final letterId = data['letterId'] ?? 'N/A';
    final subject = data['subject'] ?? 'No subject';

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<String>(
        future: _fetchOrgLogo(orgId),
        builder: (context, logoSnapshot) {
          final logoUrl = logoSnapshot.data ?? '';
          
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: SizedBox(
              width: 540,
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
                        decoration: BoxDecoration(color: Colors.white.withAlpha(38), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.mail_outline_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(letterId, style: GoogleFonts.beVietnamPro(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text(subject, style: GoogleFonts.beVietnamPro(fontSize: 12, color: Colors.white.withAlpha(166))),
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E6EA)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFE2E6EA)),
                                ),
                                child: logoUrl.isNotEmpty
                                    ? ClipOval(
                                        child: Image.network(
                                          logoUrl,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                                        ),
                                      )
                                    : _defaultAvatar(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      orgName,
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF1A202C),
                                      ),
                                    ),
                                    Text(
                                      data['orgEmail'] ?? '',
                                      style: GoogleFonts.beVietnamPro(
                                        fontSize: 12,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                              Text(subject, style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                            ],
                          ),
                        ),
                        if (message != null && message.toString().isNotEmpty) ...[
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
                                Text('Message', style: GoogleFonts.beVietnamPro(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                                const SizedBox(height: 6),
                                Text(message.toString(), style: GoogleFonts.beVietnamPro(fontSize: 13, color: const Color(0xFF374151))),
                              ],
                            ),
                          ),
                        ],
                        if (revisionNote != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AdminColors.info.withAlpha(13),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AdminColors.info.withAlpha(76)),
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
                        if (hasAttachment) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AdminColors.primaryDark.withAlpha(13),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AdminColors.primaryDark.withAlpha(51)),
                            ),
                            child: Row(children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: AdminColors.primaryDark.withAlpha(26), borderRadius: BorderRadius.circular(8)),
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
                  // Footer buttons sa dialog (View mode) - keep as is
                  if (status == 'pending' || status == 'revision' || status == 'resubmitted')
                    Container(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _updateStatus(docId, 'rejected', orgName);
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
                              _approveWithSigningSchedule(docId, orgName);
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
          );
        },
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
                  platform_file_utils.saveBytesToTempAndOpen(bytes, fileName, mimeType: mime);
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
                OverflowBar(
                  spacing: 8,
                  alignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    TextButton(onPressed: () {
                      Navigator.pop(ctx);
                      platform_file_utils.saveBytesToTempAndOpen(bytes, fileName, mimeType: mime);
                    }, child: const Text('Download')),
                  ],
                ),
              ]),
            ),
          );
        }
        return;
      }
      
      await platform_file_utils.saveBytesToTempAndOpen(bytes, fileName, mimeType: mime);
    } catch (e) {
      debugPrint('Error opening file: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error opening file: $e'), backgroundColor: AdminColors.error));
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
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(12)),
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
    return AdminExportButton(onSelected: (choice) => _doExport(context, choice));
  }

  Future<void> _doExport(BuildContext context, String format) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      var snap = await FirestoreCollections.letterRequests.orderBy('timestamp', descending: true).get();
      var docs = snap.docs;
      if (statusFilter != 'All') {
        final fv = statusFilter == 'Needs Revision' ? 'revision' : statusFilter.toLowerCase();
        docs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>?;
          return (data?['status'] ?? '').toString().toLowerCase() == fv;
        }).toList();
      }
      if (searchTerm.isNotEmpty) {
        docs = docs.where((d) {
          final data = d.data() as Map<String, dynamic>?;
          final name = (data?['orgName'] ?? '').toString().toLowerCase();
          final subject = (data?['subject'] ?? '').toString().toLowerCase();
          final message = (data?['message'] ?? '').toString().toLowerCase();
          return name.contains(searchTerm) || subject.contains(searchTerm) || message.contains(searchTerm);
        }).toList();
      }
      if (docs.isEmpty) {
        messenger.showSnackBar(const SnackBar(content: Text('No data to export.')));
        return;
      }

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      if (format == 'csv') {
        final buffer = StringBuffer();
        buffer.writeln('Letter ID,Organization,Subject,Message,Status,Date Submitted');
        for (final doc in docs) {
          final d = doc.data() as Map<String, dynamic>?;
          final date = (d?['timestamp'] as Timestamp?)?.toDate().toString().substring(0, 10) ?? '';
          final message = (d?['message'] ?? '').toString();
          String escape(String value) => '"${value.replaceAll('"', '""')}"';
          buffer.writeln([
            escape(d?['letterId'] ?? ''),
            escape(d?['orgName'] ?? ''),
            escape(d?['subject'] ?? ''),
            escape(message),
            escape(d?['status'] ?? ''),
            escape(date),
          ].join(','));
        }
        final fileName = 'letter_requests_$now.csv';
        await AdminExportUtil.saveText(buffer.toString(), fileName, mimeType: 'text/csv');
        messenger.showSnackBar(SnackBar(content: Text('Download started: $fileName')));
      } else if (format == 'pdf') {
        final rows = docs.map((doc) {
          final d = doc.data() as Map<String, dynamic>?;
          final date = (d?['timestamp'] as Timestamp?)?.toDate().toString().substring(0, 10) ?? '';
          return [
            d?['letterId'] ?? '',
            d?['orgName'] ?? '',
            d?['subject'] ?? '',
            d?['message'] ?? '',
            d?['status'] ?? '',
            date,
          ].map((value) => value.toString()).toList();
        }).toList();

        final pdfBytes = await AdminExportPdf.generateTablePdf(
          title: 'Letter Requests Report',
          headers: const ['Letter ID', 'Organization', 'Subject', 'Message', 'Status', 'Date Submitted'],
          rows: rows,
        );
        final fileName = 'letter_requests_$now.pdf';
        await AdminExportUtil.saveBytes(pdfBytes, fileName, mimeType: 'application/pdf');
        messenger.showSnackBar(SnackBar(content: Text('Download started: $fileName')));
      } else {
        throw UnsupportedError('Unsupported export format: $format');
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: AdminColors.error,
        ),
      );
    }
  }
}

// ============ ACTION ICON BUTTON ============
// Compact colored chip — matches the icon actions in org_event_proposals.dart
// / organization_management.dart / student_accounts.dart / adviser_roles.dart
// / event_proposals.dart, instead of a bare unstyled icon.
class _ActionIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _ActionIconButton({required this.icon, required this.tooltip, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 400),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
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

class _PageNumButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;
  const _PageNumButton({required this.page, required this.isActive, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        width: 30, height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AdminColors.primaryDark : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive ? null : Border.all(color: const Color(0xFFE4E8EF)),
          boxShadow: isActive ? [BoxShadow(color: AdminColors.primaryDark.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Text('$page',
            style: GoogleFonts.beVietnamPro(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF374151))),
      ),
    );
  }
}